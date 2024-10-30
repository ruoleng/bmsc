import 'package:flutter/material.dart';
import '../component/track_tile.dart';
import '../globals.dart' as globals;
import '../cache_manager.dart';
import 'dart:io';

class CacheScreen extends StatefulWidget {
  const CacheScreen({super.key});

  @override
  State<StatefulWidget> createState() => _CacheScreenState();
}

class _CacheScreenState extends State<CacheScreen> {
  List<Map<String, dynamic>> cachedFiles = [];
  List<Map<String, dynamic>> filteredFiles = [];
  bool isLoading = true;
  bool isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadCachedFiles();
    _searchController.addListener(_filterFiles);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterFiles() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredFiles = List.from(cachedFiles);
      } else {
        filteredFiles = cachedFiles.where((file) {
          final title = file['title'].toString().toLowerCase();
          final artist = file['artist'].toString().toLowerCase();
          return title.contains(query) || artist.contains(query);
        }).toList();
      }
    });
  }

  Future<void> loadCachedFiles() async {
    final db = await CacheManager.database;
    final dbResults = await db.query(
      CacheManager.tableName,
      orderBy: 'createdAt DESC',
    );

    final results = (await Future.wait(dbResults.map((x) async {
      var entity = (await db.query(
        CacheManager.entityTable,
        where: 'bvid = ? AND cid = ?',
        whereArgs: [x['bvid'], x['cid']],
      )).firstOrNull;

      if (entity == null) {
        return null;
      }

      return {
        'filePath': x['filePath'],
        'bvid': x['bvid'],
        'cid': x['cid'],
        'createdAt': x['createdAt'],
        'title': entity['part_title'],
        'artist': entity['artist'],
        'part': entity['part'],
        'bvid_title': entity['bvid_title'],
      };
    }))).whereType<Map<String, dynamic>>().toList();


    setState(() {
      cachedFiles = results;
      filteredFiles = results; // Initialize filtered list with all files
      isLoading = false;
    });
  }

  String getFileSize(String filePath) {
    try {
      final file = File(filePath);
      final sizeInBytes = file.lengthSync();
      if (sizeInBytes < 1024 * 1024) {
        return '${(sizeInBytes / 1024).toStringAsFixed(2)} KB';
      }
      return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<void> deleteCache(String bvid, int cid, String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      
      final db = await CacheManager.database;
      await db.delete(
        CacheManager.tableName,
        where: 'bvid = ? AND cid = ?',
        whereArgs: [bvid, cid],
      );

      setState(() {
        cachedFiles.removeWhere((item) => item['bvid'] == bvid && item['cid'] == cid);
      });
    } catch (e) {
    }
  }

  Future<void> clearAllCache() async {
    try {
      for (var file in cachedFiles) {
        await deleteCache(file['bvid'], file['cid'], file['filePath']);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('缓存已清空')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('缓存清空失败: $e')),
        );
      }
    }
  }

  void _toggleSearch() {
    setState(() {
      if (isSearching) {
        isSearching = false;
        _searchController.clear(); // Clear search when closing
        filteredFiles = cachedFiles; // Reset to show all files
      } else {
        isSearching = true;
      }
    });
  }

  Future<void> saveToDownloads(Map<String, dynamic> file) async {
    try {
      final sourceFile = File(file['filePath']);
      if (!await sourceFile.exists()) {
        throw Exception('Source file not found');
      }

      final downloadDir = Directory('/storage/emulated/0/Download');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final fileName = '${file['title']} - ${file['artist']}.mp3';
      final sanitizedFileName = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final targetPath = '${downloadDir.path}/$sanitizedFileName';

      await sourceFile.copy(targetPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已保存到下载目录: $sanitizedFileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索标题或作者...',
                  border: InputBorder.none,
                ),
              )
            : const Text('缓存管理'),
          actions: [
            IconButton(
              icon: Icon(isSearching ? Icons.close : Icons.search),
              onPressed: _toggleSearch,
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('清空缓存'),
                      content: const Text('确定要清空所有缓存吗？'),
                      actions: [
                        TextButton(
                          child: const Text('取消'),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        TextButton(
                          child: const Text('确定'),
                          onPressed: () {
                            Navigator.of(context).pop();
                            clearAllCache();
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: loadCachedFiles,
                child: filteredFiles.isEmpty
                    ? ListView( // Wrap Center in ListView for RefreshIndicator to work
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.8, // Push content to center
                            child: Center(
                              child: Text(
                                _searchController.text.isEmpty
                                    ? '没有缓存文件'
                                    : '没有找到匹配的文件',
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        itemCount: filteredFiles.length,
                        itemBuilder: (context, index) {
                          final file = filteredFiles[index];
                          final fileSize = getFileSize(file['filePath']);
                          final id = '${file['bvid']}_${file['cid']}';

                          return Dismissible(
                            key: Key(id),
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20.0),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (direction) async {
                              return await showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('删除缓存'),
                                  content: const Text('确定要删除这个缓存文件吗？'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('取消'),
                                    ),
                                    FilledButton(
                                      onPressed: () {
                                        Navigator.pop(context, true);
                                        deleteCache(file['bvid'], file['cid'], file['filePath']);
                                      },
                                      child: const Text('确定'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: TrackTile(
                              key: Key(id),
                              title: file['title'],
                              author: file['artist'],
                              len: fileSize,
                              album: file['part'] == 0 ? null : file['bvid_title'],
                              view: DateTime.fromMillisecondsSinceEpoch(
                                file['createdAt'],
                              ).toString().substring(0, 19),
                              onTap: () => globals.api.playCachedAudio(file['bvid'], file['cid']),
                              onAddToPlaylistButtonPressed: () => globals.api.addToPlaylistCachedAudio(file['bvid'], file['cid']),
                              onLongPress: () {
                                
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('保存到下载'),
                                    content: const Text('确定要保存到下载文件夹吗？'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('取消'),
                                      ),
                                      FilledButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          saveToDownloads(file);
                                        },
                                        child: const Text('确定'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
    );
  }
}
