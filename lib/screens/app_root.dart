import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/ai_service.dart';
import 'main_screen.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool _checkingModel = true;

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  Future<void> _initModel() async {
    final ai = context.read<AiService>();
    await ai.checkModelAvailability();

    if (mounted) {
      setState(() => _checkingModel = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingModel) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return const MainScreen();
  }
}
