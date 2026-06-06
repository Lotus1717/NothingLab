import 'package:flutter/material.dart';

import '../config/app_fonts.dart';
import '../config/theme.dart';
import '../models/sensor_data.dart';
import 'lazy_cat.dart';

/// 用于生成分享图片的离屏卡片（固定宽度，样式独立于屏幕）
class ProphecyShareCard extends StatelessWidget {
  final String prophecy;
  final SensorData? sensor;

  const ProphecyShareCard({
    super.key,
    required this.prophecy,
    this.sensor,
  });

  static const double cardWidth = 360;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: cardWidth,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFF8F3),
            Color(0xFFFFF4EC),
            Color(0xFFF8F5F0),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.secondary.withValues(alpha: 0.15),
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ShareLazyCat(),
          const SizedBox(height: 12),
          Text(
            '废话预言家',
            style: AppFonts.displayStyle(
              fontSize: 20,
              color: AppTheme.textDark,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: AppTheme.oracleGold.withValues(alpha: 0.28),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.oracleGold.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                prophecy,
                textAlign: TextAlign.left,
                style: AppFonts.bodyStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textDark,
                  height: 1.65,
                ),
              ),
            ),
          ),
          if (sensor != null) ...[
            const SizedBox(height: 16),
            _SensorSnapshot(sensor: sensor!),
          ],
        ],
      ),
    );
  }
}

class _SensorSnapshot extends StatelessWidget {
  final SensorData sensor;

  const _SensorSnapshot({required this.sensor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgMint.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: AppTheme.secondary.withValues(alpha: 0.18),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _chip(Icons.battery_full_rounded, '${sensor.battery ?? "--"}%'),
          _divider(),
          _chip(
            Icons.directions_walk_rounded,
            sensor.isRealSteps ? '${sensor.steps}' : '--',
          ),
          _divider(),
          _chip(
            Icons.volume_up_rounded,
            sensor.isRealVolume ? '${sensor.volume}%' : '--',
          ),
          _divider(),
          _chip(
            Icons.wb_sunny_outlined,
            sensor.isRealAmbientLight
                ? '${sensor.ambientLight}lx'
                : sensor.isEstimatedAmbientLight
                    ? '~${sensor.ambientLight}lx'
                    : '--',
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.secondary),
        const SizedBox(width: 3),
        Text(
          value,
          style: AppFonts.bodyStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
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
        height: 12,
        color: AppTheme.secondary.withValues(alpha: 0.2),
      ),
    );
  }
}
