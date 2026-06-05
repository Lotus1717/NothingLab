import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../services/ai_service.dart';
import '../services/sensor_service.dart';
import '../widgets/app_card.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _loadingModel = false;
  double _modelProgress = 0;

  Future<void> _loadModel() async {
    setState(() {
      _loadingModel = true;
      _modelProgress = 0;
    });
    await context.read<AiService>().loadModel(
      onProgress: (p) {
        if (mounted) setState(() => _modelProgress = p);
      },
    );
    if (mounted) setState(() => _loadingModel = false);
  }

  @override
  Widget build(BuildContext context) {
    final sensor = context.watch<SensorService>().data;
    final ai = context.watch<AiService>();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 18),
            const Text(
              '⚙️ 小设置',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 16),
            _settingCard('🔋 电池', sensor.isRealBattery ? '真实数据' : '模拟数据',
                sensor.isRealBattery),
            _settingCard('📳 运动', sensor.isRealMotion ? '真实数据' : '模拟数据',
                sensor.isRealMotion),
            _settingCard('🦶 步数', sensor.isRealSteps ? '真实数据' : '模拟数据',
                sensor.isRealSteps),
            _settingCard(
              '🧠 AI 引擎',
              ai.localAi.modelAvailable
                  ? 'AI 已就绪 🧠'
                  : ai.isModelAvailable
                      ? (ai.modelLoaded ? 'MLX 模型' : '可用，未加载')
                      : '本地回退模式',
              ai.localAi.modelAvailable ||
                  (ai.isModelAvailable && ai.modelLoaded),
            ),
            if (!ai.localAi.modelAvailable &&
                ai.isModelAvailable &&
                !ai.modelLoaded)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _loadingModel ? null : _loadModel,
                        style: TextButton.styleFrom(
                          backgroundColor:
                              AppTheme.primary.withValues(alpha: 0.1),
                          foregroundColor: AppTheme.primaryDark,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          _loadingModel ? '📥 加载中…' : '📥 加载 AI 模型',
                        ),
                      ),
                    ),
                    if (_loadingModel) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _modelProgress > 0 ? _modelProgress : null,
                          minHeight: 6,
                          backgroundColor: const Color(0xFFF0F0F0),
                          valueColor:
                              const AlwaysStoppedAnimation(AppTheme.primary),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            _settingCard('🗑️ 擦掉所有废话', '点击清空', false,
                danger: true,
                onTap: () => context.read<AiService>().clearHistory()),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                '废话预言家 v2.0\n基于传感器数据 + 本地 MLX 模型',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textLight),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _settingCard(String title, String value, bool isReal,
      {bool danger = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppCard(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: danger ? Colors.red : AppTheme.textDark,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isReal ? AppTheme.bgMint : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    color: isReal ? AppTheme.secondary : AppTheme.textLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
