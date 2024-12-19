import 'package:flutter/material.dart';

class AppTheme {
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
