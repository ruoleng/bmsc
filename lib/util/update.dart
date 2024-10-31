import 'package:bmsc/model/release.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<ReleaseResult?> checkNewVersion() async {
  ReleaseResult? ret;
  try {
    final resp = await Dio()
        .get('https://api.github.com/repos/u2x1/bmsc/releases/latest');
    ret = ReleaseResult.fromJson(resp.data);
  } catch (e) {
    return null;
  }
  return ret;
}

showUpdateDialog(
    BuildContext context, ReleaseResult newVersion, String curVersion) {
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
        await launchUrl(
            Uri.parse(
                'https://ghp.ci/' + newVersion.assets.first.browserDownloadUrl),
            mode: LaunchMode.externalApplication);
      }
    },
  );

  AlertDialog alert = AlertDialog(
    title: const Text("有新版本可用"),
    content: Text(
        "检测到版本更新 ($curVersion -> ${newVersion.tagName})。\n\n更新日志: \n${newVersion.body}"),
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
