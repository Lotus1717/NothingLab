import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../services/ai_service.dart';
import '../services/sensor_service.dart';
import '../widgets/dice_button.dart';
import '../widgets/oracle_background.dart';
import '../widgets/oracle_loading.dart';
import '../widgets/prophecy_card.dart';
import '../widgets/sensor_card.dart';
import '../widgets/status_chip.dart';

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
        final hasProphecy =
            aiSvc.currentProphecy.isNotEmpty && !aiSvc.loading;

        return OracleBackground(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _HomeHero(aiSvc: aiSvc, onRefreshSensors: () => sensorSvc.init()),
                  const SizedBox(height: 16),
                  SensorCard(sensor: s),
                  const SizedBox(height: 28),
                  if (hasProphecy)
                    ProphecyCard(
                      prophecy: aiSvc.currentProphecy,
                      onRefresh: _onDicePressed,
                    )
                  else
                    Center(
                      child: Column(
                        children: [
                          DiceButton(
                            pressed: _dicePressed,
                            loading: aiSvc.loading,
                            onPressed: _onDicePressed,
                          ),
                          const SizedBox(height: 14),
                          if (aiSvc.loading)
                            OracleLoading(
                              message: aiSvc.getLoadingText(_loadingStep),
                            )
                          else
                            Text(
                              '戳一下，听句废话',
                              style: AppTheme.caption(context).copyWith(
                                fontSize: 14,
                                color: AppTheme.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HomeHero extends StatelessWidget {
  final AiService aiSvc;
  final VoidCallback onRefreshSensors;

  const _HomeHero({
    required this.aiSvc,
    required this.onRefreshSensors,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.oracleGoldLight,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.auto_awesome_rounded,
              size: 24, color: AppTheme.oracleGold),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('废话预言家', style: AppTheme.displayTitle(context)),
              const SizedBox(height: 4),
              Text(
                '读取传感器，生成今日废话',
                style: AppTheme.caption(context).copyWith(
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (aiSvc.localAi.modelAvailable ||
            aiSvc.isModelAvailable)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: StatusChip(
              label: aiSvc.localAi.modelAvailable
                  ? 'AI'
                  : aiSvc.modelLoaded
                      ? 'MLX'
                      : '本地',
              icon: aiSvc.localAi.modelAvailable
                  ? Icons.auto_awesome_rounded
                  : aiSvc.modelLoaded
                      ? Icons.memory_rounded
                      : Icons.cloud_off_rounded,
              active: aiSvc.localAi.modelAvailable || aiSvc.modelLoaded,
              activeColor: AppTheme.secondary,
            ),
          ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 24),
          onPressed: onRefreshSensors,
          color: AppTheme.textMuted,
          tooltip: '刷新传感器',
        ),
      ],
    );
  }
}
