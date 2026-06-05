import 'package:flutter/material.dart';

import '../config/theme.dart';

class StatusChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color? activeColor;

  const StatusChip({
    super.key,
    required this.label,
    this.active = false,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? AppTheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active
            ? color.withValues(alpha: 0.15)
            : const Color(0xFFF5F0EB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active
              ? color.withValues(alpha: 0.35)
              : const Color(0xFFE8E0DA),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: AppTheme.caption(context).copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: active ? color : AppTheme.textMuted,
        ),
      ),
    );
  }
}
