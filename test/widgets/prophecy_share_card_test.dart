import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nonsense_prophet/config/share_config.dart';
import 'package:nonsense_prophet/models/sensor_data.dart';
import 'package:nonsense_prophet/widgets/prophecy_share_card.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  testWidgets('ProphecyShareCard 应渲染预言、二维码与品牌信息', (tester) async {
    final sensor = SensorData.mock();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProphecyShareCard(
            prophecy: '今日宜摸鱼，忌开会。',
            sensor: sensor,
            createdAt: DateTime(2026, 6, 7, 14, 30),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('废话预言家'), findsOneWidget);
    expect(find.textContaining('今日宜摸鱼'), findsOneWidget);
    expect(find.text(ShareConfig.qrLabel), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);

    final box = tester.renderObject(find.byType(ProphecyShareCard)) as RenderBox;
    expect(box.size.width, ProphecyShareCard.cardWidth);
    expect(box.size.height, ProphecyShareCard.cardHeight);
  });
}
