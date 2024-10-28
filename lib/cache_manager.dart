import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:audio_service/audio_service.dart';
import 'package:path/path.dart';
import 'package:just_audio/just_audio.dart';

class CacheManager {
  static Database? _database;
  static const String tableName = 'audio_cache';
  static const String excludedPartsTable = 'excluded_parts';

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDB();
    return _database!;
  }

  static Future<Database> initDB() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, "AudioCache3.db");
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
          quality INTEGER,
          mid INTEGER,
          multi INTEGER,
          raw_title TEXT,
          filePath TEXT,
          createdAt INTEGER
        )
      ''');
      await db.execute('''
        CREATE TABLE $excludedPartsTable (
          bvid TEXT NOT NULL,
          cid INTEGER NOT NULL,
          PRIMARY KEY (bvid, cid)
        )
      ''');
    });
  }

  static Future<void> addExcludedPart(String bvid, int cid) async {
    final db = await database;
    await db.insert(
      excludedPartsTable,
      {'bvid': bvid, 'cid': cid},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> removeExcludedPart(String bvid, int cid) async {
    final db = await database;
    await db.delete(
      excludedPartsTable,
      where: 'bvid = ? AND cid = ?',
      whereArgs: [bvid, cid],
    );
  }


  static Future<List<int>> getExcludedParts(String bvid) async {
    final db = await database;
    final results = await db.query(
      excludedPartsTable,
      where: 'bvid = ?',
      whereArgs: [bvid],
    );
    return results.map((row) => row['cid'] as int).toList();
  }

  static Future<bool> isSingleCached(String bvid) async {
    final db = await database;
    final results = await db.query(
      tableName,
      where: "bvid = ?",
      whereArgs: [bvid],
    );
    return results.isNotEmpty;
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
          'quality': results.first['quality'] as int,
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

  static Future<void> saveCacheMetadata(String bvid, int aid, int cid, int quality, int mid, String filePath, String title, String artist, String artUri, bool multi, String rawTitle) async {
    final db = await database;
    await db.insert(tableName, {
      'id': '${bvid}_$cid',
      'bvid': bvid,
      'aid': aid,
      'cid': cid,
      'quality': quality,
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

}

