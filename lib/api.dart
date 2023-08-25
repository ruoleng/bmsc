import 'package:audio_session/audio_session.dart';
import 'package:bmsc/model/fav.dart';
import 'package:bmsc/model/fav_detail.dart';
import 'package:bmsc/model/history.dart';
import 'package:bmsc/model/search.dart';
import 'package:bmsc/model/track.dart';
import 'package:bmsc/model/vid.dart';
import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

class API {
  int? uid;
  late String cookies;
  late Map<String, String> headers;
  Dio dio = Dio();
  late AudioSession session;
  final player = AudioPlayer();
  final playlist = ConcatenatingAudioSource(
    useLazyPreparation: true,
    children: [],
  );

  API(String cookie) {
    setCookies(cookie);
    player.setAudioSource(playlist);
    player.setLoopMode(LoopMode.all);
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

  appendPlaylist(String bvid) async {
    final srcs = await getAudioSources(bvid);
    if (srcs == null) {
      return;
    }
    playlist.addAll(srcs);
  }

  playSong(String bvid) async {
    await player.pause();
    final srcs = await getAudioSources(bvid);
    if (srcs == null) {
      return;
    }

    final idx = player.currentIndex;
    await playlist.insertAll(playlist.length == 0 ? 0 : idx! + 1, srcs);
    if (idx != null) {
      await player.seekToNext();
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

  Future<String?> getAudioUrl(String bvid, int cid) async {
    final response = await dio.get(
      'https://api.bilibili.com/x/player/playurl',
      queryParameters: {'bvid': bvid, 'cid': cid, 'fnval': 16},
    );
    if (response.data['code'] != 0) {
      return null;
    }
    final track = TrackResult.fromJson(response.data['data']);
    return track.dash.audio[0].baseUrl;
  }

  Future<List<UriAudioSource>?> getAudioSources(String bvid) async {
    final vid = await getVidDetail(bvid);
    if (vid == null) {
      return null;
    }
    return (await Future.wait<UriAudioSource?>(vid.pages.map((x) async {
      final url = await getAudioUrl(bvid, x.cid);
      if (url == null) {
        return null;
      }
      return AudioSource.uri(Uri.parse(url),
          headers: headers,
          tag: MediaItem(
              id: bvid + x.cid.toString(),
              title:
                  vid.pages.length > 1 ? "${x.part} - ${vid.title}" : vid.title,
              artUri: Uri.parse(vid.pic),
              artist: vid.owner.name));
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
}
