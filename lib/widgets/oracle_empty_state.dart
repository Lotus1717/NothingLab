import 'package:flutter/material.dart';

import '../config/theme.dart';

class OracleEmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;

  const OracleEmptyState({
    super.key,
    this.emoji = '✨',
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.oracleGoldLight,
                  AppTheme.primary.withValues(alpha: 0.35),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.oracleGold.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 40)),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTheme.bodyMedium(context).copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTheme.caption(context),
          ),
        ],
      ),
    );
  }
}
