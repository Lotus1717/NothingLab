import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../config/app_fonts.dart';
import '../config/share_config.dart';
import '../config/theme.dart';
import '../models/sensor_data.dart';
import 'lazy_cat.dart';

/// 用于生成分享图片的离屏卡片（4:5 竖版，样式独立于屏幕）
class ProphecyShareCard extends StatelessWidget {
  final String prophecy;
  final SensorData? sensor;
  final DateTime? createdAt;

  const ProphecyShareCard({
    super.key,
    required this.prophecy,
    this.sensor,
    this.createdAt,
  });

  /// 逻辑尺寸 360×450，导出时 pixelRatio 3 → 1080×1350
  static const double cardWidth = 360;
  static const double cardHeight = 450;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF8F3),
            Color(0xFFFFF0E8),
            Color(0xFFF5F0EB),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.oracleGold.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textDark.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppTheme.primaryDark.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg - 1),
        child: Stack(
          children: [
            Positioned(
              top: -40,
              right: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.secondary.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              bottom: 80,
              left: -50,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withValues(alpha: 0.1),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ShareHeader(createdAt: createdAt),
                  const SizedBox(height: 14),
                  Expanded(child: _ProphecyHero(prophecy: prophecy)),
                  if (sensor != null) ...[
                    const SizedBox(height: 12),
                    _SensorSnapshot(sensor: sensor!),
                  ],
                  const SizedBox(height: 14),
                  const _ShareFooter(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareHeader extends StatelessWidget {
  final DateTime? createdAt;

  const _ShareHeader({this.createdAt});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ShareLazyCat(width: 110, height: 64),
        const SizedBox(height: 4),
        Text(
          '废话预言家',
          style: AppFonts.displayStyle(
            fontSize: 22,
            color: AppTheme.textDark,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          ShareConfig.appTagline,
          style: AppFonts.bodyStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppTheme.textMuted,
            letterSpacing: 0.4,
          ),
        ),
        if (createdAt != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.oracleGoldLight.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.oracleGold.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              _formatTimestamp(createdAt!),
              style: AppFonts.bodyStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _formatTimestamp(DateTime time) {
    final m = time.month.toString().padLeft(2, '0');
    final d = time.day.toString().padLeft(2, '0');
    final h = time.hour.toString().padLeft(2, '0');
    final min = time.minute.toString().padLeft(2, '0');
    return '$m/$d $h:$min';
  }
}

class _ProphecyHero extends StatelessWidget {
  final String prophecy;

  const _ProphecyHero({required this.prophecy});

  double _baseFontSize(String text) {
    final length = text.length;
    if (length > 120) return 15;
    if (length > 80) return 17;
    if (length > 50) return 18;
    return 19;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.oracleGold.withValues(alpha: 0.32),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.oracleGold.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '「',
              style: AppFonts.displayStyle(
                fontSize: 28,
                color: AppTheme.oracleGold.withValues(alpha: 0.45),
                height: 1,
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      child: Text(
                        prophecy,
                        textAlign: TextAlign.center,
                        style: AppFonts.bodyStyle(
                          fontSize: _baseFontSize(prophecy),
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textDark,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '」',
              style: AppFonts.displayStyle(
                fontSize: 28,
                color: AppTheme.secondary.withValues(alpha: 0.4),
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareFooter extends StatelessWidget {
  const _ShareFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        color: AppTheme.bgMint.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: AppTheme.secondary.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.secondary.withValues(alpha: 0.25),
              ),
            ),
            child: QrImageView(
              data: ShareConfig.landingUrl,
              version: QrVersions.auto,
              size: 64,
              padding: EdgeInsets.zero,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.circle,
                color: AppTheme.textDark,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.circle,
                color: AppTheme.textDark,
              ),
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ShareConfig.qrLabel,
                  style: AppFonts.bodyStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  ShareConfig.landingUrl.replaceFirst('https://', ''),
                  style: AppFonts.bodyStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
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
        Icon(icon, size: 12, color: AppTheme.secondary),
        const SizedBox(width: 3),
        Text(
          value,
          style: AppFonts.bodyStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Container(
        width: 1,
        height: 11,
        color: AppTheme.secondary.withValues(alpha: 0.2),
      ),
    );
  }
}
