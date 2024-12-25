import 'dart:io';

import 'package:bmsc/database_manager.dart';
import 'package:bmsc/service/bilibili_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:bmsc/util/logger.dart';

final _logger = LoggerUtils.getLogger('LazyAudioSource');

class LazyAudioSource extends LockCachingAudioSource {
  final String bvid;
  final int cid;

  static LazyAudioSource file(
      String bvid, int cid, String filePath, dynamic tag) {
    return LazyAudioSource._(
        bvid, cid, Uri.parse('file://$filePath'), File(filePath), tag, null);
  }

  static Future<LazyAudioSource> create(
      String bvid, int cid, Uri uri, dynamic tag) async {
    _logger
        .info('Creating LazyAudioSource for bvid: $bvid, cid: $cid, uri: $uri');
    final cacheFile = await DatabaseManager.prepareFileForCaching(bvid, cid);
    final headers = await BilibiliService.instance.then((x) => x.headers);
    final ret = LazyAudioSource._(bvid, cid, uri, cacheFile, tag, headers);
    ret.downloadProgressStream.listen((progress) {
      if (progress == 1.0) {
        DatabaseManager.saveCacheMetadata(bvid, cid, cacheFile);
        DatabaseManager.cleanupCache(ignoreFile: cacheFile);
      }
    });
    return ret;
  }

  LazyAudioSource._(this.bvid, this.cid, Uri uri, File cacheFile, dynamic tag,
      Map<String, String>? headers)
      : super(uri, headers: headers, cacheFile: cacheFile, tag: tag);
}
