import 'package:flutter/material.dart';

import '../config/theme.dart';
import 'app_card.dart';

class ProphecyCard extends StatelessWidget {
  final String prophecy;
  final VoidCallback onRefresh;

  const ProphecyCard({
    super.key,
    required this.prophecy,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Transform.scale(
        scale: 0.92 + 0.08 * v,
        child: Opacity(opacity: v, child: child),
      ),
      child: AppCard(
        padding: const EdgeInsets.all(24),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primary, width: 2),
        child: Column(children: [
          Text(
            '"$prophecy"',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              color: AppTheme.textDark,
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _btn('🔄 再来一条', onRefresh, primary: true),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _btn(String text, VoidCallback onPressed, {bool primary = false}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: primary ? AppTheme.primary : const Color(0xFFF4F4F4),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: primary ? Colors.white : AppTheme.textDark,
          ),
        ),
      ),
    );
  }
}
