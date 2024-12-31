import 'dart:convert';

import 'package:bmsc/api/bilibili.dart';
import 'package:bmsc/audio/lazy_audio_source.dart';
import 'package:bmsc/database_manager.dart';
import 'package:bmsc/model/comment.dart';
import 'package:bmsc/model/dynamic.dart';
import 'package:bmsc/model/entity.dart';
import 'package:bmsc/model/fav.dart';
import 'package:bmsc/model/history.dart';
import 'package:bmsc/model/myinfo.dart';
import 'package:bmsc/model/search.dart';
import 'package:bmsc/model/track.dart';
import 'package:bmsc/model/user_card.dart' show UserInfoResult;
import 'package:bmsc/model/user_upload.dart' show UserUploadResult;
import 'package:bmsc/model/vid.dart';
import 'package:bmsc/service/shared_preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../model/meta.dart';
import '../util/logger.dart';

final _logger = LoggerUtils.getLogger('BilibiliService');

class BilibiliService {
  static final instance = _init();

  static Future<BilibiliService> _init() async {
    final service = BilibiliService();
    final cookie = await SharedPreferencesService.getCookie();

    if (cookie != null) {
      service._bilibiliAPI.setCookie(cookie);
    } else {
      _logger.info('No cookie found, resetting cookies');
      await service._bilibiliAPI.resetCookies();
    }

    service.myInfo = await SharedPreferencesService.getMyInfo();

    final newInfo = await service._bilibiliAPI.getMyInfo();
    if (newInfo != null) {
      await SharedPreferencesService.setMyInfo(newInfo);
      service.myInfo = newInfo;
    }
    return service;
  }

  final BilibiliAPI _bilibiliAPI = BilibiliAPI();
  Map<String, String>? get headers => _bilibiliAPI.headers;
  MyInfo? myInfo;

  Future<void> refreshMyInfo() async {
    myInfo = await _bilibiliAPI.getMyInfo();
    if (myInfo != null) {
      await SharedPreferencesService.setMyInfo(myInfo!);
    }
  }

  Future<void> logout() async {
    await _bilibiliAPI.resetCookies();
    myInfo = null;
    await SharedPreferencesService.setMyInfo(MyInfo(0, "", "", ""));
  }

  Future<List<Fav>?> getFavs(int mid, {int? rid}) async {
    final ret = await _bilibiliAPI.getFavs(mid, rid: rid);
    if (ret != null) {
      DatabaseManager.cacheFavList(ret);
    }
    return ret;
  }

  Future<List<Fav>?> getCollection(int mid) async {
    final ret = await _bilibiliAPI.getCollection(mid);
    if (ret != null) {
      DatabaseManager.cacheCollectedFavList(ret);
    }
    return ret;
  }

  Future<List<Meta>?> getCollectionMetas(int mid) async {
    final ret = await _bilibiliAPI.getCollectionMetas(mid);
    if (ret != null) {
      DatabaseManager.cacheMetas(ret);
      DatabaseManager.cacheCollectedFavListVideo(
          ret.map((x) => x.bvid).toList(), mid);
    }
    return ret;
  }

  Future<List<Meta>?> getFavMetas(int mid) async {
    final ret = await _bilibiliAPI.getFavMetas(mid);
    if (ret != null) {
      DatabaseManager.cacheMetas(ret);
      DatabaseManager.cacheFavListVideo(ret.map((x) => x.bvid).toList(), mid);
    }
    return ret;
  }

  Future<SearchResult?> search(String value, int pn) {
    return _bilibiliAPI.search(value, pn);
  }

  Future<UserInfoResult?> getUserInfo(int mid) {
    return _bilibiliAPI.getUserInfo(mid);
  }

  Future<UserUploadResult?> getUserUploads(int mid, int pn) {
    return _bilibiliAPI.getUserUploads(mid, pn);
  }

  Future<HistoryResult?> getHistory(int? timestamp) {
    return _bilibiliAPI.getHistory(timestamp);
  }

  Future<DynamicResult?> getDynamics(String? offset) {
    return _bilibiliAPI.getDynamics(offset);
  }

  Future<VidResult?> getVidDetail({String? bvid, String? aid}) async {
    final ret = await _bilibiliAPI.getVidDetail(bvid: bvid, aid: aid);
    if (ret != null) {
      DatabaseManager.cacheMetas([
        Meta(
          bvid: ret.bvid,
          aid: ret.aid,
          title: ret.title,
          artist: ret.owner.name,
          mid: ret.owner.mid,
          duration: ret.duration,
          parts: ret.videos,
          artUri: ret.pic,
        )
      ]);
      await DatabaseManager.cacheEntities(ret.pages
          .map((x) => Entity(
                bvid: ret.bvid,
                aid: ret.aid,
                cid: x.cid,
                duration: x.duration,
                part: x.page,
                artist: ret.owner.name,
                artUri: ret.pic,
                partTitle: x.part,
                bvidTitle: ret.title,
                excluded: 0,
              ))
          .toList());
    }
    return ret;
  }

  Future<List<Audio>?> getAudio(String bvid, int cid) {
    return _bilibiliAPI.getAudio(bvid, cid);
  }

  Future<List<LazyAudioSource>?> getAudios(String bvid) async {
    _logger.info('Fetching audio sources for BVID: $bvid');
    var entities = await DatabaseManager.getEntities(bvid);
    if (entities.isEmpty) {
      await getVidDetail(bvid: bvid);
      entities = await DatabaseManager.getEntities(bvid);
    }
    if (entities.isEmpty) {
      _logger.warning('Failed to get video details for BVID: $bvid');
      return null;
    }
    final meta = await DatabaseManager.getMeta(bvid);
    return (await Future.wait<LazyAudioSource?>(entities.map((x) async {
      final cachedSource = await DatabaseManager.getLocalAudio(bvid, x.cid);
      if (cachedSource != null) {
        return cachedSource;
      }
      final tag = MediaItem(
          id: '${bvid}_${x.cid}',
          title: entities.length > 1 ? "${x.bvidTitle} - ${x.partTitle}" : x.bvidTitle,
          artUri: Uri.parse(x.artUri),
          artist: x.artist,
          extras: {
            'mid': meta?.mid,
            'bvid': meta?.bvid,
            'aid': meta?.aid,
            'cid': x.cid,
            'cached': false,
            'raw_title': x.bvidTitle,
            'multi': entities.length > 1,
          });
      return LazyAudioSource(bvid, x.cid, tag: tag);
    })))
        .whereType<LazyAudioSource>()
        .toList();
    // }
  }

  Future<CommentData?> getComment(String aid, String? offset) {
    return _bilibiliAPI.getComment(aid, offset);
  }

  Future<CommentData?> getCommentsOfComment(int oid, int root, int pn) {
    return _bilibiliAPI.getCommentsOfComment(oid, root, pn);
  }

  Future<bool?> favoriteVideo(
      int avid, List<int> addMediaIds, List<int> delMediaIds) {
    return _bilibiliAPI.favoriteVideo(avid, addMediaIds, delMediaIds);
  }

  Future<bool?> isFavorited(int aid) {
    return _bilibiliAPI.isFavorited(aid);
  }

  Future<Fav?> createFavFolder(String name, {bool hide = false}) {
    return _bilibiliAPI.createFavFolder(name, hide: hide);
  }

  Future<bool?> deleteFavFolder(int fid) {
    return _bilibiliAPI.deleteFavFolder(fid);
  }

  Future<bool?> editFavFolder(int fid, String name, {bool hide = false}) {
    return _bilibiliAPI.editFavFolder(fid, name, hide: hide);
  }

  Future<List<Meta>?> getRelatedVideos(int aid, {List<int>? tidWhitelist}) {
    return _bilibiliAPI.getRelatedVideos(aid, tidWhitelist: tidWhitelist);
  }

  Future<List<String>?> getSearchSuggestions(String keyword) {
    return _bilibiliAPI.getSearchSuggestions(keyword);
  }

  Future<void> reportHistory(int aid, int cid, int? progress) {
    return _bilibiliAPI.reportHistory(aid, cid, progress);
  }

  Future<(bool, String?)> passwordLogin(
      String username, String password, Map<String, dynamic> geetestResult) {
    return _bilibiliAPI.passwordLogin(
        username: username, password: password, geetestResult: geetestResult);
  }

  Future<(bool, String?)> smsLogin(int tel, String code, String captchaKey) {
    return _bilibiliAPI.smslogin(tel: tel, code: code, captchaKey: captchaKey);
  }

  Future<(String, String?)> getSmsLoginCaptcha(
      int tel, Map<String, dynamic> geetestResult) {
    return _bilibiliAPI.getSmsLoginCaptcha(
        tel: tel, geetestResult: geetestResult);
  }

  Future<Map<String, String>?> getLoginCaptcha() {
    return _bilibiliAPI.getLoginCaptcha();
  }

  Future<String?> getRawWbiKey() {
    return _bilibiliAPI.getRawWbiKey();
  }

  Future<List<Meta>?> getRecommendations(List<Meta> tracks) async {
    if (tracks.isEmpty) {
      return null;
    }

    final prefs = await SharedPreferencesService.instance;
    final recommendHistory = prefs.getString('recommend_history');
    Set<String> history = recommendHistory != null
        ? Set<String>.from(jsonDecode(recommendHistory))
        : {};

    const tidWhitelist = [130, 193, 267, 28, 59];

    List<Meta> recommendedVideos = [];
    for (var track in tracks) {
      var videos =
          await getRelatedVideos(track.aid, tidWhitelist: tidWhitelist);
      if (videos != null && videos.isNotEmpty) {
        for (final video in videos) {
          if (!history.contains(video.bvid) && video.duration >= 60) {
            recommendedVideos.add(video);
            history.add(video.bvid);
            break;
          }
        }
      }
    }
    await prefs.setString('recommend_history', jsonEncode(history.toList()));
    await DatabaseManager.cacheMetas(recommendedVideos);
    return recommendedVideos;
  }

  Future<List<Meta>?> getDailyRecommendations({bool force = false}) async {
    final prefs = await SharedPreferencesService.instance;
    final lastUpdateStr = prefs.getString('last_recommendations_update');
    final recommendations = prefs.getString('daily_recommendations');

    if (lastUpdateStr != null) {}
    final lastUpdate =
        lastUpdateStr != null ? DateTime.parse(lastUpdateStr) : null;
    final now = DateTime.now();
    if (lastUpdate == null ||
        !DateUtils.isSameDay(now, lastUpdate) ||
        recommendations == null ||
        force == true) {
      final defaultFavFolder =
          await SharedPreferencesService.getDefaultFavFolder();
      if (defaultFavFolder == null) return null;

      final favVideos = await getFavMetas(defaultFavFolder.$1);
      if (favVideos == null || favVideos.isEmpty) return null;

      favVideos.shuffle();
      final selectedVideos = favVideos.take(30).toList();

      final recommendedVideos = await getRecommendations(selectedVideos) ?? [];

      await prefs.setString(
          'last_recommendations_update', now.toIso8601String());
      await prefs.setString('daily_recommendations',
          jsonEncode(recommendedVideos.map((v) => v.toJson()).toList()));

      return recommendedVideos;
    }

    final List<dynamic> decoded = jsonDecode(recommendations);
    return decoded.map((v) => Meta.fromJson(v)).toList();
  }
}
