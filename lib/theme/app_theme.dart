import 'package:flutter/material.dart';

/// Brand palette for "Remindly" — a purple primary with a warm-orange accent,
/// soft pastel card tints, and a warm off-white background. Derived from the
/// provided design mockups. Works in light and dark mode.
class AppColors {
  AppColors._();

  static const Color purple = Color(0xFF6C5CE7);
  static const Color purpleDark = Color(0xFF5A4AD1);
  static const Color orange = Color(0xFFF5A623);
  static const Color orangeDeep = Color(0xFFE8912A);

  // Warm neutrals
  static const Color bgLight = Color(0xFFF4F1EC);
  static const Color surfaceLight = Color(0xFFFBF9F5);
  static const Color inkLight = Color(0xFF2D2A32);
  static const Color mutedLight = Color(0xFF8A8690);

  static const Color bgDark = Color(0xFF17151C);
  static const Color surfaceDark = Color(0xFF211E28);
  static const Color inkDark = Color(0xFFF2EFF6);

  // Overdue "was due …" pill
  static const Color overduePillBg = Color(0xFFF8E0CE);
  static const Color overduePillFg = Color(0xFFB5641E);

  // Status text
  static const Color onTime = Color(0xFF2E9E5B);
  static const Color late = Color(0xFFC58218);

  /// A soft pastel background tint for a category card, blended over [surface].
  static Color softTint(Color categoryColor, Color surface) {
    return Color.alphaBlend(categoryColor.withValues(alpha: 0.14), surface);
  }
}

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.purple,
    brightness: brightness,
  ).copyWith(
    primary: AppColors.purple,
    secondary: AppColors.orange,
    tertiary: AppColors.orange,
    surface: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
  );

  final ink = isDark ? AppColors.inkDark : AppColors.inkLight;
  final bg = isDark ? AppColors.bgDark : AppColors.bgLight;

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    textTheme: Typography.material2021(platform: TargetPlatform.android)
        .black
        .apply(bodyColor: ink, displayColor: ink),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: ink,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(color: ink),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: isDark ? AppColors.surfaceDark : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.purple,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 58),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.04),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      hintStyle: TextStyle(color: isDark ? AppColors.inkDark.withValues(alpha: 0.5) : AppColors.mutedLight),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.purple, width: 2),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: ink.withValues(alpha: 0.08),
      thickness: 1,
    ),
  );
}
