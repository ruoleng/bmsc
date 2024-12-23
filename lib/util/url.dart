import 'package:bmsc/util/logger.dart';
import 'package:dio/dio.dart';

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
