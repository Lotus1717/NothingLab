import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// 每日本地推送提醒（flutter_local_notifications + timezone）
class NotificationService extends ChangeNotifier {
  static const _enabledKey = 'daily_notification_enabled';
  static const _hourKey = 'daily_notification_hour';
  static const _minuteKey = 'daily_notification_minute';
  static const dailyNotificationId = 9001;
  static const channelId = 'daily_oracle_reminder';
  static const channelName = '每日神谕提醒';

  static const defaultHour = 9;
  static const defaultMinute = 0;

  static const _messages = [
    '今日神谕尚未降临，戳一下小猫？',
    '小猫在等你戳一下，废话预言家在线',
    '传感器已就位，就差你戳一下 LazyCat',
    '废话库存充足，来听一句今日预言',
  ];

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _enabled = false;
  int _hour = defaultHour;
  int _minute = defaultMinute;
  bool _initialized = false;

  bool get enabled => _enabled;
  int get hour => _hour;
  int get minute => _minute;
  bool get isInitialized => _initialized;
  bool get isSupported {
    if (kIsWeb) return false;
    if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  String get timeLabel =>
      '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';

  Future<void> init() async {
    if (_initialized) return;
    await _loadPrefs();

    if (!isSupported) {
      _initialized = true;
      notifyListeners();
      return;
    }

    try {
      _configureLocalTimeZone();

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: iosSettings,
      );

      await _plugin.initialize(initSettings);

      if (Platform.isAndroid) {
        await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(
              const AndroidNotificationChannel(
                channelId,
                channelName,
                description: '每天提醒你戳小猫听一句废话预言',
                importance: Importance.defaultImportance,
              ),
            );
      }

      if (_enabled) {
        await _scheduleDailyNotification();
      }
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    if (!isSupported) return;

    if (value) {
      final granted = await requestPermission();
      if (!granted) return;
    }

    _enabled = value;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, _enabled);
    } catch (e) {
      debugPrint('Save notification enabled failed: $e');
    }

    if (_enabled) {
      await _scheduleDailyNotification();
    } else {
      await _plugin.cancel(dailyNotificationId);
    }
  }

  Future<void> setTime({required int hour, required int minute}) async {
    _hour = hour.clamp(0, 23);
    _minute = minute.clamp(0, 59);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_hourKey, _hour);
      await prefs.setInt(_minuteKey, _minute);
    } catch (e) {
      debugPrint('Save notification time failed: $e');
    }

    if (_enabled) {
      await _scheduleDailyNotification();
    }
  }

  Future<bool> requestPermission() async {
    if (!isSupported) return false;

    if (Platform.isIOS || Platform.isMacOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final mac = _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          await mac?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return granted ?? false;
    }

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? true;
    }

    return false;
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_enabledKey) ?? false;
      _hour = prefs.getInt(_hourKey) ?? defaultHour;
      _minute = prefs.getInt(_minuteKey) ?? defaultMinute;
    } catch (e) {
      debugPrint('Load notification prefs failed: $e');
    }
  }

  Future<void> _scheduleDailyNotification() async {
    if (!isSupported) return;

    await _plugin.cancel(dailyNotificationId);

    final body = _messages[DateTime.now().day % _messages.length];
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: '每天提醒你戳小猫听一句废话预言',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      dailyNotificationId,
      '废话预言家',
      body,
      _nextInstanceOfTime(_hour, _minute),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  void _configureLocalTimeZone() {
    tz.initializeTimeZones();
    final offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
    for (final location in tz.timeZoneDatabase.locations.values) {
      final now = tz.TZDateTime.now(location);
      if (now.timeZoneOffset.inMinutes == offsetMinutes) {
        tz.setLocalLocation(location);
        return;
      }
    }
    tz.setLocalLocation(tz.UTC);
  }
}
