import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 本地轻量埋点：生成次数与收藏率（不上报服务端）
class AnalyticsService extends ChangeNotifier {
  static const prophecyCountKey = 'analytics_prophecy_generated_count';
  static const favoriteCountKey = 'analytics_favorite_added_count';
  static const firstOpenDateKey = 'analytics_first_open_date';

  int _prophecyGeneratedCount = 0;
  int _favoriteAddedCount = 0;
  String? _firstOpenDate;
  bool _loaded = false;

  int get prophecyGeneratedCount => _prophecyGeneratedCount;
  int get favoriteAddedCount => _favoriteAddedCount;
  String? get firstOpenDate => _firstOpenDate;
  bool get isLoaded => _loaded;

  /// 收藏率 0.0–1.0；无生成记录时为 0
  double get favoriteRate {
    if (_prophecyGeneratedCount == 0) return 0;
    return _favoriteAddedCount / _prophecyGeneratedCount;
  }

  /// 收藏率百分比（四舍五入）
  int get favoriteRatePercent => (favoriteRate * 100).round();

  Future<void> init() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _prophecyGeneratedCount = prefs.getInt(prophecyCountKey) ?? 0;
      _favoriteAddedCount = prefs.getInt(favoriteCountKey) ?? 0;
      _firstOpenDate = prefs.getString(firstOpenDateKey);
      if (_firstOpenDate == null) {
        _firstOpenDate = _todayDateString();
        await prefs.setString(firstOpenDateKey, _firstOpenDate!);
      }
    } catch (e) {
      debugPrint('Analytics init failed: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> trackProphecyGenerated() async {
    _prophecyGeneratedCount++;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(prophecyCountKey, _prophecyGeneratedCount);
    } catch (e) {
      debugPrint('Analytics track prophecy failed: $e');
    }
  }

  Future<void> trackFavoriteAdded() async {
    _favoriteAddedCount++;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(favoriteCountKey, _favoriteAddedCount);
    } catch (e) {
      debugPrint('Analytics track favorite failed: $e');
    }
  }

  static String _todayDateString() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
