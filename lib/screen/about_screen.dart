import 'package:bmsc/model/release.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../util/update.dart';
import 'package:flutter/services.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String version = '';
  List<ReleaseResult>? releases;
  bool hasNewVersion = false;
  List<(String, String)> changelog = [];

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
    _checkNewVersion();
  }

  Future<void> _checkNewVersion() async {
    final latestReleases = await checkNewVersion();
    if (mounted) {
      setState(() {
        releases = latestReleases;
        if (latestReleases != null && latestReleases.isNotEmpty) {
          hasNewVersion = latestReleases.first.tagName != version;
          changelog = latestReleases.map((e) => (e.tagName, e.body)).toList();
        }
      });
    }
  }

  Future<void> _loadVersionInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = "v${packageInfo.version}";
    final changelogAsset = await rootBundle.loadString('changelog.md');
    final c = changelogAsset
        .split('#')
        .map((e) => e.trim())
        .map((e) => e
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList())
        .where((e) => e.isNotEmpty)
        .map((e) => (e[0], e.sublist(1).join('\n')))
        .toList();
    if (mounted) {
      setState(() {
        version = currentVersion;
        changelog = c;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('关于'),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/icon.png',
                    width: 100,
                    height: 100,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'BMSC',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '当前版本: $version',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (hasNewVersion) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.system_update),
                    label: const Text('有新版本可用'),
                    onPressed: () {
                      if (releases != null) {
                        showUpdateDialog(context, releases!, version);
                      }
                    },
                  ),
                ],
                const SizedBox(height: 32),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Divider(),
                        const SizedBox(height: 16),
                        Text(
                          '© ${DateTime.now().year} u2x1',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '本软件仅供学习交流使用\n请勿用于任何商业用途',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.code),
                              label: const Text('开源代码'),
                              onPressed: () => launchUrl(
                                Uri.parse('https://github.com/u2x1/bmsc'),
                                mode: LaunchMode.externalApplication,
                              ),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.bug_report),
                              label: const Text('问题反馈'),
                              onPressed: () => launchUrl(
                                Uri.parse(
                                    'https://github.com/u2x1/bmsc/issues'),
                                mode: LaunchMode.externalApplication,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              '更新历史',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...changelog.map((entry) => Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            entry.$1,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (entry.$1 == version)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                '当前版本',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entry.$2,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
