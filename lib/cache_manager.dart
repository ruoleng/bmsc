import 'dart:io';
import 'dart:async';
import 'package:bmsc/audio/lazy_audio_source.dart';
import 'package:bmsc/model/entity.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:audio_service/audio_service.dart';
import 'package:path/path.dart';
import 'package:just_audio/just_audio.dart';
import '../model/fav.dart';
import '../model/fav_detail.dart';
import '../model/meta.dart';
import 'dart:math' show min;

const String _dbName = 'AudioCache.db';

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
    String path = join(documentsDirectory.path, _dbName);
    return await openDatabase(path, version: 1, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE $tableName (
          bvid TEXT,
          cid INTEGER,
          filePath TEXT,
          createdAt INTEGER,
          PRIMARY KEY (bvid, cid)
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
          art_uri TEXT,
          PRIMARY KEY (bvid, cid)
        )
      ''');

      await db.execute('''
        CREATE TABLE $metaTable (
          bvid TEXT PRIMARY KEY,
          aid INTEGER,
          title TEXT,
          artist TEXT,
          artUri TEXT,
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
    const int chunkSize = 500; // Safe size for most SQLite configurations
    final List<Meta> allResults = [];
    
    // Process in chunks
    for (var i = 0; i < bvids.length; i += chunkSize) {
      final chunk = bvids.sublist(i, min(i + chunkSize, bvids.length));
      final placeholders = List.filled(chunk.length, '?').join(',');
      final orderString = ',${chunk.join(',')},';
      
      final results = await db.rawQuery('''
        SELECT * FROM $metaTable 
        WHERE bvid IN ($placeholders)
        ORDER BY INSTR(?, ',' || bvid || ',')
      ''', [...chunk, orderString]);
      
      allResults.addAll(results.map((e) => Meta.fromJson(e)));
    }
    
    return allResults;
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
      batch.insert(entityTable, item.toJson(), conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit();
  }

  static Future<List<Entity>> getEntities(String bvid) async {
    final db = await database;
    final results = await db.query(
      entityTable,
      where: 'bvid = ?',
      whereArgs: [bvid],
      orderBy: 'part ASC',
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
    final meta = await getMeta(bvid);
    if (meta == null) {
      return null;
    }
    
    final db = await database;
    final results = await db.query(
      tableName,
      where: "bvid = ?",
      whereArgs: [bvid],
    );

    if (results.isNotEmpty) {
      final entities = await getEntities(bvid);
      return results.map((result) {
        final filePath = result['filePath'] as String;
        final entity = entities.firstWhere((e) => e.bvid == bvid && e.cid == result['cid']);
        return AudioSource.file(filePath, tag: MediaItem(
          id: '${bvid}_${result['cid']}',
          title: entity.partTitle,
          artist: entity.artist,
          artUri: Uri.parse(entity.artUri),
          extras: {
            'bvid': bvid,
            'aid': entity.aid,
            'cid': entity.cid,
            'mid': meta.mid,
            'multi': entity.part > 0,
            'raw_title': entity.bvidTitle,
            'cached': true
            },
          ));
      }).toList();
    }
    return null;
  }


  static Future<LazyAudioSource?> getCachedAudio(String bvid, int cid) async {
    final meta = await getMeta(bvid);
    if (meta == null) {
      return null;
    }
    final db = await database;
    final results = await db.query(
      tableName,
      where: "bvid = ? AND cid = ?",
      whereArgs: [bvid, cid],
    );

    if (results.isNotEmpty) {
      final filePath = results.first['filePath'] as String;
      final entities = await getEntities(bvid);
      final entity = entities.firstWhere((e) => e.bvid == bvid && e.cid == cid);
      final tag = MediaItem(id: '${bvid}_$cid',
        title: entity.partTitle,
        artist: entity.artist,
        artUri: Uri.parse(entity.artUri),
        extras: {
          'bvid': bvid,
          'aid': entity.aid,
          'cid': cid,
          'mid': meta.mid,
          'multi': entity.part > 0,
          'raw_title': entity.bvidTitle,
          'cached': true
        });
      return LazyAudioSource.create(bvid, cid, Uri.parse(filePath), tag);
    }
    return null;
  }

  static Future<File> prepareFileForCaching(String bvid, int cid) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = '${bvid}_$cid.mp3';
    final filePath = join(directory.path, fileName);
    return File(filePath);
  }

  static Future<void> saveCacheMetadata(String bvid, int cid, String filePath) async {
    final db = await database;
    await db.insert(tableName, {
      'bvid': bvid,
      'cid': cid,
      'filePath': filePath,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
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
    batch.delete(favListVideoTable, where: 'mid = ?', whereArgs: [mid]);
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
}
