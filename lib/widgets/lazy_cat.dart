import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../utils/animations.dart';

/// 几笔勾勒的慵懒线条小猫。
///
/// 背对着趴睡的小团子，只露耳朵和尾巴；尾巴慢慢摇，耳朵偶尔动动。
/// 加载（生成预言）时耳朵竖起、身后泛起淡金光。
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
  late AnimationController _earCtrl;
  int _twitchEar = 0;
  Timer? _earTwitchTimer;

  @override
  void initState() {
    super.initState();
    _tailCtrl = AnimationController(
      duration: const Duration(milliseconds: 3200),
      vsync: this,
    );
    _earCtrl = AnimationController(
      duration: const Duration(milliseconds: 2800),
      vsync: this,
    );
    if (areUiAnimationsEnabled) {
      _tailCtrl.repeat();
      _earCtrl.repeat();
      _scheduleEarTwitch();
    }
  }

  void _scheduleEarTwitch() {
    final delay = 2200 + math.Random().nextInt(4200);
    _earTwitchTimer = Timer(Duration(milliseconds: delay), () {
      if (!mounted) return;
      setState(() => _twitchEar = 1 + math.Random().nextInt(2));
      Future.delayed(const Duration(milliseconds: 320), () {
        if (!mounted) return;
        setState(() => _twitchEar = 0);
        _scheduleEarTwitch();
      });
    });
  }

  @override
  void dispose() {
    _tailCtrl.dispose();
    _earCtrl.dispose();
    _earTwitchTimer?.cancel();
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
            animation: Listenable.merge([_tailCtrl, _earCtrl]),
            builder: (_, __) {
              return SizedBox(
                width: 200,
                height: 118,
                child: CustomPaint(
                  painter: _CatPainter(
                    tailPhase: _tailCtrl.value * 2 * math.pi,
                    earPhase: _earCtrl.value * 2 * math.pi,
                    twitchEar: _twitchEar,
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
  final double earPhase;
  final int twitchEar;
  final bool loading;

  static const _inkColor = Color(0xFF3A3A48);

  _CatPainter({
    required this.tailPhase,
    required this.earPhase,
    required this.twitchEar,
    required this.loading,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final alert = loading;
    final tailSway = (alert ? 3.5 : 5.0) * math.sin(tailPhase);
    final earSway = math.sin(earPhase) * (alert ? 0.8 : 1.4);

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
          const Rect.fromLTWH(22, 28, 152, 60),
          const Radius.circular(30),
        ),
        glow,
      );
    }

    _drawTail(canvas, ink, tailSway);
    _drawBody(canvas, ink);
    _drawEars(canvas, ink, alert, earSway);
    _drawPaws(canvas, ink);
  }

  void _drawTail(Canvas canvas, Paint ink, double tailSway) {
    final stem = Path()
      ..moveTo(154, 52)
      ..cubicTo(
        165, 45 + tailSway * 0.3,
        174, 28 + tailSway * 0.85,
        180, 17 + tailSway,
      );
    canvas.drawPath(stem, ink);

    final hook = Path()
      ..moveTo(180, 17 + tailSway)
      ..cubicTo(
        189 + tailSway * 0.35,
        9 + tailSway * 1.15,
        186 + tailSway * 0.2,
        20 + tailSway * 0.75,
        181,
        23 + tailSway * 0.55,
      );
    canvas.drawPath(hook, ink..strokeWidth = 1.85);
    ink.strokeWidth = 2.0;
  }

  /// 背对趴睡的团子轮廓，背部弧线是造型记忆点。
  void _drawBody(Canvas canvas, Paint ink) {
    final loaf = Path()
      ..moveTo(34, 64)
      ..quadraticBezierTo(24, 58, 26, 48)
      ..quadraticBezierTo(28, 34, 40, 30)
      ..quadraticBezierTo(52, 26, 62, 32)
      ..cubicTo(78, 24, 112, 20, 144, 34)
      ..cubicTo(160, 42, 162, 54, 156, 62)
      ..cubicTo(126, 78, 78, 82, 56, 76)
      ..quadraticBezierTo(42, 72, 34, 64);
    canvas.drawPath(loaf, ink);

    final spine = Paint()
      ..color = _inkColor.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      const Rect.fromLTWH(52, 30, 88, 36),
      2.95,
      0.75,
      false,
      spine,
    );
  }

  void _drawEars(Canvas canvas, Paint ink, bool alert, double earSway) {
    // 耳根始终贴在头部轮廓上，戳戳时只竖起耳尖，避免整体上移脱节。
    const leftBase = Offset(36, 33);
    const rightBase = Offset(48, 31);
    const leftFold = Offset(38, 32);
    const rightFold = Offset(52, 31);

    final leftTwitch = !alert && twitchEar == 1 ? -4.0 : 0.0;
    final rightTwitch = !alert && twitchEar == 2 ? 4.0 : 0.0;

    final leftTip = Offset(
      (alert ? 25 : 22) + leftTwitch,
      (alert ? 10 : 12) + earSway,
    );
    final rightTip = Offset(
      (alert ? 57 : 56) + rightTwitch,
      (alert ? 7 : 9) - earSway,
    );
    final leftMid = Offset(34 + leftTwitch * 0.25, alert ? 27 : 28);
    final rightMid = Offset(58 + rightTwitch * 0.25, alert ? 26 : 27);

    final leftEar = Path()
      ..moveTo(leftBase.dx, leftBase.dy)
      ..quadraticBezierTo(leftTip.dx, leftTip.dy, leftMid.dx, leftMid.dy)
      ..quadraticBezierTo(leftFold.dx, leftFold.dy, leftBase.dx, leftBase.dy);
    canvas.drawPath(leftEar, ink);

    final rightEar = Path()
      ..moveTo(rightBase.dx, rightBase.dy)
      ..quadraticBezierTo(rightTip.dx, rightTip.dy, rightMid.dx, rightMid.dy)
      ..quadraticBezierTo(rightFold.dx, rightFold.dy, rightBase.dx, rightBase.dy);
    canvas.drawPath(rightEar, ink);
  }

  void _drawPaws(Canvas canvas, Paint ink) {
    final frontPaw = Path()
      ..moveTo(66, 77)
      ..quadraticBezierTo(72, 85, 78, 77);
    canvas.drawPath(frontPaw, ink);

    final backPaw = Path()
      ..moveTo(84, 77)
      ..quadraticBezierTo(90, 84, 96, 77);
    canvas.drawPath(backPaw, ink);
  }

  @override
  bool shouldRepaint(_CatPainter oldDelegate) =>
      oldDelegate.tailPhase != tailPhase ||
      oldDelegate.earPhase != earPhase ||
      oldDelegate.twitchEar != twitchEar ||
      oldDelegate.loading != loading;
}

/// 分享图用的静态趴睡小猫（无动画）。
class ShareLazyCat extends StatelessWidget {
  final double width;
  final double height;

  const ShareLazyCat({
    super.key,
    this.width = 168,
    this.height = 99,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _CatPainter(
          tailPhase: 1.1,
          earPhase: 0.6,
          twitchEar: 0,
          loading: false,
        ),
      ),
    );
  }
}
