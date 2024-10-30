import 'package:bmsc/model/fav.dart';
import 'package:flutter/material.dart';
import '../globals.dart' as globals;
import 'fav_detail_screen.dart';
import 'package:bmsc/cache_manager.dart' as cache_manager;

class FavScreen extends StatefulWidget {
  const FavScreen({super.key});

  @override
  State<StatefulWidget> createState() => _FavScreenState();
}

class _FavScreenState extends State<FavScreen> {
  bool isLoading = true;
  List<Fav> favList = [];

  @override
  void initState() {
    super.initState();
    loadFavorites();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> loadFavorites() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    
    globals.api.getStoredUID().then((uid) async {
      if (!mounted) return;
      if (uid == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      // Try to load from cache first
      var cachedFavs = await cache_manager.CacheManager.getCachedFavList();
      if (!mounted) return;
      if (cachedFavs.isNotEmpty) {
        setState(() {
          favList = cachedFavs;
        });
      }

      // Then try to fetch from network
      try {
        final ret = (await globals.api.getFavs(uid))?.list ?? [];
        if (!mounted) return;
        if (ret.isNotEmpty) {
          setState(() {
            favList = ret;
          });
          // Cache the new data
          await cache_manager.CacheManager.cacheFavList(ret);
        }
      } catch (e) {
        // If network fetch fails, we'll still have the cached data
      } finally {
        if (mounted) {
          setState(() => isLoading = false);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('云收藏夹', 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadFavorites,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadFavorites,
        child: isLoading 
          ? const Center(child: CircularProgressIndicator())
          : favList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.folder_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        '暂无收藏夹',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: favList.length,
                  itemBuilder: (context, index) => Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    elevation: 2,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: Text(
                          favList[index].title.characters.first,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      title: Text(
                        favList[index].title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          "${favList[index].mediaCount} 首曲目",
                          style: TextStyle(color: Theme.of(context).colorScheme.secondary),
                        ),
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
      ),
    );
  }
}
