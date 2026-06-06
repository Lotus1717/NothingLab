import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../models/sensor_data.dart';
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
    final ai = context.read<AiService>();
    await ai.loadModel(
      onProgress: (p) {
        if (mounted) setState(() => _modelProgress = p);
      },
    );
    if (!mounted) return;
    setState(() => _loadingModel = false);
    if (!ai.modelLoaded && ai.lastLoadError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ai.lastLoadError!)),
      );
    } else if (ai.modelLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('千问小模型已唤醒')),
      );
    }
  }

  bool _engineReady(AiService ai) => ai.modelLoaded;

  bool _canWakeEngine(AiService ai) =>
      ai.isModelAvailable && !ai.modelLoaded;

  String _ambientLightStatus(SensorData sensor) {
    if (sensor.isRealAmbientLight) return '真实数据';
    if (sensor.isEstimatedAmbientLight) return '亮度推算';
    return '暂无数据';
  }

  String _engineStatusLabel(AiService ai) {
    if (_engineReady(ai)) return '已唤醒';
    if (_loadingModel) {
      return _modelProgress > 0 && _modelProgress < 1 ? '下载中…' : '唤醒中…';
    }
    if (ai.lastLoadError != null && _canWakeEngine(ai)) return '重试唤醒';
    if (_canWakeEngine(ai)) return '唤醒';
    return '不可用';
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        title: const Text('擦掉所有废话？'),
        content: const Text('历史记录将永久消失，此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
            ),
            child: const Text('确认擦掉'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<AiService>().clearHistory();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已全部擦掉')),
      );
    }
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
              const SizedBox(height: 12),
              Text('小设置', style: AppTheme.pageTitle(context)),
              const SizedBox(height: 20),
              const SectionHeader(title: '传感器状态'),
              _SettingRow(
                icon: Icons.battery_full_rounded,
                title: '电池',
                value: sensor.isRealBattery ? '真实数据' : '模拟数据',
                isReal: sensor.isRealBattery,
              ),
              _SettingRow(
                icon: Icons.sensors_rounded,
                title: '运动',
                value: sensor.isRealMotion ? '真实数据' : '模拟数据',
                isReal: sensor.isRealMotion,
              ),
              _SettingRow(
                icon: Icons.directions_walk_rounded,
                title: '步数',
                value: sensor.isRealSteps ? '真实数据' : '模拟数据',
                isReal: sensor.isRealSteps,
              ),
              _SettingRow(
                icon: Icons.volume_up_rounded,
                title: '系统音量',
                value: sensor.isRealVolume ? '真实数据' : '模拟数据',
                isReal: sensor.isRealVolume,
              ),
              _SettingRow(
                icon: Icons.wb_sunny_outlined,
                title: '环境亮度',
                value: _ambientLightStatus(sensor),
                isReal:
                    sensor.isRealAmbientLight || sensor.isEstimatedAmbientLight,
              ),
              if (ai.localAi.modelAvailable || ai.isModelAvailable) ...[
                const SectionHeader(title: '预言引擎'),
                _SettingRow(
                  icon: Icons.psychology_rounded,
                  title: 'AI 引擎',
                  value: _engineStatusLabel(ai),
                  isReal: _engineReady(ai),
                  onTap: _canWakeEngine(ai) && !_loadingModel
                      ? _loadModel
                      : null,
                ),
                if (_loadingModel) _ModelLoadProgress(progress: _modelProgress),
                if (!_loadingModel &&
                    ai.isModelAvailable &&
                    !ai.modelLoaded &&
                    ai.lastLoadError == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '首次唤醒从国内镜像下载约 200MB 千问模型，建议连接 Wi‑Fi',
                      style: AppTheme.caption(context).copyWith(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
              const SectionHeader(title: '数据'),
              _SettingRow(
                icon: Icons.delete_outline_rounded,
                title: '擦掉所有废话',
                value: '点击清空',
                isReal: false,
                danger: true,
                onTap: _confirmClearAll,
              ),
              const SizedBox(height: 28),
              Center(
                child: Text(
                  '废话预言家 v2.0\n使用本机小模型，数据不上传',
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
  final IconData icon;
  final String title;
  final String value;
  final bool isReal;
  final bool danger;
  final VoidCallback? onTap;

  const _SettingRow({
    required this.icon,
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
                Icon(icon,
                    size: 20,
                    color: danger ? AppTheme.danger : AppTheme.textMuted),
                const SizedBox(width: 10),
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

class _ModelLoadProgress extends StatelessWidget {
  final double progress;

  const _ModelLoadProgress({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress > 0 ? progress : null,
              minHeight: 6,
              backgroundColor: const Color(0xFFF0EBE6),
              valueColor: const AlwaysStoppedAnimation(AppTheme.primaryDark),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            progress >= 1
                ? '完成'
                : progress > 0
                    ? '下载中 ${(progress * 100).round()}%'
                    : '连接模型库…',
            textAlign: TextAlign.center,
            style: AppTheme.caption(context),
          ),
        ],
      ),
    );
  }
}
