import 'package:flutter/material.dart';

import '../config/theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final BorderRadius? borderRadius;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final Gradient? gradient;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.borderRadius,
    this.border,
    this.boxShadow,
    this.gradient,
  });

  /// 神谕揭晓专用卡片 — 内发光边框
  const AppCard.oracle({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
  })  : color = AppTheme.card,
        border = null,
        boxShadow = null,
        gradient = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFFFFBF7),
          ],
        );

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppTheme.radiusLg);
    final isOracle = gradient != null;
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? AppTheme.card) : null,
        gradient: gradient,
        borderRadius: radius,
        border: border ??
            (isOracle
                ? Border.all(
                    color: AppTheme.oracleGold.withValues(alpha: 0.35),
                    width: 1.2,
                  )
                : null),
        boxShadow: boxShadow ??
            (isOracle ? AppTheme.oracleGlowShadow : AppTheme.cardShadow),
      ),
      child: child,
    );
  }
}

class AppMintCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const AppMintCard({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.bgMint,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.secondary.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: child,
    );
  }
}
