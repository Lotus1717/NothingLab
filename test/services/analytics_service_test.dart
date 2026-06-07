import 'package:flutter_test/flutter_test.dart';
import 'package:nonsense_prophet/services/analytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('AnalyticsService', () {
    late AnalyticsService analytics;

    setUp(() {
      initTestBindings();
      analytics = AnalyticsService();
    });

    test('初始计数为 0，收藏率为 0', () async {
      await analytics.init();
      expect(analytics.prophecyGeneratedCount, 0);
      expect(analytics.favoriteAddedCount, 0);
      expect(analytics.favoriteRate, 0);
      expect(analytics.favoriteRatePercent, 0);
      expect(analytics.firstOpenDate, isNotNull);
    });

    test('trackProphecyGenerated 应递增并持久化', () async {
      await analytics.init();
      await analytics.trackProphecyGenerated();
      await analytics.trackProphecyGenerated();

      expect(analytics.prophecyGeneratedCount, 2);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(AnalyticsService.prophecyCountKey), 2);
    });

    test('trackFavoriteAdded 应递增并持久化', () async {
      await analytics.init();
      await analytics.trackFavoriteAdded();

      expect(analytics.favoriteAddedCount, 1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(AnalyticsService.favoriteCountKey), 1);
    });

    test('收藏率 = 收藏次数 / 生成次数', () async {
      await analytics.init();
      await analytics.trackProphecyGenerated();
      await analytics.trackProphecyGenerated();
      await analytics.trackFavoriteAdded();

      expect(analytics.favoriteRate, closeTo(0.5, 0.001));
      expect(analytics.favoriteRatePercent, 50);
    });

    test('应从 SharedPreferences 恢复历史数据', () async {
      SharedPreferences.setMockInitialValues({
        AnalyticsService.prophecyCountKey: 10,
        AnalyticsService.favoriteCountKey: 3,
        AnalyticsService.firstOpenDateKey: '2026-01-01',
      });
      analytics = AnalyticsService();
      await analytics.init();

      expect(analytics.prophecyGeneratedCount, 10);
      expect(analytics.favoriteAddedCount, 3);
      expect(analytics.favoriteRatePercent, 30);
      expect(analytics.firstOpenDate, '2026-01-01');
    });
  });
}
