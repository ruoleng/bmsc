import 'dart:convert';

import 'package:bmsc/audio/lazy_audio_source.dart';
import 'package:bmsc/model/myinfo.dart';
import 'package:bmsc/model/playlist_data.dart';
import 'package:bmsc/util/logger.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesService {
  static SharedPreferences? _prefs;
  static final _logger = LoggerUtils.getLogger('SharedPreferencesService');

  static Future<SharedPreferences> get instance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
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
    final playlistData = playlist.children
        .map((source) {
          if ((source is UriAudioSource || source is LazyAudioSource)) {
            final uri = source is UriAudioSource
                ? source.uri
                : (source as LazyAudioSource).uri;
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
        })
        .whereType<Map<String, dynamic>>()
        .toList();

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
    final sources = await Future.wait(playlistData.map((item) async {
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
        return LazyAudioSource.create(
          data.bvid,
          data.cid,
          Uri.parse(data.audioUri),
          MediaItem(
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

    return (sources, prefs.getInt('currentIndex') ?? 0);
  }
}
