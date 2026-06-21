import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../config/app_fonts.dart';
import '../config/share_config.dart';
import '../config/theme.dart';
import '../models/sensor_data.dart';

/// 用于生成分享图片的离屏卡片（竖版海报，高度随内容自适应）
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

  /// 逻辑宽度 360，导出时 pixelRatio 3 → 1080px 宽
  static const double cardWidth = 360;

  static const String _appLogoAsset = 'assets/fonts/share_app_logo.jpg';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: cardWidth,
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
              top: -50,
              right: -40,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.secondary.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              bottom: 40,
              left: -60,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withValues(alpha: 0.08),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _BrandingHeader(),
                  const SizedBox(height: 18),
                  const _ShareHook(),
                  const SizedBox(height: 10),
                  _ProphecyHero(prophecy: prophecy),
                  if (createdAt != null) ...[
                    const SizedBox(height: 12),
                    _TimestampLine(createdAt: createdAt!),
                  ],
                  if (sensor != null) ...[
                    const SizedBox(height: 6),
                    _SensorFootnote(sensor: sensor!),
                  ],
                  const SizedBox(height: 16),
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

/// 品牌区：App Logo + 标题/副标题
class _BrandingHeader extends StatelessWidget {
  const _BrandingHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            ProphecyShareCard._appLogoAsset,
            key: const Key('share-app-logo'),
            width: 44,
            height: 44,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '废话预言家',
                style: AppFonts.displayStyle(
                  fontSize: 24,
                  color: AppTheme.textDark,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                ShareConfig.appTagline,
                style: AppFonts.bodyStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textMuted,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShareHook extends StatelessWidget {
  const _ShareHook();

  @override
  Widget build(BuildContext context) {
    return Text(
      ShareConfig.shareHook,
      style: AppFonts.displayStyle(
        fontSize: 18,
        color: AppTheme.primaryDark,
        height: 1.2,
      ),
    );
  }
}

class _ProphecyHero extends StatelessWidget {
  final String prophecy;

  const _ProphecyHero({required this.prophecy});

  static double fontSizeFor(String text) {
    final length = text.length;
    if (length > 100) return 16;
    if (length > 70) return 17;
    if (length > 40) return 18;
    if (length > 20) return 20;
    return 22;
  }

  static bool isShortQuote(String text) => text.length <= 20;

  @override
  Widget build(BuildContext context) {
    final fontSize = fontSizeFor(prophecy);
    final shortQuote = isShortQuote(prophecy);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: shortQuote ? 18 : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: [
          BoxShadow(
            color: AppTheme.oracleGold.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        prophecy,
        textAlign: shortQuote ? TextAlign.center : TextAlign.left,
        maxLines: 10,
        overflow: TextOverflow.ellipsis,
        style: AppFonts.bodyStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: AppTheme.textDark,
          height: 1.5,
        ),
      ),
    );
  }
}

class _TimestampLine extends StatelessWidget {
  final DateTime createdAt;

  const _TimestampLine({required this.createdAt});

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatTimestamp(createdAt),
      textAlign: TextAlign.center,
      style: AppFonts.bodyStyle(
        fontSize: 10,
        fontWeight: FontWeight.w400,
        color: AppTheme.textMuted,
        letterSpacing: 0.2,
      ),
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

class _SensorFootnote extends StatelessWidget {
  final SensorData sensor;

  const _SensorFootnote({required this.sensor});

  @override
  Widget build(BuildContext context) {
    final line = _formatFootnote(sensor);
    if (line.isEmpty) return const SizedBox.shrink();

    return Text(
      line,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: AppFonts.bodyStyle(
        fontSize: 10,
        fontWeight: FontWeight.w400,
        color: AppTheme.textMuted,
        height: 1.4,
      ),
    );
  }

  String _formatFootnote(SensorData sensor) {
    final parts = <String>[];
    if (sensor.battery != null) {
      parts.add('电量${sensor.battery}%');
    }
    if (sensor.isRealSteps && sensor.steps > 0) {
      parts.add('步数${sensor.steps}');
    }
    if (sensor.dayPhase.isNotEmpty) {
      parts.add(sensor.dayPhase);
    } else if (sensor.timeHint.isNotEmpty) {
      parts.add(sensor.timeHint);
    }
    return parts.join(' · ');
  }
}

class _ShareFooter extends StatelessWidget {
  const _ShareFooter();

  static const double _qrSize = 56;

  static String get _landingHost {
    final uri = Uri.tryParse(ShareConfig.landingUrl);
    return uri?.host.isNotEmpty == true
        ? uri!.host
        : ShareConfig.landingUrl;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        color: AppTheme.bgMint.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: QrImageView(
              data: ShareConfig.landingUrl,
              version: QrVersions.auto,
              size: _qrSize,
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ShareConfig.qrLabel,
                  style: AppFonts.bodyStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _landingHost,
                  style: AppFonts.bodyStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textMuted,
                    height: 1.3,
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
