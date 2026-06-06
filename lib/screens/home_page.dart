import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../services/ai_service.dart';
import '../services/sensor_service.dart';
import '../widgets/lazy_cat.dart';
import '../widgets/oracle_background.dart';
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
    final ai = context.read<AiService>();
    if (_dicePressed || ai.loading) return;
    setState(() => _dicePressed = true);
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
        final hasProphecy = aiSvc.currentProphecy.isNotEmpty;
        final hintText = aiSvc.loading
            ? aiSvc.getLoadingText(_loadingStep)
            : hasProphecy
                ? '再戳小猫，换一句废话'
                : '戳戳小猫，听句废话';

        return OracleBackground(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _HomeHero(
                    aiSvc: aiSvc,
                    onRefreshSensors: () => sensorSvc.init(),
                  ),
                  const SizedBox(height: 16),
                  SensorCard(sensor: s),
                  const SizedBox(height: 24),
                  Center(
                    child: Column(
                      children: [
                        LazyCat(
                          animating: aiSvc.loading,
                          onTap: _onDicePressed,
                        ),
                        const SizedBox(height: 10),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: Text(
                            hintText,
                            key: ValueKey(hintText),
                            textAlign: TextAlign.center,
                            style: AppTheme.caption(context).copyWith(
                              fontSize: 14,
                              color: AppTheme.textMuted,
                              fontStyle: aiSvc.loading
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasProphecy && !aiSvc.loading) ...[
                    const SizedBox(height: 20),
                    ProphecyCard(
                      prophecy: aiSvc.currentProphecy,
                      sensor: s,
                      onRefresh: _onDicePressed,
                    ),
                  ],
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

  IconData _engineIcon(ProphecyEngine engine) => switch (engine) {
        ProphecyEngine.qwen => Icons.memory_rounded,
        ProphecyEngine.localAi => Icons.auto_awesome_rounded,
        ProphecyEngine.template => Icons.library_books_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final engine = aiSvc.displayEngine;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text('废话预言家', style: AppTheme.displayTitle(context)),
        ),
        StatusChip(
          label: engine.label,
          icon: _engineIcon(engine),
          active: engine != ProphecyEngine.template,
          activeColor: AppTheme.secondary,
        ),
        const SizedBox(width: 4),
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
