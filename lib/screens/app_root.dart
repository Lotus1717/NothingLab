import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/ai_service.dart';
import '../services/onboarding_service.dart';
import '../utils/animations.dart';
import '../widgets/app_splash.dart';
import 'main_screen.dart';
import 'onboarding_page.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with SingleTickerProviderStateMixin {
  bool _splashVisible = !kIsWeb;
  bool _showOnboarding = false;
  bool _ready = kIsWeb;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(context.read<AiService>().checkModelAvailability());
      }
    });
    if (_splashVisible) {
      _dismissSplash();
    } else {
      unawaited(_checkOnboarding());
    }
  }

  Future<void> _checkOnboarding() async {
    final completed = await OnboardingService.isCompleted();
    if (!mounted) return;
    setState(() {
      _showOnboarding = !completed;
      _ready = true;
    });
  }

  Future<void> _dismissSplash() async {
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (!mounted || !_splashVisible) return;
    if (areUiAnimationsEnabled) {
      await _fadeCtrl.forward();
    }
    if (!mounted) return;
    final completed = await OnboardingService.isCompleted();
    if (!mounted) return;
    setState(() {
      _splashVisible = false;
      _showOnboarding = !completed;
      _ready = true;
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const AppSplash();
    }

    if (_showOnboarding) {
      return OnboardingPage(
        onComplete: () => setState(() => _showOnboarding = false),
      );
    }

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
