import 'package:flutter/material.dart';

import '../config/app_fonts.dart';
import '../config/theme.dart';

/// 用于生成分享图片的离屏卡片（固定宽度，样式独立于屏幕）
class ProphecyShareCard extends StatelessWidget {
  final String prophecy;

  const ProphecyShareCard({super.key, required this.prophecy});

  static const double cardWidth = 360;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: cardWidth,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFF8F3),
            Color(0xFFFFF4EC),
            Color(0xFFF8F5F0),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🐣', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text(
                '废话预言家',
                style: AppFonts.displayStyle(
                  fontSize: 22,
                  color: AppTheme.textDark,
                  height: 1.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFFFF), Color(0xFFFFFBF7)],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(
                color: AppTheme.oracleGold.withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: AppTheme.oracleGlowShadow,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        size: 14, color: AppTheme.oracleGold),
                    const SizedBox(width: 6),
                    Text(
                      '今日神谕',
                      style: AppFonts.bodyStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.oracleGold,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  prophecy,
                  textAlign: TextAlign.center,
                  style: AppFonts.bodyStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textDark,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '基于手机传感器的无厘头预言',
            style: AppFonts.bodyStyle(
              fontSize: 11,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
