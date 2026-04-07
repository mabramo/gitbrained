import 'package:flutter/material.dart';
import 'screens/settings_screen.dart';
import 'screens/browser_screen.dart';

const _inter = 'Inter';
const _jetBrainsMono = 'JetBrainsMono';

// Convenience helpers used across the app
TextStyle interStyle({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? height,
  FontStyle? fontStyle,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: _inter,
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    fontStyle: fontStyle,
    letterSpacing: letterSpacing,
  );
}

TextStyle monoStyle({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  Color? backgroundColor,
  double? height,
}) {
  return TextStyle(
    fontFamily: _jetBrainsMono,
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    backgroundColor: backgroundColor,
    height: height,
  );
}

class GitbrainedApp extends StatelessWidget {
  final bool isConfigured;
  const GitbrainedApp({super.key, required this.isConfigured});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gitbrained',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.dark),
      home: isConfigured
          ? const BrowserScreen(path: '')
          : const SettingsScreen(isFirstLaunch: true),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF7C9E87),
        brightness: brightness,
      ),
      fontFamily: _inter,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: base.colorScheme.surface,
        foregroundColor: base.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: interStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: base.colorScheme.onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      dividerTheme: DividerThemeData(
        color: base.colorScheme.outlineVariant.withAlpha(100),
        thickness: 0.5,
      ),
    );
  }
}
