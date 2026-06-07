import 'package:flutter_test/flutter_test.dart';
import 'package:nonsense_prophet/config/deepseek_config.dart';
import 'package:nonsense_prophet/services/deepseek_usage_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('DeepSeekUsageTracker', () {
    late DeepSeekUsageTracker tracker;

    setUp(() {
      initTestBindings();
      tracker = DeepSeekUsageTracker();
    });

    test('新设备当日计数为 0', () async {
      expect(await tracker.getTodayCount(), 0);
      expect(await tracker.canUseDeepSeek(), isTrue);
    });

    test('recordCall 应递增当日计数', () async {
      await tracker.recordCall();
      await tracker.recordCall();
      expect(await tracker.getTodayCount(), 2);
    });

    test('达到每日上限后 canUseDeepSeek 为 false', () async {
      final today = DeepSeekUsageTracker.todayDateString();
      SharedPreferences.setMockInitialValues({
        'deepseek_daily_usage_date_v1': today,
        'deepseek_daily_usage_count_v1': DeepSeekConfig.dailyLimit,
      });
      tracker = DeepSeekUsageTracker();
      expect(await tracker.canUseDeepSeek(), isFalse);
    });

    test('日期变更后计数应重置', () async {
      SharedPreferences.setMockInitialValues({
        'deepseek_daily_usage_date_v1': '2000-01-01',
        'deepseek_daily_usage_count_v1': DeepSeekConfig.dailyLimit,
      });
      tracker = DeepSeekUsageTracker();
      expect(await tracker.getTodayCount(), 0);
      expect(await tracker.canUseDeepSeek(), isTrue);
    });
  });
}
