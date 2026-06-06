import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';
import '../models/sensor_data.dart';
import '../utils/prophecy_image_share.dart';
import 'app_card.dart';
import 'prophecy_share_card.dart';

class ProphecyCard extends StatefulWidget {
  final String prophecy;
  final SensorData? sensor;
  final VoidCallback onRefresh;

  const ProphecyCard({
    super.key,
    required this.prophecy,
    this.sensor,
    required this.onRefresh,
  });

  @override
  State<ProphecyCard> createState() => _ProphecyCardState();
}

class _ProphecyCardState extends State<ProphecyCard>
    with SingleTickerProviderStateMixin {
  final GlobalKey _shareImageKey = GlobalKey();
  bool _sharing = false;

  late AnimationController _revealCtrl;
  late Animation<double> _fade;

  String _displayedText = '';
  Timer? _typeTimer;
  int _charIndex = 0;
  bool _typingDone = false;

  @override
  void initState() {
    super.initState();
    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fade = CurvedAnimation(parent: _revealCtrl, curve: Curves.easeOut);
    _revealCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_typingDone) {
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
        _typingDone = true;
        timer.cancel();
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(ProphecyCard old) {
    super.didUpdateWidget(old);
    if (old.prophecy != widget.prophecy) {
      _typeTimer?.cancel();
      _typingDone = false;
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

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正在生成分享图…'),
          duration: Duration(seconds: 1),
        ),
      );
    }

    try {
      await WidgetsBinding.instance.endOfFrame;
      await shareRepaintBoundaryAsImage(_shareImageKey);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.prophecy));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已复制到剪贴板')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -5000,
            child: RepaintBoundary(
              key: _shareImageKey,
              child: ProphecyShareCard(
                prophecy: widget.prophecy,
                sensor: widget.sensor,
              ),
            ),
          ),
          AppCard.oracle(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Text(
                    _displayedText,
                    textAlign: TextAlign.center,
                    style: AppTheme.prophecyBody(context),
                  ),
                ),
                if (_typingDone) ...[
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ActionButton(
                        icon: Icons.refresh_rounded,
                        label: '再来一条',
                        primary: true,
                        onPressed: widget.onRefresh,
                      ),
                      const SizedBox(width: 10),
                      _ActionButton(
                        icon: Icons.content_copy_rounded,
                        label: '复制',
                        primary: false,
                        onPressed: _copy,
                      ),
                      const SizedBox(width: 10),
                      _ActionButton(
                        icon: Icons.image_rounded,
                        label: _sharing ? '生成中' : '分享图',
                        primary: false,
                        onPressed: _sharing ? null : _share,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.primary,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            decoration: BoxDecoration(
              gradient: primary
                  ? const LinearGradient(
                      colors: [Color(0xFFFFB7B2), Color(0xFFFF8A7A)],
                    )
                  : null,
              color: primary ? null : const Color(0xFFF4F0EC),
              borderRadius: BorderRadius.circular(24),
              boxShadow: primary
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryDark.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      size: 16,
                      color: primary ? Colors.white : AppTheme.textDark),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: AppTheme.caption(context).copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: primary ? Colors.white : AppTheme.textDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
