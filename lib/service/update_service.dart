import 'package:bmsc/model/release.dart';
import 'package:bmsc/util/logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

final _logger = LoggerUtils.getLogger('Update');

class UpdateService {
  static Future<UpdateService> instance = _init();

  List<ReleaseResult>? newVersionInfo;
  bool hasNewVersion = false;
  String? curVersion;

  static Future<UpdateService> _init() async {
    final x = UpdateService();
    final packageInfo = await PackageInfo.fromPlatform();
    x.newVersionInfo = await checkNewVersion();
    x.curVersion = packageInfo.version;
    x.hasNewVersion = x.newVersionInfo != null &&
        x.newVersionInfo!.first.tagName != 'v${x.curVersion}';
    _logger.info('hasNewVersion: ${x.hasNewVersion}');
    _logger.info('curVersion: ${x.curVersion}');
    _logger.info('newVersionInfo: ${x.newVersionInfo!.first.tagName}');
    return x;
  }

  static Future<List<ReleaseResult>?> checkNewVersion() async {
    List<ReleaseResult>? ret;
    try {
      _logger.info("requesting latest release");
      final resp =
          await Dio().get('https://api.github.com/repos/u2x1/bmsc/releases');
      ret = List.from(resp.data).map((e) => ReleaseResult.fromJson(e)).toList();
    } catch (e) {
      _logger.severe("error: $e");
      return null;
    }
    return ret;
  }

  void showUpdateDialog(BuildContext context, String curVersion) {
    if (newVersionInfo == null) {
      return;
    }
    var changelog = "";
    for (var version in newVersionInfo!) {
      changelog += "# ${version.tagName}\n\n${version.body}\n\n";
      if (version.tagName == 'v$curVersion') {
        break;
      }
    }
    final newVersion = newVersionInfo!.first;
    Widget viewButton = TextButton(
      child: const Text("查看"),
      onPressed: () async {
        await launchUrl(
            Uri.parse('https://github.com/u2x1/bmsc/releases/latest'),
            mode: LaunchMode.externalApplication);
      },
    );

    Widget downloadButton = TextButton(
      child: const Text("下载"),
      onPressed: () async {
        if (newVersion.assets.isNotEmpty) {
          await launchUrl(
              Uri.parse(
                  "https://github.com/u2x1/bmsc/releases/download/${newVersion.tagName}/bmsc-${newVersion.tagName}-arm64.apk"),
              mode: LaunchMode.externalApplication);
        }
      },
    );

    AlertDialog alert = AlertDialog(
      title: const Text("有新版本可用"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("检测到版本更新 ($curVersion -> ${newVersion.tagName})"),
          const SizedBox(height: 10),
          Flexible(child: SingleChildScrollView(child: Text(changelog))),
        ],
      ),
      actions: [
        viewButton,
        downloadButton,
      ],
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }
}
