import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../services/ai_service.dart';
import '../services/sensor_service.dart';
import '../widgets/app_card.dart';
import '../widgets/oracle_background.dart';
import '../widgets/section_header.dart';
import '../widgets/status_chip.dart';

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

    return OracleBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text('⚙️ 小设置', style: AppTheme.pageTitle(context)),
              const SizedBox(height: 8),
              Text(
                '传感器与神谕引擎',
                style: AppTheme.caption(context),
              ),
              const SizedBox(height: 20),
              const SectionHeader(title: '传感器状态'),
              _SettingRow(
                title: '🔋 电池',
                value: sensor.isRealBattery ? '真实数据' : '模拟数据',
                isReal: sensor.isRealBattery,
              ),
              _SettingRow(
                title: '📳 运动',
                value: sensor.isRealMotion ? '真实数据' : '模拟数据',
                isReal: sensor.isRealMotion,
              ),
              _SettingRow(
                title: '🦶 步数',
                value: sensor.isRealSteps ? '真实数据' : '模拟数据',
                isReal: sensor.isRealSteps,
              ),
              const SectionHeader(title: '预言引擎'),
              _SettingRow(
                title: '🧠 AI 引擎',
                value: ai.localAi.modelAvailable
                    ? 'AI 已就绪 🧠'
                    : ai.isModelAvailable
                        ? (ai.modelLoaded ? 'MLX 模型' : '可用，未加载')
                        : '本地回退模式',
                isReal: ai.localAi.modelAvailable ||
                    (ai.isModelAvailable && ai.modelLoaded),
              ),
              if (!ai.localAi.modelAvailable &&
                  ai.isModelAvailable &&
                  !ai.modelLoaded)
                _ModelLoadSection(
                  loading: _loadingModel,
                  progress: _modelProgress,
                  onLoad: _loadModel,
                ),
              const SectionHeader(title: '数据'),
              _SettingRow(
                title: '🗑️ 擦掉所有废话',
                value: '点击清空',
                isReal: false,
                danger: true,
                onTap: () {
                  context.read<AiService>().clearHistory();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已全部擦掉')),
                  );
                },
              ),
              const SizedBox(height: 28),
              Center(
                child: Text(
                  '废话预言家 v2.0\n基于传感器数据 + 本地 MLX 模型',
                  textAlign: TextAlign.center,
                  style: AppTheme.caption(context),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String title;
  final String value;
  final bool isReal;
  final bool danger;
  final VoidCallback? onTap;

  const _SettingRow({
    required this.title,
    required this.value,
    required this.isReal,
    this.danger = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppTheme.bodyMedium(context).copyWith(
                      fontWeight: FontWeight.w600,
                      color: danger ? AppTheme.danger : AppTheme.textDark,
                    ),
                  ),
                ),
                StatusChip(
                  label: value,
                  active: isReal && !danger,
                  activeColor: danger ? AppTheme.danger : AppTheme.secondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModelLoadSection extends StatelessWidget {
  final bool loading;
  final double progress;
  final VoidCallback onLoad;

  const _ModelLoadSection({
    required this.loading,
    required this.progress,
    required this.onLoad,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: loading ? null : onLoad,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryDark,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppTheme.primary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                elevation: 0,
              ),
              child: Text(
                loading ? '📥 加载中…' : '📥 加载 AI 模型',
                style: AppTheme.bodyMedium(context).copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (loading) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress > 0 ? progress : null,
                minHeight: 6,
                backgroundColor: const Color(0xFFF0EBE6),
                valueColor:
                    const AlwaysStoppedAnimation(AppTheme.primaryDark),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              progress > 0
                  ? '${(progress * 100).round()}%'
                  : '准备中…',
              textAlign: TextAlign.center,
              style: AppTheme.caption(context),
            ),
          ],
        ],
      ),
    );
  }
}
