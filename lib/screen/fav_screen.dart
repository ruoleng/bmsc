import 'package:bmsc/database_manager.dart';
import 'package:bmsc/model/fav.dart';
import 'package:bmsc/service/audio_service.dart';
import 'package:bmsc/service/bilibili_service.dart';
import 'package:flutter/material.dart';
import '../service/shared_preferences_service.dart';
import 'fav_detail_screen.dart';
import 'recommendation_screen.dart';
import 'package:bmsc/util/logger.dart';

final logger = LoggerUtils.getLogger('FavScreen');

class FavScreen extends StatefulWidget {
  final void Function(FavScreenState state)? onInit;

  const FavScreen({super.key, this.onInit});

  @override
  State<FavScreen> createState() => FavScreenState();
}

class FavScreenState extends State<FavScreen> {
  bool signedin = false;
  List<Fav> favList = [];
  List<Fav> collectedFavList = [];

  @override
  void initState() {
    super.initState();
    widget.onInit?.call(this);
    BilibiliService.instance.then((x) {
      setState(() {
        signedin = x.myInfo?.mid != null && x.myInfo?.mid != 0;
      });
      if (signedin) {
        loadFavorites(local: true);
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> loadFavorites({bool local = false}) async {
    if (!mounted || !signedin) return;

    if (local) {
      var cachedFavs = await DatabaseManager.getCachedFavList();
      var cachedCollectedFavs =
          await DatabaseManager.getCachedCollectedFavList();

      if (cachedFavs.isNotEmpty || cachedCollectedFavs.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          favList = cachedFavs;
          collectedFavList = cachedCollectedFavs;
        });
      }

      logger.info(
          'got ${cachedFavs.length} cached favs and ${cachedCollectedFavs.length} collected favs');
    } else {
      BilibiliService.instance.then((x) async {
        if (!mounted) return;
        final uid = x.myInfo?.mid;
        if (uid == null || uid == 0) {
          return;
        }

        try {
          final ret = (await x.getFavs(uid)) ?? [];
          final collectedRet = (await x.getCollection(uid)) ?? [];

          if (ret.isNotEmpty || collectedRet.isNotEmpty) {
            if (!mounted) return;
            setState(() {
              favList = ret;
              collectedFavList = collectedRet;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('加载成功')),
            );
            logger.info(
                'got ${ret.length} favs and ${collectedRet.length} collected favs from network');
          }
        } catch (e) {
          logger.severe('loadFavorites error: $e');

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('加载失败')),
          );
        }
        logger.info('loadFavorites done');
      });
    }
  }

  Future<void> _showCreateFolderDialog() async {
    final nameController = TextEditingController();
    bool isPrivate = false;

    final result = await showDialog<(String, bool)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('创建收藏夹'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '收藏夹名称',
                  hintText: '请输入收藏夹名称',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: isPrivate,
                    onChanged: (value) => setState(() => isPrivate = value!),
                  ),
                  const Text('设为私密收藏夹'),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入收藏夹名称')),
                  );
                  return;
                }
                Navigator.pop(context, (
                  nameController.text.trim(),
                  isPrivate,
                ));
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final folderId =
          await BilibiliService.instance.then((x) => x.createFavFolder(
                result.$1,
                hide: result.$2,
              ));

      if (folderId != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('创建成功')),
          );
          loadFavorites();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('创建失败')),
          );
        }
      }
    }
  }

  Future<void> _showEditFolderDialog(Fav fav) async {
    final nameController = TextEditingController(text: fav.title);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('编辑收藏夹'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '收藏夹名称',
                  hintText: '请输入收藏夹名称',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入收藏夹名称')),
                  );
                  return;
                }
                Navigator.pop(context, nameController.text.trim());
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final success =
          await BilibiliService.instance.then((x) => x.editFavFolder(
                fav.id,
                result,
              ));

      if (success == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('修改成功')),
          );
          loadFavorites();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('修改失败')),
          );
        }
      }
    }
  }

  Future<void> _showDeleteConfirmation(Fav fav) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除收藏夹'),
        content: Text('确定要删除收藏夹"${fav.title}"吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success =
          await BilibiliService.instance.then((x) => x.deleteFavFolder(fav.id));
      if (success == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('删除成功')),
          );
          loadFavorites();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('删除失败')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('云收藏夹',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: !signedin
            ? []
            : [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _showCreateFolderDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: loadFavorites,
                ),
              ],
      ),
      body: !signedin
          ? const Center(child: Text('请先登录'))
          : ListView(
              children: [
                if (favList.isEmpty && collectedFavList.isEmpty)
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
                  ),

                if (favList.isNotEmpty || collectedFavList.isNotEmpty) ...[
                  FutureBuilder<bool>(
                    future: SharedPreferencesService.instance.then((prefs) =>
                        prefs.getBool('show_daily_recommendations') ?? true),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || !snapshot.data!) {
                        return const SizedBox();
                      }
                      return Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                            ),
                            leading: const Icon(Icons.star_border),
                            title: const Text('每日推荐',
                                style: TextStyle(fontWeight: FontWeight.w500)),
                            subtitle: const Text('基于收藏夹的推荐'),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<Widget>(
                                  builder: (_) => const RecommendationScreen()),
                            ),
                          ),
                          const Divider(),
                        ],
                      );
                    },
                  ),
                ],

                // 我的收藏夹标题
                if (favList.isNotEmpty)
                  const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                    child: Text(
                      '我的收藏夹',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                // 我的收藏夹列表
                ...buildFavList(favList, true),

                // 收藏的收藏夹标题
                if (collectedFavList.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                    child: Text(
                      '收藏的收藏夹',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // 收藏的收藏夹列表
                  ...buildFavList(collectedFavList, false),
                ],

                // 显示空状态
              ],
            ),
    );
  }

  List<Widget> buildFavList(List<Fav> favs, bool isOwned) {
    return favs
        .map((fav) => Column(
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
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text('${fav.mediaCount} 个视频'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FavDetailScreen(
                            fav: fav,
                            isCollected: !isOwned,
                          ),
                        ),
                      );
                    },
                    trailing: isOwned
                        ? IconButton(
                            icon: const Icon(Icons.more_vert),
                            onPressed: () => showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('选择操作'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.playlist_add),
                                      title: const Text('添加到播放列表'),
                                      onTap: () async {
                                        Navigator.pop(context);
                                        final bvids = await DatabaseManager
                                            .getCachedFavBvids(fav.id);
                                        await AudioService.instance
                                            .then((x) => x.playByBvids(bvids));
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.star_outline),
                                      title: const Text('设为默认收藏夹'),
                                      onTap: () async {
                                        Navigator.pop(context);
                                        await SharedPreferencesService
                                            .setDefaultFavFolder(
                                                fav.id, fav.title);
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
                                    ListTile(
                                      leading: const Icon(Icons.edit),
                                      title: const Text('编辑收藏夹'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _showEditFolderDialog(fav);
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.delete,
                                          color: Colors.red),
                                      title: const Text('删除收藏夹',
                                          style: TextStyle(color: Colors.red)),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _showDeleteConfirmation(fav);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : null),
                const Divider(),
              ],
            ))
        .toList();
  }
}
