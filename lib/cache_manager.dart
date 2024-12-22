import 'dart:io';
import 'dart:async';
import 'package:bmsc/audio/lazy_audio_source.dart';
import 'package:bmsc/model/entity.dart';
import 'package:bmsc/util/shared_preferences_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:audio_service/audio_service.dart';
import 'package:path/path.dart';
import 'package:just_audio/just_audio.dart';
import '../model/fav.dart';
import '../model/fav_detail.dart';
import '../model/meta.dart';
import 'dart:math' as math;
import 'package:bmsc/util/logger.dart';

final _logger = LoggerUtils.getLogger('CacheManager');

const String _dbName = 'AudioCache.db';

class CacheManager {
  static Database? _database;
  static const String tableName = 'audio_cache';
  static const String metaTable = 'meta_cache';
  static const String favListVideoTable = 'fav_list_video';
  static const String collectedFavListVideoTable = 'collected_fav_list_video';
  static const String collectedFavListTable = 'collected_fav_list';
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
    try {
      final db = await openDatabase(
        path,
        version: 2,
        onCreate: (db, version) async {
          _logger.info('Creating new database tables...');
          await db.execute('''
          CREATE TABLE $tableName (
            bvid TEXT,
            cid INTEGER,
            filePath TEXT,
            fileSize INTEGER,
            playCount INTEGER DEFAULT 0,
            lastPlayed INTEGER,
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

          await db.execute('''
          CREATE TABLE $collectedFavListTable (
            id INTEGER PRIMARY KEY,
            title TEXT,
            mediaCount INTEGER,
            list_order INTEGER
          )
        ''');

          await db.execute('''
          CREATE TABLE $collectedFavListVideoTable (
            bvid TEXT,
            mid INTEGER,
            PRIMARY KEY (bvid, mid)
          )
        ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          _logger.info('Upgrading database from v$oldVersion to v$newVersion');
          
          if (oldVersion == 1) {
            await db.execute('''
              CREATE TABLE ${tableName}_new (
                bvid TEXT,
                cid INTEGER,
                filePath TEXT,
                fileSize INTEGER,
                playCount INTEGER DEFAULT 0,
                lastPlayed INTEGER,
                createdAt INTEGER,
                PRIMARY KEY (bvid, cid)
              )
            ''');

            await db.execute('''
              INSERT INTO ${tableName}_new (bvid, cid, filePath, createdAt)
              SELECT bvid, cid, filePath, createdAt
              FROM $tableName
            ''');

            final rows = await db.query('${tableName}_new');
            final batch = db.batch();
            
            for (final row in rows) {
              final filePath = row['filePath'] as String;
              final file = File(filePath);
              int fileSize = 0;
              try {
                if (await file.exists()) {
                  fileSize = await file.length();
                }
              } catch (e) {
                _logger.warning('Failed to get file size for $filePath: $e');
              }

              batch.update(
                '${tableName}_new',
                {
                  'fileSize': fileSize,
                  'playCount': 0,
                  'lastPlayed': DateTime.now().millisecondsSinceEpoch,
                },
                where: 'bvid = ? AND cid = ?',
                whereArgs: [row['bvid'] as String, row['cid'] as int],
              );
            }

            await db.execute('DROP TABLE $tableName');
            await db.execute('ALTER TABLE ${tableName}_new RENAME TO $tableName');
          }
        },
      );
      return db;
    } catch (e, stackTrace) {
      _logger.severe('Failed to initialize database', e, stackTrace);
      rethrow;
    }
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
    _logger.info('Caching ${metas.length} metas');
    try {
      final db = await database;
      final batch = db.batch();
      for (int i = 0; i < metas.length; i++) {
        var json = metas[i].toJson();
        json['list_order'] = i;
        batch.insert(metaTable, json,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit();
      _logger.info('cached ${metas.length} metas');
    } catch (e, stackTrace) {
      _logger.severe('Failed to cache metas', e, stackTrace);
      rethrow;
    }
  }

  static Future<Meta?> getMeta(String bvid) async {
    final db = await database;
    final results =
        await db.query(metaTable, where: 'bvid = ?', whereArgs: [bvid]);
    final ret = results.firstOrNull;
    if (ret == null) {
      return null;
    }
    return Meta.fromJson(ret);
  }

  static Future<List<Meta>> getMetas(List<String> bvids) async {
    if (bvids.isEmpty) {
      _logger.info('No bvids to fetch');
      return [];
    }
    _logger.info('Fetching ${bvids.length} metas from cache');
    try {
      final db = await database;
      const int chunkSize = 500;
      final List<Meta> allResults = [];

      for (var i = 0; i < bvids.length; i += chunkSize) {
        final chunk = bvids.sublist(i, math.min(i + chunkSize, bvids.length));
        final placeholders = List.filled(chunk.length, '?').join(',');
        final orderString = ',${chunk.join(',')},';

        final results = await db.rawQuery('''
          SELECT * FROM $metaTable 
          WHERE bvid IN ($placeholders)
          ORDER BY INSTR(?, ',' || bvid || ',')
        ''', [...chunk, orderString]);

        allResults.addAll(results.map((e) => Meta.fromJson(e)));
      }

      _logger.info('Retrieved ${allResults.length} metas from cache');
      return allResults;
    } catch (e, stackTrace) {
      _logger.severe('Failed to get metas from cache', e, stackTrace);
      rethrow;
    }
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
      batch.insert(entityTable, item.toJson(),
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit();
    _logger.info('cached ${data.length} entities');
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
        final entity = entities
            .firstWhere((e) => e.bvid == bvid && e.cid == result['cid']);
        return AudioSource.file(filePath,
            tag: MediaItem(
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
    _logger.info('Fetching cached audio for bvid: $bvid, cid: $cid');
    try {
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
        _logger.info('Found cached audio for bvid: $bvid, cid: $cid');
        final filePath = results.first['filePath'] as String;
        final entities = await getEntities(bvid);
        final entity =
            entities.firstWhere((e) => e.bvid == bvid && e.cid == cid);
        final tag = MediaItem(
            id: '${bvid}_$cid',
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
      } else {
        _logger.info('No cached audio found for bvid: $bvid, cid: $cid');
      }
      return null;
    } catch (e, stackTrace) {
      _logger.severe('Failed to get cached audio', e, stackTrace);
      rethrow;
    }
  }

  static Future<File> prepareFileForCaching(String bvid, int cid) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = '${bvid}_$cid.mp3';
    final filePath = join(directory.path, fileName);
    return File(filePath);
  }

  static Future<void> saveCacheMetadata(
      String bvid, int cid, File file) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      int ret = await db.insert(
          tableName,
          {
            'bvid': bvid,
            'cid': cid,
            'filePath': file.path,
            'fileSize': file.lengthSync(),
            'playCount': 0,
            'lastPlayed': now,
            'createdAt': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
      if (ret != 0) {
        _logger.info('audio cache metadata saved');
      }
    } catch (e, stackTrace) {
      _logger.severe('Failed to save audio cache metadata', e, stackTrace);
      rethrow;
    }
  }

  static Future<void> updatePlayStats(String bvid, int cid) async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE $tableName 
      SET playCount = playCount + 1,
          lastPlayed = ?
      WHERE bvid = ? AND cid = ?
      ''',
      [DateTime.now().millisecondsSinceEpoch, bvid, cid]);
  }

  static Future<int> getCacheTotalSize() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(fileSize) as total FROM $tableName'
    );
    return (result.first['total'] as int?) ?? 0;
  }

  static Future<void> cleanupCache({File? ignoreFile}) async {
    const double playCountWeight = 0.7;
    const double recencyWeight = 0.3;
    final currentSize = await getCacheTotalSize();
    final maxCacheSize = await SharedPreferencesService.getCacheLimitSize() * 1024 * 1024;
    _logger.info('currentSize: $currentSize, maxCacheSize: $maxCacheSize');
    if (currentSize <= maxCacheSize) {
      return;
    }

    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // 获取所有缓存文件信息并计算分数
    final results = await db.query(tableName);
    
    // 计算最大播放次数用于归一化
    final maxPlayCount = results.fold<int>(1, (max, row) => 
      math.max(max, row['playCount'] as int));
      
    var files = results.map((row) {
      final playCount = row['playCount'] as int;
      final lastPlayed = row['lastPlayed'] as int;
      final daysAgo = (now - lastPlayed) / (24 * 60 * 60 * 1000);
      
      // 计算归一化分数
      final playScore = playCount / maxPlayCount;
      final recencyScore = math.exp(-daysAgo / 7); // 使用指数衰减
      
      final score = (playScore * playCountWeight) + 
                  (recencyScore * recencyWeight);
                  
      return {
        'bvid': row['bvid'],
        'cid': row['cid'],
        'filePath': row['filePath'],
        'fileSize': row['fileSize'],
        'score': score,
      };
    }).toList();

    // 按分数升序排序(分数低的先删除)
    files.sort((a, b) => (a['score'] as double).compareTo(b['score'] as double));

    // 删除文件直到缓存大小低于限制
    int removedSize = 0;
    for (var file in files) {
      if (ignoreFile != null && file['filePath'] == ignoreFile.path) {
        continue;
      }
      if (currentSize - removedSize <= maxCacheSize) {
        break;
      }

      final filePath = file['filePath'] as String;
      final fileObj = File(filePath);
      if (await fileObj.exists()) {
        await fileObj.delete();
      }

      await db.delete(
        tableName,
        where: 'bvid = ? AND cid = ?',
        whereArgs: [file['bvid'], file['cid']],
      );

      removedSize += file['fileSize'] as int;
    }
    _logger.info('Cleaned up cache, removed $removedSize bytes');
  }

  static Future<void> cacheFavList(List<Fav> favs) async {
    final db = await database;

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
    _logger.info('cached ${favs.length} fav lists');
  }

  static Future<void> cacheCollectedFavList(List<Fav> favs) async {
    final db = await database;

    await db.delete(collectedFavListTable);

    final batch = db.batch();

    for (int i = 0; i < favs.length; i++) {
      batch.insert(
        collectedFavListTable,
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
    _logger.info('cached collected ${favs.length} fav lists');
  }

  static Future<List<Fav>> getCachedCollectedFavList() async {
    final db = await database;
    final results =
        await db.query(collectedFavListTable, orderBy: 'list_order ASC');

    return results
        .map((row) => Fav(
              id: row['id'] as int,
              title: row['title'] as String,
              mediaCount: row['mediaCount'] as int,
            ))
        .toList();
  }

  static Future<void> cacheCollectedFavListVideo(
      List<String> bvids, int mid) async {
    final db = await database;
    final batch = db.batch();
    batch
        .delete(collectedFavListVideoTable, where: 'mid = ?', whereArgs: [mid]);
    for (var bvid in bvids) {
      batch.insert(collectedFavListVideoTable, {'bvid': bvid, 'mid': mid});
    }
    await batch.commit();
    _logger.info('cached ${bvids.length} collected fav list videos');
  }

  static Future<List<String>> getCachedCollectedFavListVideo(int mid) async {
    final db = await database;
    final results = await db
        .query(collectedFavListVideoTable, where: 'mid = ?', whereArgs: [mid]);
    return results.map((row) => row['bvid'] as String).toList();
  }

  static Future<void> cacheFavDetail(int favId, List<Medias> medias) async {
    final db = await database;
    final batch = db.batch();

    await db.delete(
      favDetailTable,
      where: 'fav_id = ?',
      whereArgs: [favId],
    );

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
          'list_order': i,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit();
    _logger.info('cached ${medias.length} fav details');
  }

  static Future<void> appendCacheFavDetail(
      int favId, List<Medias> medias) async {
    final db = await database;
    final batch = db.batch();

    final maxOrderResult = await db.rawQuery(
        'SELECT MAX(list_order) as max_order FROM $favDetailTable WHERE fav_id = ?',
        [favId]);
    final int startOrder = (maxOrderResult.first['max_order'] as int?) ?? -1;

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
    _logger.info('appended ${medias.length} fav details');
  }

  static Future<List<Fav>> getCachedFavList() async {
    final db = await database;
    final results = await db.query(favListTable, orderBy: 'list_order ASC');

    return results
        .map((row) => Fav(
              id: row['id'] as int,
              title: row['title'] as String,
              mediaCount: row['mediaCount'] as int,
            ))
        .toList();
  }

  static Future<void> cacheFavListVideo(List<String> bvids, int mid) async {
    final db = await database;
    final batch = db.batch();
    batch.delete(favListVideoTable, where: 'mid = ?', whereArgs: [mid]);
    for (var bvid in bvids) {
      batch.insert(favListVideoTable, {'bvid': bvid, 'mid': mid});
    }
    await batch.commit();
    _logger.info('cached ${bvids.length} fav list videos');
  }

  static Future<List<String>> getCachedFavListVideo(int mid) async {
    final db = await database;
    final results =
        await db.query(favListVideoTable, where: 'mid = ?', whereArgs: [mid]);
    return results.map((row) => row['bvid'] as String).toList();
  }
}
