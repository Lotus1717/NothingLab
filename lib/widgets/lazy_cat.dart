import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../utils/animations.dart';

/// 几笔勾勒的慵懒线条小猫。
///
/// 趴着的猫咪，忽而摇尾巴，忽而打哈欠，忽而眨眼睛。
/// 加载（生成预言）时会进入竖耳警觉状态。
class LazyCat extends StatefulWidget {
  final bool animating;
  final VoidCallback onTap;

  const LazyCat({
    super.key,
    required this.animating,
    required this.onTap,
  });

  @override
  State<LazyCat> createState() => _LazyCatState();
}

class _LazyCatState extends State<LazyCat> with TickerProviderStateMixin {
  late AnimationController _tailCtrl;
  bool _isYawning = false;
  bool _isBlinking = false;
  Timer? _yawnTimer;
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    _tailCtrl = AnimationController(
      duration: const Duration(milliseconds: 3200),
      vsync: this,
    );
    if (areUiAnimationsEnabled) {
      _tailCtrl.repeat();
      _scheduleNextYawn();
      _scheduleNextBlink();
    }
  }

  void _scheduleNextYawn() {
    final delay = 4500 + math.Random().nextInt(5500);
    _yawnTimer = Timer(Duration(milliseconds: delay), () {
      if (!mounted) return;
      setState(() => _isYawning = true);
      Future.delayed(const Duration(milliseconds: 1700), () {
        if (!mounted) return;
        setState(() => _isYawning = false);
        _scheduleNextYawn();
      });
    });
  }

  void _scheduleNextBlink() {
    final delay = 1800 + math.Random().nextInt(2800);
    _blinkTimer = Timer(Duration(milliseconds: delay), () {
      if (!mounted) return;
      setState(() => _isBlinking = true);
      Future.delayed(const Duration(milliseconds: 140), () {
        if (!mounted) return;
        setState(() => _isBlinking = false);
        _scheduleNextBlink();
      });
    });
  }

  @override
  void dispose() {
    _tailCtrl.dispose();
    _yawnTimer?.cancel();
    _blinkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '戳戳小猫',
      child: GestureDetector(
        onTap: widget.animating ? null : widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: AnimatedBuilder(
            animation: _tailCtrl,
            builder: (_, __) {
              return SizedBox(
                width: 200,
                height: 118,
                child: CustomPaint(
                  painter: _CatPainter(
                    tailPhase: _tailCtrl.value * 2 * math.pi,
                    isYawning: _isYawning,
                    isBlinking: _isBlinking,
                    loading: widget.animating,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CatPainter extends CustomPainter {
  final double tailPhase;
  final bool isYawning;
  final bool isBlinking;
  final bool loading;

  static const _inkColor = Color(0xFF3A3A48);

  _CatPainter({
    required this.tailPhase,
    required this.isYawning,
    required this.isBlinking,
    required this.loading,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final alert = loading;
    final tailSway = (alert ? 3.5 : 5.5) * math.sin(tailPhase);

    final ink = Paint()
      ..color = _inkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (alert) {
      final glow = Paint()
        ..color = AppTheme.oracleGold
            .withValues(alpha: 0.12 + 0.08 * math.sin(tailPhase * 2))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(28, 34, 148, 58),
          const Radius.circular(28),
        ),
        glow,
      );
    }

    // 尾巴（先画，在身体下层）
    final tail = Path()
      ..moveTo(158, 50)
      ..cubicTo(
        168, 42 + tailSway * 0.4,
        178, 24 + tailSway,
        186, 16 + tailSway * 1.4,
      );
    canvas.drawPath(tail, ink);

    // 身体：侧面「面包」轮廓，与头部自然衔接
    final body = Path()
      ..moveTo(66, 46)
      ..cubicTo(92, 34, 128, 34, 156, 46)
      ..cubicTo(166, 52, 166, 62, 158, 68)
      ..cubicTo(130, 80, 88, 82, 72, 78)
      ..cubicTo(64, 74, 62, 66, 66, 58)
      ..cubicTo(68, 52, 66, 46, 66, 46);
    canvas.drawPath(body, ink);

    // 头部
    canvas.drawCircle(const Offset(50, 56), 17, ink);

    // 耳朵（圆角三角，警觉时竖起）
    final earLift = alert ? -4.0 : 0.0;
    final backEar = Path()
      ..moveTo(40, 46 + earLift)
      ..quadraticBezierTo(34, 30 + earLift, 42, 40 + earLift)
      ..quadraticBezierTo(44, 44 + earLift, 40, 46 + earLift);
    canvas.drawPath(backEar, ink);

    final frontEar = Path()
      ..moveTo(54, 44 + earLift)
      ..quadraticBezierTo(60, 28 + earLift, 62, 42 + earLift)
      ..quadraticBezierTo(60, 46 + earLift, 54, 44 + earLift);
    canvas.drawPath(frontEar, ink);

    _drawEyes(canvas, ink, alert);
    _drawNoseAndMouth(canvas, ink);
    _drawWhiskers(canvas, ink);
    _drawPaws(canvas, ink);
  }

  void _drawEyes(Canvas canvas, Paint ink, bool alert) {
    const left = Offset(44, 54);
    const right = Offset(56, 54);

    if (isYawning) {
      for (final center in [left, right]) {
        canvas.drawArc(
          Rect.fromCenter(center: center, width: 8, height: 5),
          math.pi,
          math.pi,
          false,
          ink,
        );
      }
      return;
    }

    if (alert) {
      final fill = Paint()
        ..color = _inkColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(left, 3, fill);
      canvas.drawCircle(right, 3, fill);
      return;
    }

    if (isBlinking) {
      canvas.drawLine(
        Offset(left.dx - 3.5, left.dy),
        Offset(left.dx + 3.5, left.dy),
        ink,
      );
      canvas.drawLine(
        Offset(right.dx - 3.5, right.dy),
        Offset(right.dx + 3.5, right.dy),
        ink,
      );
      return;
    }

    for (final center in [left, right]) {
      canvas.drawArc(
        Rect.fromCenter(center: center, width: 7, height: 3.5),
        0.15,
        2.8,
        false,
        ink,
      );
    }
  }

  void _drawNoseAndMouth(Canvas canvas, Paint ink) {
    final fill = Paint()
      ..color = _inkColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(50, 60), 1.6, fill);

    if (isYawning) {
      final mouth = Path()
        ..moveTo(44, 63)
        ..quadraticBezierTo(50, 74, 56, 63);
      canvas.drawPath(mouth, ink);
      return;
    }

    final mouth = Path()
      ..moveTo(47, 64)
      ..quadraticBezierTo(50, 67, 53, 64);
    canvas.drawPath(mouth, ink);
  }

  void _drawWhiskers(Canvas canvas, Paint ink) {
    final whisker = Paint()
      ..color = _inkColor.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(const Offset(34, 58), const Offset(22, 55), whisker);
    canvas.drawLine(const Offset(34, 62), const Offset(22, 63), whisker);
    canvas.drawLine(const Offset(66, 58), const Offset(78, 55), whisker);
    canvas.drawLine(const Offset(66, 62), const Offset(78, 63), whisker);
  }

  void _drawPaws(Canvas canvas, Paint ink) {
    // 侧面只露两只前爪，简化成小弧线
    final frontPaw = Path()
      ..moveTo(78, 78)
      ..quadraticBezierTo(84, 86, 90, 78);
    canvas.drawPath(frontPaw, ink);

    final backPaw = Path()
      ..moveTo(96, 78)
      ..quadraticBezierTo(102, 85, 108, 78);
    canvas.drawPath(backPaw, ink);
  }

  @override
  bool shouldRepaint(_CatPainter oldDelegate) =>
      oldDelegate.tailPhase != tailPhase ||
      oldDelegate.isYawning != isYawning ||
      oldDelegate.isBlinking != isBlinking ||
      oldDelegate.loading != loading;
}
