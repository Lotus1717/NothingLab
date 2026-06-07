import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/deepseek_config.dart';

/// 本地追踪 DeepSeek 每日调用次数（自然日、设备时区）
class DeepSeekUsageTracker {
  static const _dateKey = 'deepseek_daily_usage_date_v1';
  static const _countKey = 'deepseek_daily_usage_count_v1';

  static String todayDateString() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<int> getTodayCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedDate = prefs.getString(_dateKey);
      final today = todayDateString();
      if (storedDate != today) return 0;
      return prefs.getInt(_countKey) ?? 0;
    } catch (e) {
      debugPrint('Read DeepSeek daily usage failed: $e');
      return 0;
    }
  }

  Future<bool> canUseDeepSeek() async {
    final count = await getTodayCount();
    return count < DeepSeekConfig.dailyLimit;
  }

  Future<void> recordCall() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = todayDateString();
      final storedDate = prefs.getString(_dateKey);
      var count = 0;
      if (storedDate == today) {
        count = prefs.getInt(_countKey) ?? 0;
      }
      count++;
      await prefs.setString(_dateKey, today);
      await prefs.setInt(_countKey, count);
      debugPrint('DeepSeek daily usage: $count/${DeepSeekConfig.dailyLimit}');
    } catch (e) {
      debugPrint('Record DeepSeek daily usage failed: $e');
    }
  }
}
