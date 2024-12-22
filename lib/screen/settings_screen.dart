import 'package:bmsc/cache_manager.dart';
import 'package:bmsc/screen/about_screen.dart';
import 'package:bmsc/screen/cache_screen.dart';
import 'package:bmsc/screen/login_screen.dart';
import 'package:bmsc/screen/playlist_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:bmsc/globals.dart' as globals;
import '../util/shared_preferences_service.dart';
import '../theme.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoggedIn = globals.api.uid != 0;
  final String? _username = globals.api.username;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _logout() async {
    logger.info('user logout');
    await globals.api.resetCookies();
    globals.api.uid = 0;
    globals.api.username = null;
    await CacheManager.cacheFavList([]);
    final prefs = await SharedPreferencesService.instance;
    await prefs.setInt('uid', 0);
    await prefs.setString('username', '');
    if (mounted) {
      setState(() {
        _isLoggedIn = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '账号',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            title: Text(_isLoggedIn ? '退出登录' : '登录'),
            subtitle: Text(_isLoggedIn ? '当前已登录: $_username' : '点击登录账号'),
            leading: Icon(_isLoggedIn ? Icons.logout : Icons.login),
            onTap: () {
              if (_isLoggedIn) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('退出登录'),
                    content: const Text('确定要退出登录吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        onPressed: () async {
                          await _logout();
                          if (context.mounted) {
                            Navigator.pop(context);
                            Navigator.pop(context, true);
                          }
                        },
                        child: const Text('确定'),
                      ),
                    ],
                  ),
                );
              } else {
                Navigator.push<bool>(
                  context,
                  MaterialPageRoute<bool>(builder: (_) => const LoginScreen()),
                ).then((value) async {
                  if (value == true) {
                    if (context.mounted) {
                      Navigator.pop(context, true);
                    }
                  }
                });
              }
            },
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '缓存',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            title: const Text('缓存管理'),
            leading: const Icon(Icons.storage),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<Widget>(builder: (_) => const CacheScreen()),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '显示',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),

          ListTile(
            title: const Text('主题模式'),
            leading: const Icon(Icons.palette),
            subtitle: Text(
              switch (ThemeProvider.instance.themeMode) {
                ThemeMode.light => '浅色',
                ThemeMode.dark => '深色',
                ThemeMode.system => '跟随系统',
              }
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('选择主题模式'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile<ThemeMode>(
                        title: const Text('浅色'),
                        value: ThemeMode.light,
                        groupValue: ThemeProvider.instance.themeMode,
                        onChanged: (ThemeMode? value) async {
                          if (value != null) {
                            await ThemeProvider.instance.setThemeMode(value);
                            if (context.mounted) Navigator.pop(context);
                          }
                        },
                      ),
                      RadioListTile<ThemeMode>(
                        title: const Text('深色'),
                        value: ThemeMode.dark,
                        groupValue: ThemeProvider.instance.themeMode,
                        onChanged: (ThemeMode? value) async {
                          if (value != null) {
                            await ThemeProvider.instance.setThemeMode(value);
                            if (context.mounted) Navigator.pop(context);
                          }
                        },
                      ),
                      RadioListTile<ThemeMode>(
                        title: const Text('跟随系统'),
                        value: ThemeMode.system,
                        groupValue: ThemeProvider.instance.themeMode,
                        onChanged: (ThemeMode? value) async {
                          if (value != null) {
                            await ThemeProvider.instance.setThemeMode(value);
                            if (context.mounted) Navigator.pop(context);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
           ListTile(
            title: const Text('评论字体大小'),
            subtitle: Text('${ThemeProvider.instance.commentFontSize}'),
            leading: const Icon(Icons.format_size),
            onTap: () {
              var fontSize = ThemeProvider.instance.commentFontSize;
              showDialog(
                context: context,
                builder: (context) => SimpleDialog(
                  title: const Text('评论字体大小'),
                  children: [
                    StatefulBuilder(
                      builder: (context, setState) => Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Row(
                              children: [
                                Text('12', 
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.secondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Expanded(
                                  child: Slider(
                                    value: fontSize.toDouble(),
                                    min: 12,
                                    max: 20,
                                    divisions: 8,
                                    label: fontSize.toString(),
                                    onChanged: (value) {
                                      setState(() {
                                        fontSize = value.toInt();
                                      });
                                    },
                                  ),
                                ),
                                Text('20',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.secondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).then((_) {
                if (context.mounted) {
                  setState(() {
                    ThemeProvider.instance.setCommentFontSize(fontSize);
                  });
                }
              });
            },
          ),
          StatefulBuilder(
            builder: (context, setState) => FutureBuilder<bool>(
              future: SharedPreferencesService.instance.then((prefs) =>
                  prefs.getBool('show_daily_recommendations') ?? true),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                return SwitchListTile(
                  title: const Text('显示每日推荐'),
                  secondary: const Icon(Icons.recommend),
                  subtitle: const Text('在收藏夹页面显示每日推荐'),
                  value: snapshot.data!,
                  onChanged: (bool value) async {
                    final prefs = await SharedPreferencesService.instance;
                    await prefs.setBool('show_daily_recommendations', value);
                    setState(() {});
                  },
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '工具',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            title: const Text('导入歌单'),
            leading: const Icon(Icons.import_export),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<Widget>(
                    builder: (_) => const PlaylistSearchScreen()),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '其他',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            title: const Text('关于'),
            leading: const Icon(Icons.info_outline),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<Widget>(builder: (_) => const AboutScreen()),
              );
            },
          ),
         
        ],
      ),
    );
  }
}
