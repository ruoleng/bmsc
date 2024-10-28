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
import 'package:bmsc/model/tag.dart';

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
  bool recommendationMode = false;
  static const int _recommendationBatchSize = 3;

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
          if (recommendationMode) {
            _handleTrackChange(player.currentIndex!);
          }
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

  Future<void> appendPlaylistSingle(String bvid, {int? insertIndex, Map<String, dynamic>? extraExtras}) async {
    final srcs = await getAudioSources(bvid);
    if (srcs == null) {
      return;
    }
    await _addUniqueSourcesToPlaylist([srcs[0]], insertIndex: insertIndex, extraExtras: extraExtras);
  }

  Future<void> appendPlaylist(String bvid, {int? insertIndex, Map<String, dynamic>? extraExtras}) async {
    final srcs = await getAudioSources(bvid);
    if (srcs == null) {
      return;
    }
    await _addUniqueSourcesToPlaylist(srcs, insertIndex: insertIndex, extraExtras: extraExtras);
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
                'aid': vid.aid,
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

  Future<void> _downloadAndCache(String bvid, int aid, int cid, String url, File file, int quality, int mid, String title, String artist, String artUri) async {
    try {
      final request = http.Request('GET', Uri.parse(url));
      request.headers.addAll(headers);
      final response = await http.Client().send(request);

      final sink = file.openWrite();
      await response.stream.pipe(sink);
      await sink.close();

      await CacheManager.saveCacheMetadata(bvid, aid, cid, quality, mid, file.path, title, artist, artUri);
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
    final aid = mediaItem.extras?['aid'] as int?;
    final quality = mediaItem.extras?['quality'] as int?;
    final mid = mediaItem.extras?['mid'] as int?;

    if (mediaItem.extras?['cached'] == true) {
      return;
    }

    if (bvid == null || cid == null || aid == null) {
      return;
    }

    final cached = await CacheManager.isCached(bvid, cid);
    if (!cached) {
      // If not cached, start caching
      try {
        final file = await CacheManager.prepareFileForCaching(bvid, cid);
        await _downloadAndCache(bvid, aid, cid, currentItem.uri.toString(), file, quality ?? 0, mid ?? 0, mediaItem.title, mediaItem.artist ?? '', mediaItem.artUri.toString());
      } catch (e) {
      }
    }
  }

  Future<int?> _addUniqueSourcesToPlaylist(List<UriAudioSource> sources, {int? insertIndex, Map<String, dynamic>? extraExtras}) async {
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
          if (extraExtras != null) {
            mediaItem.extras?.addAll(extraExtras!);
          }
          if (insertIndex != null) {
            print(source.uri);
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
          aid: tag.extras?['aid'] ?? 0,
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

  void enableRecommendationMode() async {
    if (recommendationMode) return;
    recommendationMode = true;
    
    // Get current track's bvid
    final currentSource = player.sequence?[player.currentIndex ?? 0];
    if (currentSource == null) return;
    
    final currentBvid = (currentSource.tag as MediaItem).extras?['bvid'] as String?;
    if (currentBvid == null) return;

    // Add initial batch of recommendations
    await _addRecommendedTracks(currentBvid);

  }

  void disableRecommendationMode() {
    recommendationMode = false;
    removeRecommendations();
  }

  Future<void> removeRecommendations() async {
    final toRemove = <int>[];
    for (int i = 0; i < playlist.length; i++) {
      final source = playlist.sequence[i];
      if ((source.tag as MediaItem).extras?['isRecommendation'] as bool? ?? false) {
        toRemove.add(i);
      }
    }
    // Remove in reverse order to maintain correct indices
    for (final index in toRemove.reversed) {
      await playlist.removeAt(index);
    }
  }

  Future<void> _handleTrackChange(int currentIndex) async {
    if (!recommendationMode) return;
    
    final currentSource = player.sequence?[currentIndex];
    if (currentSource == null) return;
    
    // Check if current song is a recommendation
    final isRecommendation = (currentSource.tag as MediaItem).extras?['isRecommendation'] as bool? ?? false;
    
    if (!isRecommendation) {
      final lastIndex = currentIndex == 0 ? player.sequence!.length - 1 : currentIndex - 1;
      final isLastRecommendation =
          ((player.sequence![lastIndex].tag as MediaItem).extras?['isRecommendation'] as bool? ?? false);
      final isNextRecommendation =
          ((player.sequence![currentIndex + 1].tag as MediaItem).extras?['isRecommendation'] as bool? ?? false);
      if (isLastRecommendation && !isNextRecommendation) {
        final bvid = (currentSource.tag as MediaItem).extras?['bvid'] as String?;
        if (bvid != null) {
          await _addRecommendedTracks(bvid);
        }
      }
    }
  }

  Future<void> _addRecommendedTracks(String bvid) async {
    try {
      final recommendations = await _getRecommendations(bvid);
      if (recommendations.isEmpty) return;

      // Take up to _recommendationBatchSize unique recommendations
      final uniqueRecs = recommendations.take(_recommendationBatchSize);
      final insertIndex = player.currentIndex! + 1;
      
      for (final (recBvid, _) in uniqueRecs) {
        // Add recommendation flag when creating the audio source
        await appendPlaylistSingle(
          recBvid,
          insertIndex: insertIndex,
          extraExtras: {'isRecommendation': true}
        );
      }
    } catch (e) {
      print('Failed to get recommendations: $e');
    }
  }

  Future<List<(String, int)>> _getRecommendations(String bvid) async {
    final response = await dio.get(
      'https://api.bilibili.com/x/web-interface/archive/related',
      queryParameters: {'bvid': bvid},
    );
    
    if (response.data['code'] == 0) {
      final List<dynamic> related = response.data['data'];
      return related
          .map((video) => (video['bvid'] as String, video['cid'] as int))
          .where((tuple) => !_isInPlaylist(tuple.$1, tuple.$2))
          .toList();
    }
    return [];
  }

  bool _isInPlaylist(String bvid, int cid) {
    return playlist.children.any((source) {
      if (source is UriAudioSource && source.tag is MediaItem) {
        return (source.tag as MediaItem).extras?['bvid'] == bvid && (source.tag as MediaItem).extras?['cid'] == cid;
      }
      return false;
    });
  }

  Future<bool> favoriteVideo(int avid, List<int> addMediaIds, List<int> delMediaIds) async {
    final response = await dio.post(
      'https://api.bilibili.com/x/v3/fav/resource/deal',
      queryParameters: {
        'rid': avid,
        'type': 2,  // 2 represents video type
        'add_media_ids': addMediaIds.join(','),
        'del_media_ids': delMediaIds.join(','),
        'csrf': _extractCSRF(cookies),
      }
    );
    print(response.data);
    return response.data['code'] == 0;
  }

  String _extractCSRF(String cookies) {
    final csrfMatch = RegExp(r'bili_jct=([^;]+)').firstMatch(cookies);
    return csrfMatch?.group(1) ?? '';
  }

  Future<bool> isFavorited(int aid) async {
    final response = await dio.get("https://api.bilibili.com/x/v2/fav/video/favoured",
      queryParameters: {'aid': aid});
    if (response.data['code'] != 0) {
      return false;
    }
    return response.data['data']['favoured'];
  }

  Future<int?> getDefaultFavFolder() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('default_fav_folder');
  }

  Future<void> setDefaultFavFolder(int folderId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('default_fav_folder', folderId);
  }
}
