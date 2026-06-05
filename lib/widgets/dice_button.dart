import 'package:flutter/material.dart';

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
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    _anim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.linear));
  }

  @override
  void didUpdateWidget(DiceButton old) {
    super.didUpdateWidget(old);
    if (widget.loading && !old.loading) {
      _ctrl.repeat();
    } else if (!widget.loading && old.loading) {
      _ctrl.stop();
      _ctrl.reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.loading ? null : widget.onPressed,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Transform.rotate(
          angle: widget.loading ? _anim.value * 6.2832 : 0,
          child: Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFD3B5), Color(0xFFFFB7B2)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFB7B2).withValues(alpha: 0.45),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Center(
              child: Text('🎲', style: TextStyle(fontSize: 52)),
            ),
          ),
        ),
      ),
    );
  }
}
