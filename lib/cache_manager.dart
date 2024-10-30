import 'dart:io';
import 'dart:async';
import 'package:bmsc/model/entity.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:audio_service/audio_service.dart';
import 'package:path/path.dart';
import 'package:just_audio/just_audio.dart';
import '../model/fav.dart';
import '../model/fav_detail.dart';
import '../model/meta.dart';

class CacheManager {
  static Database? _database;
  static const String tableName = 'audio_cache';
  static const String metaTable = 'meta_cache';
  static const String favListVideoTable = 'fav_list_video';
  static const String entityTable = 'entity_cache';
  static const String favListTable = 'fav_list';
  static const String favDetailTable = 'fav_detail';

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDB();
    return _database!;
  }

  static Future<Database> initDB() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, "AudioCache.db");
    return await openDatabase(path, version: 1, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE $tableName (
          id TEXT PRIMARY KEY,
          bvid TEXT,
          cid INTEGER,
          aid INTEGER,
          title TEXT,
          artist TEXT,
          artUri TEXT,
          mid INTEGER,
          multi INTEGER,
          raw_title TEXT,
          filePath TEXT,
          createdAt INTEGER
        )
      ''');

      await db.execute('''
        CREATE TABLE $entityTable (
          aid INTEGER,
          cid INTEGER,
          bvid TEXT,
          artist TEXT,
          part INTEGER,
          duration INTEGER,
          excluded INTEGER,
          part_title TEXT,
          bvid_title TEXT,
          PRIMARY KEY (bvid, cid)
        )
      ''');

      await db.execute('''
        CREATE TABLE $metaTable (
          bvid TEXT PRIMARY KEY,
          aid INTEGER,
          title TEXT,
          artist TEXT,
          mid INTEGER,
          duration INTEGER,
          parts INTEGER,
          list_order INTEGER
        )
      ''');

      await db.execute('''
        CREATE TABLE $favListVideoTable (
          bvid TEXT,
          mid INTEGER,
          PRIMARY KEY (bvid, mid)
        )
      ''');
      
      await db.execute('''
        CREATE TABLE $favListTable (
          id INTEGER PRIMARY KEY,
          title TEXT,
          mediaCount INTEGER,
          list_order INTEGER
        )
      ''');

      await db.execute('''
        CREATE TABLE $favDetailTable (
          id INTEGER,
          title TEXT,
          cover TEXT,
          page INTEGER,
          duration INTEGER,
          upper_name TEXT,
          play_count INTEGER,
          bvid TEXT,
          fav_id INTEGER,
          list_order INTEGER,
          PRIMARY KEY (id, fav_id)
        )
      ''');
    });
  }

  static Future<void> addExcludedPart(String bvid, int cid) async {
    final db = await database;
    await db.update(
      entityTable,
      {'excluded': 1},
      where: 'bvid = ? AND cid = ?',
      whereArgs: [bvid, cid],
    );
  }

  static Future<void> cacheMetas(List<Meta> metas) async {
    final db = await database;
    final batch = db.batch();
    for (int i = 0; i < metas.length; i++) {
      var json = metas[i].toJson();
      json['list_order'] = i;
      batch.insert(metaTable, json, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit();
  }

  static Future<Meta?> getMeta(String bvid) async {
    final db = await database;
    final results = await db.query(metaTable, where: 'bvid = ?', whereArgs: [bvid]);
    final ret = results.firstOrNull;
    if (ret == null) {
      return null;
    }
    return Meta.fromJson(ret);
  }

  static Future<List<Meta>> getMetas(List<String> bvids) async {
    final db = await database;
    final placeholders = List.filled(bvids.length, '?').join(',');
    final results = await db.query(
      metaTable,
      where: 'bvid IN ($placeholders)',
      whereArgs: bvids,
      orderBy: 'list_order ASC'
    );
    return results.map((e) => Meta.fromJson(e)).toList();
  }

  static Future<void> removeExcludedPart(String bvid, int cid) async {
    final db = await database;
     await db.update(
      entityTable,
      {'excluded': 0},
      where: 'bvid = ? AND cid = ?',
      whereArgs: [bvid, cid],
    );
  }

  static Future<List<int>> getExcludedParts(String bvid) async {
    final db = await database;
    final results = await db.query(
      entityTable,
      where: 'bvid = ? AND excluded = 1',
      whereArgs: [bvid],
    );
    return results.map((row) => row['cid'] as int).toList();
  }

  static Future<void> cacheEntities(List<Entity> data) async {
    final db = await database;
    final batch = db.batch();
    for (var item in data) {
      batch.insert(entityTable, item.toJson());
    }
    await batch.commit();
  }

  static Future<List<Entity>> getEntities(String bvid) async {
    final db = await database;
    final results = await db.query(
      entityTable,
      where: 'bvid = ?',
      whereArgs: [bvid],
    );
    return results.map((e) => Entity.fromJson(e)).toList();
  }

  static Future<int> cachedCount(String bvid) async {
    final db = await database;
    final results = await db.query(
      tableName,
      where: "bvid = ?",
      whereArgs: [bvid],
    );
    return results.length;
  }

  static Future<bool> isCached(String bvid, int cid) async {
    final db = await database;
    final results = await db.query(
      tableName,
      where: "bvid = ? AND cid = ?",
      whereArgs: [bvid, cid],
    );
    return results.isNotEmpty;
  }

  static Future<List<UriAudioSource>?> getCachedAudioList(String bvid) async {
    final db = await database;
    final results = await db.query(
      tableName,
      where: "bvid = ?",
      whereArgs: [bvid],
    );

    if (results.isNotEmpty) {
      return results.map((result) {
      final filePath = result['filePath'] as String;
      return AudioSource.file(filePath, tag: MediaItem(
        id: result['id'] as String,
        title: result['title'] as String,
        artist: result['artist'] as String,
        artUri: Uri.parse(result['artUri'] as String),
        extras: {
          'bvid': result['bvid'] as String,
          'aid': result['aid'] as int,
          'cid': result['cid'] as int,
          'mid': result['mid'] as int,
          'multi': result['multi'] as int == 1,
          'raw_title': result['raw_title'] as String,
          'cached': true
          },
        ));
      }).toList();
    }
    return null;
  }

  static Future<UriAudioSource?> getCachedAudio(String bvid, int cid) async {
    final db = await database;
    final results = await db.query(
      tableName,
      where: "bvid = ? AND cid = ?",
      whereArgs: [bvid, cid],
    );

    if (results.isNotEmpty) {
      final filePath = results.first['filePath'] as String;
      return AudioSource.file(filePath, tag: MediaItem(
        id: results.first['id'] as String,
        title: results.first['title'] as String,
        artist: results.first['artist'] as String,
        artUri: Uri.parse(results.first['artUri'] as String),
        extras: {
          'bvid': results.first['bvid'] as String,
          'aid': results.first['aid'] as int,
          'cid': results.first['cid'] as int,
          'mid': results.first['mid'] as int,
          'multi': results.first['multi'] as int == 1,
          'raw_title': results.first['raw_title'] as String,
          'cached': true
        },
      ));
    }
    return null;
  }

  static Future<File> prepareFileForCaching(String bvid, int cid) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = '${bvid}_$cid.mp3';
    final filePath = join(directory.path, fileName);
    return File(filePath);
  }

  static Future<void> saveCacheMetadata(String bvid, int aid, int cid, int mid, String filePath, String title, String artist, String artUri, bool multi, String rawTitle) async {
    final db = await database;
    await db.insert(tableName, {
      'id': '${bvid}_$cid',
      'bvid': bvid,
      'aid': aid,
      'cid': cid,
      'mid': mid,
      'filePath': filePath,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'title': title,
      'artist': artist,
      'artUri': artUri,
      'multi': multi ? 1 : 0,
      'raw_title': rawTitle,
    });
  }

  static Future<void> resetCache() async {
    final db = await database;
    await db.delete(tableName);
  }

  static Future<void> cacheFavList(List<Fav> favs) async {
    final db = await database;
    
    // Clear existing table first
    await db.delete(favListTable);
    
    final batch = db.batch();
    
    for (int i = 0; i < favs.length; i++) {
      batch.insert(
        favListTable,
        {
          'id': favs[i].id,
          'title': favs[i].title,
          'mediaCount': favs[i].mediaCount,
          'list_order': i,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit();
  }

  static Future<void> cacheFavDetail(int favId, List<Medias> medias) async {
    final db = await database;
    final batch = db.batch();
    
    // First clear existing entries for this fav_id to avoid order conflicts
    await db.delete(
      favDetailTable,
      where: 'fav_id = ?',
      whereArgs: [favId],
    );
    
    // Insert with order information
    for (int i = 0; i < medias.length; i++) {
      final media = medias[i];
      batch.insert(
        favDetailTable,
        {
          'id': media.id,
          'title': media.title,
          'cover': media.cover,
          'page': media.page,
          'duration': media.duration,
          'upper_name': media.upper.name,
          'play_count': media.cntInfo.play,
          'bvid': media.bvid,
          'fav_id': favId,
          'list_order': i,  // Add order field
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit();
  }

  static Future<void> appendCacheFavDetail(int favId, List<Medias> medias) async {
    final db = await database;
    final batch = db.batch();
    
    // Get current max order
    final maxOrderResult = await db.rawQuery(
      'SELECT MAX(list_order) as max_order FROM $favDetailTable WHERE fav_id = ?',
      [favId]
    );
    final int startOrder = (maxOrderResult.first['max_order'] as int?) ?? -1;

    // Insert new items with incremented order
    for (int i = 0; i < medias.length; i++) {
      final media = medias[i];
      batch.insert(
        favDetailTable,
        {
          'id': media.id,
          'title': media.title,
          'cover': media.cover,
          'page': media.page,
          'duration': media.duration,
          'upper_name': media.upper.name,
          'play_count': media.cntInfo.play,
          'bvid': media.bvid,
          'fav_id': favId,
          'list_order': startOrder + i + 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit();
  }

  static Future<List<Fav>> getCachedFavList() async {
    final db = await database;
    final results = await db.query(
      favListTable,
      orderBy: 'list_order ASC'
    );
    
    return results.map((row) => Fav(
      id: row['id'] as int,
      title: row['title'] as String,
      mediaCount: row['mediaCount'] as int,
    )).toList();
  }

  static Future<void> cacheFavListVideo(List<String> bvids, int mid) async {
    final db = await database;
    final batch = db.batch();
    for (var bvid in bvids) {
      batch.insert(favListVideoTable, {'bvid': bvid, 'mid': mid});
    }
    await batch.commit();
  }

  static Future<List<String>> getCachedFavListVideo(int mid) async {
    final db = await database;
    final results = await db.query(favListVideoTable, where: 'mid = ?', whereArgs: [mid]);
    return results.map((row) => row['bvid'] as String).toList();
  }

  static Future<List<Medias>> getCachedFavDetail(int favId) async {
    final db = await database;
    final results = await db.query(
      favDetailTable,
      where: 'fav_id = ?',
      whereArgs: [favId],
      orderBy: 'list_order ASC'  // Order by the list_order field
    );
    
    return results.map((row) => Medias(
      id: row['id'] as int,
      title: row['title'] as String,
      cover: row['cover'] as String,
      page: row['page'] as int,
      duration: row['duration'] as int,
      bvid: row['bvid'] as String,
      upper: Upper(
        name: row['upper_name'] as String,
        mid: 0,  // Default value since we don't need it
        face: '',  // Default value since we don't need it
      ),
      cntInfo: CntInfo(
        play: row['play_count'] as int,
        collect: 0,  // Default value since we don't need it
      ),
      link: '',  // Default value since we don't need it
      ctime: 0,  // Default value since we don't need it
      pubtime: 0,  // Default value since we don't need it
      favTime: 0,  // Default value since we don't need it
      type: 0,  // Default value since we don't need it
      intro: '',  // Default value since we don't need it
    )).toList();
  }

}
