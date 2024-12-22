import 'package:flutter/material.dart';

import 'util/shared_preferences_service.dart';

class ThemeProvider extends ChangeNotifier {
  static final ThemeProvider _instance = ThemeProvider._internal();
  factory ThemeProvider() => _instance;
  ThemeProvider._internal();

  static ThemeProvider get instance => _instance;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  int _commentFontSize = 16;
  int get commentFontSize => _commentFontSize;

  Future<void> init() async {
    final prefs = await SharedPreferencesService.instance;
    _commentFontSize = prefs.getInt('comment_font_size') ?? 14;
    switch (prefs.getString('theme_mode') ?? '') {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      case 'system':
        _themeMode = ThemeMode.system;
        break;
      default:
        _themeMode = ThemeMode.system;
        break;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode != mode) {
      _themeMode = mode;
      final prefs = await SharedPreferencesService.instance;
      await prefs.setString('theme_mode', mode.name);
      notifyListeners();
    }
  }

  Future<void> setCommentFontSize(int size) async {
    if (_commentFontSize != size) {
      _commentFontSize = size;
      final prefs = await SharedPreferencesService.instance;
      await prefs.setInt('comment_font_size', size);
    }
  }

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF191919),
      actionTextColor: Colors.white70,
      contentTextStyle: TextStyle(color: Colors.white70),
    ),
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
      surface: Colors.black,
      primary: Colors.blue.shade300,
      onPrimary: Colors.black,
      surfaceContainerHighest: const Color(0xFF262626),
      surfaceContainerHigh: const Color(0xFF1F1F1F),
      surfaceContainer: const Color(0xFF191919),
      surfaceContainerLow: const Color(0xFF141414),
      surfaceContainerLowest: const Color(0xFF0A0A0A),
      error: const Color(0xFFFF5757),
      onError: Colors.black,
      secondary: Colors.blueGrey.shade200,
      onSecondary: Colors.black,
      outline: const Color(0xFF6E6E6E),
      outlineVariant: const Color(0xFF2C2C2C),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFFE0E0E0)),
      bodyMedium: TextStyle(color: Color(0xFFE0E0E0)),
      bodySmall: TextStyle(color: Color(0xFFBDBDBD)),
    ),
  );
}
