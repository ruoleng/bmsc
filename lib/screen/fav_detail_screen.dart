import 'package:flutter/material.dart';
import 'package:bmsc/model/fav.dart';
import '../component/track_tile.dart';
import '../globals.dart' as globals;
import 'package:bmsc/cache_manager.dart';
import 'package:bmsc/component/excluded_parts_dialog.dart';
import '../component/playing_card.dart';
import 'package:just_audio/just_audio.dart';
import 'package:bmsc/model/meta.dart';
import 'package:bmsc/util/logger.dart';

class FavDetailScreen extends StatefulWidget {
  final Fav fav;

  const FavDetailScreen({super.key, required this.fav});

  @override
  State<StatefulWidget> createState() => _FavDetailScreenState();
}

class _FavDetailScreenState extends State<FavDetailScreen> {
  List<Meta> favInfo = [];
  bool isLoading = false;
  static final _logger = LoggerUtils.getLogger('FavDetailScreen');

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    _logger.info('Loading initial data for fav ${widget.fav.id}');
    final cachedData = await globals.api.getCachedFavListVideo(widget.fav.id);
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
      final metas = await globals.api.getFavMetas(widget.fav.id);
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
                await globals.api.playFavList(widget.fav.id);
              },
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: ListView.builder(
          itemCount: favInfo.length,
          itemBuilder: (context, index) => favDetailListTileView(index),
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
              pic: favInfo[index].artUri,
              parts: favInfo[index].parts,
              excludedParts: excludedCount,
              title: favInfo[index].title,
              author: favInfo[index].artist,
              len: duration,
              cachedCount: cachedCount,
              onTap: () async {
                try {
                  _logger.info(
                      'Playing fav list ${widget.fav.id} from index $index');
                  await globals.api.playFavList(widget.fav.id, index: index);
                } catch (e, stackTrace) {
                  _logger.severe('Error playing fav list', e, stackTrace);
                }
              },
              onAddToPlaylistButtonPressed: () async {
                try {
                  _logger.info('Adding ${favInfo[index].bvid} to playlist');
                  await globals.api.appendPlaylist(favInfo[index].bvid,
                      insertIndex: globals.api.playlist.length == 0
                          ? 0
                          : globals.api.player.currentIndex! + 1);
                } catch (e) {
                  _logger.warning(
                      'Failed to append to playlist, trying cached playlist',
                      e);
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
                        if (favInfo[index].parts > 1)
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
                              ).then((_) {
                                setState(() {});
                              });
                            },
                          ),
                        ListTile(
                          leading: const Icon(Icons.delete),
                          title: const Text('取消收藏'),
                          onTap: () async {
                            Navigator.pop(dialogContext);
                            final success = await globals.api.favoriteVideo(
                                  favInfo[index].aid,
                                  [],
                                  [widget.fav.id],
                                ) ??
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
