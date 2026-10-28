// Defines shared typography, contrast and control geometry for both supported appearances.

import 'package:flutter/material.dart';

const appFontFamily = 'OmniQuizSans';

ThemeData buildTheme({Brightness brightness = Brightness.light}) {
  final dark = brightness == Brightness.dark;
  const green = Color(0xFF24684F);
  final scheme = ColorScheme.fromSeed(
    seedColor: green,
    brightness: brightness,
    surface: dark ? const Color(0xFF111A17) : const Color(0xFFF5F7F5),
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
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: .55),
      space: 24,
      thickness: 1,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? scheme.surfaceContainerLow : Colors.white,
      indicatorColor: scheme.secondaryContainer,
      elevation: 0,
      height: 72,
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontFamily: appFontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? scheme.surfaceContainerLow : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      labelStyle: TextStyle(
        fontFamily: appFontFamily,
        color: scheme.onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? scheme.surfaceContainerLow : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: .7),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
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
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .55)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: const TextStyle(
          fontFamily: appFontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        side: BorderSide(color: scheme.outlineVariant),
        textStyle: const TextStyle(
          fontFamily: appFontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        textStyle: const TextStyle(
          fontFamily: appFontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontSize: 32,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -.5,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontSize: 24,
        height: 1.35,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
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
