import 'package:flutter/material.dart';

/// 本地打包字体，避免运行时从 Google Fonts CDN 拉取。
class AppFonts {
  AppFonts._();

  static const String display = 'ZCOOLKuaiLe';
  static const String body = 'NotoSansSC';

  static const List<String> fallback = [
    'PingFang SC',
    'Hiragino Sans GB',
    'Microsoft YaHei',
    'sans-serif',
  ];

  static TextStyle displayStyle({
    required double fontSize,
    Color? color,
    double? height,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return TextStyle(
      fontFamily: display,
      fontFamilyFallback: fallback,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  static TextStyle bodyStyle({
    required double fontSize,
    Color? color,
    double? height,
    FontWeight fontWeight = FontWeight.w400,
    FontStyle fontStyle = FontStyle.normal,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: body,
      fontFamilyFallback: fallback,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
    );
  }
}
