import 'package:bmsc/model/release.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

Future<ReleaseResult?> checkNewVersion() async {
  final resp =
      await Dio().get('https://api.github.com/repos/u2x1/bmsc/releases/latest');
  return ReleaseResult.fromJson(resp.data);
}

showUpdateDialog(
    BuildContext context, ReleaseResult newVersion, String curVersion) {
  // set up the buttons
  Widget cancelButton = TextButton(
    child: const Text("取消"),
    onPressed: () {},
  );
  Widget continueButton = TextButton(
    child: const Text("查看"),
    onPressed: () async {
      await launchUrl(Uri.parse('https://github.com/u2x1/bmsc/releases/latest'),
          mode: LaunchMode.externalApplication);
    },
  );

  // set up the AlertDialog
  AlertDialog alert = AlertDialog(
    title: const Text("有新版本可用"),
    content: Text(
        "检测到版本更新 ($curVersion -> ${newVersion.tagName})。\n\n更新日志: \n${newVersion.body}"),
    actions: [
      cancelButton,
      continueButton,
    ],
  );

  // show the dialog
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return alert;
    },
  );
}
