import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_version.dart';
import '../config/theme.dart';
import '../models/sensor_data.dart';
import '../services/ai_service.dart';
import '../services/analytics_service.dart';
import '../services/notification_service.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<AiService>().syncModelState();
    });
  }

  Future<void> _pickReminderTime(NotificationService notifications) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: notifications.hour, minute: notifications.minute),
      helpText: '选择每日提醒时间',
    );
    if (picked != null && mounted) {
      await notifications.setTime(hour: picked.hour, minute: picked.minute);
    }
  }

  Future<void> _toggleDailyReminder(
    NotificationService notifications,
    bool enabled,
  ) async {
    if (!notifications.isSupported) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前平台暂不支持本地推送')),
      );
      return;
    }

    final previous = notifications.enabled;
    await notifications.setEnabled(enabled);
    if (!mounted) return;

    if (enabled && !notifications.enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('需要通知权限才能开启每日提醒')),
      );
      return;
    }

    if (notifications.enabled != previous) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            notifications.enabled
                ? '每日 ${notifications.timeLabel} 会提醒你戳小猫'
                : '每日提醒已关闭',
          ),
        ),
      );
    }
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        title: const Text('清空所有收藏？'),
        content: const Text('收藏的废话将永久消失，此操作不可撤销。'),
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
      context.read<AiService>().clearFavorites();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('收藏已清空')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sensor = context.watch<SensorService>().data;
    final notifications = context.watch<NotificationService>();
    final analytics = context.watch<AnalyticsService>();

    return OracleBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text('设置', style: AppTheme.pageTitle(context)),
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
              const SectionHeader(title: '每日提醒'),
              _SettingRow(
                icon: Icons.notifications_outlined,
                title: '每日提醒',
                value: notifications.enabled ? '已开启' : '已关闭',
                isReal: notifications.enabled,
                onTap: notifications.isSupported
                    ? () => _toggleDailyReminder(
                          notifications,
                          !notifications.enabled,
                        )
                    : null,
              ),
              if (notifications.enabled && notifications.isSupported)
                _SettingRow(
                  icon: Icons.schedule_rounded,
                  title: '提醒时间',
                  value: notifications.timeLabel,
                  isReal: true,
                  onTap: () => _pickReminderTime(notifications),
                ),
              const SectionHeader(title: '数据'),
              _SettingRow(
                icon: Icons.delete_outline_rounded,
                title: '清空收藏',
                value: '点击清空',
                isReal: false,
                danger: true,
                onTap: _confirmClearAll,
              ),
              const SizedBox(height: 28),
              Center(
                child: Text(
                  '废话预言家 v$appVersion',
                  textAlign: TextAlign.center,
                  style: AppTheme.caption(context),
                ),
              ),
              if (analytics.isLoaded) ...[
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    '累计生成 ${analytics.prophecyGeneratedCount} 次 · 收藏率 ${analytics.favoriteRatePercent}%',
                    textAlign: TextAlign.center,
                    style: AppTheme.caption(context).copyWith(
                      fontSize: 11,
                      color: AppTheme.textMuted.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _ambientLightStatus(SensorData sensor) {
    if (sensor.isRealAmbientLight) return '真实数据';
    if (sensor.isEstimatedAmbientLight) return '亮度推算';
    return '暂无数据';
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
