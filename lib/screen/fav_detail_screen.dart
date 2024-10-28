import 'package:flutter/material.dart';
import 'package:bmsc/model/fav_detail.dart';
import 'package:bmsc/model/fav.dart';
import '../component/track_tile.dart';
import '../globals.dart' as globals;
import '../util/string.dart';
import 'package:bmsc/cache_manager.dart';
import 'package:bmsc/component/excluded_parts_dialog.dart';
import '../component/playing_card.dart';
import 'package:just_audio/just_audio.dart';

class FavDetailScreen extends StatefulWidget {
  final Fav fav;

  const FavDetailScreen({super.key, required this.fav});

  @override
  State<StatefulWidget> createState() => _FavDetailScreenState();
}

class _FavDetailScreenState extends State<FavDetailScreen> {
  List<Medias> favInfo = [];
  bool hasMore = true;
  int nextPn = 1;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // First try to load from cache
    final cachedData = await CacheManager.getCachedFavDetail(widget.fav.id);
    if (cachedData.isNotEmpty) {
      setState(() {
        favInfo = cachedData;
      });
    }

    // Then load from network
    await loadMore();
  }

  Future<void> loadMore() async {
    if (isLoading || !hasMore) return;

    setState(() {
      isLoading = true;
    });

    try {
      final detail = await globals.api.getFavDetail(widget.fav.id, nextPn);
      if (detail == null) {
        return;
      }

      setState(() {
        if (nextPn == 1) {
          // Replace all data if it's the first page
          favInfo = detail.medias;
        } else {
          // Append data for subsequent pages
          favInfo.addAll(detail.medias);
        }
        hasMore = detail.hasMore;
        nextPn++;
      });

      // Cache the new data
      if (nextPn == 2) { // Only cache first page
        await CacheManager.cacheFavDetail(widget.fav.id, detail.medias);
      } else {
        await CacheManager.appendCacheFavDetail(widget.fav.id, detail.medias);
      }
    } catch (_) {
      
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      nextPn = 1;
      hasMore = true;
      favInfo.clear();
    });
    await loadMore();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fav.title),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Icon(Icons.play_arrow, size: 18),
                  ),
                  Text(
                    '播放全部',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              onPressed: () async {
                final bvids = await globals.api.getFavBvids(widget.fav.id);
                if (bvids == null) {
                  return;
                }
                await globals.api.player.stop();
                await globals.api.playlist.clear();
                for (final x in bvids) {
                  await globals.api.appendPlaylist(x);
                }
                await globals.api.player.seek(Duration.zero, index: 0);
                await globals.api.player.play();
              },
            ),
          ),
        ],
      ),
      body: NotificationListener<ScrollEndNotification>(
        onNotification: (scrollEnd) {
          final metrics = scrollEnd.metrics;
          if (metrics.atEdge) {
            bool isTop = metrics.pixels == 0;
            if (!isTop && hasMore) {
              loadMore();
            }
          }
          return true;
        },
        child: RefreshIndicator(
          onRefresh: _refreshData,
          child: ListView.builder(
            itemCount: favInfo.length,
            itemBuilder: (context, index) => favDetailListTileView(index),
          ),
        ),
      ),
      bottomNavigationBar: StreamBuilder<SequenceState?>(
        stream: globals.api.player.sequenceStateStream,
        builder: (_, snapshot) {
          final src = snapshot.data?.sequence;
          return (src == null || src.isEmpty)
              ? const SizedBox()
              : const PlayingCard();
        },
      ),
    );
  }

  Widget favDetailListTileView(int index) {
    int min = favInfo[index].duration ~/ 60;
    int sec = favInfo[index].duration % 60;
    final duration = "$min:${sec.toString().padLeft(2, '0')}";
    
    return FutureBuilder<(List<int>, int)>(
      future: Future.wait([
        CacheManager.getExcludedParts(favInfo[index].bvid),
        CacheManager.cachedCount(favInfo[index].bvid),
      ]).then((results) => (results[0] as List<int>, results[1] as int)),
      builder: (context, snapshot) {
        final excludedCount = snapshot.data?.$1.length ?? 0;
        final cachedCount = snapshot.data?.$2 ?? 0;
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TrackTile(
            key: Key(favInfo[index].bvid),
            pic: favInfo[index].cover,
            parts: favInfo[index].page,
            excludedParts: excludedCount,
            title: favInfo[index].title,
            author: favInfo[index].upper.name,
            len: duration,
            view: unit(favInfo[index].cntInfo.play),
            cachedCount: cachedCount,
            onTap: () async {
              try {
                await globals.api.playByBvid(favInfo[index].bvid);
              } catch (e) {
                await globals.api.playCachedBvid(favInfo[index].bvid);
              }
            },
            onAddToPlaylistButtonPressed: () async {
              try {
                await globals.api.appendPlaylist(
                  favInfo[index].bvid,
                  insertIndex: globals.api.playlist.length == 0 ? 0 : globals.api.player.currentIndex! + 1
                );
              } catch (e) {
                await globals.api.appendCachedPlaylist(favInfo[index].bvid);
              }
            },
            onLongPress: () async {
              if (!context.mounted) return;
              showDialog(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('选择操作'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (favInfo[index].page > 1)
                        ListTile(
                          leading: const Icon(Icons.playlist_remove),
                          title: const Text('管理分P'),
                          onTap: () {
                            Navigator.pop(dialogContext);
                            showDialog(
                              context: context,
                              builder: (context) => ExcludedPartsDialog(
                                bvid: favInfo[index].bvid,
                                title: favInfo[index].title,
                              ),
                            );
                          },
                        ),
                      ListTile(
                        leading: const Icon(Icons.delete),
                        title: const Text('取消收藏'),
                        onTap: () async {
                          Navigator.pop(dialogContext);
                          final success = await globals.api.favoriteVideo(
                            favInfo[index].id,
                            [],
                            [widget.fav.id],
                          );
                          
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
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }
    );
  }
}
