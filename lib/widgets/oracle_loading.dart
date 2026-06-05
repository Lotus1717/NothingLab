import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/animations.dart';

import '../config/theme.dart';

/// 神谕生成中的仪式感加载动画
class OracleLoading extends StatefulWidget {
  final String? message;

  const OracleLoading({super.key, this.message});

  @override
  State<OracleLoading> createState() => _OracleLoadingState();
}

class _OracleLoadingState extends State<OracleLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (areUiAnimationsEnabled) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.rotate(
                    angle: _ctrl.value * 6.283,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.oracleGold.withValues(
                            alpha: 0.25 + 0.35 * _ctrl.value,
                          ),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: 0.5 + 0.5 * math.sin(_ctrl.value * 6.283),
                    child: const Text('✨', style: TextStyle(fontSize: 28)),
                  ),
                ],
              ),
            ),
            if (widget.message != null) ...[
              const SizedBox(height: 12),
              Text(
                widget.message!,
                textAlign: TextAlign.center,
                style: AppTheme.caption(context).copyWith(
                  color: AppTheme.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

}
