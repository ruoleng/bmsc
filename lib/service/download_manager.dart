import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:bmsc/database_manager.dart';
import 'package:bmsc/model/download_task.dart';
import 'package:bmsc/service/bilibili_service.dart';
import 'package:bmsc/service/shared_preferences_service.dart';
import 'package:bmsc/util/logger.dart';
import 'package:path/path.dart' as path;
import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadManager {
  int maxConcurrentDownloads = 3;
  static const String downloadPath = '/storage/emulated/0/Download/BMSC';

  static final _logger = LoggerUtils.getLogger('DownloadManager');
  final _dio = Dio();
  final _tasks = <String, DownloadTask>{};
  final _downloadQueue = Queue<DownloadTask>();
  final _activeDownloads = <String>{};

  final _taskController = BehaviorSubject<Map<String, DownloadTask>>.seeded({});

  static final instance = _instance();

  static Future<DownloadManager> _instance() async {
    final headers = (await BilibiliService.instance).headers;
    final instance = DownloadManager();
    instance.maxConcurrentDownloads =
        await SharedPreferencesService.getMaxConcurrentDownloads();
    SharedPreferencesService.maxConcurrentDownloadsStream.listen((value) {
      _logger.info('maxConcurrentDownloads changed to $value');
      instance.maxConcurrentDownloads = value;
      instance._processQueue();
    });

    instance._dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers = headers;
        return handler.next(options);
      },
    ));
    instance._init();
    return instance;
  }

  Future<void> _init() async {
    final dir = Directory(downloadPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    await _restoreTasks();

    final db = await DatabaseManager.database;
    final downloads = await db.query(DatabaseManager.downloadTable);

    for (final download in downloads) {
      final bvid = download['bvid'] as String;
      final cid = download['cid'] as int;
      final filePath = download['filePath'] as String;

      if (!await File(filePath).exists()) {
        continue;
      }

      final entity = await DatabaseManager.getEntity(bvid, cid);
      if (entity == null) {
        continue;
      }

      final task = DownloadTask(
        bvid: bvid,
        cid: cid,
        status: DownloadStatus.completed,
        progress: 1.0,
        targetPath: filePath,
      );

      _tasks['$bvid-$cid'] = task;
    }

    _taskController.add(_tasks);
  }

  Stream<Map<String, DownloadTask>> get tasksStream => _taskController.stream;
  Map<String, DownloadTask> get tasks => Map.unmodifiable(_tasks);

  Future<void> addBvidTasks(List<String> bvids) async {
    await Future.wait(bvids.map((bvid) async {
      final vid =
          await (await BilibiliService.instance).getVidDetail(bvid: bvid);
      if (vid == null) {
        return;
      }

      if (await DatabaseManager.downloadedCount(bvid) != 0) {
        return;
      }

      for (var part in vid.pages) {
        final taskId = '$bvid-${part.cid}';
        if (_tasks.containsKey(taskId)) {
          continue;
        }
        final task = DownloadTask(
          bvid: bvid,
          cid: part.cid,
        );
        _tasks[taskId] = task;
        _downloadQueue.add(task);
      }
      _taskController.add(_tasks);
    }));

    await _saveTasks();
    _processQueue();
  }

  Future<void> addTasks(List<(String, int)> bvidscids) async {
    for (var (bvid, cid) in bvidscids) {
      final taskId = '$bvid-$cid';
      if (_tasks.containsKey(taskId)) {
        continue;
      }
      final task = DownloadTask(
        bvid: bvid,
        cid: cid,
      );
      _tasks[taskId] = task;
      _downloadQueue.add(task);
      _taskController.add(_tasks);
    }
    await _saveTasks();
    _processQueue();
  }

  Future<void> removeDownloaded(List<(String, int)> bvidscids) async {
    for (var (bvid, cid) in bvidscids) {
      final taskId = '$bvid-$cid';
      _tasks.remove(taskId);
      final path = await DatabaseManager.getDownloadPath(bvid, cid);
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          _logger.info('Removed downloaded file: $path');
        }
      }
    }
    await DatabaseManager.removeDownloaded(bvidscids);
  }

  Future<void> pauseTask(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;

    if (task.status == DownloadStatus.downloading) {
      task.cancelToken?.cancel('Paused by user');
      task.status = DownloadStatus.paused;
      _activeDownloads.remove(taskId);
      _taskController.add(_tasks);
      await _saveTasks();
      _processQueue();
    } else if (task.status == DownloadStatus.pending) {
      task.status = DownloadStatus.paused;
      _downloadQueue.removeWhere((t) => '${t.bvid}-${t.cid}' == taskId);
      _taskController.add(_tasks);
      await _saveTasks();
    }
  }

  Future<void> resumeTask(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;

    if (task.status == DownloadStatus.paused ||
        task.status == DownloadStatus.failed) {
      task.status = DownloadStatus.pending;
      _downloadQueue.add(task);
      _taskController.add(_tasks);
      _processQueue();
    }
  }

  Future<void> cancelTask(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;

    task.cancelToken?.cancel('Cancelled by user');
    task.status = DownloadStatus.canceled;
    _tasks.remove(taskId);
    _downloadQueue.removeWhere((t) => '${t.bvid}-${t.cid}' == taskId);
    _activeDownloads.remove(taskId);
    _taskController.add(_tasks);

    if (task.targetPath != null) {
      final file = File(task.targetPath!);
      if (await file.exists()) {
        await file.delete();
      }
      final tempFile = File('${task.targetPath}.temp');
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }

    await _saveTasks();
  }

  void _processQueue() async {
    while (_activeDownloads.length < maxConcurrentDownloads &&
        _downloadQueue.isNotEmpty) {
      final task = _downloadQueue.removeFirst();
      final taskId = '${task.bvid}-${task.cid}';

      if (!_tasks.containsKey(taskId)) continue;

      final fileName = '${task.bvid}-${task.cid}.mp3';
      task.targetPath = path.join(downloadPath, fileName.replaceAll(' ', '-'));

      final localPath =
          await DatabaseManager.getCachedPath(task.bvid, task.cid);
      if (localPath != null) {
        _logger
            .info('Cached file found, copying it to target path: $localPath');
        File(localPath).copySync(task.targetPath!);
        task.status = DownloadStatus.completed;
        task.progress = 1.0;
        _taskController.add(_tasks);
        continue;
      }
      _activeDownloads.add(taskId);
      task.status = DownloadStatus.downloading;
      task.cancelToken = CancelToken();
      _taskController.add(_tasks);

      _logger.info('Downloading ${task.bvid}-${task.cid}');

      try {
        final audios = await (await BilibiliService.instance)
            .getAudio(task.bvid, task.cid);
        final url = audios?.first.baseUrl;
        if (url == null) {
          throw Exception('Failed to get audio URL');
        }

        final tempPath = '${task.targetPath}.temp';
        int startBytes = 0;

        if (await File(tempPath).exists()) {
          startBytes = await File(tempPath).length();
          _logger.info('Resuming download from $startBytes bytes');
        }

        final options = Options(
          headers: {
            'Range': 'bytes=$startBytes-',
          },
          responseType: ResponseType.stream,
        );

        final response = await _dio.get(
          url,
          options: options,
          cancelToken: task.cancelToken,
        );

        final total =
            int.parse(response.headers.value('content-length') ?? '-1');
        final contentRange = response.headers.value('content-range');
        final totalBytes = contentRange != null
            ? int.parse(contentRange.split('/').last)
            : total + startBytes;

        final file = File(tempPath);
        final raf = await file.open(mode: FileMode.append);

        int received = startBytes;

        await response.data.stream.listen(
          (List<int> chunk) {
            raf.writeFromSync(chunk);
            received += chunk.length;
            if (totalBytes != -1) {
              task.progress = received / totalBytes;
              _taskController.add(_tasks);
            }
          },
          onDone: () async {
            await raf.close();
            // 下载完成后，将临时文件重命名为目标文件
            await file.rename(task.targetPath!);

            _logger.info('Download task ${task.bvid}-${task.cid} completed');
            await DatabaseManager.saveDownload(
                task.bvid, task.cid, task.targetPath!);

            task.status = DownloadStatus.completed;
            task.progress = 1.0;
            _activeDownloads.remove(taskId);
            task.cancelToken = null;
            _taskController.add(_tasks);
            await _saveTasks();
            _processQueue();
          },
          onError: (error) async {
            await raf.close();
            _handleDownloadError(task, taskId, error);
          },
          cancelOnError: true,
        );
      } catch (e) {
        _handleDownloadError(task, taskId, e);
      }
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = _tasks.values
        .where((task) =>
            task.status != DownloadStatus.completed &&
            task.status != DownloadStatus.canceled &&
            task.status != DownloadStatus.failed)
        .map((task) => task.toJson())
        .toList();
    await prefs.setString('download_tasks', jsonEncode(tasksJson));
  }

  Future<void> _restoreTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = prefs.getString('download_tasks');
    if (tasksJson != null) {
      final List<dynamic> tasksList = jsonDecode(tasksJson);
      for (final taskJson in tasksList) {
        final task = DownloadTask.fromJson(taskJson);
        final taskId = '${task.bvid}-${task.cid}';
        _tasks[taskId] = task;

        if (task.status == DownloadStatus.downloading) {
          task.status = DownloadStatus.pending;
        }
      }
      _taskController.add(_tasks);
    }
  }

  void dispose() {
    _taskController.close();
  }

  void _handleDownloadError(DownloadTask task, String taskId, dynamic error) {
    if (!task.cancelToken!.isCancelled) {
      task.status = DownloadStatus.failed;
      task.error = error.toString();
      _logger.severe('Download failed: $taskId', error);
    }
    _activeDownloads.remove(taskId);
    task.cancelToken = null;
    _taskController.add(_tasks);
    _saveTasks();
    _processQueue();
  }
}
