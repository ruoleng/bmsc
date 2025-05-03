import 'dart:collection';
import 'dart:io';
import 'package:bmsc/database_manager.dart';
import 'package:bmsc/model/download_task.dart';
import 'package:bmsc/service/bilibili_service.dart';
import 'package:bmsc/service/shared_preferences_service.dart';
import 'package:bmsc/util/logger.dart';
import 'package:path/path.dart' as path;
import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sqflite/sqflite.dart';

class DownloadManager {
  int maxConcurrentDownloads = 3;
  late final String downloadPath;

  static final _logger = LoggerUtils.getLogger('DownloadManager');
  final _dio = Dio();
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
    downloadPath = await SharedPreferencesService.getDownloadPath();
    final dir = Directory(downloadPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Load tasks from database
    await _loadTasksFromDatabase();
  }

  Future<void> _loadTasksFromDatabase() async {
    // Load completed downloads
    final downloads = await DatabaseManager.getAllDownloadTasks();
    final tasks = <String, DownloadTask>{};

    for (final task in downloads) {
      final taskId = '${task.bvid}-${task.cid}';
      tasks[taskId] = task;

      // Add pending or paused tasks to the queue
      if (task.status == DownloadStatus.pending ||
          task.status == DownloadStatus.paused) {
        if (task.status == DownloadStatus.pending) {
          _downloadQueue.add(task);
        }
      }
    }

    _taskController.add(tasks);
  }

  Stream<Map<String, DownloadTask>> get tasksStream => _taskController.stream;

  Future<Map<String, DownloadTask>> get tasks async {
    final allTasks = await DatabaseManager.getAllDownloadTasks();
    final tasksMap = <String, DownloadTask>{};
    for (final task in allTasks) {
      tasksMap['${task.bvid}-${task.cid}'] = task;
    }
    return Map.unmodifiable(tasksMap);
  }

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
        final existingTask =
            await DatabaseManager.getDownloadTask(bvid, part.cid);
        if (existingTask != null) {
          continue;
        }

        final task = DownloadTask(
          bvid: bvid,
          cid: part.cid,
          status: DownloadStatus.pending,
        );

        await DatabaseManager.saveDownloadTask(task);
        _downloadQueue.add(task);
      }

      // Update the task controller with the latest tasks
      final updatedTasks = await tasks;
      _taskController.add(updatedTasks);
    }));

    _processQueue();
  }

  Future<void> addTasks(List<(String, int)> bvidscids) async {
    for (var (bvid, cid) in bvidscids) {
      final existingTask = await DatabaseManager.getDownloadTask(bvid, cid);
      if (existingTask != null) {
        continue;
      }

      final task = DownloadTask(
        bvid: bvid,
        cid: cid,
        status: DownloadStatus.pending,
      );

      await DatabaseManager.saveDownloadTask(task);
      _downloadQueue.add(task);
    }

    // Update the task controller with the latest tasks
    final updatedTasks = await tasks;
    _taskController.add(updatedTasks);

    _processQueue();
  }

  Future<void> removeDownloaded(List<(String, int)> bvidscids) async {
    // First, get all paths outside the transaction
    final pathsToDelete = await Future.wait(bvidscids
        .map((tuple) => DatabaseManager.getDownloadPath(tuple.$1, tuple.$2)));

    // Delete files outside the transaction
    for (final path in pathsToDelete) {
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          _logger.info('Removed downloaded file: $path');
        }
      }
    }

    // Now handle the database operations in a transaction
    final db = await DatabaseManager.database;
    await db.transaction((txn) async {
      for (var (bvid, cid) in bvidscids) {
        await txn.delete(
          DatabaseManager.downloadTable,
          where: 'bvid = ? AND cid = ?',
          whereArgs: [bvid, cid],
        );

        await txn.delete(
          DatabaseManager.downloadTaskTable,
          where: 'bvid = ? AND cid = ?',
          whereArgs: [bvid, cid],
        );
      }
    });

    // Update the task controller with the latest tasks
    final updatedTasks = await tasks;
    _taskController.add(updatedTasks);
  }

  Future<void> pauseTask(String taskId) async {
    final parts = taskId.split('-');
    if (parts.length != 2) return;

    final bvid = parts[0];
    final cid = int.parse(parts[1]);

    final task = await DatabaseManager.getDownloadTask(bvid, cid);
    if (task == null) return;

    if (task.status == DownloadStatus.downloading) {
      task.cancelToken?.cancel('Paused by user');
      task.status = DownloadStatus.paused;
      await DatabaseManager.updateDownloadTaskStatus(
          bvid, cid, DownloadStatus.paused);
      _activeDownloads.remove(taskId);

      // Update the task controller with the latest tasks
      final updatedTasks = await tasks;
      _taskController.add(updatedTasks);

      _processQueue();
    } else if (task.status == DownloadStatus.pending) {
      await DatabaseManager.updateDownloadTaskStatus(
          bvid, cid, DownloadStatus.paused);
      _downloadQueue.removeWhere((t) => '${t.bvid}-${t.cid}' == taskId);

      // Update the task controller with the latest tasks
      final updatedTasks = await tasks;
      _taskController.add(updatedTasks);
    }
  }

  Future<void> resumeTask(String taskId) async {
    final parts = taskId.split('-');
    if (parts.length != 2) return;

    final bvid = parts[0];
    final cid = int.parse(parts[1]);

    final task = await DatabaseManager.getDownloadTask(bvid, cid);
    if (task == null) return;

    if (task.status == DownloadStatus.paused ||
        task.status == DownloadStatus.failed) {
      task.status = DownloadStatus.pending;
      await DatabaseManager.updateDownloadTaskStatus(
          bvid, cid, DownloadStatus.pending);
      _downloadQueue.add(task);

      // Update the task controller with the latest tasks
      final updatedTasks = await tasks;
      _taskController.add(updatedTasks);

      _processQueue();
    }
  }

  Future<void> cancelTask(String taskId) async {
    final parts = taskId.split('-');
    if (parts.length != 2) return;

    final bvid = parts[0];
    final cid = int.parse(parts[1]);

    final task = await DatabaseManager.getDownloadTask(bvid, cid);
    if (task == null) return;

    task.cancelToken?.cancel('Cancelled by user');

    // Remove the task from the database
    await DatabaseManager.removeDownloadTask(bvid, cid);

    _downloadQueue.removeWhere((t) => '${t.bvid}-${t.cid}' == taskId);
    _activeDownloads.remove(taskId);

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

    // Update the task controller with the latest tasks
    final updatedTasks = await tasks;
    _taskController.add(updatedTasks);
  }

  void _processQueue() async {
    while (_activeDownloads.length < maxConcurrentDownloads &&
        _downloadQueue.isNotEmpty) {
      final task = _downloadQueue.removeFirst();
      final taskId = '${task.bvid}-${task.cid}';

      final dbTask = await DatabaseManager.getDownloadTask(task.bvid, task.cid);
      if (dbTask == null) continue;

      final fileName = '${task.bvid}-${task.cid}.m4a';
      final targetPath = path.join(downloadPath, fileName.replaceAll(' ', '-'));

      // Update the target path in the database
      task.targetPath = targetPath;
      await DatabaseManager.saveDownloadTask(task);

      final localPath =
          await DatabaseManager.getCachedPath(task.bvid, task.cid);
      if (localPath != null) {
        _logger
            .info('Cached file found, copying it to target path: $localPath');
        File(localPath).copySync(targetPath);

        // Update task status to completed
        await DatabaseManager.updateDownloadTaskStatus(
            task.bvid, task.cid, DownloadStatus.completed);
        await DatabaseManager.updateDownloadTaskProgress(
            task.bvid, task.cid, 1.0);

        // Save to downloads table
        await DatabaseManager.saveDownload(task.bvid, task.cid, targetPath);

        // Update the task controller with the latest tasks
        final updatedTasks = await tasks;
        _taskController.add(updatedTasks);

        continue;
      }

      _activeDownloads.add(taskId);

      // Update task status to downloading
      await DatabaseManager.updateDownloadTaskStatus(
          task.bvid, task.cid, DownloadStatus.downloading);
      task.status = DownloadStatus.downloading;
      task.cancelToken = CancelToken();

      // Update the task controller with the latest tasks
      final updatedTasks = await tasks;
      _taskController.add(updatedTasks);

      _logger.info('Downloading ${task.bvid}-${task.cid}');

      try {
        final audios = await (await BilibiliService.instance)
            .getAudio(task.bvid, task.cid);
        final url = audios?.first.baseUrl;
        if (url == null) {
          throw Exception('Failed to get audio URL');
        }

        final tempPath = '$targetPath.temp';
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
        double lastProgress = 0;
        int lastUpdateTime = DateTime.now().millisecondsSinceEpoch;
        const progressThreshold = 0.01; // Update every 1% change
        const timeThreshold = 100; // Or every 100ms, whichever comes first

        await response.data.stream.listen(
          (List<int> chunk) {
            raf.writeFromSync(chunk);
            received += chunk.length;
            if (totalBytes != -1) {
              final progress = received / totalBytes;
              final now = DateTime.now().millisecondsSinceEpoch;
              final timeDiff = now - lastUpdateTime;

              // Update if progress changed significantly or enough time has passed
              if ((progress - lastProgress).abs() >= progressThreshold ||
                  timeDiff >= timeThreshold) {
                // Update progress in the database
                DatabaseManager.updateDownloadTaskProgress(
                    task.bvid, task.cid, progress);
                task.progress = progress;

                // Update the task controller
                _taskController.add({..._taskController.value, taskId: task});

                lastProgress = progress;
                lastUpdateTime = now;
              }
            }
          },
          onDone: () async {
            await raf.close();
            // Rename temp file to target file before database operations
            await file.rename(targetPath);

            _logger.info('Download task ${task.bvid}-${task.cid} completed');

            // Use a single transaction for all database operations
            final db = await DatabaseManager.database;
            await db.transaction((txn) async {
              // Save to downloads table
              await txn.insert(
                DatabaseManager.downloadTable,
                {
                  'bvid': task.bvid,
                  'cid': task.cid,
                  'filePath': targetPath,
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );

              // Update task status to completed
              await txn.update(
                DatabaseManager.downloadTaskTable,
                {
                  'status': DownloadStatus.completed.index,
                  'progress': 1.0,
                },
                where: 'bvid = ? AND cid = ?',
                whereArgs: [task.bvid, task.cid],
              );
            });

            _activeDownloads.remove(taskId);
            task.cancelToken = null;

            // Update the task controller with the latest tasks
            final updatedTasks = await DatabaseManager.getAllDownloadTasks();
            _taskController.add(Map.fromEntries(
                updatedTasks.map((t) => MapEntry('${t.bvid}-${t.cid}', t))));

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

  void dispose() {
    _taskController.close();
  }

  void _handleDownloadError(DownloadTask task, String taskId, dynamic error) {
    if (task.cancelToken != null && !task.cancelToken!.isCancelled) {
      // Update task status to failed
      DatabaseManager.updateDownloadTaskStatus(
          task.bvid, task.cid, DownloadStatus.failed);
      task.status = DownloadStatus.failed;
      task.error = error.toString();
      _logger.severe('Download failed: $taskId', error);
    }

    _activeDownloads.remove(taskId);
    task.cancelToken = null;

    // Update the task controller
    _taskController.add({..._taskController.value, taskId: task});

    _processQueue();
  }
}
