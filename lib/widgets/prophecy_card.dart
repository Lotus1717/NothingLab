import 'dart:async';

import 'package:flutter/material.dart';

import '../config/theme.dart';
import 'app_card.dart';

class ProphecyCard extends StatefulWidget {
  final String prophecy;
  final VoidCallback onRefresh;

  const ProphecyCard({
    super.key,
    required this.prophecy,
    required this.onRefresh,
  });

  @override
  State<ProphecyCard> createState() => _ProphecyCardState();
}

class _ProphecyCardState extends State<ProphecyCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _revealCtrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  String _displayedText = '';
  Timer? _typeTimer;
  int _charIndex = 0;
  bool _cardVisible = false;

  @override
  void initState() {
    super.initState();
    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _revealCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _revealCtrl, curve: Curves.easeOutCubic));

    _revealCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_cardVisible) {
        _cardVisible = true;
        _startTyping();
      }
    });
    _revealCtrl.forward();
  }

  void _startTyping() {
    _typeTimer?.cancel();
    _charIndex = 0;
    _displayedText = '';

    final text = widget.prophecy;
    const typingSpeed = Duration(milliseconds: 30);

    _typeTimer = Timer.periodic(typingSpeed, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_charIndex < text.length) {
        _charIndex++;
        setState(() => _displayedText = text.substring(0, _charIndex));
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void didUpdateWidget(ProphecyCard old) {
    super.didUpdateWidget(old);
    if (old.prophecy != widget.prophecy) {
      _typeTimer?.cancel();
      _cardVisible = false;
      _displayedText = '';
      _charIndex = 0;
      _revealCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _revealCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: AppCard.oracle(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            children: [
              Text(
                '「',
                style: AppTheme.displayTitle(context).copyWith(
                  fontSize: 36,
                  color: AppTheme.oracleGold.withValues(alpha: 0.7),
                  height: 0.6,
                ),
              ),
              Text(
                _displayedText,
                textAlign: TextAlign.center,
                style: AppTheme.prophecyBody(context),
              ),
              if (_charIndex >= widget.prophecy.length)
                Text(
                  '」',
                  style: AppTheme.displayTitle(context).copyWith(
                    fontSize: 36,
                    color: AppTheme.oracleGold.withValues(alpha: 0.7),
                    height: 0.6,
                  ),
                ),
              const SizedBox(height: 12),
              if (_charIndex >= widget.prophecy.length)
                _OracleButton(
                  label: '🔄 再来一条',
                  primary: true,
                  onPressed: widget.onRefresh,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OracleButton extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onPressed;

  const _OracleButton({
    required this.label,
    required this.primary,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(30),
        child: Ink(
          decoration: BoxDecoration(
            gradient: primary
                ? const LinearGradient(
                    colors: [Color(0xFFFFB7B2), Color(0xFFFF8A7A)],
                  )
                : null,
            color: primary ? null : const Color(0xFFF4F0EC),
            borderRadius: BorderRadius.circular(30),
            boxShadow: primary
                ? [
                    BoxShadow(
                      color: AppTheme.primaryDark.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            child: Text(
              label,
              style: AppTheme.bodyMedium(context).copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: primary ? Colors.white : AppTheme.textDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
