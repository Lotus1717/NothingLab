import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:pedometer_2/pedometer_2.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/sensor_data.dart';

class SensorService extends ChangeNotifier {
  static const _motionIdleDuration = Duration(seconds: 3);

  SensorData _data = SensorData.mock();
  final Battery _battery = Battery();
  final ScreenBrightness _screenBrightness = ScreenBrightness();

  StreamSubscription? _batterySub;
  StreamSubscription? _accelSub;
  StreamSubscription? _pedoSub;
  Timer? _stepTimer;
  Timer? _timeHintTimer;
  Timer? _motionIdleTimer;
  int _stepOffset = 0;

  bool _initializing = false;
  bool _initialized = false;

  SensorData get data => _data.withCurrentTimeHints();

  Future<void> init() async {
    if (_initializing) return;
    _initializing = true;
    try {
      if (_initialized) {
        await _cancelSubscriptions();
      }
      _refreshTimeHints();
      await _initBattery();
      _initAccelerometer();
      await _initPedometer();
      _initBrightness();
      _startMockSteps();
      _startTimeHintRefresh();
      _initialized = true;
    } finally {
      _initializing = false;
    }
  }

  void _refreshTimeHints() {
    final now = DateTime.now();
    _data = _data.copyWith(
      timestamp: now,
      timeHint: SensorData.timeHintFor(now),
      dayPhase: SensorData.dayPhaseFor(now),
    );
    notifyListeners();
  }

  void _startTimeHintRefresh() {
    _timeHintTimer?.cancel();
    _timeHintTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _refreshTimeHints();
    });
  }

  Future<void> _cancelSubscriptions() async {
    await _batterySub?.cancel();
    _batterySub = null;
    await _accelSub?.cancel();
    _accelSub = null;
    await _pedoSub?.cancel();
    _pedoSub = null;
    _stepTimer?.cancel();
    _stepTimer = null;
    _timeHintTimer?.cancel();
    _timeHintTimer = null;
    _motionIdleTimer?.cancel();
    _motionIdleTimer = null;
    _stepOffset = 0;
  }

  Future<void> _initBattery() async {
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      _data = _data.copyWith(
        battery: level,
        charging:
            state == BatteryState.charging || state == BatteryState.full,
        isRealBattery: true,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Battery error: $e');
    }
    await _batterySub?.cancel();
    _batterySub = _battery.onBatteryStateChanged.listen((s) {
      _battery.batteryLevel.then((l) {
        _data = _data.copyWith(
          battery: l,
          charging: s == BatteryState.charging || s == BatteryState.full,
        );
        notifyListeners();
      });
    });
  }

  void _initAccelerometer() {
    try {
      _accelSub?.cancel();
      _accelSub = accelerometerEventStream().listen((e) {
        final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
        if ((mag - 9.8).abs() > 3) {
          _data = _data.copyWith(
            isMoving: true,
            isRealMotion: true,
            timestamp: DateTime.now(),
          );
          notifyListeners();
          _scheduleMotionIdleReset();
        }
      });
    } catch (e) {
      debugPrint('Accel error: $e');
    }
  }

  void _scheduleMotionIdleReset() {
    _motionIdleTimer?.cancel();
    _motionIdleTimer = Timer(_motionIdleDuration, () {
      _data = _data.copyWith(isMoving: false);
      notifyListeners();
    });
  }

  Future<bool> _requestActivityRecognition() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.activityRecognition.status;
    if (status.isGranted) return true;
    final result = await Permission.activityRecognition.request();
    return result.isGranted;
  }

  Future<void> _initPedometer() async {
    if (!await _requestActivityRecognition()) {
      debugPrint('Activity recognition permission denied');
      return;
    }
    try {
      await _pedoSub?.cancel();
      final pedometer = Pedometer();
      _pedoSub = pedometer.stepCountStream().listen(
        (stepCount) {
          if (_stepOffset == 0) {
            _stepOffset = stepCount;
            return;
          }
          final steps = stepCount - _stepOffset;
          if (steps >= 0) {
            _data = _data.copyWith(steps: steps, isRealSteps: true);
            notifyListeners();
          }
        },
        onError: (e) {
          debugPrint('Pedometer error: $e');
        },
      );
    } catch (e) {
      debugPrint('Pedometer error: $e');
    }
  }

  Future<void> _initBrightness() async {
    try {
      final current = await _screenBrightness.current;
      final percent = (current * 100).round().clamp(0, 100);
      _data = _data.copyWith(brightness: percent);
      notifyListeners();
    } catch (e) {
      debugPrint('Brightness error: $e');
    }
  }

  void _startMockSteps() {
    _stepTimer?.cancel();
    _stepTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_data.isRealSteps) {
        final random = Random();
        _data = _data.copyWith(
          steps: _data.steps + random.nextInt(3),
          timestamp: DateTime.now(),
        );
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }
}
