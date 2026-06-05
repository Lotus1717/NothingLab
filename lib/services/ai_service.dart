import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/prophecy_record.dart';
import '../models/sensor_data.dart';
import 'local_ai_bridge.dart';
import 'prophecy_generator.dart';

class AiService extends ChangeNotifier {
  static const _historyKey = 'prophecy_history_v1';
  static const _maxHistory = 30;

  bool _loading = false;
  bool _modelLoaded = false;
  bool _isModelAvailable = false;
  String _currentProphecy = '';
  List<ProphecyRecord> _history = [];

  final LocalAiBridge _localAi = LocalAiBridge();
  final ProphecyGeneratorBridge _bridge = ProphecyGeneratorBridge();

  bool get loading => _loading;
  bool get modelLoaded => _modelLoaded;
  bool get isModelAvailable => _isModelAvailable;
  String get currentProphecy => _currentProphecy;
  List<ProphecyRecord> get history => List.unmodifiable(_history);
  LocalAiBridge get localAi => _localAi;

  AiService() {
    _loadHistory();
  }

  static const _animalLoading = [
    '🐱 小猫正在抓阄中...',
    '🦊 小狐狸在编废话...',
    '🐢 乌龟在认真思考...',
    '🐰 小兔子在翻预言书...',
    '🦡 獾子在推算命运...',
  ];

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw) as List<dynamic>;
      _history = list
          .map((e) => ProphecyRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Load history failed: $e');
    }
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_history.map((e) => e.toJson()).toList());
      await prefs.setString(_historyKey, encoded);
    } catch (e) {
      debugPrint('Save history failed: $e');
    }
  }

  Future<void> checkModelAvailability() async {
    await _localAi.initialize();
    if (_localAi.modelAvailable) {
      _isModelAvailable = true;
      _modelLoaded = true;
      notifyListeners();
      return;
    }

    try {
      if (!await _bridge.isPlatformSupported()) {
        _isModelAvailable = false;
        _modelLoaded = false;
        notifyListeners();
        return;
      }
      final loaded = await _bridge.isLoaded();
      _isModelAvailable = true;
      _modelLoaded = loaded;
      notifyListeners();
    } catch (e) {
      _isModelAvailable = false;
      _modelLoaded = false;
      debugPrint('ML model not available: $e');
    }
  }

  Future<void> loadModel({void Function(double progress)? onProgress}) async {
    if (_modelLoaded) return;

    await _localAi.initialize();
    if (_localAi.modelAvailable) {
      _modelLoaded = true;
      _isModelAvailable = true;
      onProgress?.call(1.0);
      notifyListeners();
      return;
    }

    if (_isModelAvailable && !_modelLoaded) {
      try {
        await _bridge.loadModel();
        _modelLoaded = true;
        onProgress?.call(1.0);
      } catch (e) {
        debugPrint('Model load failed: $e');
      }
      notifyListeners();
    }
  }

  static final _fallbackProphecies = [
    (SensorData d) =>
        '电量${d.battery ?? 50}%时，你的拇指滑屏速度会比平时快${((d.battery ?? 50) % 5 + 1) * 0.2}倍',
    (SensorData d) =>
        '今日步数${d.steps}步，你的手指比预期早了${((d.battery ?? 50) % 7) * 0.1}秒划到下一张图',
    (SensorData d) =>
        '屏幕亮度${d.brightness}%时，你的下一口呼吸比上一口重${(((d.battery ?? 50) % 3) + 1) * 0.001}克',
    (SensorData d) =>
        '电量${d.battery ?? 50}%且${d.isMoving ? "正在移动" : "静止"}，你接下来的路会踩到一片落叶',
    (SensorData d) =>
        '步数破${(d.steps / 1000).ceil()}k时，你划过的第${((d.battery ?? 50) % 5) + 1}条视频会讲一只猫的名字',
    (SensorData d) =>
        '当前状态${d.timeHint}，你的眼角余光会捕捉到一只路过的小鸟',
    (SensorData d) =>
        '电量${d.battery ?? 50}%的此刻，你口袋里有一张被遗忘的小票在等你发现',
    (SensorData d) =>
        '${d.dayPhase}好！根据你${d.isMoving ? "正在移动" : "静止"}的状态推算，你下一次打哈欠会在${((d.battery ?? 50) % 8) + 2}分钟后',
    (SensorData d) =>
        '你的手机壳温度比平时高了${(((d.battery ?? 50) % 3) + 1) * 0.3}℃，说明你刚才握得比较紧',
    (SensorData d) =>
        '步数${d.steps}，你今天少走的${((d.battery ?? 50) % 200 + 50)}步会在明天变成小零食补回来',
    (SensorData d) =>
        '电量${d.battery ?? 50}%时，你更适合做需要耐心的决定——比如先刷哪条视频',
    (SensorData d) =>
        '现在是${d.dayPhase}，你大脑的多巴胺水平比上午低了${((d.battery ?? 50) % 20) + 5}%',
    (SensorData d) =>
        '你的手机处于${d.brightness > 60 ? "高亮度" : "省电模式"}状态，你的心情指数也类似',
    (SensorData d) =>
        '检测到你在${d.timeHint}，接下来适合做创意的白日梦',
  ];

  Future<String> generateProphecy(SensorData sensor) async {
    final fresh = sensor.withCurrentTimeHints();
    _loading = true;
    notifyListeners();

    String prophecy;

    if (_localAi.modelAvailable) {
      final result = await _localAi.generate(
        battery: fresh.battery ?? 50,
        brightness: fresh.brightness,
        steps: fresh.steps,
        isMoving: fresh.isMoving,
        ambientLight: fresh.ambientLight,
        timeHint: fresh.timeHint,
        dayPhase: fresh.dayPhase,
      );
      prophecy = result ?? _getFallbackProphecy(fresh);
    } else if (_modelLoaded && _isModelAvailable) {
      try {
        prophecy = await _bridge.generateProphecy(
          battery: fresh.battery ?? 50,
          brightness: fresh.brightness,
          steps: fresh.steps,
          isMoving: fresh.isMoving,
          ambientLight: fresh.ambientLight,
          timeHint: fresh.timeHint,
          dayPhase: fresh.dayPhase,
        );
        if (prophecy.startsWith('🤖')) {
          prophecy = _getFallbackProphecy(fresh);
        }
      } catch (e) {
        debugPrint('ML generation failed, using fallback: $e');
        prophecy = _getFallbackProphecy(fresh);
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 800));
      prophecy = _getFallbackProphecy(fresh);
    }

    _currentProphecy = prophecy;
    _history.insert(
      0,
      ProphecyRecord.fromSensor(
        text: prophecy,
        battery: fresh.battery,
        brightness: fresh.brightness,
        steps: fresh.steps,
        isMoving: fresh.isMoving,
      ),
    );
    if (_history.length > _maxHistory) {
      _history.removeLast();
    }
    await _saveHistory();

    _loading = false;
    notifyListeners();
    return prophecy;
  }

  String _getFallbackProphecy(SensorData sensor) {
    final idx = ((sensor.battery ?? 50) +
            sensor.brightness +
            sensor.steps % 10 +
            sensor.timestamp.minute)
        .abs() %
        _fallbackProphecies.length;
    return _fallbackProphecies[idx](sensor);
  }

  Future<void> clearHistory() async {
    _history.clear();
    await _saveHistory();
    notifyListeners();
  }

  Future<void> deleteHistory(int i) async {
    if (i >= 0 && i < _history.length) {
      _history.removeAt(i);
      await _saveHistory();
      notifyListeners();
    }
  }

  String getLoadingText(int s) => _animalLoading[s % _animalLoading.length];
}
