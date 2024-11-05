import 'package:bmsc/cache_manager.dart';
import 'package:bmsc/screen/about_screen.dart';
import 'package:bmsc/screen/cache_screen.dart';
import 'package:bmsc/screen/login_screen.dart';
import 'package:bmsc/screen/playlist_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:bmsc/globals.dart' as globals;
import 'package:bmsc/util/logger.dart';

final logger = LoggerUtils.getLogger('SettingsScreen');

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoggedIn = true;
  String? _username;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final uid = await globals.api.getUID();
    final username = await globals.api.getStoredUsername();
    if (mounted) {
      setState(() {
        _isLoggedIn = uid != 0;
        _username = username;
      });
    }
  }

  Future<void> _logout() async {
    logger.info('user logout');
    await globals.api.resetCookies();
    await globals.api.getUID();
    await CacheManager.cacheFavList([]);
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
                          }
                        },
                        child: const Text('确定'),
                      ),
                    ],
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute<Widget>(
                      builder: (_) => const LoginScreen()),
                ).then((value) async {
                  await _checkLoginStatus();
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
