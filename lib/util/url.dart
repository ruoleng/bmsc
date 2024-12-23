import 'package:bmsc/util/logger.dart';
import 'package:dio/dio.dart';
import 'package:bmsc/globals.dart' as globals;

import '../model/vid.dart';

final _logger = LoggerUtils.getLogger("url");

/// get 302 redirect url
Future<String> getRedirectUrl(String url) async {
  try {
    final dio = Dio(BaseOptions(
      followRedirects: false,
      validateStatus: (status) {
        return status == 200 || status == 301 || status == 302;
      },
    ));
    final response = await dio.get(url);
    final ret = response.headers.value('location');
    if (ret == null) {
      _logger.severe('No redirect url found for $url');
      return url;
    }
    return ret;
  } catch (e) {
    _logger.severe('Error getting redirect url: $e');
    return url;
  }
}

Future<VidResult?> getVidDetailFromUrl(String text) async {
  VidResult? vidDetail;
  String? bvid;

    final urlMatch = RegExp(r'https?://b23\.tv/[a-zA-Z0-9]+').firstMatch(text);
    if (urlMatch != null) {
      final url = urlMatch.group(0)!;
      _logger.info('b23.tv url detected, trying to get redirect url: $url');
      text = await getRedirectUrl(url);
    }

    final bvMatch = RegExp(r'[Bb][Vv][a-zA-Z0-9]{10}').firstMatch(text);
    if (bvMatch != null) {
      bvid = bvMatch.group(0)!;
      vidDetail = await globals.api.getVidDetail(bvid: bvid);
    }

    final avMatch = RegExp(r'[Aa][Vv]([0-9]+)').firstMatch(text);
    if (avMatch != null) {
      final aid = avMatch.group(1)!;
    vidDetail = await globals.api.getVidDetail(aid: aid);
  }
  return vidDetail;
}

String? extractBiliUrl(String text) {
  final urlMatch = RegExp(r'https?://b23\.tv/[a-zA-Z0-9]+').firstMatch(text);
  if (urlMatch != null) {
    return urlMatch.group(0)!;
  }

  final bvMatch = RegExp(r'[Bb][Vv][a-zA-Z0-9]{10}').firstMatch(text);
  if (bvMatch != null) {
    return bvMatch.group(0)!;
  }

  final avMatch = RegExp(r'[Aa][Vv]([0-9]+)').firstMatch(text);
  if (avMatch != null) {
    return avMatch.group(0)!;
  }
  return null;
}
