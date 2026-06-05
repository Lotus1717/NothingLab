import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../services/ai_service.dart';
import '../widgets/oracle_background.dart';
import '../widgets/oracle_loading.dart';
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
      return Scaffold(
        body: OracleBackground(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.oracleGoldLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.auto_awesome_rounded,
                      size: 36, color: AppTheme.oracleGold),
                ),
                const SizedBox(height: 16),
                Text(
                  '废话预言家',
                  style: AppTheme.displayTitle(context),
                ),
                const SizedBox(height: 24),
                const OracleLoading(message: '唤醒神谕引擎…'),
              ],
            ),
          ),
        ),
      );
    }

    return const MainScreen();
  }
}
