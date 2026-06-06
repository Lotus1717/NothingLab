import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/preferred_engine.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ai = context.read<AiService>();
      await ai.syncModelState();
      if (!mounted) return;
      await _ensureQwenLoadedIfNeeded(ai);
    });
  }

  Future<void> _ensureQwenLoadedIfNeeded(AiService ai) async {
    if (ai.preferredEngine != PreferredEngine.qwen ||
        ai.modelLoaded ||
        !ai.mlxPlatformSupported) {
      return;
    }
    await _loadQwenModel(ai);
  }

  Future<void> _loadQwenModel(AiService ai) async {
    if (_loadingModel || ai.modelLoaded) return;

    setState(() {
      _loadingModel = true;
      _modelProgress = 0;
    });

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
    }
  }

  IconData _engineIcon(PreferredEngine engine) => switch (engine) {
        PreferredEngine.apple => Icons.apple_rounded,
        PreferredEngine.qwen => Icons.memory_rounded,
        PreferredEngine.deepseek => Icons.cloud_outlined,
        PreferredEngine.template => Icons.library_books_outlined,
      };

  String _engineOptionSubtitle(AiService ai, PreferredEngine engine) {
    switch (engine) {
      case PreferredEngine.apple:
        return ai.appleLocalReady
            ? 'Apple 自带本地模型，选中即用'
            : 'Apple 本地模型不可用，生成时将回退模板库';
      case PreferredEngine.qwen:
        if (!ai.mlxPlatformSupported) return '当前设备不支持千问';
        if (_loadingModel) {
          return _modelProgress > 0
              ? '正在加载内置千问模型 ${(_modelProgress * 100).round()}%'
              : '正在加载内置千问模型…';
        }
        return ai.modelLoaded
            ? '内置千问已加载到内存，选中即用'
            : '选中后自动加载内置千问模型';
      case PreferredEngine.deepseek:
        if (!ai.deepseekConfigured) {
          return '需先配置 API 密钥；未配置时回退模板库';
        }
        if (ai.lastDeepSeekError != null) {
          return ai.lastDeepSeekError!;
        }
        return 'DeepSeek 云端生成，需联网';
      case PreferredEngine.template:
        return '内置废话模板，选中即用';
    }
  }

  String _pathwayValueLabel(AiService ai) {
    if (ai.preferredEngine == PreferredEngine.qwen && _loadingModel) {
      return _modelProgress > 0 && _modelProgress < 1 ? '加载中…' : '加载中…';
    }
    return ai.preferredEngine.label;
  }

  Future<void> _pickEngine(AiService ai) async {
    if (_loadingModel) return;

    final choice = await showModalBottomSheet<PreferredEngine>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text('选择生成途径', style: AppTheme.bodyMedium(ctx)),
            const SizedBox(height: 8),
            for (final engine in PreferredEngine.all)
              ListTile(
                leading: Icon(_engineIcon(engine)),
                title: Text(engine.label),
                subtitle: Text(_engineOptionSubtitle(ai, engine)),
                trailing: ai.preferredEngine == engine
                    ? Icon(Icons.check_rounded, color: AppTheme.secondary)
                    : null,
                onTap: () => Navigator.pop(ctx, engine),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;

    if (choice == PreferredEngine.deepseek && !ai.deepseekConfigured) {
      final configured = await _editDeepSeekApiKey(ai);
      if (!configured || !mounted) return;
    }

    await ai.setPreferredEngine(choice);
    if (choice == PreferredEngine.qwen) {
      await _loadQwenModel(ai);
    }
  }

  Future<bool> _editDeepSeekApiKey(AiService ai) async {
    final controller = TextEditingController(
      text: ai.deepseekConfigured ? '••••••••••••' : '',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        title: const Text('DeepSeek API 密钥'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '在 platform.deepseek.com 创建密钥。仅保存在本机，用于云端生成废话。',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'API Key',
                hintText: 'sk-...',
                border: OutlineInputBorder(),
              ),
              onTap: () {
                if (controller.text == '••••••••••••') {
                  controller.clear();
                }
              },
            ),
          ],
        ),
        actions: [
          if (ai.deepseekConfigured)
            TextButton(
              onPressed: () async {
                await ai.setDeepSeekApiKey('');
                if (ctx.mounted) Navigator.pop(ctx, false);
              },
              child: Text('清除', style: TextStyle(color: AppTheme.danger)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消', style: TextStyle(color: AppTheme.textMuted)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.secondary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    final input = controller.text;
    controller.dispose();
    if (saved != true || !mounted) return ai.deepseekConfigured;

    if (input.isEmpty || input == '••••••••••••') {
      return ai.deepseekConfigured;
    }
    await ai.setDeepSeekApiKey(input);
    if (!mounted) return ai.deepseekConfigured;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('DeepSeek 密钥已保存')),
    );
    return ai.deepseekConfigured;
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
              const SectionHeader(title: '预言引擎'),
              _SettingRow(
                icon: Icons.route_rounded,
                title: '生成途径',
                value: _pathwayValueLabel(ai),
                isReal: ai.preferredEngine != PreferredEngine.template &&
                    !(_loadingModel &&
                        ai.preferredEngine == PreferredEngine.qwen),
                onTap: _loadingModel ? null : () => _pickEngine(ai),
              ),
              _SettingRow(
                icon: Icons.key_rounded,
                title: 'DeepSeek 密钥',
                value: ai.deepseekConfigured ? '已配置' : '未配置',
                isReal: ai.deepseekConfigured,
                onTap: () => _editDeepSeekApiKey(ai),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _engineOptionSubtitle(ai, ai.preferredEngine),
                  style: AppTheme.caption(context).copyWith(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
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
                  '废话预言家 v2.0\n本地途径数据不上传；DeepSeek 会发送传感器摘要',
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
