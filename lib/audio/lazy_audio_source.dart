import 'dart:io';

import 'package:bmsc/cache_manager.dart';
import 'package:just_audio/just_audio.dart';
import 'package:bmsc/globals.dart' as globals;

class LazyAudioSource extends LockCachingAudioSource {
  final String bvid;
  final int cid;

  static Future<LazyAudioSource> create(
      String bvid, int cid, Uri uri, dynamic tag) async {
    final cacheFile = await CacheManager.prepareFileForCaching(bvid, cid);
    final ret = LazyAudioSource._(bvid, cid, uri, cacheFile, tag);
    ret.downloadProgressStream.listen((progress) {
      if (progress == 1.0) {
        CacheManager.saveCacheMetadata(bvid, cid, cacheFile.path);
      }
    });
    return ret;
  }

  LazyAudioSource._(this.bvid, this.cid, Uri uri, File cacheFile, dynamic tag)
      : super(uri,
            headers: globals.api.headers, cacheFile: cacheFile, tag: tag);
}
