import 'package:flutter/material.dart';
import 'package:bmsc/model/fav_detail.dart';
import 'package:bmsc/model/fav.dart';
import '../component/track_tile.dart';
import '../globals.dart' as globals;
import '../util/string.dart';
import 'package:bmsc/cache_manager.dart';
import 'package:bmsc/component/excluded_parts_dialog.dart';
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

  @override
  void initState() {
    super.initState();
    loadMore();
  }

  loadMore() async {
    final detail = await globals.api.getFavDetail(widget.fav.id, nextPn);
    if (detail == null) {
      return;
    }
    setState(() {
      favInfo.addAll(detail.medias);
      hasMore = detail.hasMore;
      nextPn++;
    });
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
        child: ListView.builder(
          itemCount: favInfo.length,
          itemBuilder: (context, index) => favDetailListTileView(index),
        ),
      ),
    );
  }

  Widget favDetailListTileView(int index) {
    int min = favInfo[index].duration ~/ 60;
    int sec = favInfo[index].duration % 60;
    final duration = "$min:${sec.toString().padLeft(2, '0')}";
    return FutureBuilder<bool>(
      future: CacheManager.isSingleCached(favInfo[index].bvid),
      builder: (context, snapshot) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TrackTile(
            key: Key(favInfo[index].bvid),
            pic: favInfo[index].cover,
            parts: favInfo[index].page,
            title: favInfo[index].title,
            author: favInfo[index].upper.name,
            len: duration,
            view: unit(favInfo[index].cntInfo.play),
            cached: favInfo[index].page == 1 && (snapshot.data ?? false),
            onTap: () => globals.api.playByBvid(favInfo[index].bvid),
            onAddToPlaylistButtonPressed: () => globals.api.appendPlaylist(favInfo[index].bvid, insertIndex: globals.api.playlist.length == 0 ? 0 : globals.api.player.currentIndex! + 1),
            onLongPress: favInfo[index].page > 1 ? () async {
              if (!context.mounted) return;
              showDialog(
                context: context,
                builder: (context) => ExcludedPartsDialog(
                  bvid: favInfo[index].bvid,
                  title: favInfo[index].title,
                ),
              );
            } : null,

          ),
        );
      },
    );
  }
}
