import 'package:flutter/material.dart';

import '../config/app_fonts.dart';
import '../config/theme.dart';
import 'lazy_cat.dart';
import 'oracle_background.dart';

/// 应用内启动页：蜜桃底 + 慵懒小猫，与 Web 静态启动页视觉一致。
class AppSplash extends StatelessWidget {
  const AppSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.bg,
      child: OracleBackground(
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const IgnorePointer(
                  child: LazyCat(
                    animating: false,
                    onTap: _noop,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '废话预言家',
                  style: AppFonts.displayStyle(
                    fontSize: 26,
                    color: AppTheme.textDark,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '小猫醒来中…',
                  style: AppFonts.bodyStyle(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _noop() {}
