import 'dart:io';

import 'package:bmsc/cache_manager.dart';
import 'package:bmsc/service/bilibili_service.dart';
import 'package:just_audio/just_audio.dart';

class LazyAudioSource extends LockCachingAudioSource {
  final String bvid;
  final int cid;

  static Future<LazyAudioSource> create(
      String bvid, int cid, Uri uri, dynamic tag) async {
    final cacheFile = await CacheManager.prepareFileForCaching(bvid, cid);
    final headers = await BilibiliService.instance.then((x) => x.headers);
    final ret = LazyAudioSource._(bvid, cid, uri, cacheFile, tag, headers);
    ret.downloadProgressStream.listen((progress) {
      if (progress == 1.0) {
        CacheManager.saveCacheMetadata(bvid, cid, cacheFile);
        CacheManager.cleanupCache(ignoreFile: cacheFile);
      }
    });
    return ret;
  }

  LazyAudioSource._(this.bvid, this.cid, Uri uri, File cacheFile, dynamic tag,
      Map<String, String>? headers)
      : super(uri, headers: headers, cacheFile: cacheFile, tag: tag);
}
