import 'package:bmsc/model/release.dart';
import 'package:bmsc/util/logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

final logger = LoggerUtils.getLogger('Update');

class UpdateService {
  static Future<UpdateService> instance = _init();

  List<ReleaseResult>? newVersionInfo;

  static Future<UpdateService> _init() async {
    final x = UpdateService();
    x.newVersionInfo = await checkNewVersion();
    return x;
  }

  static Future<List<ReleaseResult>?> checkNewVersion() async {
    List<ReleaseResult>? ret;
    try {
      logger.info("requesting latest release");
      final resp =
          await Dio().get('https://api.github.com/repos/u2x1/bmsc/releases');
      ret = List.from(resp.data).map((e) => ReleaseResult.fromJson(e)).toList();
    } catch (e) {
      logger.severe("error: $e");
      return null;
    }
    return ret;
  }

  static void showUpdateDialog(
    BuildContext context, List<ReleaseResult> newVersions, String curVersion) {
  var changelog = "";
  for (var version in newVersions) {
    changelog += "# ${version.tagName}\n\n${version.body}\n\n";
    if (version.tagName == curVersion) {
      break;
    }
  }
  final newVersion = newVersions.first;
  Widget viewButton = TextButton(
    child: const Text("查看"),
    onPressed: () async {
      await launchUrl(Uri.parse('https://github.com/u2x1/bmsc/releases/latest'),
          mode: LaunchMode.externalApplication);
    },
  );

  Widget downloadButton = TextButton(
    child: const Text("下载"),
    onPressed: () async {
      if (newVersion.assets.isNotEmpty) {
        await launchUrl(Uri.parse(newVersion.assets.first.browserDownloadUrl),
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
