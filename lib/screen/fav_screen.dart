import 'package:bmsc/model/fav.dart';
import 'package:flutter/material.dart';
import '../globals.dart' as globals;
import 'fav_detail_screen.dart';
import 'package:bmsc/cache_manager.dart' as cache_manager;
import 'recommendation_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
            : ListView(
                children: [
                  // 每日推荐入口
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                    ),
                    leading: const Icon(Icons.recommend, color: Colors.orange),
                    title: const Text('每日推荐',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: const Text('基于收藏夹的个性化推荐'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<Widget>(
                          builder: (_) => const RecommendationScreen()),
                    ),
                  ),
                  const Divider(),
                  // 收藏夹列表
                  if (favList.isEmpty)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.folder_outlined,
                              size: 64, color: Colors.grey),
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
                  else
                    ...favList.map((fav) => Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                              ),
                              leading: Icon(
                                Icons.folder_outlined,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              title: Text(
                                fav.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text('${fav.mediaCount} 个视频'),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        FavDetailScreen(fav: fav),
                                  ),
                                );
                              },
                              trailing: IconButton(
                                icon: const Icon(Icons.more_vert),
                                onPressed: () => showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('选择操作'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ListTile(
                                          leading:
                                              const Icon(Icons.playlist_add),
                                          title: const Text('添加到播放列表'),
                                          onTap: () async {
                                            Navigator.pop(context);
                                            await globals.api
                                                .addFavListToPlaylist(fav.id);
                                          },
                                        ),
                                        ListTile(
                                          leading:
                                              const Icon(Icons.star_outline),
                                          title: const Text('设为默认收藏夹'),
                                          onTap: () async {
                                            Navigator.pop(context);
                                            final prefs =
                                                await SharedPreferences
                                                    .getInstance();
                                            await prefs.setInt(
                                                'default_fav_folder_id',
                                                fav.id);
                                            await prefs.setString(
                                                'default_fav_folder_name',
                                                fav.title);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      '已将 ${fav.title} 设为默认收藏夹'),
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const Divider(),
                          ],
                        )),
                ],
              ),
      ),
    );
  }
}
