import 'package:bmsc/component/download_parts_dialog.dart';
import 'package:bmsc/screen/comment_screen.dart';
import 'package:bmsc/screen/user_detail_screen.dart';
import 'package:bmsc/service/audio_service.dart';
import 'package:bmsc/service/bilibili_service.dart';
import 'package:bmsc/service/download_manager.dart';
import 'package:flutter/material.dart';
import 'package:bmsc/model/fav.dart';
import '../component/track_tile.dart';
import 'package:bmsc/database_manager.dart';
import 'package:bmsc/component/excluded_parts_dialog.dart';
import '../component/playing_card.dart';
import 'package:bmsc/model/meta.dart';
import 'package:bmsc/util/logger.dart';

class FavDetailScreen extends StatefulWidget {
  final Fav fav;
  final bool isCollected;

  const FavDetailScreen({
    super.key,
    required this.fav,
    required this.isCollected,
  });

  @override
  State<StatefulWidget> createState() => _FavDetailScreenState();
}

class _FavDetailScreenState extends State<FavDetailScreen> {
  List<Meta> favInfo = [];
  bool isLoading = false;
  bool isSelectionMode = false;
  Set<String> selectedItems = {};
  static final _logger = LoggerUtils.getLogger('FavDetailScreen');

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    _logger.info('Loading initial data for fav ${widget.fav.id}');
    final cachedData = widget.isCollected
        ? await DatabaseManager.getCachedCollectionMetas(widget.fav.id)
        : await DatabaseManager.getCachedFavMetas(widget.fav.id);
    if (cachedData.isNotEmpty) {
      _logger.info('Loaded ${cachedData.length} items from cache');
      setState(() {
        favInfo = cachedData;
      });
    } else {
      _logger.info('No cached data found, loading from network');
      await loadMetas();
    }
  }

  Future<void> loadMetas() async {
    if (isLoading) {
      _logger.info('Already loading metas, skipping request');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final metas = widget.isCollected
          ? await BilibiliService.instance
              .then((x) => x.getCollectionMetas(widget.fav.id))
          : await BilibiliService.instance
              .then((x) => x.getFavMetas(widget.fav.id));
      if (metas != null) {
        _logger.info('Loaded ${metas.length} metas from network');
        setState(() {
          favInfo = metas;
        });
      } else {
        _logger.warning('Failed to load metas from network');
      }
    } catch (e, stackTrace) {
      _logger.severe('Error loading metas', e, stackTrace);
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      favInfo.clear();
    });
    await loadMetas();
  }

  void toggleSelectionMode() {
    setState(() {
      isSelectionMode = !isSelectionMode;
      if (!isSelectionMode) {
        selectedItems.clear();
      }
    });
  }

  void _toggleItemSelection(String id) {
    setState(() {
      if (selectedItems.contains(id)) {
        selectedItems.remove(id);
        _logger.info('Unselected item $id');
      } else {
        selectedItems.add(id);
        _logger.info('Selected item $id');
      }

      if (selectedItems.isEmpty) {
        isSelectionMode = false;
      } else {
        isSelectionMode = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fav.title),
        leading: isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => toggleSelectionMode(),
              )
            : null,
        actions: [
          if (isSelectionMode)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () async {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('下载'),
                    content: Text('是否要下载${selectedItems.length}个视频？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        onPressed: () async {
                          Navigator.pop(context, true);
                        },
                        child: const Text('下载'),
                      ),
                    ],
                  ),
                ).then((value) async {
                  if (value == true) {
                    final dm = await DownloadManager.instance;
                    await dm.addBvidTasks(selectedItems.toList());

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('已添加 ${selectedItems.length} 个下载任务'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    toggleSelectionMode();
                  }
                });
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: ListView.builder(
          cacheExtent: 10000,
          itemCount: favInfo.length,
          itemBuilder: (context, index) => favDetailListTileView(index),
        ),
      ),
      bottomNavigationBar: const PlayingCard(),
    );
  }

  Widget favDetailListTileView(int index) {
    int min = favInfo[index].duration ~/ 60;
    int sec = favInfo[index].duration % 60;
    final duration = "$min:${sec.toString().padLeft(2, '0')}";

    return FutureBuilder<(List<int>, int, int)>(
        future: Future.wait([
          DatabaseManager.getExcludedParts(favInfo[index].bvid),
          DatabaseManager.cachedCount(favInfo[index].bvid),
          DatabaseManager.downloadedCount(favInfo[index].bvid),
        ]).then((results) =>
            (results[0] as List<int>, results[1] as int, results[2] as int)),
        builder: (context, snapshot) {
          final excludedCount = snapshot.data?.$1.length ?? 0;
          final cachedCount = snapshot.data?.$2 ?? 0;
          final downloadedCount = snapshot.data?.$3 ?? 0;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TrackTile(
              key: Key(favInfo[index].bvid),
              pic: favInfo[index].artUri,
              parts: favInfo[index].parts,
              excludedParts: excludedCount,
              title: favInfo[index].title,
              author: favInfo[index].artist,
              len: duration,
              cached: cachedCount > 0,
              downloaded: downloadedCount > 0,
              color: isSelectionMode
                  ? selectedItems.contains(favInfo[index].bvid)
                      ? Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withOpacity(0.7)
                      : Theme.of(context).colorScheme.surfaceContainerLow
                  : null,
              onPicTap: () => _toggleItemSelection(favInfo[index].bvid),
              onTap: isSelectionMode
                  ? () => _toggleItemSelection(favInfo[index].bvid)
                  : () async {
                      try {
                        _logger.info(
                            'Playing fav list ${widget.fav.id} from index $index');
                        final bvids = widget.isCollected
                            ? await DatabaseManager.getCachedCollectionBvids(
                                widget.fav.id)
                            : await DatabaseManager.getCachedFavBvids(
                                widget.fav.id);
                        await AudioService.instance
                            .then((x) => x.playByBvids(bvids, index: index));
                      } catch (e, stackTrace) {
                        _logger.severe('Error playing fav list', e, stackTrace);
                      }
                    },
              onAddToPlaylistButtonPressed: () async {
                try {
                  _logger.info('Adding ${favInfo[index].bvid} to playlist');
                  await AudioService.instance.then((x) => x.appendPlaylist(
                      favInfo[index].bvid,
                      insertIndex: x.playlist.length == 0
                          ? 0
                          : x.player.currentIndex! + 1));
                } catch (e) {
                  _logger.warning(
                      'Failed to append to playlist, trying cached playlist',
                      e);
                  await AudioService.instance
                      .then((x) => x.appendCachedPlaylist(favInfo[index].bvid));
                }
              },
              onLongPress: isSelectionMode
                  ? null
                  : () async {
                      if (!context.mounted) return;
                      showDialog(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('选择操作'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.person),
                                title: const Text('查看 UP 主'),
                                onTap: () {
                                  Navigator.pop(dialogContext);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => UserDetailScreen(
                                        mid: favInfo[index].mid,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.playlist_remove),
                                title: const Text('屏蔽分 P'),
                                onTap: () {
                                  Navigator.pop(dialogContext);
                                  showDialog(
                                    context: context,
                                    builder: (context) => ExcludedPartsDialog(
                                      bvid: favInfo[index].bvid,
                                      title: favInfo[index].title,
                                    ),
                                  ).then((_) {
                                    setState(() {});
                                  });
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.comment_outlined),
                                title: const Text('查看评论'),
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => CommentScreen(
                                              aid: favInfo[index]
                                                  .aid
                                                  .toString())));
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.delete),
                                title: const Text('取消收藏'),
                                onTap: () async {
                                  Navigator.pop(dialogContext);
                                  final success = await BilibiliService.instance
                                          .then((x) => x.favoriteVideo(
                                                favInfo[index].aid,
                                                [],
                                                [widget.fav.id],
                                              )) ??
                                      false;

                                  if (!context.mounted) return;

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(success ? '已取消收藏' : '操作失败'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );

                                  if (success) {
                                    setState(() {
                                      favInfo.removeAt(index);
                                    });
                                  }
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.download),
                                title: const Text('下载'),
                                onTap: () {
                                  Navigator.pop(dialogContext);
                                  showDialog(
                                    context: context,
                                    builder: (context) => DownloadPartsDialog(
                                      bvid: favInfo[index].bvid,
                                      title: favInfo[index].title,
                                    ),
                                  ).then((_) {
                                    setState(() {});
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
            ),
          );
        });
  }
}
