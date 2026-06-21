import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nonsense_prophet/config/share_config.dart';
import 'package:nonsense_prophet/models/sensor_data.dart';
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

  testWidgets('ProphecyShareCard 应渲染预言、二维码、Logo 与扫码文案', (tester) async {
    final sensor = SensorData.mock();
    await pumpCard(
      tester,
      prophecy: '今日宜摸鱼，忌开会。',
      sensor: sensor,
      createdAt: DateTime(2026, 6, 7, 14, 30),
    );

    expect(find.text('废话预言家'), findsOneWidget);
    expect(find.text(ShareConfig.shareHook), findsOneWidget);
    expect(find.textContaining('今日宜摸鱼'), findsOneWidget);
    expect(find.text(ShareConfig.qrLabel), findsOneWidget);
    expect(find.text('nonsense-prophet.app'), findsOneWidget);
    expect(find.byKey(const Key('share-app-logo')), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('06/07 14:30'), findsOneWidget);
    expect(find.textContaining('电量'), findsOneWidget);

    final box = tester.renderObject(find.byType(ProphecyShareCard)) as RenderBox;
    expect(box.size.width, ProphecyShareCard.cardWidth);
    expect(box.size.height, greaterThan(200));
    expect(box.size.height, lessThan(520));
  });

  testWidgets('品牌标题应位于页脚二维码之上', (tester) async {
    await pumpCard(tester, prophecy: '短预言');

    final titleFinder = find.text('废话预言家');
    final qrFinder = find.byType(QrImageView);
    expect(titleFinder, findsOneWidget);
    expect(qrFinder, findsOneWidget);

    final titleBox = tester.renderObject(titleFinder) as RenderBox;
    final qrBox = tester.renderObject(qrFinder) as RenderBox;
    expect(
      titleBox.localToGlobal(Offset.zero).dy,
      lessThan(qrBox.localToGlobal(Offset.zero).dy),
    );
  });

  testWidgets('短预言卡片高度应紧凑，无大面积空白', (tester) async {
    await pumpCard(tester, prophecy: '今日宜摸鱼');

    final box = tester.renderObject(find.byType(ProphecyShareCard)) as RenderBox;
    expect(box.size.height, lessThan(380));
  });

  testWidgets('长预言卡片高度随内容增长', (tester) async {
    await pumpCard(tester, prophecy: '短');

    final shortBox = tester.renderObject(find.byType(ProphecyShareCard)) as RenderBox;
    final shortHeight = shortBox.size.height;

    await pumpCard(
      tester,
      prophecy: '电量充足时，你的摸鱼效率会提升三成，宜多喝水，'
          '忌开会，今日步数破万时会有意外惊喜等着你。',
      sensor: SensorData.mock(),
      createdAt: DateTime(2026, 6, 7, 14, 30),
    );

    final longBox = tester.renderObject(find.byType(ProphecyShareCard)) as RenderBox;
    expect(longBox.size.height, greaterThan(shortHeight));
  });

  testWidgets('短预言居中、较长预言左对齐', (tester) async {
    await pumpCard(tester, prophecy: '今日宜摸鱼');

    final shortText = tester.widget<Text>(find.text('今日宜摸鱼'));
    expect(shortText.textAlign, TextAlign.center);
    expect(shortText.style?.fontSize, 22);

    await pumpCard(
      tester,
      prophecy: '电量充足时，你的摸鱼效率会提升三成，宜多喝水。',
    );

    final longText = tester.widget<Text>(
      find.textContaining('电量充足'),
    );
    expect(longText.textAlign, TextAlign.left);
    expect(longText.style?.fontSize, greaterThanOrEqualTo(16));
    expect(longText.maxLines, 10);
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
    expect(prophecyBox.size.height, greaterThan(20));
  });
}
