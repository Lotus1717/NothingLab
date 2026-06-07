import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nonsense_prophet/config/share_config.dart';
import 'package:nonsense_prophet/models/sensor_data.dart';
import 'package:nonsense_prophet/widgets/lazy_cat.dart';
import 'package:nonsense_prophet/widgets/prophecy_share_card.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    required String prophecy,
    SensorData? sensor,
    DateTime? createdAt,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProphecyShareCard(
            prophecy: prophecy,
            sensor: sensor,
            createdAt: createdAt,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('ProphecyShareCard 应渲染预言、二维码与品牌信息', (tester) async {
    final sensor = SensorData.mock();
    await pumpCard(
      tester,
      prophecy: '今日宜摸鱼，忌开会。',
      sensor: sensor,
      createdAt: DateTime(2026, 6, 7, 14, 30),
    );

    expect(find.text('废话预言家'), findsOneWidget);
    expect(find.textContaining('今日宜摸鱼'), findsOneWidget);
    expect(find.text('「'), findsNothing);
    expect(find.text('」'), findsNothing);
    expect(find.text(ShareConfig.qrLabel), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.byType(FittedBox), findsNothing);

    final box = tester.renderObject(find.byType(ProphecyShareCard)) as RenderBox;
    expect(box.size.width, ProphecyShareCard.cardWidth);
    expect(box.size.height, ProphecyShareCard.cardHeight);
  });

  testWidgets('品牌标题应位于小猫插画之上', (tester) async {
    await pumpCard(tester, prophecy: '短预言');

    final titleFinder = find.text('废话预言家');
    final catFinder = find.byType(ShareLazyCat);
    expect(titleFinder, findsOneWidget);
    expect(catFinder, findsOneWidget);

    final titleBox = tester.renderObject(titleFinder) as RenderBox;
    final catBox = tester.renderObject(catFinder) as RenderBox;
    expect(
      titleBox.localToGlobal(Offset.zero).dy,
      lessThan(catBox.localToGlobal(Offset.zero).dy),
    );
  });

  testWidgets('预言正文应使用 22–28 字号且不缩放', (tester) async {
    await pumpCard(tester, prophecy: '今日宜摸鱼，忌开会。');

    final prophecyText = tester.widget<Text>(
      find.textContaining('今日宜摸鱼'),
    );
    expect(prophecyText.style?.fontSize, greaterThanOrEqualTo(22));
    expect(prophecyText.style?.fontSize, lessThanOrEqualTo(28));
    expect(prophecyText.maxLines, 6);
    expect(prophecyText.overflow, TextOverflow.ellipsis);
  });

  testWidgets('含传感器数据时预言区仍有足够高度', (tester) async {
    await pumpCard(
      tester,
      prophecy: '电量充足时，你的摸鱼效率会提升三成。',
      sensor: SensorData.mock(),
      createdAt: DateTime(2026, 6, 7, 14, 30),
    );

    final prophecyFinder = find.textContaining('电量充足');
    final prophecyBox = tester.renderObject(prophecyFinder) as RenderBox;
    expect(prophecyBox.size.height, greaterThan(40));
  });
}
