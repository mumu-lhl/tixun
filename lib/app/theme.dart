import 'package:flutter/material.dart';

ThemeData appTheme(Brightness brightness, {ColorScheme? scheme}) {
  final dark = brightness == Brightness.dark;
  final colors =
      scheme ??
      ColorScheme.fromSeed(
        seedColor: const Color(0xff226450),
        brightness: brightness,
        surface: dark ? const Color(0xff151c1a) : const Color(0xfffafbf8),
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    brightness: brightness,
    fontFamily: 'NotoSansSC',
    scaffoldBackgroundColor: colors.surface,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.4,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.4,
      ),
      // Completes the type scale. Values match the M3 defaults the theme
      // previously fell back to silently (ThemeData merges missing slots
      // from the default typography), so defining them changes no pixels:
      // headlineSmall is also the markdown h1 style, and bolding it here
      // would bold every h1 in the app and invalidate the golden tests.
      // If a bolder headline is ever wanted, it is a deliberate design
      // change and the goldens need regenerating with it.
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        height: 1.33,
      ),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontSize: 16, height: 1.6),
      bodyMedium: TextStyle(fontSize: 14, height: 1.6),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        height: 1.33,
      ),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ).apply(bodyColor: colors.onSurface, displayColor: colors.onSurface),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceContainerLowest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .5)),
      ),
      margin: EdgeInsets.zero,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide(color: colors.outlineVariant.withValues(alpha: .5)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      labelStyle: const TextStyle(fontSize: 12),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: colors.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colors.outlineVariant.withValues(alpha: .6),
      thickness: 1,
      space: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.surface,
      elevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
