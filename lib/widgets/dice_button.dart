import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../utils/animations.dart';

class DiceButton extends StatefulWidget {
  final bool pressed;
  final bool loading;
  final VoidCallback onPressed;

  const DiceButton({
    super.key,
    required this.pressed,
    required this.loading,
    required this.onPressed,
  });

  @override
  State<DiceButton> createState() => _DiceButtonState();
}

class _DiceButtonState extends State<DiceButton>
    with TickerProviderStateMixin {
  late AnimationController _spinCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _pressCtrl;
  late Animation<double> _spinAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _scaleAnim;

  static const double _size = 120;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _spinAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _spinCtrl, curve: Curves.linear),
    );

    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
      value: 1,
    );
    if (areUiAnimationsEnabled) {
      _pulseCtrl.repeat(reverse: true);
    }
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _pressCtrl = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 1, end: 0.92).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(DiceButton old) {
    super.didUpdateWidget(old);
    if (widget.loading && !old.loading) {
      _spinCtrl.repeat();
      _pulseCtrl.stop();
    } else if (!widget.loading && old.loading) {
      _spinCtrl.stop();
      _spinCtrl.reset();
      if (areUiAnimationsEnabled && !_pulseCtrl.isAnimating) {
        _pulseCtrl.repeat(reverse: true);
      }
    }
    if (widget.pressed && !old.pressed) {
      _pressCtrl.forward();
    } else if (!widget.pressed && old.pressed) {
      _pressCtrl.reverse();
    }
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _pulseCtrl.dispose();
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !widget.loading;

    return Semantics(
      button: true,
      label: '骰子按钮',
      child: GestureDetector(
        onTapDown: enabled ? (_) => _pressCtrl.forward() : null,
        onTapUp: enabled ? (_) => _pressCtrl.reverse() : null,
        onTapCancel: enabled ? () => _pressCtrl.reverse() : null,
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedBuilder(
          animation: Listenable.merge([_spinAnim, _pulseAnim, _scaleAnim]),
          builder: (_, __) {
            final pulse = widget.loading ? 1.0 : _pulseAnim.value;
            final scale = _scaleAnim.value;
            return Transform.scale(
              scale: scale,
              child: Transform.rotate(
                angle: widget.loading ? _spinAnim.value * 6.2832 : 0,
                child: Container(
                  width: _size,
                  height: _size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFE4D6),
                        Color(0xFFFFB7B2),
                        Color(0xFFFF8A7A),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryDark
                            .withValues(alpha: 0.35 * pulse),
                        blurRadius: 32 * pulse,
                        spreadRadius: 2,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: AppTheme.oracleGold
                            .withValues(alpha: 0.2 * pulse),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Text('🎲', style: TextStyle(fontSize: 56)),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
