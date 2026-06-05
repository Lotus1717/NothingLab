import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:nonsense_prophet/main.dart';
import 'package:nonsense_prophet/config/theme.dart';
import 'helpers/test_helpers.dart';

void main() {
  setUpAll(() {
    mockAllPlatformChannels();
  });

  tearDownAll(() {
    clearAllMocks();
  });

  group('MyApp — 完整应用', () {
    testWidgets('应显示应用标题和底部导航栏', (tester) async {
      await tester.pumpWidget(const MyApp());
      // 等待异步加载完成
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 标题
      expect(find.text('废话预言家'), findsOneWidget);

      // 底部导航栏
      expect(find.text('首页'), findsOneWidget);
      expect(find.text('历史'), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);
    });

    testWidgets('底部导航切换应更换页面', (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 默认在首页
      expect(find.text('🐣'), findsOneWidget);

      // 切换到历史页
      await tester.tap(find.text('历史'));
      await tester.pumpAndSettle();
      expect(find.text('小本本'), findsOneWidget);

      // 切换到设置页
      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      expect(find.text('小设置'), findsOneWidget);

      // 切回首页
      await tester.tap(find.text('首页'));
      await tester.pumpAndSettle();
      expect(find.text('🐣'), findsOneWidget);
    });
  });

  group('首页 — HomePage', () {
    testWidgets('应显示传感器卡片', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MainScreen()));
      await tester.pump();

      // 传感器指标存在
      expect(find.text('电量'), findsOneWidget);
      expect(find.text('步数'), findsOneWidget);
      expect(find.text('骰子按钮'), findsNWidgets(0)); // 用 emoji 渲染

      // 有骰子按钮（🎲）
      expect(find.text('🎲'), findsOneWidget);
    });

    testWidgets('戳骰子应生成预言', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MainScreen()));
      await tester.pump();

      // 戳骰子
      await tester.tap(find.text('🎲'));
      await tester.pump(const Duration(milliseconds: 500));

      // 开始加载
      expect(find.textContaining('小猫'), findsWidgets);
    });
  });

  group('设置页 — SettingsPage', () {
    testWidgets('应显示传感器状态', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SensorService()),
            ChangeNotifierProvider(create: (_) => AiService()),
          ],
          child: const SettingsPage(),
        ),
      ));
      await tester.pump();

      expect(find.text('小设置'), findsOneWidget);
      expect(find.text('电池'), findsOneWidget);
      expect(find.text('运动'), findsOneWidget);
      expect(find.text('步数'), findsOneWidget);
      expect(find.text('AI 引擎'), findsOneWidget);
    });
  });

  group('主题 — AppTheme', () {
    test('主题颜色常量应定义', () {
      expect(AppTheme.primary, isNotNull);
      expect(AppTheme.primaryDark, isNotNull);
      expect(AppTheme.bg, isNotNull);
      expect(AppTheme.bgMint, isNotNull);
      expect(AppTheme.card, isNotNull);
      expect(AppTheme.secondary, isNotNull);
      expect(AppTheme.textDark, isNotNull);
      expect(AppTheme.textLight, isNotNull);
    });

    test('lightTheme 应正确引用颜色', () {
      final theme = AppTheme.lightTheme;
      expect(theme.scaffoldBackgroundColor, AppTheme.bg);
      expect(theme.primaryColor, AppTheme.primary);
    });
  });
}
