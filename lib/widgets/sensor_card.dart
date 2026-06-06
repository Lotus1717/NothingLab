import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/sensor_data.dart';

/// 仪表盘风格传感器状态条
class SensorCard extends StatelessWidget {
  final SensorData sensor;

  const SensorCard({super.key, required this.sensor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgMint.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: AppTheme.secondary.withValues(alpha: 0.2),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          _sensor(Icons.battery_full_rounded, '${sensor.battery ?? "--"}%'),
          _divider(),
          _sensor(
            Icons.directions_walk_rounded,
            sensor.isRealSteps ? '${sensor.steps}' : '--',
          ),
          _divider(),
          _sensor(
            Icons.sensors_rounded,
            sensor.isMoving ? '移动' : '静止',
          ),
          _divider(),
          _sensor(
            Icons.volume_up_rounded,
            sensor.isRealVolume ? '${sensor.volume}%' : '--',
          ),
          _divider(),
          _sensor(
            Icons.wb_sunny_outlined,
            sensor.isRealAmbientLight ? '${sensor.ambientLight}lx' : '--',
          ),
          const Spacer(),
          Text(
            '${sensor.dayPhase} · ${sensor.timeHint}',
            style: AppTheme.caption(context).copyWith(
              fontSize: 10,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sensor(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.secondary),
        const SizedBox(width: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
            fontFamily: '.SF Pro Text',
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        width: 1,
        height: 14,
        color: AppTheme.secondary.withValues(alpha: 0.2),
      ),
    );
  }
}
