import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_helpers.dart';

void main() {
  setUpAll(() {
    mockAllPlatformChannels();
  });

  tearDownAll(() {
    clearAllMocks();
  });

  testWidgets('应用应该正常启动并显示标题', (WidgetTester tester) async {
    await tester.pumpWidget(await buildTestApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('废话预言家'), findsOneWidget);
  });

  testWidgets('底部导航栏有三个标签', (WidgetTester tester) async {
    await tester.pumpWidget(await buildTestApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('首页'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });
}
