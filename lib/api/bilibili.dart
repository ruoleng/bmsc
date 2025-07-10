import 'dart:convert' as convert;

import 'package:bmsc/api/bilibili_api_constant.dart';
import 'package:bmsc/model/comment.dart';
import 'package:bmsc/model/dynamic.dart';
import 'package:bmsc/model/fav.dart';
import 'package:bmsc/model/history.dart';
import 'package:bmsc/model/meta.dart';
import 'package:bmsc/model/myinfo.dart';
import 'package:bmsc/model/search.dart';
import 'package:bmsc/model/subtitle.dart';
import 'package:bmsc/model/track.dart';
import 'package:bmsc/model/user_card.dart';
import 'package:bmsc/model/user_upload.dart' show UserUploadResult;
import 'package:bmsc/model/vid.dart';
import 'package:bmsc/service/connection_service.dart';
import 'package:bmsc/util/logger.dart';
import 'package:bmsc/service/shared_preferences_service.dart';
import 'package:bmsc/util/crypto.dart' as crypto;
import 'package:dio/dio.dart';

class BilibiliAPI {
  static final _logger = LoggerUtils.getLogger('BilibiliAPI');

  late String cookies;
  late Map<String, String> headers;
  Dio dio = Dio();
  bool noNetwork = false;
  ConnectionService connectionService = ConnectionService.getInstance();

  BilibiliAPI() {
  connectionService.initialize();
  connectionService.connectionChange.listen((result) {
    noNetwork = !result;
  });
  noNetwork = !connectionService.hasConnection;
  
  // 添加Dio的基础配置
  dio.options.connectTimeout = Duration(seconds: 30);
  dio.options.receiveTimeout = Duration(seconds: 30);
  dio.options.sendTimeout = Duration(seconds: 30);
  
  // 添加错误处理和重试拦截器
  dio.interceptors.add(InterceptorsWrapper(
    onError: (DioException e, handler) async {
      // 获取请求选项
      final options = e.requestOptions;
      
      // 获取重试次数
      options.extra['retryCount'] = (options.extra['retryCount'] ?? 0) + 1;
      
      // 如果重试次数小于3次，则重试
      if (options.extra['retryCount'] <= 3) {
        _logger.info('Retrying request (${options.extra['retryCount']}/3)...');
        
        // 等待一段时间后重试
        await Future.delayed(Duration(seconds: options.extra['retryCount']));
        
        // 重新发送请求
        return handler.resolve(await dio.fetch(options));
      }
      
      return handler.next(e);
    },
  ));
}

// 重试请求方法
Future<Response<dynamic>> _retry(RequestOptions requestOptions) async {
  final options = Options(
    method: requestOptions.method,
    headers: requestOptions.headers,
  );
  return dio.request<dynamic>(
    requestOptions.path,
    data: requestOptions.data,
    queryParameters: requestOptions.queryParameters,
    options: options,
  );
    }

  Future<void> setCookie(String cookie, {bool save = false}) async {
    if (save) {
      await SharedPreferencesService.setCookie(cookie);
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

  Future<void> resetCookies() async {
    final response = await dio.get("https://www.bilibili.com");
    final cookie = response.headers['set-cookie'];
    _logger.info('init cookies: ${response.headers['set-cookie']}');
    if (cookie != null) {
      setCookie(cookie.join('; '), save: true);
    }
  }

  Future<T?> _callAPI<T>(String url,
      {Map<String, dynamic>? queryParameters,
      T? Function(dynamic data)? callback,
      Function(dynamic data)? callbackAsync,
      bool isPost = false,
      String unwrapKey = "data",
      bool needDecode = false}) async {
    try {
      if (noNetwork) {
        _logger.info("no network. return null");
        return null;
      }
      final response = isPost
          ? await dio.post(url, queryParameters: queryParameters)
          : await dio.get(url, queryParameters: queryParameters);
      _logger.info('calling API: ${response.requestOptions.uri}');
      var data = response.data;
      if (needDecode) {
        data = convert.jsonDecode(data);
      }
      // _logger.info('response: $data');
      if ((unwrapKey == "data" && data['code'] != 0) ||
          data[unwrapKey] == null) {
        return null;
      }
      data = data[unwrapKey];
      if (callback != null) {
        return callback(data);
      }
      if (callbackAsync != null) {
        return await callbackAsync(data);
      }
      return data;
    } on DioException catch (e) {
      _logger.info('DioException: ${e.response}');
      if (e.response?.statusCode == 412) {
        throw Exception('错误代码 412，可能触发了 B 站风控，请等待一段时间后重试');
      }
      return null;
    } catch (e) {
      _logger.severe('Error calling API: $e');
      return null;
    }
  }

  Future<List<T>?> _callAPIMultiPage<T>(String url,
      {Map<String, dynamic>? queryParameters,
      required Map<String, dynamic> Function(int page) params,
      required List<T> Function(dynamic data) extract,
      required bool Function(dynamic data, int len) hasMoreCheck}) async {
    List<T> ret = [];
    int pn = 1;
    dynamic data;
    do {
      data = await _callAPI(url,
          queryParameters: {...?queryParameters, ...params(pn)});
      if (data == null) {
        return null;
      }
      ret.addAll(extract(data));
      ++pn;
    } while (hasMoreCheck(data, ret.length));
    return ret;
  }

  Future<MyInfo?> getMyInfo() {
    return _callAPI(apiMyInfoUrl, callback: (data) => MyInfo.fromJson(data));
  }

  /// 获取收藏夹列表
  /// rid: 视频稿件 avid ，检查收藏夹是否包含该稿件
  Future<List<Fav>?> getFavs(int uid, {int? rid}) async {
    return _callAPI(apiFavsUrl,
        queryParameters: {'up_mid': uid, 'rid': rid},
        callback: (data) => FavResult.fromJson(data).list);
  }

  Future<List<Fav>?> getCollection(int uid) async {
    return _callAPIMultiPage(apiCollectionUrl,
        params: (pn) => {'up_mid': uid, 'pn': pn, 'ps': 20, 'platform': 'web'},
        extract: (data) =>
            (data['list'] as List).map((x) => Fav.fromJson(x)).toList(),
        hasMoreCheck: (data, _) => data['has_more'] as bool);
  }

  Future<List<Meta>?> getCollectionMetas(int mid) async {
    return _callAPIMultiPage(apiCollectionMetasUrl,
        params: (pn) => {
              'season_id': mid,
              'ps': 20,
              'pn': pn,
            },
        extract: (data) {
          return (data['medias'] as List)
              .map((x) => Meta(
                    bvid: x['bvid'],
                    title: x['title'],
                    artist: x['upper']['name'],
                    mid: x['upper']['mid'],
                    aid: x['id'],
                    duration: x['duration'],
                    artUri: x['cover'],
                  ))
              .toList();
        },
        hasMoreCheck: (data, len) => len < (data['info']['media_count'] ?? 1));
  }

  Future<List<Meta>?> getFavMetas(int mid) async {
    return _callAPIMultiPage(apiFavMetasUrl,
        params: (pn) => {
              'media_id': mid,
              'ps': 40,
              'pn': pn,
            },
        extract: (data) => (data['medias'] as List)
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
            .toList(),
        hasMoreCheck: (data, _) => data['has_more'] as bool);
  }

  Future<UserInfoResult?> getUserInfo(int mid) {
    return _callAPI(apiUserInfoUrl,
        queryParameters: {'mid': mid},
        callback: (data) => UserInfoResult.fromJson(data));
  }

  Future<(List<Meta>, int)?> getUserUploadMetas(int mid, int pn) async {
    final params = await crypto.encodeParams({'mid': mid, 'ps': 40, 'pn': pn});
    return _callAPI(apiUserUploadsUrl, queryParameters: params,
        callback: (data) {
      final uploads = UserUploadResult.fromJson(data);
      final nextPn =
          uploads.page.pn * uploads.page.ps < uploads.page.count ? pn + 1 : -1;
      return (
        uploads.list.vlist
            .map((x) => Meta(
                aid: x.aid,
                bvid: x.bvid,
                mid: mid,
                title: x.title,
                artist: x.author,
                artUri: x.pic,
                parts: x.play,
                duration: int.parse(x.length.split(':')[0]) * 60 +
                    int.parse(x.length.split(':')[1])))
            .toList(),
        nextPn
      );
    });
  }

  Future<CommentData?> getComment(String aid, String? offset) async {
    return _callAPI(apiCommentUrl,
        queryParameters: await crypto
            .encodeParams({'oid': aid, 'type': 1, 'pagination_str': offset}),
        callback: (data) => CommentData.fromJson(data));
  }

  Future<CommentData?> getCommentsOfComment(int oid, int root, int pn) {
    return _callAPI(apiCommentsOfCommentUrl,
        queryParameters: {
          'type': 1,
          'oid': oid,
          'root': root,
          'pn': pn,
          'ps': 20
        },
        callback: (data) => CommentData.fromJson(data));
  }

  Future<SearchResult?> search(String value, int pn) {
    return _callAPI(apiSearchUrl,
        queryParameters: {'search_type': 'video', 'keyword': value, 'page': pn},
        callback: (data) => SearchResult.fromJson(data));
  }

  Future<HistoryResult?> getHistory(int? timestamp) {
    return _callAPI(apiHistoryUrl,
        queryParameters: {'type': 'archive', 'view_at': timestamp},
        callback: (data) => HistoryResult.fromJson(data));
  }

  Future<DynamicResult?> getDynamics(String? offset) {
    return _callAPI(apiDynamicUrl,
        queryParameters: {'type': 'video', 'offset': offset},
        callback: (data) => DynamicResult.fromJson(data));
  }

  Future<VidResult?> getVidDetail({String? bvid, String? aid}) async {
    assert(bvid != null || aid != null, 'Either bvid or aid must be provided');
    assert(!(bvid != null && aid != null), 'Cannot provide both bvid and aid');
    return _callAPI(apiVideoDetailUrl,
        queryParameters: {
          'bvid': bvid,
          'aid': aid,
        },
        callback: (data) => VidResult.fromJson(data));
  }

  Future<List<Audio>?> getAudio(String bvid, int cid) async {
    final hires = await SharedPreferencesService.getHiResFirst();
    return _callAPI(apiAudioUrl,
        queryParameters: {'bvid': bvid, 'cid': cid, 'fnval': 4048},
        callback: (data) {
      final dash = TrackResult.fromJson(data).dash;
      if (hires && dash.flac?.audio != null) {
        return [dash.flac!.audio!] + dash.audio;
      } else {
        return dash.audio;
      }
    });
  }

  Future<bool?> favoriteVideo(int avid, List<int> adds, List<int> dels) {
    return _callAPI(
      apiDoFavVideoUrl,
      queryParameters: {
        'rid': avid,
        'type': 2,
        'add_media_ids': adds.join(','),
        'del_media_ids': dels.join(','),
        'csrf': crypto.extractCSRF(cookies),
      },
      callback: (_) => true,
      isPost: true,
    );
  }

  Future<bool?> isFavorited(int aid) async {
    return _callAPI(apiIsFavoritedUrl,
        queryParameters: {'aid': aid}, callback: (data) => data['favoured']);
  }

  Future<Fav?> createFavFolder(String name, {bool hide = false}) async {
    return _callAPI(apiCreateFavFolderUrl,
        queryParameters: {
          'title': name,
          'privacy': hide ? 1 : 0,
          'csrf': crypto.extractCSRF(cookies)
        },
        callback: (data) => Fav.fromJson(data),
        isPost: true);
  }

  Future<bool?> deleteFavFolder(int mediaId) {
    return _callAPI(apiDeleteFavFolderUrl,
        queryParameters: {
          'media_ids': mediaId,
          'csrf': crypto.extractCSRF(cookies)
        },
        isPost: true);
  }

  Future<bool?> editFavFolder(int mediaId, String name, {bool hide = false}) {
    return _callAPI(apiEditFavFolderUrl,
        queryParameters: {
          'media_id': mediaId,
          'title': name,
          'privacy': hide ? 1 : 0,
          'csrf': crypto.extractCSRF(cookies)
        },
        isPost: true);
  }

  Future<List<Meta>?> getRelatedVideos(int aid,
      {List<int>? tidWhitelist}) async {
    return _callAPI(apiRelatedVideosUrl,
        queryParameters: {'aid': aid},
        callback: (data) => (data as List)
            .where((video) => tidWhitelist?.contains(video['tid']) ?? true)
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
            .toList());
  }

  Future<List<String>?> getSearchSuggestions(String keyword) async {
    return _callAPI(apiSearchSuggestionsUrl,
        queryParameters: {'term': keyword},
        unwrapKey: 'result',
        needDecode: true, callback: (data) {
      List<String> suggestions = [];
      for (final tag in data['tag']) {
        suggestions.add(tag['term'] as String);
      }
      return suggestions;
    });
  }

  Future<void> reportHistory(int aid, int cid, int? progress) {
    return _callAPI(apiReportHistoryUrl,
        queryParameters: {
          'aid': aid,
          'cid': cid,
          'progress': progress,
          'csrf': crypto.extractCSRF(cookies),
        },
        isPost: true);
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
    final data = await _callAPI(apiNavUrl);
    if (data == null) return null;
    final wbiImg = data['wbi_img'];
    final imgsubNew = wbiImg['img_url'] as String?;
    final subidNew = wbiImg['sub_url'] as String?;
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

  Future<Map<String, String>?> getLoginCaptcha() async {
    return _callAPI(apiLoginCaptchaUrl,
        queryParameters: {'source': 'main_web'},
        callback: (data) => {
              'challenge': data['geetest']['challenge'],
              'gt': data['geetest']['gt'],
              'token': data['token'],
            });
  }

  Future<List<(String, String)>?> getSubTitleInfo(int aid, int cid) async {
    return _callAPI(apiPlayer, queryParameters: {'aid': aid, 'cid': cid},
        callback: (data) {
      final subtitles = data['subtitle']['subtitles'] as List<dynamic>;
      return subtitles.map((x) {
        var url = x['subtitle_url'] as String;
        if (url != "" && url[0] == '/') {
          url = "https:$url";
        }
        return (x['lan_doc'] as String, url);
      }).toList();
    });
  }

  Future<List<BilibiliSubtitle>?> getSubTitleData(String url) async {
    return _callAPI(url,
        unwrapKey: "body",
        callback: (data) => (data as List<dynamic>)
            .map((x) => BilibiliSubtitle.fromJson(x))
            .toList());
  }

  Future<Map<String, dynamic>?> _getLoginKey() async {
    return _callAPI(apiLoginKeyUrl);
  }

  Future<(bool, String?)> passwordLogin({
    required String username,
    required String password,
    required Map<String, dynamic> geetestResult,
  }) async {
    _logger.info('Logging in with username: $username');
    try {
      final loginKey = await _getLoginKey();
      if (loginKey == null) {
        throw Exception('Failed to get login key');
      }

      final encryptedPassword =
          crypto.encryptPassword(password, loginKey['key']!, loginKey['hash']!);

      final loginResponse = await dio.post(
        apiPasswordLoginUrl,
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

      if (loginResponse.data['code'] != 0) {
        return (false, "网络错误");
      }

      if (loginResponse.data['data']['status'] != 0) {
        return (false, loginResponse.data['data']['message'] as String);
      }

      final cookies = loginResponse.headers['set-cookie'];
      if (cookies != null) {
        await setCookie(cookies.join(';'), save: true);
      }

      return (true, null);
    } catch (e) {
      _logger.severe('Login error: $e');
      return (false, e.toString());
    }
  }

  Future<(String, String?)> getSmsLoginCaptcha({
    required int tel,
    required Map<String, dynamic> geetestResult,
  }) async {
    try {
      final response = await dio.post(
        apiSmsCaptchaUrl,
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
        apiSmsLoginUrl,
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
        await setCookie(cookies.join(';'), save: true);
      }

      return (true, null);
    } catch (e) {
      _logger.severe('Login error: $e');
      return (false, e.toString());
    }
  }

  Future<(String, String)?> getQrcodeLoginInfo() async {
    return _callAPI(apiGetQrcodeLoginUrl,
        callback: (data) =>
            (data['url'] as String, data['qrcode_key'] as String));
  }

  Future<int?> checkQrcodeLoginStatus(String qrcodeKey) async {
    try {
      final loginResponse = await dio.get(
        apiCheckQrcodeLoginStatusUrl,
        queryParameters: {
          'qrcode_key': qrcodeKey,
        },
      );
      _logger
          .info('called login with url: ${loginResponse.requestOptions.uri}');

      if (loginResponse.data['code'] != 0) {
        _logger.severe('Login error: ${loginResponse.data['message']}');
        return null;
      }

      if (loginResponse.data['data']['code'] == 0) {
        final cookies = loginResponse.headers['set-cookie'];
        if (cookies != null) {
          await setCookie(cookies.join(';'), save: true);
        }
        return 0;
      }
      return loginResponse.data['data']['code'];
    } catch (e) {
      _logger.severe('Login error: $e');
      return null;
    }
  }
}
