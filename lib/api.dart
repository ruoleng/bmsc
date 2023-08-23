import 'package:bmsc/model/search.dart';
import 'package:bmsc/model/track.dart';
import 'package:bmsc/util/string.dart';
import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

class API {
  String cookies;
  late Map<String, String> headers;
  Dio dio = Dio();
  final player = AudioPlayer();

  playSong(Result vid) async {
    final url = await getAudioUrl(vid.bvid);
    final src = LockCachingAudioSource(
      Uri.parse(url!),
      headers: headers,
      tag: MediaItem(
        id: vid.id.toString(),
        title: stripHtmlIfNeeded(vid.title),
        artist: vid.author,
        artUri: Uri.parse('https:${vid.pic}'),
      ),
    );
    await player.setAudioSource(src);
    await player.play();
  }

  API(this.cookies) {
    headers = {
      'cookie': cookies,
      'User-Agent':
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/113.0",
      'referer': "https://www.bilibili.com",
    };
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers = headers;
        return handler.next(options);
      },
    ));
  }

  Future<List<Result>?> search(String value) async {
    final response = await dio.get(
      'https://api.bilibili.com/x/web-interface/search/type',
      queryParameters: {'search_type': 'video', 'keyword': value},
    );

    final ret = Search.fromJson(response.data);
    if (ret.code != 0) {
      return null;
    }
    return ret.data.result;
  }

  Future<String?> getAudioUrl(String bvid, {int idx = 0}) async {
    final cid = await getCid(bvid);
    if (cid == null) {
      return null;
    }
    final response = await dio.get(
      'https://api.bilibili.com/x/player/playurl',
      queryParameters: {'bvid': bvid, 'cid': cid[idx], 'fnval': 16},
    );
    final resp = Track.fromJson(response.data);
    if (resp.code != 0) {
      return null;
    }
    return resp.data.dash.audio[0].baseUrl;
  }

  Future<List<int>?> getCid(String bvid) async {
    final response = await dio.get(
      'https://api.bilibili.com/x/player/pagelist',
      queryParameters: {'bvid': bvid},
    );
    if (response.data['code'] != 0) {
      return null;
    }
    List<int> ret = [];
    for (final x in response.data['data']) {
      ret.add(x['cid']);
    }
    return ret;
  }
}
