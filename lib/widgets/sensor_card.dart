import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/sensor_data.dart';
import 'app_card.dart';

class SensorCard extends StatelessWidget {
  final SensorData sensor;

  const SensorCard({super.key, required this.sensor});

  @override
  Widget build(BuildContext context) {
    return AppMintCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _item('🔋', '电量', '${sensor.battery ?? "--"}%')),
              Expanded(child: _item('☀️', '亮度', '${sensor.brightness}%')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _item('🚶', '步数', '${sensor.steps}')),
              Expanded(
                  child:
                      _item('📳', '状态', sensor.isMoving ? '移动中' : '静止')),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0x11000000), width: 1),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '${sensor.dayPhase} · ${sensor.timeHint}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
                ),
                const Spacer(),
                Text(
                  sensor.isRealBattery ? '🔋真' : '🔋模',
                  style: TextStyle(
                    fontSize: 11,
                    color: sensor.isRealBattery
                        ? AppTheme.secondary
                        : AppTheme.textLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(String emoji, String label, String value) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 7),
        Text(label,
            style: const TextStyle(fontSize: 13, color: AppTheme.textLight)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDark,
          ),
        ),
      ],
    );
  }
}
