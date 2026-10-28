// Defines shared typography, contrast and control geometry for both supported appearances.

import 'package:flutter/material.dart';

const appFontFamily = 'OmniQuizSans';

ThemeData buildTheme({Brightness brightness = Brightness.light}) {
  final dark = brightness == Brightness.dark;
  const green = Color(0xFF245C46);
  final scheme = ColorScheme.fromSeed(
    seedColor: green,
    brightness: brightness,
    surface: dark ? const Color(0xFF111914) : const Color(0xFFF7F8F3),
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: appFontFamily,
    fontFamilyFallback: const [
      'Microsoft YaHei',
      'PingFang SC',
      'Noto Sans CJK SC',
      'Noto Sans SC',
      'sans-serif',
    ],
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? scheme.surfaceContainerLow : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      helperStyle: const TextStyle(
        fontFamily: appFontFamily,
        fontSize: 14,
        height: 1.5,
        letterSpacing: 0,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    cardTheme: CardThemeData(
      margin: EdgeInsets.zero,
      color: dark ? scheme.surfaceContainerLow : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      bodySmall: base.textTheme.bodySmall?.copyWith(
        fontSize: 14,
        height: 1.5,
        letterSpacing: 0,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        height: 1.5,
        letterSpacing: 0,
      ),
    ),
  );
}
