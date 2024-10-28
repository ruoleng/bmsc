import 'package:flutter/material.dart';
import '../component/track_tile.dart';
import '../globals.dart' as globals;
import '../model/history.dart';
import '../util/string.dart';
import '../component/playing_card.dart';
import 'package:just_audio/just_audio.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<StatefulWidget> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool login = true;
  List<HistoryData> hisList = [];
  @override
  void initState() {
    super.initState();
    loadMore();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('历史记录')),
        body: hisListView(),
        bottomNavigationBar: StreamBuilder<SequenceState?>(
          stream: globals.api.player.sequenceStateStream,
          builder: (_, snapshot) {
            final src = snapshot.data?.sequence;
            return (src == null || src.isEmpty)
                ? const SizedBox()
                : const PlayingCard();
          },
        ));
  }

  hisListView() {
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
          itemCount: hisList.length,
          itemBuilder: (context, index) => hisListTileView(index),
        ));
  }

  int viewat = 0;
  loadMore() async {
    final detail = await globals.api.getHistory(viewat);
    if (detail == null) {
      return;
    }
    setState(() {
      hisList.addAll(detail.list);
      viewat = detail.cursor.viewAt;
    });
  }

  hisListTileView(int index) {
    int pmin = hisList[index].progress ~/ 60;
    int psec = hisList[index].progress % 60;
    int min = hisList[index].duration ~/ 60;
    int sec = hisList[index].duration % 60;
    final duration = "$min:${sec.toString().padLeft(2, '0')}";
    final progress = "$pmin:${psec.toString().padLeft(2, '0')}";
    return TrackTile(
      key: Key(hisList[index].history.bvid),
      pic: hisList[index].cover,
      title: hisList[index].title,
      author: hisList[index].authorName,
      len: duration,
      view: time(hisList[index].viewAt * 1000000),
      onTap: () => globals.api.playByBvid(hisList[index].history.bvid),
      onAddToPlaylistButtonPressed: () => globals.api.appendPlaylist(hisList[index].history.bvid, insertIndex: globals.api.playlist.length == 0 ? 0 : globals.api.player.currentIndex! + 1),
    );
  }
}
