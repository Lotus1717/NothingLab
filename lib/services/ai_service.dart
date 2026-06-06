import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/prophecy_style.dart';
import '../models/prophecy_record.dart';
import '../models/sensor_data.dart';
import '../utils/prophecy_normalizer.dart';
import '../utils/prophecy_prompt_builder.dart';
import 'local_ai_bridge.dart';
import 'prophecy_generator.dart';

/// 废话生成来源
enum ProphecyEngine {
  qwen,
  localAi,
  template;

  String get label => switch (this) {
        ProphecyEngine.qwen => '千问',
        ProphecyEngine.localAi => '本地AI',
        ProphecyEngine.template => '模板库',
      };
}

class AiService extends ChangeNotifier {
  static const _historyKey = 'prophecy_history_v1';
  static const _maxHistory = 30;

  bool _loading = false;
  bool _modelLoaded = false;
  bool _isModelAvailable = false;
  bool _mlxPlatformSupported = false;
  ProphecyEngine _lastProphecyEngine = ProphecyEngine.template;
  String _currentProphecy = '';
  int _generationSeq = 0;
  List<ProphecyRecord> _history = [];

  final LocalAiBridge _localAi = LocalAiBridge();
  final ProphecyGeneratorBridge _bridge = ProphecyGeneratorBridge();

  bool get loading => _loading;
  bool get modelLoaded => _modelLoaded;
  bool get isModelAvailable => _isModelAvailable;
  bool get mlxPlatformSupported => _mlxPlatformSupported;
  ProphecyEngine get lastProphecyEngine => _lastProphecyEngine;
  ProphecyEngine get plannedProphecyEngine {
    if (_shouldUseMlx()) return ProphecyEngine.qwen;
    if (_localAi.modelAvailable) return ProphecyEngine.localAi;
    return ProphecyEngine.template;
  }

  /// 首页展示：有废话时显示上次来源，否则显示即将使用的引擎
  ProphecyEngine get displayEngine =>
      _currentProphecy.isNotEmpty ? _lastProphecyEngine : plannedProphecyEngine;

  String get currentProphecy => _currentProphecy;
  int get generationSeq => _generationSeq;
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
    _mlxPlatformSupported = await _bridge.isPlatformSupported();

    if (_mlxPlatformSupported) {
      try {
        final loaded = await _bridge.isLoaded();
        _isModelAvailable = true;
        _modelLoaded = loaded;
      } catch (e) {
        _isModelAvailable = false;
        _modelLoaded = false;
        debugPrint('ML model not available: $e');
      }
      notifyListeners();
      return;
    }

    await _localAi.initialize();
    if (_localAi.modelAvailable) {
      _isModelAvailable = true;
      _modelLoaded = true;
      notifyListeners();
      return;
    }

    _isModelAvailable = false;
    _modelLoaded = false;
    notifyListeners();
  }

  Future<void> loadModel({void Function(double progress)? onProgress}) async {
    if (_modelLoaded) return;

    _mlxPlatformSupported = await _bridge.isPlatformSupported();
    if (_mlxPlatformSupported) {
      _isModelAvailable = true;
      try {
        await _bridge.loadModel();
        _modelLoaded = await _bridge.isLoaded();
        if (_modelLoaded) {
          _isModelAvailable = true;
          onProgress?.call(1.0);
        } else {
          debugPrint('MLX model load finished but isLoaded=false');
        }
      } catch (e) {
        debugPrint('Model load failed: $e');
      }
      notifyListeners();
      return;
    }

    await _localAi.initialize();
    if (_localAi.modelAvailable) {
      _modelLoaded = true;
      _isModelAvailable = true;
      onProgress?.call(1.0);
      notifyListeners();
    }
  }

  bool _shouldUseMlx() =>
      _mlxPlatformSupported && _modelLoaded && _isModelAvailable;

  static final _fallbackProphecies = [
    (SensorData d) =>
        '电量${d.battery ?? 50}%时，你的拇指滑屏速度会比平时快${((d.battery ?? 50) % 5 + 1) * 0.2}倍',
    (SensorData d) =>
        '今日步数${d.steps}步，你的手指比预期早了${((d.battery ?? 50) % 7) * 0.1}秒划到下一张图',
    (SensorData d) =>
        '系统音量${d.volume}%时，你听到的下一句废话会比上一句响${((d.volume % 5) + 1) * 0.1}分贝',
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
        '屏幕亮度${d.brightness}%时，你的瞳孔会比平时多收缩${((d.brightness % 4) + 1) * 0.1}毫米',
    (SensorData d) =>
        '环境光线${d.ambientLight}勒克斯时，你眼角余光会多捕捉到${((d.ambientLight % 3) + 1)}粒灰尘',
    (SensorData d) =>
        '${d.timeHint}音量${d.volume}%时，接下来适合做创意的白日梦',
  ];

  Future<String> generateProphecy(SensorData sensor) async {
    if (_loading) return _currentProphecy;

    final fresh = sensor.withCurrentTimeHints();
    final previous = _currentProphecy;
    final nonce = ++_generationSeq;

    _loading = true;
    notifyListeners();

    String prophecy;
    ProphecyEngine engine;

    if (_shouldUseMlx()) {
      try {
        prophecy = await _generateWithQualityGate(
          () => _bridge.generateProphecy(
            prompt: ProphecyPromptBuilder.buildChatMLPrompt(
              fresh,
              avoidText: previous,
              nonce: nonce,
            ),
          ),
          () => _bridge.generateProphecy(
            prompt: ProphecyPromptBuilder.buildChatMLPrompt(
              fresh,
              avoidText: previous,
              nonce: nonce + 1000,
            ),
          ),
        );
        if (prophecy.isEmpty) {
          prophecy = _getFallbackProphecy(fresh, salt: nonce);
          engine = ProphecyEngine.template;
        } else {
          engine = ProphecyEngine.qwen;
        }
      } catch (e) {
        debugPrint('ML generation failed, using fallback: $e');
        prophecy = _getFallbackProphecy(fresh, salt: nonce);
        engine = ProphecyEngine.template;
      }
    } else if (_localAi.modelAvailable) {
      prophecy = await _generateWithQualityGate(
        () => _localAi.generate(
          prompt: ProphecyPromptBuilder.buildPrompt(
            fresh,
            avoidText: previous,
            nonce: nonce,
          ),
        ),
        () => _localAi.generate(
          prompt: ProphecyPromptBuilder.buildPrompt(
            fresh,
            avoidText: previous,
            nonce: nonce + 1000,
          ),
          temperature: ProphecyStyle.retryTemperature,
        ),
      );
      if (prophecy.isEmpty) {
        prophecy = _getFallbackProphecy(fresh, salt: nonce);
        engine = ProphecyEngine.template;
      } else {
        engine = ProphecyEngine.localAi;
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 800));
      prophecy = _getFallbackProphecy(fresh, salt: nonce);
      engine = ProphecyEngine.template;
    }

    prophecy = ProphecyNormalizer.normalizeProphecy(prophecy);
    prophecy = _ensureDistinctProphecy(
      prophecy,
      previous: previous,
      sensor: fresh,
      salt: nonce,
    );

    _lastProphecyEngine = engine;
    _currentProphecy = prophecy;
    _history.insert(
      0,
      ProphecyRecord.fromSensor(
        text: prophecy,
        battery: fresh.battery,
        brightness: fresh.brightness,
        steps: fresh.steps,
        isMoving: fresh.isMoving,
        volume: fresh.isRealVolume ? fresh.volume : null,
        ambientLight: fresh.isRealAmbientLight ? fresh.ambientLight : null,
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

  /// AI 路径：首次生成 + 质量门，不合格最多重试 1 次
  Future<String> _generateWithQualityGate(
    Future<String?> Function() generate,
    Future<String?> Function() retry,
  ) async {
    String? softCandidate;

    var raw = await generate();
    var text = ProphecyNormalizer.normalizeProphecy(raw ?? '');
    if (text.isNotEmpty && ProphecyNormalizer.isAcceptableProphecy(text)) {
      return text;
    }
    if (text.isNotEmpty && ProphecyNormalizer.isSoftAcceptableProphecy(text)) {
      softCandidate = text;
    }

    raw = await retry();
    text = ProphecyNormalizer.normalizeProphecy(raw ?? '');
    if (text.isNotEmpty && ProphecyNormalizer.isAcceptableProphecy(text)) {
      return text;
    }
    if (text.isNotEmpty && ProphecyNormalizer.isSoftAcceptableProphecy(text)) {
      return text;
    }
    return softCandidate ?? '';
  }

  String _getFallbackProphecy(SensorData sensor, {required int salt}) {
    final idx = ((sensor.battery ?? 50) +
            sensor.brightness +
            sensor.steps % 10 +
            sensor.timestamp.millisecond +
            salt)
        .abs() %
        _fallbackProphecies.length;
    return _fallbackProphecies[idx](sensor);
  }

  String _ensureDistinctProphecy(
    String prophecy, {
    required String previous,
    required SensorData sensor,
    required int salt,
  }) {
    if (prophecy.isEmpty) {
      return _getFallbackProphecy(sensor, salt: salt);
    }
    if (previous.isEmpty || prophecy != previous) return prophecy;

    var alt = _getFallbackProphecy(sensor, salt: salt + 1);
    if (alt != previous) return alt;

    alt = _getFallbackProphecy(sensor, salt: salt + 2);
    return alt == previous ? prophecy : alt;
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
