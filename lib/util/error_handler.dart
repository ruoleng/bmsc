import 'package:flutter/material.dart';

class ErrorHandler {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static void showError(String message) {
    if (navigatorKey.currentContext == null) return;

    ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(8),
        action: SnackBarAction(
          label: '关闭',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(navigatorKey.currentContext!).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  static void handleException(dynamic error) {
    showError(error.toString());
  }
}
