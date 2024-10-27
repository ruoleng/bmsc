import 'package:bmsc/model/fav.dart';
import 'package:bmsc/model/fav_detail.dart';
import 'package:bmsc/util/string.dart';
import 'package:flutter/material.dart';
import '../component/track_tile.dart';
import '../globals.dart' as globals;
import 'fav_detail_screen.dart';

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
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('云收藏夹', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView.builder(
        itemCount: favList.length,
        itemBuilder: (context, index) => Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          elevation: 2,
          child: ListTile(
            title: Text(
              favList[index].title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              "${favList[index].mediaCount} 首",
              style: TextStyle(color: Theme.of(context).colorScheme.secondary),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FavDetailScreen(fav: favList[index]),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
