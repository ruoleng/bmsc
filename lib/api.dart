import 'package:audio_session/audio_session.dart';
import 'package:bmsc/model/dynamic.dart';
import 'package:bmsc/model/fav.dart';
import 'package:bmsc/model/fav_detail.dart';
import 'package:bmsc/model/history.dart';
import 'package:bmsc/model/search.dart';
import 'package:bmsc/model/track.dart';
import 'package:bmsc/model/user_card.dart';
import 'package:bmsc/model/user_upload.dart';
import 'package:bmsc/model/vid.dart';
import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:io';
import 'package:bmsc/cache_manager.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bmsc/model/playlist_data.dart';

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
  int? uid;
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

  API(String cookie) {
    setCookies(cookie);
    player.setAudioSource(playlist);
    player.setLoopMode(LoopMode.all);
    durationState = Rx.combineLatest2<Duration, PlaybackEvent, DurationState>(
        player.positionStream,
        player.playbackEventStream,
        (position, playbackEvent) => DurationState(
              progress: position,
              buffered: playbackEvent.bufferedPosition,
              total: playbackEvent.duration,
            )).asBroadcastStream();
    player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.ready && state.playing == true) {
        if (player.currentIndex != null) {
          _checkAndCacheCurrentSong(player.currentIndex!);
        }
      }
    });
    player.sequenceStateStream.listen((sequenceState) {
      if (sequenceState != null) {
        _prepareNextSong(sequenceState);
      }
    });
  }

  Future<UserUploadResult?> getUserUploads(int mid, int pn) async {
    final response = await dio.get(
        "https://api.bilibili.com/x/space/wbi/arc/search",
        queryParameters: {'mid': mid, 'ps': 40, 'pn': pn});
    if (response.data['code'] != 0) {
      return null;
    }
    return UserUploadResult.fromJson(response.data['data']);
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

  initAudioSession() async {
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

  setCookies(String cookie) {
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
  }

  Future<void> appendPlaylist(String bvid) async {
    final srcs = await getAudioSources(bvid);
    if (srcs == null) {
      return;
    }
    await _addUniqueSourcesToPlaylist(srcs);
  }

  Future<void> playCachedAudio(String bvid, int cid) async {
    await player.pause();
    final cachedSource = await CacheManager.getCachedAudio(bvid, cid);
    if (cachedSource == null) {
      return;
    }
    final idx = await _addUniqueSourcesToPlaylist([cachedSource], insertIndex: playlist.length == 0 ? 0 : player.currentIndex! + 1);

    if (idx != null) {
      await player.seek(Duration.zero, index: idx);
    }
    await player.play();
  }

  Future<void> playByBvid(String bvid) async {
    await player.pause();
    final srcs = await getAudioSources(bvid);
    if (srcs == null) {
      return;
    }

    final idx = await _addUniqueSourcesToPlaylist(srcs, insertIndex: playlist.length == 0 ? 0 : player.currentIndex! + 1);
    if (idx != null) {
      await player.seek(Duration.zero, index: idx);
    }
    await player.play();
  }

  Future<int?> getStoredUID() async {
    if (uid != null) {
      return uid;
    }
    uid = await getUID();
    return uid;
  }

  Future<int?> getUID() async {
    final response = await dio.get('https://api.bilibili.com/x/space/myinfo');
    if (response.data['code'] != 0) {
      return null;
    }
    return response.data['data']['mid'];
  }

  Future<FavResult?> getFavs(int uid) async {
    final response = await dio.get(
        'https://api.bilibili.com/x/v3/fav/folder/created/list-all',
        queryParameters: {'up_mid': uid});
    if (response.data['code'] != 0) {
      return null;
    }
    return FavResult.fromJson(response.data['data']);
  }

  Future<FavDetail?> getFavDetail(int mid, int pn) async {
    final response = await dio.get(
        'https://api.bilibili.com/x/v3/fav/resource/list',
        queryParameters: {'media_id': mid, 'ps': 10, 'pn': pn});
    if (response.data['code'] != 0) {
      return null;
    }
    return FavDetail.fromJson(response.data['data']);
  }

  Future<List<String>?> getFavBvids(int mid) async {
    final response = await dio.get(
        'https://api.bilibili.com/x/v3/fav/resource/ids',
        queryParameters: {'media_id': mid});
    if (response.data['code'] != 0) {
      return null;
    }
    List<String> ret = [];
    for (final x in response.data['data']) {
      ret.add(x['bv_id']);
    }
    return ret;
  }

  Future<SearchResult?> search(String value, int pn) async {
    final response = await dio.get(
      'https://api.bilibili.com/x/web-interface/search/type',
      queryParameters: {'search_type': 'video', 'keyword': value, 'page': pn},
    );
    if (response.data['code'] != 0) {
      return null;
    }
    return SearchResult.fromJson(response.data['data']);
  }

  Future<HistoryResult?> getHistory(int? timestamp) async {
    final response = await dio.get(
      'https://api.bilibili.com/x/web-interface/history/cursor',
      queryParameters: {'type': 'archive', 'view_at': timestamp},
    );
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
    if (response.data['code'] != 0) {
      return null;
    }
    final track = TrackResult.fromJson(response.data['data']);
    return track.dash.audio;
  }

  Future<List<UriAudioSource>?> getAudioSources(String bvid) async {
    final vid = await getVidDetail(bvid);
    if (vid == null) {
      return null;
    }
    return (await Future.wait<UriAudioSource?>(vid.pages.map((x) async {
      final cachedSource = await CacheManager.getCachedAudio(bvid, x.cid);
      if (cachedSource != null) {
        return cachedSource;
      }
      final audios = await getAudio(bvid, x.cid);
      if (audios == null || audios.isEmpty) {
        return null;
      }
      final firstAudio = audios[0];
      return AudioSource.uri(Uri.parse(firstAudio.baseUrl),
          headers: headers,
          tag: MediaItem(
              id: '${bvid}_${x.cid}',
              title:
                  vid.pages.length > 1 ? "${x.part} - ${vid.title}" : vid.title,
              artUri: Uri.parse(vid.pic),
              artist: vid.owner.name,
              extras: {
                'quality': firstAudio.id,
                'mid': vid.owner.mid,
                'bvid': bvid,
                'cid': x.cid,
                'cached': false
              }));
    })))
        .whereType<UriAudioSource>()
        .toList();
  }

  Future<VidResult?> getVidDetail(String bvid) async {
    final response = await dio.get(
      'https://api.bilibili.com/x/web-interface/view',
      queryParameters: {'bvid': bvid},
    );
    if (response.data['code'] != 0) {
      return null;
    }
    return VidResult.fromJson(response.data['data']);
  }

  Future<void> _downloadAndCache(String bvid, int cid, String url, File file, int quality, int mid, String title, String artist, String artUri) async {
    try {
      final request = http.Request('GET', Uri.parse(url));
      request.headers.addAll(headers);
      final response = await http.Client().send(request);

      final sink = file.openWrite();
      await response.stream.pipe(sink);
      await sink.close();

      await CacheManager.saveCacheMetadata(bvid, cid, quality, mid, file.path, title, artist, artUri);
    } catch (e) {
      await file.delete();
    }
  }

  Future<void> _prepareNextSong(SequenceState sequenceState) async {
    final currentIndex = sequenceState.currentIndex;
    if (currentIndex + 1 >= sequenceState.effectiveSequence.length) {
      return;
    }
    final nextIndex = (currentIndex + 1) % sequenceState.effectiveSequence.length;
    final nextItem = sequenceState.effectiveSequence[nextIndex];
    
    if (nextItem.tag is MediaItem) {
      var mediaItem = nextItem.tag as MediaItem;
      final bvid = mediaItem.extras?['bvid'] as String?;
      final cid = mediaItem.extras?['cid'] as int?;

      if (mediaItem.extras?['cached'] == true) {
        return;
      }

      if (bvid == null || cid == null) {
        return;
      }

      final cached = await CacheManager.isCached(bvid, cid);
      if (cached) {
        // If cached, prepare to switch to cached file
        final cachedSource = await CacheManager.getCachedAudio(bvid, cid);
        if (cachedSource != null) {
          await playlist.removeAt(nextIndex);
          await playlist.insert(nextIndex, cachedSource);
        }
      }
    }
  }

  Future<void> _checkAndCacheCurrentSong(int index) async {
    if (index < 0 || index >= playlist.length) {
      return;
    }
    final currentItem = playlist.children[index] as UriAudioSource;
    var mediaItem = currentItem.tag as MediaItem;
    final bvid = mediaItem.extras?['bvid'] as String?;
    final cid = mediaItem.extras?['cid'] as int?;
    final quality = mediaItem.extras?['quality'] as int?;
    final mid = mediaItem.extras?['mid'] as int?;

    if (mediaItem.extras?['cached'] == true) {
      return;
    }

    if (bvid == null || cid == null) {
      return;
    }

    final cached = await CacheManager.isCached(bvid, cid);
    if (!cached) {
      // If not cached, start caching
      try {
        final file = await CacheManager.prepareFileForCaching(bvid, cid);
        await _downloadAndCache(bvid, cid, currentItem.uri.toString(), file, quality ?? 0, mid ?? 0, mediaItem.title, mediaItem.artist ?? '', mediaItem.artUri.toString());
      } catch (e) {
      }
    }
  }

  Future<int?> _addUniqueSourcesToPlaylist(List<UriAudioSource> sources, {int? insertIndex}) async {
    int? ret;
    for (var source in sources) {
      if (source.tag is MediaItem) {
        var mediaItem = source.tag as MediaItem;
        var duplicatePos = playlist.children.indexWhere((child) {
          if (child is UriAudioSource && child.tag is MediaItem) {
            return (child.tag as MediaItem).id == mediaItem.id;
          }
          return false;
        });

        if (duplicatePos == -1) {
          if (insertIndex != null) {
            await playlist.insert(insertIndex, source);
            ret ??= insertIndex;
            insertIndex++;
          } else {
            await playlist.add(source);
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
    final prefs = await SharedPreferences.getInstance();
    final playlistData = playlist.children.map((source) {
      if (source is UriAudioSource && source.tag is MediaItem) {
        final tag = source.tag as MediaItem;
        return PlaylistData(
          id: tag.id,
          title: tag.title,
          artist: tag.artist ?? '',
          artUri: tag.artUri?.toString() ?? '',
          audioUri: source.uri.toString(),  // Added this
          bvid: tag.extras?['bvid'] ?? '',
          cid: tag.extras?['cid'] ?? 0,
          quality: tag.extras?['quality'] ?? 0,
          mid: tag.extras?['mid'] ?? 0,
          cached: tag.extras?['cached'] ?? false,
        ).toJson();
      }
      return null;
    }).whereType<Map<String, dynamic>>().toList();

    await prefs.setString('playlist', jsonEncode(playlistData));
    await prefs.setInt('currentIndex', player.currentIndex ?? 0);
    await prefs.setInt('position', player.position.inMilliseconds);
  }

  Future<void> restorePlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    final playlistJson = prefs.getString('playlist');
    if (playlistJson == null) return;

    final List<dynamic> playlistData = jsonDecode(playlistJson);
    final sources = await Future.wait(playlistData.map((item) async {
      final data = PlaylistData.fromJson(item);
      final cachedSource = await CacheManager.getCachedAudio(data.bvid, data.cid);
      if (cachedSource != null) return cachedSource;

      return AudioSource.uri(
        Uri.parse(data.audioUri),  // Use the stored audio URI
        tag: MediaItem(
          id: data.id,
          title: data.title,
          artist: data.artist,
          artUri: Uri.parse(data.artUri),
          extras: {
            'bvid': data.bvid,
            'cid': data.cid,
            'quality': data.quality,
            'mid': data.mid,
            'cached': data.cached,
          },
        ),
      );
    }));

    await playlist.clear();
    await playlist.addAll(sources);
    
    final currentIndex = prefs.getInt('currentIndex') ?? 0;
    final position = prefs.getInt('position') ?? 0;
    if (sources.isNotEmpty) {
      await player.seek(Duration(milliseconds: position), index: currentIndex);
    }
  }
}
