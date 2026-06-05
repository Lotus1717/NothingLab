import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/theme.dart';

/// 页面顶部轻柔星点装饰
class OracleBackground extends StatelessWidget {
  final Widget child;

  const OracleBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: AppTheme.oracleGradientBg,
          child: CustomPaint(painter: _SparklePainter()),
        ),
        child,
      ],
    );
  }
}

class _SparklePainter extends CustomPainter {
  static final _stars = [
    _Star(0.12, 0.06, 2.2, 0.35),
    _Star(0.78, 0.04, 1.8, 0.28),
    _Star(0.92, 0.12, 2.0, 0.22),
    _Star(0.55, 0.08, 1.5, 0.2),
    _Star(0.25, 0.14, 1.6, 0.18),
    _Star(0.88, 0.18, 1.4, 0.15),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final gold = Paint()
      ..color = AppTheme.oracleGold.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final mint = Paint()
      ..color = AppTheme.secondary.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    for (var i = 0; i < _stars.length; i++) {
      final s = _stars[i];
      final center = Offset(s.x * size.width, s.y * size.height);
      final paint = i.isEven ? gold : mint;
      _drawSparkle(canvas, center, s.radius, s.opacity, paint);
    }
  }

  void _drawSparkle(
    Canvas canvas,
    Offset center,
    double radius,
    double opacity,
    Paint base,
  ) {
    final paint = Paint()
      ..color = base.color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, paint);
    for (var a = 0; a < 4; a++) {
      final angle = a * math.pi / 2;
      final dx = math.cos(angle) * radius * 2.2;
      final dy = math.sin(angle) * radius * 2.2;
      canvas.drawCircle(
        Offset(center.dx + dx, center.dy + dy),
        radius * 0.35,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Star {
  final double x;
  final double y;
  final double radius;
  final double opacity;

  const _Star(this.x, this.y, this.radius, this.opacity);
}
