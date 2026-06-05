import 'package:flutter/material.dart';

import '../config/theme.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onTrailingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Text(title, style: AppTheme.sectionHeader(context)),
          const Spacer(),
          if (trailing != null)
            GestureDetector(
              onTap: onTrailingTap,
              child: Text(
                trailing!,
                style: AppTheme.caption(context).copyWith(
                  color: onTrailingTap != null
                      ? AppTheme.primaryDark
                      : AppTheme.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
