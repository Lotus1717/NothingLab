import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:pedometer_2/pedometer_2.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:light/light.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:volume_controller/volume_controller.dart';

import '../models/sensor_data.dart';

class SensorService extends ChangeNotifier {
  static const _motionIdleDuration = Duration(seconds: 3);

  SensorData _data = SensorData.initial();
  final Battery _battery = Battery();
  final ScreenBrightness _screenBrightness = ScreenBrightness();

  StreamSubscription? _batterySub;
  StreamSubscription? _accelSub;
  StreamSubscription? _pedoSub;
  StreamSubscription<double>? _volumeSub;
  StreamSubscription<int>? _lightSub;
  final Light _light = Light();
  Timer? _timeHintTimer;
  Timer? _motionIdleTimer;
  int? _androidBootBaseline;

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
      _data = _data.copyWith(steps: 0, isRealSteps: false);
      await _initBattery();
      _initAccelerometer();
      await _initPedometer();
      _initBrightness();
      await _initVolume();
      await _initAmbientLight();
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
    _volumeSub?.cancel();
    _volumeSub = null;
    VolumeController.instance.removeListener();
    await _lightSub?.cancel();
    _lightSub = null;
    _timeHintTimer?.cancel();
    _timeHintTimer = null;
    _motionIdleTimer?.cancel();
    _motionIdleTimer = null;
    _androidBootBaseline = null;
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
      _data = _data.copyWith(
        charging: s == BatteryState.charging || s == BatteryState.full,
      );
      notifyListeners();
      _battery.batteryLevel.then((l) {
        _data = _data.copyWith(battery: l);
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

  @visibleForTesting
  static DateTime startOfToday(DateTime now) =>
      DateTime(now.year, now.month, now.day);

  @visibleForTesting
  static int? applyAndroidStreamStep({
    required int? bootBaseline,
    required int currentTodaySteps,
    required int streamStep,
    required bool hasRealSteps,
  }) {
    if (bootBaseline == null) return streamStep;
    final delta = streamStep - bootBaseline;
    if (delta <= 0 || !hasRealSteps) return null;
    return currentTodaySteps + delta;
  }

  @visibleForTesting
  static int volumePercentFromLevel(double level) =>
      (level * 100).round().clamp(0, 100);

  @visibleForTesting
  static int? ambientLuxFromReading(int lux) {
    if (lux < 0) return null;
    return lux.clamp(0, 100000);
  }

  Future<bool> _requestStepPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.activityRecognition.status;
      if (status.isGranted) return true;
      final result = await Permission.activityRecognition.request();
      return result.isGranted;
    }
    if (Platform.isIOS) {
      final status = await Permission.sensors.status;
      if (status.isGranted) return true;
      final result = await Permission.sensors.request();
      return result.isGranted;
    }
    return false;
  }

  void _applyRealSteps(int steps) {
    if (steps < 0) return;
    _data = _data.copyWith(steps: steps, isRealSteps: true);
    notifyListeners();
  }

  Future<void> _initPedometer() async {
    if (!await _requestStepPermission()) {
      debugPrint('Step permission denied');
      return;
    }
    try {
      await _pedoSub?.cancel();
      _androidBootBaseline = null;
      final pedometer = Pedometer();
      final todayStart = startOfToday(DateTime.now());

      try {
        final todaySteps = await pedometer.getStepCount(from: todayStart);
        _applyRealSteps(todaySteps);
      } catch (e) {
        debugPrint('getStepCount error: $e');
      }

      if (Platform.isIOS) {
        _pedoSub = pedometer.stepCountStreamFrom(from: todayStart).listen(
          _applyRealSteps,
          onError: (e) => debugPrint('Pedometer stream error: $e'),
        );
      } else if (Platform.isAndroid) {
        _pedoSub = pedometer.stepCountStream().listen(
          (stepCount) {
            final updated = applyAndroidStreamStep(
              bootBaseline: _androidBootBaseline,
              currentTodaySteps: _data.steps,
              streamStep: stepCount,
              hasRealSteps: _data.isRealSteps,
            );
            if (_androidBootBaseline == null) {
              _androidBootBaseline = stepCount;
              return;
            }
            if (updated != null) {
              _applyRealSteps(updated);
              _androidBootBaseline = stepCount;
            }
          },
          onError: (e) => debugPrint('Pedometer stream error: $e'),
        );
      }
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

  void _applyVolume(double level) {
    _data = _data.copyWith(
      volume: volumePercentFromLevel(level),
      isRealVolume: true,
    );
    notifyListeners();
  }

  Future<void> _initVolume() async {
    if (kIsWeb) return;
    try {
      final level = await VolumeController.instance.getVolume();
      _applyVolume(level);
      _volumeSub?.cancel();
      VolumeController.instance.removeListener();
      _volumeSub = VolumeController.instance.addListener(
        _applyVolume,
        fetchInitialVolume: false,
      );
    } catch (e) {
      debugPrint('Volume error: $e');
    }
  }

  void _applyAmbientLight(int lux) {
    final parsed = ambientLuxFromReading(lux);
    if (parsed == null) return;
    _data = _data.copyWith(
      ambientLight: parsed,
      isRealAmbientLight: true,
    );
    notifyListeners();
  }

  Future<void> _initAmbientLight() async {
    if (kIsWeb) return;
    try {
      if (Platform.isIOS) {
        await _light.requestAuthorization();
      }
      await _lightSub?.cancel();
      _lightSub = _light.lightSensorStream.listen(
        _applyAmbientLight,
        onError: (e) => debugPrint('Ambient light error: $e'),
      );
    } catch (e) {
      debugPrint('Ambient light error: $e');
    }
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }
}
