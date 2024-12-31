import 'dart:convert';
import 'dart:io';

import 'package:bmsc/audio/lazy_audio_source.dart';
import 'package:bmsc/model/myinfo.dart';
import 'package:bmsc/model/playlist_data.dart';
import 'package:bmsc/util/logger.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rxdart/subjects.dart';

final _logger = LoggerUtils.getLogger('SharedPreferencesService');

class SharedPreferencesService {
  static final instance = _instance();
  static final _maxConcurrentDownloadsController = BehaviorSubject<int>();
  static final _downloadPathController = BehaviorSubject<String>();
  static Stream<int> get maxConcurrentDownloadsStream =>
      _maxConcurrentDownloadsController.stream;
  static Stream<String> get downloadPathStream =>
      _downloadPathController.stream;

  static Future<SharedPreferences> _instance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs;
  }

  /// 单位为MB
  static Future<void> setCacheLimitSize(int size) async {
    final prefs = await instance;
    await prefs.setInt('cacheLimitSize', size);
  }

  /// 单位为MB
  static Future<int> getCacheLimitSize() async {
    final prefs = await instance;
    return prefs.getInt('cacheLimitSize') ?? 300;
  }

  static Future<String> getDownloadPath() async {
    final prefs = await instance;
    final value =
        prefs.getString('downloadPath') ?? '/storage/emulated/0/Download/BMSC';
    return value;
  }

  static Future<void> setDownloadPath(String value) async {
    final prefs = await instance;
    await prefs.setString('downloadPath', value);
    _downloadPathController.add(value);
  }

  static Future<int> getMaxConcurrentDownloads() async {
    final prefs = await instance;
    final value = prefs.getInt('maxConcurrentDownloads') ?? 3;
    return value;
  }

  static Future<void> setMaxConcurrentDownloads(int value) async {
    final prefs = await instance;
    await prefs.setInt('maxConcurrentDownloads', value);
    _maxConcurrentDownloadsController.add(value);
  }

  static Future<bool> getReadFromClipboard() async {
    final prefs = await instance;
    return prefs.getBool('readFromClipboard') ?? true;
  }

  static Future<void> setReadFromClipboard(bool value) async {
    final prefs = await instance;
    await prefs.setBool('readFromClipboard', value);
  }

  static Future<void> setUID(int uid) async {
    final prefs = await instance;
    await prefs.setInt('uid', uid);
  }

  static Future<int?> getUID() async {
    final prefs = await instance;
    return prefs.getInt('uid');
  }

  static Future<void> setCookie(String cookie) async {
    final prefs = await instance;
    await prefs.setString('cookie', cookie);
  }

  static Future<String?> getCookie() async {
    final prefs = await instance;
    return prefs.getString('cookie');
  }

  static Future<(int, String)?> getDefaultFavFolder() async {
    final prefs = await instance;
    final id = prefs.getInt('default_fav_folder');
    final name = prefs.getString('default_fav_folder_name');
    return id != null && name != null ? (id, name) : null;
  }

  static Future<void> setDefaultFavFolder(int id, String name) async {
    final prefs = await instance;
    await prefs.setInt('default_fav_folder', id);
    await prefs.setString('default_fav_folder_name', name);
  }

  static Future<void> setMyInfo(MyInfo info) async {
    final prefs = await instance;
    await prefs.setInt('my_info_mid', info.mid);
    await prefs.setString('my_info_name', info.name);
    await prefs.setString('my_info_face', info.face);
    await prefs.setString('my_info_sign', info.sign);
  }

  static Future<MyInfo?> getMyInfo() async {
    final prefs = await instance;
    final mid = prefs.getInt('my_info_mid');
    final name = prefs.getString('my_info_name');
    final face = prefs.getString('my_info_face');
    final sign = prefs.getString('my_info_sign');
    return mid != null && name != null && face != null && sign != null
        ? MyInfo(mid, name, face, sign)
        : null;
  }

  static Future<int> getPlayMode() async {
    final prefs = await SharedPreferencesService.instance;
    return prefs.getInt('playmode') ?? 0;
  }

  static Future<void> setPlayMode(int mode) async {
    final prefs = await SharedPreferencesService.instance;
    await prefs.setInt('playmode', mode);
  }

  static Future<void> savePlaylist(
      ConcatenatingAudioSource playlist, AudioPlayer player) async {
    final prefs = await SharedPreferencesService.instance;
    final playlistData =
        await Future.wait(playlist.children.map((source) async {
      if ((source is UriAudioSource || source is LazyAudioSource)) {
        final String uri = source is UriAudioSource
            ? source.uri.toString()
            : (source as LazyAudioSource).isLocal
                ? "file://${(await source.localFile).path}"
                : "";
        final tag = (source as IndexedAudioSource).tag as MediaItem;

        final dummy = tag.extras?['dummy'] ?? false;
        return PlaylistData(
          id: tag.id,
          title: tag.title,
          artist: tag.artist ?? '',
          artUri: tag.artUri?.toString() ?? '',
          audioUri: dummy ? 'asset:///assets/silent.m4a' : uri.toString(),
          bvid: tag.extras?['bvid'] ?? '',
          aid: tag.extras?['aid'] ?? 0,
          cid: tag.extras?['cid'] ?? 0,
          multi: tag.extras?['multi'] ?? false,
          rawTitle: tag.extras?['raw_title'] ?? '',
          mid: tag.extras?['mid'] ?? 0,
          cached: tag.extras?['cached'] ?? false,
          dummy: dummy,
        ).toJson();
      }
    }).toList());

    await prefs.setString('playlist', jsonEncode(playlistData));
    await prefs.setInt('currentIndex', player.currentIndex ?? 0);
  }

  static Future<(List<IndexedAudioSource>, int)?> getPlaylist() async {
    _logger.info('Restoring playlist from preferences');
    final prefs = await SharedPreferencesService.instance;
    final playlistJson = prefs.getString('playlist');

    if (playlistJson == null) {
      _logger.info('No saved playlist found');
      return null;
    }

    final List<dynamic> playlistData = jsonDecode(playlistJson);
    final sources = (playlistData.map((item) {
      final data = PlaylistData.fromJson(item);
      if (data.dummy) {
        return AudioSource.uri(Uri.parse(data.audioUri),
            tag: MediaItem(
              id: data.id,
              title: data.title,
              artist: data.artist,
              artUri: Uri.parse(data.artUri),
              extras: {
                'dummy': true,
              },
            ));
      } else {
        final uri = data.audioUri == "" ? null : Uri.parse(data.audioUri);
        final file =
            uri != null && uri.isScheme('file') ? File(uri.path) : null;

        return LazyAudioSource(
          data.bvid,
          data.cid,
          localFile: file,
          tag: MediaItem(
            id: data.id,
            title: data.title,
            artist: data.artist,
            artUri: Uri.parse(data.artUri),
            extras: {
              'bvid': data.bvid,
              'cid': data.cid,
              'aid': data.aid,
              'multi': data.multi,
              'raw_title': data.rawTitle,
              'mid': data.mid,
              'cached': data.cached,
            },
          ),
        );
      }
    }));

    return (sources.toList(), prefs.getInt('currentIndex') ?? 0);
  }

  static Future<int> getPlayPosition() async {
    final prefs = await SharedPreferencesService.instance;
    return prefs.getInt('play_position') ?? 0;
  }

  static Future<void> setPlayPosition(int position) async {
    final prefs = await SharedPreferencesService.instance;
    await prefs.setInt('play_position', position);
  }

  static Future<void> setHistoryReported(bool value) async {
    final prefs = await SharedPreferencesService.instance;
    await prefs.setBool('enable_history_report', value);
  }

  static Future<bool> getHistoryReported() async {
    final prefs = await SharedPreferencesService.instance;
    return prefs.getBool('enable_history_report') ?? false;
  }

  static Future<void> setReportHistoryInterval(int interval) async {
    final prefs = await SharedPreferencesService.instance;
    await prefs.setInt('report_history_interval', interval);
  }

  static Future<int> getReportHistoryInterval() async {
    final prefs = await SharedPreferencesService.instance;
    _logger.info('getReportHistoryInterval: ${prefs.getInt('report_history_interval')}');
    return prefs.getInt('report_history_interval') ?? 10;
  }
}
