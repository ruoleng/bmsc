import 'package:bmsc/component/excluded_parts_dialog.dart';
import 'package:bmsc/screen/comment_screen.dart';
import 'package:bmsc/screen/user_detail_screen.dart';
import 'package:bmsc/service/audio_service.dart';
import 'package:bmsc/service/bilibili_service.dart';
import 'package:flutter/material.dart';
import '../component/track_tile.dart';
import '../model/dynamic.dart';
import '../component/playing_card.dart';

class DynamicScreen extends StatefulWidget {
  const DynamicScreen({super.key});

  @override
  State<StatefulWidget> createState() => _DynamicScreenState();
}

class _DynamicScreenState extends State<DynamicScreen> {
  bool login = true;
  List<Modules> dynList = [];
  @override
  void initState() {
    super.initState();
    loadMore();
    _checkLogin();
  }

  void _checkLogin() async {
    final info = await BilibiliService.instance.then((x) => x.myInfo);
    setState(() {
      login = info != null && info.mid != 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('动态')),
      body: login ? dynListView() : const Center(child: Text('请先登录')),
      bottomNavigationBar: const PlayingCard(),
    );
  }

  dynListView() {
    return NotificationListener<ScrollEndNotification>(
        onNotification: (scrollEnd) {
          final metrics = scrollEnd.metrics;
          if (metrics.atEdge) {
            bool isTop = metrics.pixels == 0;
            if (!isTop) {
              loadMore();
            }
          }
          return true;
        },
        child: ListView.builder(
          cacheExtent: 10000,
          itemCount: dynList.length,
          itemBuilder: (context, index) => dynListTileView(index),
        ));
  }

  String? offset;
  loadMore() async {
    final detail =
        await BilibiliService.instance.then((x) => x.getDynamics(offset));
    if (detail == null) {
      return;
    }
    setState(() {
      dynList.addAll(detail.items.map((e) => e.modules));
      offset = detail.offset;
    });
  }

  dynListTileView(int index) {
    return TrackTile(
      key: Key(dynList[index].moduleDynamic.major.archive.bvid),
      pic: dynList[index].moduleDynamic.major.archive.cover,
      title: dynList[index].moduleDynamic.major.archive.title,
      author: dynList[index].moduleAuthor.name,
      len: dynList[index].moduleDynamic.major.archive.durationText,
      view: dynList[index].moduleDynamic.major.archive.stat.play,
      time: dynList[index].moduleAuthor.pubTime,
      onTap: () => AudioService.instance.then(
          (x) => x.playByBvid(dynList[index].moduleDynamic.major.archive.bvid)),
      onAddToPlaylistButtonPressed: () => AudioService.instance.then((x) =>
          x.appendPlaylist(dynList[index].moduleDynamic.major.archive.bvid,
              insertIndex:
                  x.playlist.length == 0 ? 0 : x.player.currentIndex! + 1)),
      onLongPress: () async {
        if (!context.mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('选择操作'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('查看 UP 主'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => UserDetailScreen(
                              mid: dynList[index].moduleAuthor.mid)),
                    );
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
                                aid: dynList[index].moduleDynamic.major.archive
                                    .aid)));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.playlist_remove),
                  title: const Text('屏蔽分 P'),
                  onTap: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (context) => ExcludedPartsDialog(
                        bvid: dynList[index].moduleDynamic.major.archive.bvid,
                        title: dynList[index].moduleDynamic.major.archive.title,
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
    );
  }
}
