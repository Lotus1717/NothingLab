import 'package:flutter/material.dart';

import 'app_fonts.dart';

/// 「俏皮神谕 · Playful Oracle」— 温暖极简 + 一点仪式感
class AppTheme {
  static const Color primary = Color(0xFFFFB7B2);
  static const Color primaryDark = Color(0xFFFF8A7A);
  static const Color bg = Color(0xFFFFF8F3);
  static const Color bgMint = Color(0xFFF0F7F4);
  static const Color card = Color(0xFFFFFFFF);
  static const Color secondary = Color(0xFF7EC8B8);
  static const Color secondaryMuted = Color(0xFFB5E3C5);
  static const Color textDark = Color(0xFF3D2C2C);
  static const Color textMuted = Color(0xFF9A8A8A);
  static const Color textLight = Color(0xFFBBBBBB);
  static const Color oracleGold = Color(0xFFE8B86D);
  static const Color oracleGoldLight = Color(0xFFFFF4E0);
  static const Color danger = Color(0xFFE57373);

  static const double radiusSm = 12;
  static const double radiusMd = 18;
  static const double radiusLg = 24;
  static const EdgeInsets pagePadding =
      EdgeInsets.symmetric(horizontal: 20, vertical: 16);

  static TextStyle displayTitle(BuildContext context) =>
      AppFonts.displayStyle(
        fontSize: 26,
        color: textDark,
        height: 1.3,
      );

  static TextStyle pageTitle(BuildContext context) =>
      AppFonts.displayStyle(
        fontSize: 22,
        color: textDark,
        height: 1.3,
      );

  static TextStyle sectionHeader(BuildContext context) =>
      AppFonts.bodyStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: textMuted,
        letterSpacing: 0.6,
      );

  static TextStyle bodyLarge(BuildContext context) =>
      AppFonts.bodyStyle(
        fontSize: 17,
        fontWeight: FontWeight.w500,
        color: textDark,
        height: 1.55,
      );

  static TextStyle bodyMedium(BuildContext context) =>
      AppFonts.bodyStyle(
        fontSize: 15,
        color: textDark,
        height: 1.5,
      );

  static TextStyle caption(BuildContext context) =>
      AppFonts.bodyStyle(
        fontSize: 12,
        color: textMuted,
        height: 1.4,
      );

  static TextStyle prophecyBody(BuildContext context) =>
      AppFonts.bodyStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: textDark,
        height: 1.6,
      );

  static BoxDecoration oracleGradientBg = const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFFFF8F3),
        Color(0xFFFFF4EC),
        Color(0xFFF8F5F0),
      ],
    ),
  );

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: const Color(0xFF3D2C2C).withValues(alpha: 0.06),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: primaryDark.withValues(alpha: 0.04),
      blurRadius: 12,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> oracleGlowShadow = [
    BoxShadow(
      color: oracleGold.withValues(alpha: 0.25),
      blurRadius: 24,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: primaryDark.withValues(alpha: 0.12),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bg,
      primaryColor: primaryDark,
      fontFamily: AppFonts.body,
      fontFamilyFallback: AppFonts.fallback,
      colorScheme: const ColorScheme.light(
        primary: primaryDark,
        secondary: secondary,
        surface: card,
        onSurface: textDark,
        error: danger,
      ),
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: textDark,
        displayColor: textDark,
        fontFamily: AppFonts.body,
        fontFamilyFallback: AppFonts.fallback,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textDark,
        contentTextStyle: AppFonts.bodyStyle(
          color: Colors.white,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card.withValues(alpha: 0.95),
        indicatorColor: primary.withValues(alpha: 0.35),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppFonts.bodyStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? primaryDark : textMuted,
          );
        }),
      ),
    );
  }
}
