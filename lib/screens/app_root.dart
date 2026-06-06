import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/ai_service.dart';
import '../utils/animations.dart';
import '../widgets/app_splash.dart';
import 'main_screen.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with SingleTickerProviderStateMixin {
  bool _splashVisible = !kIsWeb;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    context.read<AiService>().checkModelAvailability();
    if (_splashVisible) {
      _dismissSplash();
    }
  }

  Future<void> _dismissSplash() async {
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (!mounted || !_splashVisible) return;
    if (areUiAnimationsEnabled) {
      await _fadeCtrl.forward();
    }
    if (!mounted) return;
    setState(() => _splashVisible = false);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const MainScreen(),
        if (_splashVisible)
          FadeTransition(
            opacity: Tween<double>(begin: 1, end: 0).animate(_fadeAnim),
            child: const AppSplash(),
          ),
      ],
    );
  }
}
