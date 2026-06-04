import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFFFFB7B2);
  static const Color primaryDark = Color(0xFFFF8A7A);
  static const Color bg = Color(0xFFFFF9F0);
  static const Color bgMint = Color(0xFFF0F7F4);
  static const Color card = Color(0xFFFFFFFF);
  static const Color secondary = Color(0xFFB5E3C5);
  static const Color textDark = Color(0xFF2E2E2E);
  static const Color textLight = Color(0xFFBBBBBB);
  static ThemeData get lightTheme => ThemeData(
    scaffoldBackgroundColor: bg,
    primaryColor: primary,
    colorScheme: const ColorScheme.light(primary: primary, secondary: secondary, surface: card),
    fontFamily: '.SF Pro Text',
  );
}