import 'package:audio_session/audio_session.dart';
import 'package:bmsc/audio/lazy_audio_source.dart';
import 'package:bmsc/model/comment.dart';
import 'package:bmsc/model/dynamic.dart';
import 'package:bmsc/model/fav.dart';
import 'package:bmsc/model/history.dart';
import 'package:bmsc/model/search.dart';
import 'package:bmsc/model/track.dart';
import 'package:bmsc/model/user_card.dart';
import 'package:bmsc/model/user_upload.dart' show UserUploadResult;
import 'package:bmsc/model/vid.dart';
import 'package:bmsc/util/crypto.dart';
import 'package:bmsc/util/logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:rxdart/rxdart.dart';
import 'package:bmsc/database_manager.dart';
import 'dart:convert';
import 'package:bmsc/model/playlist_data.dart';
import 'package:bmsc/model/tag.dart';
import 'package:bmsc/model/meta.dart';
import 'model/entity.dart';
import 'service/shared_preferences_service.dart';

class DurationState {
  const DurationState({
    required this.progress,
    required this.buffered,
    this.total,
  });
  final Duration progress;
  final Duration buffered;
  final Duration? total;
}

class API {
  static final _logger = LoggerUtils.getLogger('API');

  int? uid;
  String? username;
  late String cookies;
  late Map<String, String> headers;
  Dio dio = Dio();
  late AudioSession session;
  final player = AudioPlayer();
  Stream<DurationState>? durationState;
  final playlist = ConcatenatingAudioSource(
    useLazyPreparation: true,
    children: [],
  );
  bool restored = false;

  Future<void> resetCookies() async {
    final response = await dio.get("https://www.bilibili.com");
    final cookie = response.headers['set-cookie'];
    _logger.info('init cookies: ${response.headers['set-cookie']}');
    if (cookie != null) {
      setCookies(cookie.join('; '), save: true);
    }
  }

  Future<void> init() async {
    getStoredUID();
    getStoredUsername();
    _logger.info('init cookies');
    final prefs = await SharedPreferencesService.instance;
    final cookie = prefs.getString('cookie');
    if (cookie != null) {
      setCookies(cookie);
      _logger.info('Loaded cookies: $cookie');
    } else {
      await resetCookies();
    }
    _logger.info('init player');
    player.setAudioSource(playlist);
    const cycleModes = [
      LoopMode.off,
      LoopMode.all,
      LoopMode.one,
      LoopMode.off,
    ];
    durationState = Rx.combineLatest2<Duration, PlaybackEvent, DurationState>(
        player.positionStream,
        player.playbackEventStream,
        (position, playbackEvent) => DurationState(
              progress: position,
              buffered: playbackEvent.bufferedPosition,
              total: playbackEvent.duration,
            )).asBroadcastStream();
    player.playerStateStream.listen((state) async {
      if (state.processingState == ProcessingState.completed) {
        if (!restored) {
          restored = true;
          await restorePlaylist();
          final prefs = await SharedPreferencesService.instance;
          final playmode = prefs.getInt('playmode');
          if (playmode != null) {
            if (playmode == 3) {
              await player.setShuffleModeEnabled(true);
              await player.setLoopMode(LoopMode.off);
            } else {
              await player.setLoopMode(cycleModes[playmode]);
            }
            _logger.info('Restored playmode: $playmode');
          }
        }
      }
      if (state.processingState == ProcessingState.ready) {
        final index = player.currentIndex;
        if (index == null) {
          return;
        }
        if (state.playing == false) {
          return;
        }
        _logger.info('processing state hijack dummy source for index: $index');
        await _hijackDummySource(index: index);
        _logger.info('processing state hijack done');
      }
    });
    Rx.combineLatest2(
        player.loopModeStream,
        player.shuffleModeEnabledStream,
        (loopMode, shuffleModeEnabled) => (
              loopMode,
              loopMode == LoopMode.off && shuffleModeEnabled
            )).listen((data) async {
      if (!restored) {
        return;
      }
      final (loopMode, shuffleModeEnabled) = data;
      final prefs = await SharedPreferencesService.instance;

      if (loopMode == LoopMode.off && shuffleModeEnabled) {
        prefs.setInt('playmode', 3);
      } else {
        prefs.setInt('playmode', cycleModes.indexOf(loopMode));
      }
    });

    player.currentIndexStream.listen((index) async {
      if (index != null && restored) {
        final prefs = await SharedPreferencesService.instance;
        await prefs.setInt('currentIndex', index);
        if (player.playing) {
          _logger
              .info('currentIndexStream hijack dummy source for index: $index');
          await _hijackDummySource(index: index);
          _logger.info('currentIndexStream hijack done');
        }
      }
    });

    player.playbackEventStream.listen(null, onError: (error, stackTrace) async {
      if (player.loopMode == LoopMode.off &&
          player.currentIndex != null &&
          player.currentIndex! == playlist.length - 1) {
        return;
      }
      if (player.loopMode == LoopMode.one) {
        return;
      }
      await player.seekToNext();
      await player.play();
    });
  }

  Future<void> _hijackDummySource({int? index}) async {
    index ??= player.currentIndex;
    if (index == null) {
      _logger.warning('No current index available for hijacking');
      return;
    }

    final currentSource = playlist.sequence[index];

    final extras = currentSource.tag.extras;
    if (extras == null) {
      return;
    }
    if (extras['dummy'] != true) {
      if (extras['bvid'] != null && extras['cid'] != null) {
        await DatabaseManager.updatePlayStats(extras['bvid'], extras['cid']);
        _logger.info(
            'update play stats for bvid: ${extras['bvid']} cid: ${extras['cid']}');
      }
      return;
    }
    _logger.info('Hijacking dummy source for index: $index');

    await player.pause();
    List<IndexedAudioSource>? srcs;
    try {
      srcs = await getAudioSources(currentSource.tag.id);
    } catch (e) {
      _logger.warning('Failed to get audio sources: $e');
      srcs = await DatabaseManager.getCachedAudioList(currentSource.tag.id);
    }
    final excludedCids =
        await DatabaseManager.getExcludedParts(currentSource.tag.id);
    for (var cid in excludedCids) {
      srcs?.removeWhere((src) => src.tag.extras?['cid'] == cid);
    }
    if (srcs == null) {
      _logger
          .warning('No audio sources found for BVID: ${currentSource.tag.id}');
      if (player.loopMode != LoopMode.one &&
          player.currentIndex != null &&
          player.currentIndex! < playlist.length - 1) {
        await player.seekToNext();
        await player.play();
      }
      return;
    }
    await doAndSave(() async {
      final shuffleModeEnabled = player.shuffleModeEnabled;
      if (shuffleModeEnabled) {
        await player.setShuffleModeEnabled(false);
      }
      await playlist.insertAll(index! + 1, srcs!);
      await playlist.removeAt(index);
      if (shuffleModeEnabled) {
        await player.setShuffleModeEnabled(true);
      }
    });
    await player.play();
  }

  Future<void> doAndSave(Future<void> Function() func) async {
    await func();
    await savePlaylist();
  }

  Future<UserUploadResult?> getUserUploads(int mid, int pn) async {
    final response =
        await dio.get("https://api.bilibili.com/x/space/wbi/arc/search",
            queryParameters: await encodeParams({
              'mid': mid,
              'ps': 40,
              'pn': pn,
            }));
    _logger
        .info('called getUserUploads with url: ${response.requestOptions.uri}');
    if (response.data['code'] != 0) {
      return null;
    }
    final ret = UserUploadResult.fromJson(response.data['data']);
    await DatabaseManager.cacheMetas(ret.list.vlist.map((x) {
      final durations = x.length.split(':').map(int.parse).toList();
      return Meta(
        bvid: x.bvid,
        aid: x.aid,
        title: x.title,
        artist: x.author,
        mid: x.mid,
        duration: durations[0] * 60 + durations[1],
        artUri: x.pic,
      );
    }).toList());
    return ret;
  }

  Future<UserInfoResult?> getUserInfo(int mid) async {
    final response = await dio.get(
        "https://api.bilibili.com/x/web-interface/card",
        queryParameters: {'mid': mid});
    if (response.data['code'] != 0) {
      return null;
    }
    return UserInfoResult.fromJson(response.data['data']);
  }

  Future<void> initAudioSession() async {
    session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        player.pause();
      }
    });
    session.becomingNoisyEventStream.listen((_) {
      player.pause();
    });
  }

  Future<void> setCookies(String cookie, {bool save = false}) async {
    if (save) {
      final prefs = await SharedPreferencesService.instance;
      await prefs.setString('cookie', cookie);
    }
    cookies = cookie;
    headers = {
      'cookie': cookie,
      'User-Agent':
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/113.0",
      'referer': "https://www.bilibili.com",
    };
    dio.interceptors.clear();
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers = headers;
        return handler.next(options);
      },
    ));
    _logger.info('setCookies: $cookie');
  }

  Future<void> appendPlaylistSingle(String bvid,
      {int? insertIndex, Map<String, dynamic>? extraExtras}) async {
    final srcs = await getAudioSources(bvid);
    if (srcs == null) {
      return;
    }
    await _addUniqueSourcesToPlaylist([srcs[0]],
        insertIndex: insertIndex, extraExtras: extraExtras);
  }

  Future<void> playFavList(int mid, {int index = 0}) async {
    final bvids = await DatabaseManager.getCachedFavBvids(mid);
    if (bvids.isEmpty) {
      return;
    }
    await playByBvids(bvids, index: index);
  }

  Future<void> playCollectedFavList(int mid, {int index = 0}) async {
    final bvids = await DatabaseManager.getCachedCollectionBvids(mid);
    if (bvids.isEmpty) {
      return;
    }
    await playByBvids(bvids, index: index);
  }

  Future<void> addFavListToPlaylist(int mid) async {
    final bvids = await DatabaseManager.getCachedFavBvids(mid);
    if (bvids.isEmpty) {
      return;
    }
    await addBvidsToPlaylist(bvids, insertIndex: playlist.length);
  }

  Future<void> addCollectedFavListToPlaylist(int mid) async {
    final bvids = await DatabaseManager.getCachedCollectionBvids(mid);
    if (bvids.isEmpty) {
      return;
    }
    await addBvidsToPlaylist(bvids, insertIndex: playlist.length);
  }

  Future<void> playByBvids(List<String> bvids, {int index = 0}) async {
    if (bvids.isEmpty) {
      return;
    }
    final srcs = await Future.wait(bvids.map((x) async {
      final meta = await DatabaseManager.getMeta(x);
      return AudioSource.uri(Uri.parse('asset:///assets/silent.m4a'),
          tag: MediaItem(
              id: x,
              title: meta?.title ?? '',
              artUri: Uri.parse(meta?.artUri ?? ''),
              artist: meta?.artist ?? '',
              extras: {'dummy': true}));
    }).toList());
    await player.stop();
    await doAndSave(() async {
      await playlist.clear();
      await playlist.addAll(srcs);
    });
    await player.seek(Duration.zero, index: index);
    await player.play();
  }

  Future<void> addBvidsToPlaylist(List<String> bvids,
      {int? insertIndex}) async {
    if (bvids.isEmpty) {
      return;
    }
    final srcs = await Future.wait(bvids.map((x) async {
      final meta = await DatabaseManager.getMeta(x);
      return AudioSource.uri(Uri.parse('asset:///assets/silent.m4a'),
          tag: MediaItem(
              id: x,
              title: meta?.title ?? '',
              artUri: Uri.parse(meta?.artUri ?? ''),
              artist: meta?.artist ?? '',
              extras: {'dummy': true}));
    }).toList());
    await doAndSave(() async {
      insertIndex ??= player.currentIndex ?? playlist.length;
      await playlist.insertAll(insertIndex!, srcs);
    });
  }

  Future<void> appendPlaylist(String bvid,
      {int? insertIndex, Map<String, dynamic>? extraExtras}) async {
    final srcs = await getAudioSources(bvid);
    final excludedCids = await DatabaseManager.getExcludedParts(bvid);
    for (var cid in excludedCids) {
      srcs?.removeWhere((src) => src.tag.extras?['cid'] == cid);
    }
    if (srcs == null) {
      return;
    }
    await _addUniqueSourcesToPlaylist(srcs,
        insertIndex: insertIndex, extraExtras: extraExtras);
  }

  Future<void> appendCachedPlaylist(String bvid,
      {int? insertIndex, Map<String, dynamic>? extraExtras}) async {
    final srcs = await DatabaseManager.getCachedAudioList(bvid);
    final excludedCids = await DatabaseManager.getExcludedParts(bvid);
    for (var cid in excludedCids) {
      srcs?.removeWhere((src) => src.tag.extras?['cid'] == cid);
    }
    if (srcs == null) {
      return;
    }
    await _addUniqueSourcesToPlaylist(srcs,
        insertIndex: insertIndex, extraExtras: extraExtras);
  }

  Future<void> addToPlaylistCachedAudio(String bvid, int cid) async {
    final cachedSource = await DatabaseManager.getCachedAudio(bvid, cid);
    if (cachedSource == null) {
      return;
    }
    await _addUniqueSourcesToPlaylist([cachedSource],
        insertIndex: playlist.length == 0 ? 0 : player.currentIndex! + 1);
  }

  Future<void> playCachedAudio(String bvid, int cid) async {
    await player.pause();
    final cachedSource = await DatabaseManager.getCachedAudio(bvid, cid);
    if (cachedSource == null) {
      return;
    }
    final idx = await _addUniqueSourcesToPlaylist([cachedSource],
        insertIndex: playlist.length == 0 ? 0 : player.currentIndex! + 1);

    if (idx != null) {
      await player.seek(Duration.zero, index: idx);
    }
    await player.play();
  }

  Future<void> playByBvid(String bvid) async {
    _logger.info('Playing by BVID: $bvid');
    await player.pause();
    final srcs = await getAudioSources(bvid);
    if (srcs == null) {
      _logger.warning('No audio sources found for BVID: $bvid');
      return;
    }
    final excludedCids = await DatabaseManager.getExcludedParts(bvid);
    for (var cid in excludedCids) {
      srcs.removeWhere((src) => src.tag.extras?['cid'] == cid);
    }

    final idx = await _addUniqueSourcesToPlaylist(srcs,
        insertIndex: playlist.length == 0 ? 0 : player.currentIndex! + 1);
    if (idx != null) {
      await player.seek(Duration.zero, index: idx);
    }
    await player.play();
  }

  Future<void> playCachedBvid(String bvid) async {
    await player.pause();
    final srcs = await DatabaseManager.getCachedAudioList(bvid);
    final excludedCids = await DatabaseManager.getExcludedParts(bvid);
    for (var cid in excludedCids) {
      srcs?.removeWhere((src) => src.tag.extras?['cid'] == cid);
    }
    if (srcs == null) {
      throw Exception('无网络');
    }

    final idx = await _addUniqueSourcesToPlaylist(srcs,
        insertIndex: playlist.length == 0 ? 0 : player.currentIndex! + 1);
    if (idx != null) {
      await player.seek(Duration.zero, index: idx);
    }
    await player.play();
  }

  Future<int?> getStoredUID() async {
    if (uid != null && uid != 0) {
      return uid;
    }
    final prefs = await SharedPreferencesService.instance;
    uid = prefs.getInt('uid');
    if (uid != null) {
      _logger.info('UID in prefs: $uid');
      return uid;
    }
    uid = await getUID();
    return uid;
  }

  Future<int?> getUID() async {
    final prefs = await SharedPreferencesService.instance;
    try {
      final response = await dio.get('https://api.bilibili.com/x/space/myinfo');
      if (response.data['code'] != 0) {
        _logger.severe('getUID error: ${response.data}');
        return 0;
      }
      final ret = response.data['data']['mid'] ?? 0;
      _logger.info('getUID from api: $ret');
      await prefs.setInt('uid', ret);
      uid = ret;
      return ret;
    } catch (e) {
      _logger.severe('getUID error: $e');
      final uid = prefs.getInt('uid');
      if (uid != null) {
        return uid;
      }
      return null;
    }
  }

  Future<String?> getStoredUsername() async {
    if (username != null) {
      return username;
    }
    final prefs = await SharedPreferencesService.instance;
    username = prefs.getString('username');
    if (username != null) {
      _logger.info('username in prefs: $username');
      return username;
    }
    username = await getUsername();
    return username;
  }

  Future<String?> getUsername() async {
    final prefs = await SharedPreferencesService.instance;
    try {
      final response = await dio.get('https://api.bilibili.com/x/space/myinfo');
      if (response.data['code'] != 0) {
        return null;
      }
      final ret = response.data['data']['name'];
      _logger.info('getUsername from api: $ret');
      await prefs.setString('username', ret);
      username = ret;
      return ret;
    } catch (e) {
      final username = prefs.getString('username');
      if (username != null) {
        return username;
      }
      return null;
    }
  }

  Future<List<Fav>?> getFavs(int uid, {int? rid}) async {
    final response = await dio.get(
        'https://api.bilibili.com/x/v3/fav/folder/created/list-all',
        queryParameters: {'up_mid': uid, 'rid': rid});
    if (response.data['code'] != 0) {
      return null;
    }
    final ret = FavResult.fromJson(response.data['data']);
    if (rid == null) {
      await DatabaseManager.cacheFavList(ret.list);
    }
    return ret.list;
  }

  Future<List<Fav>?> getCollectedFavList(int uid) async {
    int pn = 1;
    List<Fav> ret = [];
    bool hasMore = true;
    while (hasMore) {
      final response = await dio.get(
          'https://api.bilibili.com/x/v3/fav/folder/collected/list',
          queryParameters: {
            'up_mid': uid,
            'pn': pn,
            'ps': 20,
            'platform': 'web'
          });
      _logger.info(
          'called getCollectedFavList with url: ${response.requestOptions.uri}');
      if (response.data['code'] != 0) {
        return null;
      }
      hasMore = response.data['data']['has_more'] as bool;
      ++pn;
      ret.addAll((response.data['data']['list'] as List)
          .map((x) => Fav.fromJson(x))
          .toList());
    }
    await DatabaseManager.cacheCollectedFavList(ret);
    return ret;
  }

  Future<List<Meta>> getCachedFavListVideo(int mid) async {
    final bvids = await DatabaseManager.getCachedFavBvids(mid);
    final metas = await DatabaseManager.getMetas(bvids);
    return metas;
  }

  Future<List<Meta>> getCachedCollectedFavListVideo(int mid) async {
    final bvids = await DatabaseManager.getCachedCollectionBvids(mid);
    final metas = await DatabaseManager.getMetas(bvids);
    return metas;
  }

  Future<List<Meta>> getCollectedFavMetas(int mid) async {
    List<Meta> ret = [];
    int pn = 1;
    int? mediaCount;
    while (ret.length < (mediaCount ?? 1)) {
      final response = await dio.get(
          'https://api.bilibili.com/x/space/fav/season/list',
          queryParameters: {'season_id': mid, 'ps': 20, 'pn': pn});
      _logger.info(
          'called getCollectedFavMetas with url: ${response.requestOptions.uri}');
      if (response.data['code'] != 0) {
        return [];
      }
      mediaCount ??= response.data['data']['info']['media_count'];
      ret.addAll((response.data['data']['medias'] as List)
          .map((x) => Meta(
                bvid: x['bvid'],
                title: x['title'],
                artist: x['upper']['name'],
                mid: x['upper']['mid'],
                aid: x['id'],
                duration: x['duration'],
                artUri: x['cover'],
              ))
          .toList());
      ++pn;
    }
    await DatabaseManager.cacheMetas(ret);
    await DatabaseManager.cacheCollectedFavListVideo(
        ret.map((x) => x.bvid).toList(), mid);
    return ret;
  }

  Future<List<Meta>?> getFavMetas(int mid) async {
    bool hasMore = true;
    int pn = 1;
    List<Meta> ret = [];
    while (hasMore) {
      final response = await dio.get(
          'https://api.bilibili.com/x/v3/fav/resource/list',
          queryParameters: {'media_id': mid, 'ps': 40, 'pn': pn});
      if (response.data['code'] != 0) {
        return null;
      }
      _logger
          .info('called getFavMetas with url: ${response.requestOptions.uri}');
      ret.addAll((response.data['data']['medias'] as List)
          .map((x) => Meta(
                bvid: x['bvid'],
                title: x['title'],
                artist: x['upper']['name'],
                mid: x['upper']['mid'],
                aid: x['id'],
                duration: x['duration'],
                artUri: x['cover'],
                parts: x['page'],
              ))
          .toList());
      hasMore = response.data['data']['has_more'] as bool;
      pn++;
    }
    await DatabaseManager.cacheMetas(ret);
    await DatabaseManager.cacheFavListVideo(ret.map((x) => x.bvid).toList(), mid);
    return ret;
  }

  // Future<List<String>?> getFavBvids(int mid) async {
  //   final response = await dio.get(
  //       'https://api.bilibili.com/x/v3/fav/resource/ids',
  //       queryParameters: {'media_id': mid});
  //   _logger.info('called getFavBvids with url: ${response.requestOptions.uri}');
  //   if (response.data['code'] != 0) {
  //     return null;
  //   }
  //   List<String> ret = [];
  //   for (final x in response.data['data']) {
  //     ret.add(x['bv_id']);
  //   }
  //   return ret;
  // }

  Future<SearchResult?> search(String value, int pn) async {
    try {
      final response = await dio.get(
        'https://api.bilibili.com/x/web-interface/search/type',
        queryParameters: {'search_type': 'video', 'keyword': value, 'page': pn},
      );
      _logger.info('called search with url: ${response.requestOptions.uri}');
      if (response.data['code'] != 0 || response.data['data'] == null) {
        return null;
      }
      return SearchResult.fromJson(response.data['data']);
    } catch (e) {
      return null;
    }
  }

  Future<HistoryResult?> getHistory(int? timestamp) async {
    final response = await dio.get(
      'https://api.bilibili.com/x/web-interface/history/cursor',
      queryParameters: {'type': 'archive', 'view_at': timestamp},
    );
    _logger.info('called getHistory with url: ${response.requestOptions.uri}');
    if (response.data['code'] != 0) {
      return null;
    }
    return HistoryResult.fromJson(response.data['data']);
  }

  Future<DynamicResult?> getDynamics(String? offset) async {
    final response = await dio.get(
      'https://api.bilibili.com/x/polymer/web-dynamic/v1/feed/all',
      queryParameters: {'type': 'video', 'offset': offset},
    );
    _logger.info('called getDynamics with url: ${response.requestOptions.uri}');
    if (response.data['code'] != 0) {
      return null;
    }
    return DynamicResult.fromJson(response.data['data']);
  }

  Future<List<Audio>?> getAudio(String bvid, int cid) async {
    final response = await dio.get(
      'https://api.bilibili.com/x/player/playurl',
      queryParameters: {'bvid': bvid, 'cid': cid, 'fnval': 16},
    );
    _logger.info('called getAudio with url: ${response.requestOptions.uri}');
    if (response.data['code'] != 0) {
      return null;
    }
    final track = TrackResult.fromJson(response.data['data']);
    return track.dash.audio;
  }

  Future<List<LazyAudioSource>?> getAudioSources(String bvid) async {
    _logger.info('Fetching audio sources for BVID: $bvid');
    final vid = await getVidDetail(bvid: bvid);
    if (vid == null) {
      _logger.warning('Failed to get video details for BVID: $bvid');
      return null;
    }
    return (await Future.wait<LazyAudioSource?>(vid.pages.map((x) async {
      final cachedSource = await DatabaseManager.getCachedAudio(bvid, x.cid);
      if (cachedSource != null) {
        return cachedSource;
      }
      final audios = await getAudio(bvid, x.cid);
      if (audios == null || audios.isEmpty) {
        return null;
      }
      final firstAudio = audios[0];
      final tag = MediaItem(
          id: '${bvid}_${x.cid}',
          title: vid.pages.length > 1 ? "${x.part} - ${vid.title}" : vid.title,
          artUri: Uri.parse(vid.pic),
          artist: vid.owner.name,
          extras: {
            'mid': vid.owner.mid,
            'bvid': bvid,
            'aid': vid.aid,
            'cid': x.cid,
            'cached': false,
            'raw_title': vid.title,
            'multi': vid.pages.length > 1,
          });
      return LazyAudioSource.create(
          bvid, x.cid, Uri.parse(firstAudio.baseUrl), tag);
    })))
        .whereType<LazyAudioSource>()
        .toList();
  }

  Future<CommentData?> getComment(String aid, int pn) async {
    final response = await dio.get(
      'https://api.bilibili.com/x/v2/reply/main',
      queryParameters: {'oid': aid, 'pn': pn, 'sort': 1, 'type': 1},
    );
    _logger.info('called getComment with url: ${response.requestOptions.uri}');
    if (response.data['code'] != 0) {
      return null;
    }
    return CommentData.fromJson(response.data['data']);
  }

  Future<CommentData?> getCommentsOfComment(int oid, int root, int pn) async {
    final response = await dio.get(
      "https://api.bilibili.com/x/v2/reply/reply",
      queryParameters: {
        'type': 1,
        'oid': oid,
        'root': root,
        'pn': pn,
        'ps': 20
      },
    );
    _logger.info(
        'called getCommentsOfComment with url: ${response.requestOptions.uri}');
    if (response.data['code'] != 0) {
      return null;
    }
    return CommentData.fromJson(response.data['data']);
  }

  Future<VidResult?> getVidDetail({String? bvid, String? aid}) async {
    assert(bvid != null || aid != null, 'Either bvid or aid must be provided');
    assert(!(bvid != null && aid != null), 'Cannot provide both bvid and aid');
    try {
      final response = await dio.get(
        'https://api.bilibili.com/x/web-interface/view',
        queryParameters: {
          'bvid': bvid,
          'aid': aid,
        },
      );
      _logger
          .info('called getVidDetail with url: ${response.requestOptions.uri}');
      if (response.data['code'] != 0) {
        return null;
      }
      final ret = VidResult.fromJson(response.data['data']);
      await DatabaseManager.cacheMetas([
        Meta(
          bvid: ret.bvid,
          aid: ret.aid,
          title: ret.title,
          artist: ret.owner.name,
          mid: ret.owner.mid,
          duration: ret.duration,
          parts: ret.videos,
          artUri: ret.pic,
        )
      ]);
      await DatabaseManager.cacheEntities(ret.pages
          .map((x) => Entity(
                bvid: ret.bvid,
                aid: ret.aid,
                cid: x.cid,
                duration: x.duration,
                part: x.page,
                artist: ret.owner.name,
                artUri: ret.pic,
                partTitle: x.part,
                bvidTitle: ret.title,
                excluded: 0,
              ))
          .toList());
      return ret;
    } catch (e) {
      _logger.severe('Error getting video detail: $e');
      return null;
    }
  }

  Future<TagResult?> getTags(String bvid) async {
    final response = await dio.get(
      'https://api.bilibili.com/x/tag/archive/tags',
      queryParameters: {'bvid': bvid},
    );
    if (response.data['code'] != 0) {
      return null;
    }
    return TagResult.fromJson(response.data);
  }

  Future<int?> _addUniqueSourcesToPlaylist(List<IndexedAudioSource> sources,
      {int? insertIndex, Map<String, dynamic>? extraExtras}) async {
    int? ret;
    for (var source in sources) {
      if (source.tag is MediaItem) {
        var mediaItem = source.tag as MediaItem;
        var duplicatePos = playlist.children.indexWhere((child) {
          if (child is IndexedAudioSource && child.tag is MediaItem) {
            return (child.tag as MediaItem).id == mediaItem.id;
          }
          return false;
        });

        if (duplicatePos == -1) {
          if (extraExtras != null) {
            mediaItem.extras?.addAll(extraExtras);
          }
          if (insertIndex != null) {
            await doAndSave(() async {
              await playlist.insert(insertIndex!, source);
            });
            ret ??= insertIndex;
            insertIndex++;
          } else {
            await doAndSave(() async {
              await playlist.add(source);
            });
            ret ??= playlist.length - 1;
          }
        } else {
          ret = duplicatePos;
        }
      }
    }
    return ret;
  }

  Future<void> savePlaylist() async {
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

  Future<void> restorePlaylist() async {
    _logger.info('Restoring playlist from preferences');
    final prefs = await SharedPreferencesService.instance;
    final playlistJson = prefs.getString('playlist');
    final currentIndex = prefs.getInt('currentIndex') ?? 0;

    if (playlistJson == null) {
      _logger.info('No saved playlist found');
      return;
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

    await playlist.clear();
    await playlist.addAll(sources);

    if (sources.isNotEmpty) {
      await player.seek(Duration(seconds: 0), index: currentIndex);
    }
  }

  Future<bool?> favoriteVideo(
      int avid, List<int> addMediaIds, List<int> delMediaIds) async {
    _logger.info(
        'Favoriting video - AVID: $avid, Adding: $addMediaIds, Removing: $delMediaIds');
    try {
      final response = await dio.post(
          'https://api.bilibili.com/x/v3/fav/resource/deal',
          queryParameters: {
            'rid': avid,
            'type': 2,
            'add_media_ids': addMediaIds.join(','),
            'del_media_ids': delMediaIds.join(','),
            'csrf': _extractCSRF(cookies),
          });
      _logger.info(
          'called favoriteVideo with url: ${response.requestOptions.uri}');
      if (response.data['code'] != 0) {
        _logger.warning('Failed to favorite video: ${response.data}');
      }
      return response.data['code'] == 0;
    } catch (e) {
      _logger.severe('Error favoriting video: $e');
      return null;
    }
  }

  String _extractCSRF(String cookies) {
    final csrfMatch = RegExp(r'bili_jct=([^;]+)').firstMatch(cookies);
    return csrfMatch?.group(1) ?? '';
  }

  Future<bool?> isFavorited(int aid) async {
    try {
      final response = await dio.get(
          "https://api.bilibili.com/x/v2/fav/video/favoured",
          queryParameters: {'aid': aid});
      if (response.data['code'] != 0) {
        return null;
      }
      return response.data['data']['favoured'];
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getDefaultFavFolder() async {
    final prefs = await SharedPreferencesService.instance;
    final id = prefs.getInt('default_fav_folder');
    final name = prefs.getString('default_fav_folder_name');
    if (id == null) return null;
    return {
      'id': id,
      'name': name,
    };
  }

  Future<void> setDefaultFavFolder(int folderId, String folderName) async {
    final prefs = await SharedPreferencesService.instance;
    await prefs.setInt('default_fav_folder', folderId);
    await prefs.setString('default_fav_folder_name', folderName);
  }

  Future<List<Map<String, dynamic>>?> fetchNeteasePlaylistTracks(
      String playlistId) async {
    try {
      final response = await dio.get('https://rp.u2x1.work/playlist/track/all',
          queryParameters: {'id': playlistId});
      final List<Map<String, dynamic>> tracks = [];
      for (final song in response.data['songs']) {
        tracks.add({
          'name': song['name'],
          'artist': song['ar'][0]['name'],
          'duration': song['dt'] ~/ 1000,
        });
      }
      return tracks;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return [];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> fetchTencentPlaylistTracks(
      String playlistId) async {
    try {
      final response = await dio.get(
          'https://api.timelessq.com/music/tencent/songList',
          queryParameters: {'disstid': playlistId});
      if (response.data['errno'] != 0) {
        return [];
      }
      final List<Map<String, dynamic>> tracks = [];
      for (final song in response.data['data']['songlist']) {
        tracks.add({
          'name': song['songname'],
          'artist': song['singer'].map((e) => e['name']).join(', '),
          'duration': song['interval'],
        });
      }
      return tracks;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> fetchKuGouPlaylistTracks(
      String playlistId) async {
    try {
      final response = await dio.get(
          'https://kg.u2x1.work/playlist/track/all?id=$playlistId&pagesize=300');
      if (response.data['status'] == 0) {
        return [];
      }
      final total = response.data['data']['count'];
      final List<Map<String, dynamic>> tracks = [];
      for (final song in response.data['data']['info']) {
        final fullname = song['name'];
        final pos = fullname.indexOf('-');
        final name = pos == -1 ? fullname : fullname.substring(0, pos);
        final artist = pos == -1 ? '' : fullname.substring(pos + 1).trim();
        tracks.add({
          'name': name,
          'artist': artist,
          'duration': song['timelen'] ~/ 1000,
        });
      }
      if (total > 300) {
        final pageSize = (total / 300).ceil();
        for (int i = 2; i <= pageSize; i++) {
          final response = await dio.get(
              'https://kg.u2x1.work/playlist/track/all?id=$playlistId&pagesize=300&page=$i');
          for (final song in response.data['data']['info']) {
            final fullname = song['name'];
            final pos = fullname.indexOf('-');
            final name = pos == -1 ? fullname : fullname.substring(0, pos);
            final artist = pos == -1 ? '' : fullname.substring(pos + 1).trim();
            tracks.add({
              'name': name,
              'artist': artist,
              'duration': song['timelen'] ~/ 1000,
            });
          }
        }
      }
      return tracks;
    } catch (e) {
      return null;
    }
  }

  Future<List<Meta>?> getDailyRecommendations({bool force = false}) async {
    _logger.info('Getting daily recommendations (force: $force)');
    final prefs = await SharedPreferencesService.instance;
    final lastUpdateStr = prefs.getString('last_recommendations_update');
    final recommendations = prefs.getString('daily_recommendations');

    if (lastUpdateStr != null) {
      _logger.info('Last recommendations update: $lastUpdateStr');
    }
    final lastUpdate =
        lastUpdateStr != null ? DateTime.parse(lastUpdateStr) : null;
    final now = DateTime.now();
    if (lastUpdate == null ||
        !DateUtils.isSameDay(now, lastUpdate) ||
        recommendations == null ||
        force == true) {
      final defaultFavFolder = await getDefaultFavFolder();
      if (defaultFavFolder == null) return null;

      final favVideos = await getFavMetas(defaultFavFolder['id']);
      if (favVideos == null || favVideos.isEmpty) return null;

      favVideos.shuffle();
      final selectedVideos = favVideos.take(30).toList();

      final recommendedVideos = await getRecommendations(selectedVideos) ?? [];

      await prefs.setString(
          'last_recommendations_update', now.toIso8601String());
      await prefs.setString('daily_recommendations',
          jsonEncode(recommendedVideos.map((v) => v.toJson()).toList()));

      return recommendedVideos;
    }

    final List<dynamic> decoded = jsonDecode(recommendations);
    return decoded.map((v) => Meta.fromJson(v)).toList();
  }

  Future<Fav?> createFavFolder(String name, {bool privacy = false}) async {
    final response = await dio
        .post('https://api.bilibili.com/x/v3/fav/folder/add', queryParameters: {
      'title': name,
      'privacy': privacy ? 1 : 0,
      'csrf': _extractCSRF(cookies)
    });
    _logger.info(
        'called createFavFolder with url: ${response.requestOptions.uri}');
    if (response.data['code'] != 0) {
      return null;
    }
    return Fav.fromJson(response.data['data']);
  }

  Future<bool?> deleteFavFolder(int mediaId) async {
    final response = await dio.post(
        'https://api.bilibili.com/x/v3/fav/folder/del',
        queryParameters: {'media_ids': mediaId, 'csrf': _extractCSRF(cookies)});
    _logger.info(
        'called deleteFavFolder with url: ${response.requestOptions.uri}');
    return response.data['code'] == 0;
  }

  Future<bool?> editFavFolder(int mediaId, String name,
      {bool privacy = false}) async {
    final response = await dio.post(
        'https://api.bilibili.com/x/v3/fav/folder/edit',
        queryParameters: {
          'media_id': mediaId,
          'title': name,
          'privacy': privacy ? 1 : 0,
          'csrf': _extractCSRF(cookies)
        });
    _logger
        .info('called editFavFolder with url: ${response.requestOptions.uri}');
    return response.data['code'] == 0;
  }

  Future<List<Meta>?> getRecommendations(List<Meta> tracks) async {
    _logger.info('Getting recommendations for ${tracks.length} tracks');
    if (tracks.isEmpty) {
      _logger.warning('No tracks provided for recommendations');
      return null;
    }

    final prefs = await SharedPreferencesService.instance;
    final recommendHistory = prefs.getString('recommend_history');
    Set<String> history = recommendHistory != null
        ? Set<String>.from(jsonDecode(recommendHistory))
        : {};

    const tidWhitelist = [130, 193, 267, 28, 59];
    const durationConstraint = null;

    List<Meta> recommendedVideos = [];
    for (var track in tracks) {
      final relatedVideos = await getRelatedVideos(track.aid,
          tidWhitelist: tidWhitelist, durationConstraint: durationConstraint);
      if (relatedVideos != null && relatedVideos.isNotEmpty) {
        for (final video in relatedVideos) {
          if (!history.contains(video.bvid) && video.duration >= 60) {
            recommendedVideos.add(video);
            history.add(video.bvid);
            break;
          }
        }
      }
    }
    await prefs.setString('recommend_history', jsonEncode(history.toList()));
    await DatabaseManager.cacheMetas(recommendedVideos);
    return recommendedVideos;
  }

  Future<List<Meta>?> getRelatedVideos(int aid,
      {List<int>? tidWhitelist, int? durationConstraint}) async {
    try {
      final response = await dio.get(
        'https://api.bilibili.com/x/web-interface/archive/related',
        queryParameters: {'aid': aid},
      );
      _logger.info(
          'called getRelatedVideos with url: ${response.requestOptions.uri}');
      if (response.data['code'] != 0) return null;

      var videos = response.data['data'] as List;
      if (tidWhitelist != null) {
        videos = videos
            .where((video) => tidWhitelist.contains(video['tid']))
            .toList();
      }
      if (durationConstraint != null) {
        videos = videos
            .where((video) => video['duration'] <= durationConstraint)
            .toList();
      }

      return videos
          .map((video) => Meta(
                bvid: video['bvid'],
                title: video['title'],
                artist: video['owner']['name'],
                mid: video['owner']['mid'],
                aid: video['aid'],
                duration: video['duration'],
                artUri: video['pic'],
                parts: video['videos'],
              ))
          .toList();
    } catch (e) {
      return null;
    }
  }

  Future<List<String>> getSearchSuggestions(String keyword) async {
    final response = await dio.get(
      'https://s.search.bilibili.com/main/suggest',
      queryParameters: {'term': keyword},
    );
    _logger.info(
        'called getSearchSuggestions with url: ${response.requestOptions.uri}');
    final data = jsonDecode(response.data);
    if (data['code'] != 0) return [];
    List<String> suggestions = [];
    for (final tag in data['result']['tag']) {
      suggestions.add(tag['term'] as String);
    }
    return suggestions;
  }

  Future<String?> getRawWbiKey() async {
    final prefs = await SharedPreferencesService.instance;
    final rawWbiKey = prefs.getString('raw_wbi_key');
    final lastUpdateDay = prefs.getInt('img_sub_key_last_update');
    final currentDay = (DateTime.now().millisecondsSinceEpoch ~/ 86400000);
    if (lastUpdateDay != null &&
        rawWbiKey != null &&
        lastUpdateDay == currentDay) {
      return rawWbiKey;
    }
    _logger.info('Getting new raw_wbi_key');
    final response =
        await dio.get('https://api.bilibili.com/x/web-interface/nav');
    _logger
        .info('called getRawWbiKey with url: ${response.requestOptions.uri}');
    if (response.data['code'] != 0) return null;
    final data = response.data['data']['wbi_img'];
    final imgsubNew = data['img_url'] as String?;
    final subidNew = data['sub_url'] as String?;
    if (imgsubNew == null || subidNew == null) return null;
    final rawWbiKeyNew = imgsubNew.substring(
            imgsubNew.lastIndexOf('/') + 1, imgsubNew.lastIndexOf('.')) +
        subidNew.substring(
            subidNew.lastIndexOf('/') + 1, subidNew.lastIndexOf('.'));
    await prefs.setString('raw_wbi_key', rawWbiKeyNew);
    await prefs.setInt('img_sub_key_last_update', currentDay);
    _logger.info('New raw_wbi_key: $rawWbiKeyNew');
    return rawWbiKeyNew;
  }

  Future<Map<String, dynamic>?> getGeetestParams() async {
    try {
      final response = await dio.get(
        'https://passport.bilibili.com/x/passport-login/web/key',
      );
      if (response.data['code'] != 0) {
        return null;
      }
      return response.data['data'];
    } catch (e) {
      _logger.severe('Error getting geetest params: $e');
      return null;
    }
  }

  Future<Map<String, String>?> getLoginCaptcha() async {
    final response = await dio.get(
      'https://passport.bilibili.com/x/passport-login/captcha?source=main_web',
    );
    if (response.data['code'] != 0) {
      return null;
    }
    return {
      'challenge': response.data['data']['geetest']['challenge'],
      'gt': response.data['data']['geetest']['gt'],
      'token': response.data['data']['token'],
    };
  }

  Future<Map<String, dynamic>?> getLoginKey() async {
    final response = await dio.get(
      'https://passport.bilibili.com/x/passport-login/web/key',
    );
    _logger.info('called getLoginKey with url: ${response.requestOptions.uri}');
    if (response.data['code'] != 0) {
      return null;
    }
    return response.data['data'];
  }

  Future<(bool, String?)> login({
    required String username,
    required String password,
    required Map<String, dynamic> geetestResult,
  }) async {
    _logger.info('Logging in with username: $username');
    try {
      final loginKey = await getLoginKey();
      if (loginKey == null) {
        throw Exception('Failed to get login key');
      }

      final encryptedPassword =
          encryptPassword(password, loginKey['key']!, loginKey['hash']!);
      _logger.info('Encrypted password: $encryptedPassword');

      final loginResponse = await dio.post(
        'https://passport.bilibili.com/x/passport-login/web/login',
        queryParameters: {
          'username': username,
          'password': encryptedPassword,
          'token': geetestResult['token'],
          'go_url': 'https://www.bilibili.com',
          'source': 'main-fe-header',
          'challenge': geetestResult['challenge'],
          'validate': geetestResult['validate'],
          'seccode': geetestResult['seccode'],
        },
      );
      _logger
          .info('called login with url: ${loginResponse.requestOptions.uri}');

      if (loginResponse.data['code'] != 0) {
        return (false, "网络错误");
      }

      if (loginResponse.data['data']['status'] != 0) {
        return (false, loginResponse.data['data']['message'] as String);
      }

      final cookies = loginResponse.headers['set-cookie'];
      if (cookies != null) {
        await setCookies(cookies.join(';'), save: true);
      }

      return (true, null);
    } catch (e) {
      _logger.severe('Login error: $e');
      return (false, e.toString());
    }
  }

  Future<(String, String?)> getSmsCaptcha({
    required int tel,
    required Map<String, dynamic> geetestResult,
  }) async {
    try {
      final response = await dio.post(
        'https://passport.bilibili.com/x/passport-login/web/sms/send',
        queryParameters: {
          'cid': "86",
          'tel': tel.toString(),
          'source': 'main-fe-header',
          'token': geetestResult['token'],
          'challenge': geetestResult['challenge'],
          'validate': geetestResult['validate'],
          'seccode': geetestResult['seccode'],
        },
      );
      _logger.info(
          'called getSmsCaptcha with url: ${response.requestOptions.uri}');
      if (response.data['code'] != 0) {
        return ("", response.data['message'] as String);
      }
      return (response.data['data']['captcha_key'] as String, null);
    } on DioException catch (e) {
      _logger.info('${e.response?.statusCode}: ${e.response?.data}');
      _logger.severe('Error getting sms captcha: $e');
      return ("", e.toString());
    } catch (e) {
      _logger.severe('Error getting sms captcha: $e');
      return ("", e.toString());
    }
  }

  Future<(bool, String?)> smslogin({
    required int tel,
    required String code,
    required String captchaKey,
  }) async {
    _logger.info('Logging in with sms: $tel');
    try {
      final loginResponse = await dio.post(
        'https://passport.bilibili.com/x/passport-login/web/login/sms',
        queryParameters: {
          'cid': "86",
          'tel': tel.toString(),
          'code': code,
          'captcha_key': captchaKey,
          'source': 'main-fe-header'
        },
      );
      _logger
          .info('called login with url: ${loginResponse.requestOptions.uri}');

      if (loginResponse.data['code'] != 0) {
        return (false, loginResponse.data['message'] as String);
      }

      if (loginResponse.data['data']['status'] != 0) {
        return (false, loginResponse.data['data']['message'] as String);
      }

      final cookies = loginResponse.headers['set-cookie'];
      if (cookies != null) {
        await setCookies(cookies.join(';'), save: true);
      }

      return (true, null);
    } catch (e) {
      _logger.severe('Login error: $e');
      return (false, e.toString());
    }
  }
}
