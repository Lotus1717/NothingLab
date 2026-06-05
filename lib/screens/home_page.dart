import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../services/ai_service.dart';
import '../services/sensor_service.dart';
import '../widgets/dice_button.dart';
import '../widgets/prophecy_card.dart';
import '../widgets/sensor_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _dicePressed = false;
  int _loadingStep = 0;
  Timer? _loadingTimer;

  void _onDicePressed() async {
    if (_dicePressed) return;
    setState(() => _dicePressed = true);
    final ai = context.read<AiService>();
    final sensor = context.read<SensorService>().data;
    int step = 0;
    _loadingTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (!mounted || !ai.loading) {
        _loadingTimer?.cancel();
        return;
      }
      setState(() => _loadingStep = step++);
    });
    await ai.generateProphecy(sensor);
    _loadingTimer?.cancel();
    if (mounted) setState(() => _dicePressed = false);
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SensorService, AiService>(
      builder: (context, sensorSvc, aiSvc, _) {
        final s = sensorSvc.data;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Text('🐣', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 8),
                    const Text(
                      '废话预言家',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const Spacer(),
                    if (aiSvc.localAi.modelAvailable || aiSvc.isModelAvailable)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (aiSvc.localAi.modelAvailable ||
                                  aiSvc.modelLoaded)
                              ? AppTheme.secondary.withValues(alpha: 0.2)
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          aiSvc.localAi.modelAvailable
                              ? '🧠 AI'
                              : aiSvc.modelLoaded
                                  ? '🧠 MLX'
                                  : '📡 本地',
                          style: TextStyle(
                            fontSize: 11,
                            color: (aiSvc.localAi.modelAvailable ||
                                    aiSvc.modelLoaded)
                                ? AppTheme.textDark
                                : AppTheme.textLight,
                          ),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 24),
                      onPressed: () => sensorSvc.init(),
                      color: AppTheme.textLight,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SensorCard(sensor: s),
                const SizedBox(height: 24),
                Center(
                  child: Column(
                    children: [
                      DiceButton(
                        pressed: _dicePressed,
                        loading: aiSvc.loading,
                        onPressed: _onDicePressed,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        aiSvc.loading
                            ? aiSvc.getLoadingText(_loadingStep)
                            : '[ 戳一下 ]',
                        style: const TextStyle(
                            fontSize: 15, color: AppTheme.textLight),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (aiSvc.currentProphecy.isNotEmpty && !aiSvc.loading)
                  ProphecyCard(
                    prophecy: aiSvc.currentProphecy,
                    onRefresh: _onDicePressed,
                  ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    '⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯⋯',
                    style: TextStyle(
                      color: Color(0xFFDDDDDD),
                      fontSize: 13,
                      letterSpacing: 3,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}
