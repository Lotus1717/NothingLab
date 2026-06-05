import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/sensor_data.dart';
import 'app_card.dart';
import 'status_chip.dart';

class SensorCard extends StatelessWidget {
  final SensorData sensor;

  const SensorCard({super.key, required this.sensor});

  @override
  Widget build(BuildContext context) {
    return AppMintCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '此刻感应',
            style: AppTheme.sectionHeader(context).copyWith(
              color: AppTheme.secondary,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SensorTile(
                  icon: Icons.battery_charge_full_rounded,
                  label: '电量',
                  value: '${sensor.battery ?? "--"}%',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SensorTile(
                  icon: Icons.brightness_high_rounded,
                  label: '亮度',
                  value: '${sensor.brightness}%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SensorTile(
                  icon: Icons.directions_walk_rounded,
                  label: '步数',
                  value: '${sensor.steps}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SensorTile(
                  icon: Icons.sensors_rounded,
                  label: '状态',
                  value: sensor.isMoving ? '移动中' : '静止',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: AppTheme.textDark.withValues(alpha: 0.06),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${sensor.dayPhase} · ${sensor.timeHint}',
                  style: AppTheme.caption(context),
                ),
              ),
              StatusChip(
                label: sensor.isRealBattery ? '电池' : '模拟',
                icon: Icons.battery_charge_full_rounded,
                active: sensor.isRealBattery,
              ),
              const SizedBox(width: 6),
              StatusChip(
                label: sensor.isRealMotion ? '运动' : '模拟',
                icon: Icons.sensors_rounded,
                active: sensor.isRealMotion,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SensorTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SensorTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.secondary),
              const SizedBox(width: 6),
              Text(label, style: AppTheme.caption(context)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTheme.bodyMedium(context).copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
