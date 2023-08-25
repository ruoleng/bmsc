import 'package:bmsc/model/fav.dart';
import 'package:bmsc/model/fav_detail.dart';
import 'package:flutter/material.dart';
import '../globals.dart' as globals;

class FavScreen extends StatefulWidget {
  const FavScreen({super.key});

  @override
  State<StatefulWidget> createState() => _FavScreenState();
}

class _FavScreenState extends State<FavScreen> {
  bool login = true;
  List<Fav> favList = [];
  @override
  void initState() {
    super.initState();
    globals.api.getStoredUID().then((uid) async {
      if (uid == null) {
        setState(() {
          login = false;
        });
        return;
      }
      final ret = (await globals.api.getFavs(uid))?.list ?? [];
      setState(() {
        favList = ret;
        hasMore = List.generate(ret.length, (idx) => ret[idx].mediaCount != 0);
        nextPn = List.generate(ret.length, (_) => 1);
        favInfo = List.generate(ret.length, (_) => []);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('云收藏夹')), body: favListView());
  }

  favListView() {
    return ListView.builder(
      itemCount: favList.length,
      itemBuilder: (context, index) => favListTileView(index),
    );
  }

  List<List<Medias>> favInfo = [];
  List<bool> hasMore = [];
  List<int> nextPn = [];
  favListTileView(int index) {
    return Card(
      clipBehavior: Clip.hardEdge,
      child: ExpansionTile(
        onExpansionChanged: (value) {
          if (value == true && favInfo[index].isEmpty) {
            loadMore(index);
          }
        },
        shape: Border.all(width: 0.1, color: Colors.transparent),
        title: Text(favList[index].title),
        subtitle: Text("${favList[index].mediaCount} 首"),
        trailing: FilledButton(
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.only(right: 10.0),
                child: Icon(Icons.play_arrow),
              ),
              Text('播放全部'),
            ],
          ),
          onPressed: () async {
            final bvids = await globals.api.getFavBvids(favList[index].id);
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
        children: [
          favDetailListView(index),
          hasMore[index]
              ? ListTile(
                  title: const Text("加载更多"),
                  onTap: () => loadMore(index),
                )
              : Container()
        ],
      ),
    );
  }

  loadMore(int index) async {
    final detail =
        await globals.api.getFavDetail(favList[index].id, nextPn[index]);
    if (detail == null) {
      return;
    }
    setState(() {
      favInfo[index].addAll(detail.medias);
      hasMore[index] = detail.hasMore;
      nextPn[index]++;
    });
  }

  Widget favDetailListView(int index) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: favInfo[index].length,
      itemBuilder: (context, index2) => favDetailListTileView(index, index2),
    );
  }

  Widget favDetailListTileView(int favIndex, int trackIndex) {
    return Column(children: [
      ListTile(
          onTap: () {
            globals.api.playSong(favInfo[favIndex][trackIndex].bvid);
          },
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(5.0),
            child: SizedBox(
                width: 50,
                height: 50,
                child: Image.network(
                  fit: BoxFit.cover,
                  favInfo[favIndex][trackIndex].cover,
                )),
          ),
          title: Text(
            favInfo[favIndex][trackIndex].title,
            softWrap: false,
          ),
          subtitle: Row(
            children: [
              const Icon(Icons.person_outline, size: 12),
              Text(favInfo[favIndex][trackIndex].upper.name,
                  style: const TextStyle(fontSize: 10), softWrap: false),
            ],
          )),
      const Divider(height: 0),
    ]);
  }
}
