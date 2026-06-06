import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/preferred_engine.dart';
import '../config/prophecy_style.dart';
import '../models/prophecy_record.dart';
import '../models/sensor_data.dart';
import '../utils/prophecy_normalizer.dart';
import '../utils/prophecy_prompt_builder.dart';
import 'deepseek_client.dart';
import 'local_ai_bridge.dart';
import 'prophecy_generator.dart';

/// 废话生成来源
enum ProphecyEngine {
  qwen,
  localAi,
  deepseek,
  template;

  String get label => switch (this) {
        ProphecyEngine.qwen => '千问',
        ProphecyEngine.localAi => '苹果本地',
        ProphecyEngine.deepseek => 'DeepSeek',
        ProphecyEngine.template => '模板库',
      };
}

class AiService extends ChangeNotifier {
  static const _favoritesKey = 'prophecy_favorites_v1';
  static const _preferredEngineKey = 'preferred_engine_v2';
  static const _deepseekApiKeyKey = 'deepseek_api_key_v1';
  static const _maxFavorites = 30;

  bool _loading = false;
  bool _modelLoaded = false;
  bool _isModelAvailable = false;
  bool _mlxPlatformSupported = false;
  bool _preferenceLoaded = false;
  PreferredEngine _preferredEngine = PreferredEngine.apple;
  String? _deepseekApiKey;
  String? _lastDeepSeekError;
  String? _lastLoadError;
  ProphecyEngine _lastProphecyEngine = ProphecyEngine.template;
  String _currentProphecy = '';
  int _generationSeq = 0;
  List<ProphecyRecord> _favorites = [];

  final LocalAiBridge _localAi = LocalAiBridge();
  final ProphecyGeneratorBridge _bridge = ProphecyGeneratorBridge();
  final DeepSeekClient _deepseek;

  AiService({DeepSeekClient? deepseekClient})
      : _deepseek = deepseekClient ?? DeepSeekClient() {
    _loadFavorites();
  }

  bool get loading => _loading;
  bool get modelLoaded => _modelLoaded;
  bool get isModelAvailable => _isModelAvailable;
  bool get mlxPlatformSupported => _mlxPlatformSupported;
  PreferredEngine get preferredEngine => _preferredEngine;
  bool get appleLocalReady =>
      _localAi.initialized && _localAi.modelAvailable;
  String? get lastLoadError => _lastLoadError;
  String? get lastDeepSeekError => _lastDeepSeekError;
  bool get deepseekConfigured =>
      _deepseekApiKey != null && _deepseekApiKey!.trim().isNotEmpty;
  ProphecyEngine get lastProphecyEngine => _lastProphecyEngine;
  ProphecyEngine get plannedProphecyEngine => switch (_preferredEngine) {
        PreferredEngine.apple => ProphecyEngine.localAi,
        PreferredEngine.qwen => ProphecyEngine.qwen,
        PreferredEngine.deepseek => ProphecyEngine.deepseek,
        PreferredEngine.template => ProphecyEngine.template,
      };

  /// 首页角标：下一次戳小猫将使用的生成途径
  ProphecyEngine get displayEngine => plannedProphecyEngine;

  String get currentProphecy => _currentProphecy;
  int get generationSeq => _generationSeq;
  List<ProphecyRecord> get favorites => List.unmodifiable(_favorites);
  bool get isCurrentFavorited =>
      _currentProphecy.isNotEmpty &&
      _favorites.any((f) => f.text == _currentProphecy);
  LocalAiBridge get localAi => _localAi;

  static const _animalLoading = [
    '🐱 小猫正在抓阄中...',
    '🦊 小狐狸在编废话...',
    '🐢 乌龟在认真思考...',
    '🐰 小兔子在翻预言书...',
    '🦡 獾子在推算命运...',
  ];

  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_favoritesKey);
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw) as List<dynamic>;
      _favorites = list
          .map((e) => ProphecyRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Load favorites failed: $e');
    }
  }

  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_favorites.map((e) => e.toJson()).toList());
      await prefs.setString(_favoritesKey, encoded);
    } catch (e) {
      debugPrint('Save favorites failed: $e');
    }
  }

  /// 与原生侧同步模型加载状态（设置页唤醒后、回前台时调用）
  Future<void> syncModelState() async {
    await checkModelAvailability();
  }

  Future<void> checkModelAvailability() async {
    _mlxPlatformSupported = await _bridge.isPlatformSupported();
    await _localAi.initialize();
    await _ensurePreferredEngineLoaded();
    await _loadDeepSeekApiKey();

    if (_mlxPlatformSupported) {
      try {
        final loaded = await _bridge.isLoaded();
        _isModelAvailable = true;
        _modelLoaded = loaded;
      } catch (e) {
        _isModelAvailable = _mlxPlatformSupported;
        _modelLoaded = false;
        debugPrint('ML model not available: $e');
      }
    } else {
      _isModelAvailable = appleLocalReady;
      _modelLoaded = false;
    }

    notifyListeners();
  }

  Future<void> setDeepSeekApiKey(String key) async {
    final trimmed = key.trim();
    _deepseekApiKey = trimmed.isEmpty ? null : trimmed;
    _lastDeepSeekError = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_deepseekApiKey == null) {
        await prefs.remove(_deepseekApiKeyKey);
      } else {
        await prefs.setString(_deepseekApiKeyKey, _deepseekApiKey!);
      }
    } catch (e) {
      debugPrint('Save DeepSeek API key failed: $e');
    }
    notifyListeners();
  }

  Future<void> _loadDeepSeekApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_deepseekApiKeyKey);
      _deepseekApiKey =
          saved != null && saved.trim().isNotEmpty ? saved.trim() : null;
    } catch (e) {
      debugPrint('Load DeepSeek API key failed: $e');
      _deepseekApiKey = null;
    }
  }

  Future<void> setPreferredEngine(PreferredEngine engine) async {
    _preferredEngine = engine;
    _preferenceLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_preferredEngineKey, engine.storageValue);
    } catch (e) {
      debugPrint('Save preferred engine failed: $e');
    }
    notifyListeners();
  }

  Future<void> _ensurePreferredEngineLoaded() async {
    if (_preferenceLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = PreferredEngine.fromStorage(
        prefs.getString(_preferredEngineKey),
      );
      _preferredEngine = saved ?? _defaultPreferredEngine();
    } catch (e) {
      debugPrint('Load preferred engine failed: $e');
      _preferredEngine = _defaultPreferredEngine();
    }
    _preferenceLoaded = true;
  }

  PreferredEngine _defaultPreferredEngine() {
    if (!kIsWeb && Platform.isIOS) return PreferredEngine.apple;
    if (_mlxPlatformSupported) return PreferredEngine.qwen;
    return PreferredEngine.template;
  }

  Future<void> loadModel({void Function(double progress)? onProgress}) async {
    if (_modelLoaded) return;

    _lastLoadError = null;
    _mlxPlatformSupported = await _bridge.isPlatformSupported();
    if (!_mlxPlatformSupported) {
      _lastLoadError = '当前设备不支持内置千问模型';
      notifyListeners();
      return;
    }

    _isModelAvailable = true;
    Timer? progressTimer;
    try {
      progressTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
        unawaited(_pollLoadProgress(onProgress));
      });
      await _bridge.loadModel();
      _modelLoaded = await _bridge.isLoaded();
      if (_modelLoaded) {
        onProgress?.call(1.0);
      } else {
        _lastLoadError = '内置模型加载未完成，请重试';
        debugPrint('MLX model load finished but isLoaded=false');
      }
    } on PlatformException catch (e) {
      _lastLoadError = _friendlyLoadError(e);
      debugPrint('Model load failed: ${e.message}');
    } catch (e) {
      _lastLoadError = '唤醒失败，请稍后重试';
      debugPrint('Model load failed: $e');
    } finally {
      progressTimer?.cancel();
      notifyListeners();
    }
  }

  bool _shouldUseMlx() =>
      _preferredEngine == PreferredEngine.qwen &&
      _mlxPlatformSupported &&
      _modelLoaded;

  bool _shouldUseAppleLocal() =>
      _preferredEngine == PreferredEngine.apple && appleLocalReady;

  bool _shouldUseDeepSeek() =>
      _preferredEngine == PreferredEngine.deepseek && deepseekConfigured;

  Future<void> _pollLoadProgress(void Function(double progress)? onProgress) async {
    try {
      final progress = await _bridge.getLoadProgress();
      if (progress > 0) {
        onProgress?.call(progress.clamp(0.0, 1.0));
      }
    } catch (e) {
      debugPrint('Load progress poll failed: $e');
    }
  }

  static String _friendlyLoadError(PlatformException e) {
    final msg = (e.message ?? '').toLowerCase();
    if (msg.contains('missing') || msg.contains('bundled') || msg.contains('内置')) {
      return '内置模型文件缺失，请重新安装应用';
    }
    if (msg.contains('memory') || msg.contains('space') || msg.contains('disk')) {
      return '存储或内存不足，请腾出空间后重试';
    }
    if (e.message != null && e.message!.isNotEmpty) {
      return '唤醒失败：${e.message}';
    }
    return '唤醒失败，请稍后重试';
  }

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

    if (_preferredEngine == PreferredEngine.template) {
      await Future.delayed(const Duration(milliseconds: 800));
      prophecy = _getFallbackProphecy(fresh, salt: nonce);
      engine = ProphecyEngine.template;
    } else if (_shouldUseAppleLocal()) {
      prophecy = await _generateWithQualityGate(
        () => _localAi.generate(
          prompt: ProphecyPromptBuilder.buildPrompt(fresh, nonce: nonce),
        ),
        () => _localAi.generate(
          prompt: ProphecyPromptBuilder.buildPrompt(
            fresh,
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
    } else if (_shouldUseMlx()) {
      try {
        prophecy = await _generateMlxWithQualityGate(fresh, nonce: nonce);
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
    } else if (_shouldUseDeepSeek()) {
      try {
        _lastDeepSeekError = null;
        prophecy = await _generateWithQualityGate(
          () => _deepseek.generate(
            apiKey: _deepseekApiKey!,
            sensor: fresh,
            nonce: nonce,
          ),
          () => _deepseek.generate(
            apiKey: _deepseekApiKey!,
            sensor: fresh,
            nonce: nonce + 1000,
            temperature: ProphecyStyle.retryTemperature,
          ),
        );
        if (prophecy.isEmpty) {
          prophecy = _getFallbackProphecy(fresh, salt: nonce);
          engine = ProphecyEngine.template;
        } else {
          engine = ProphecyEngine.deepseek;
        }
      } on DeepSeekException catch (e) {
        _lastDeepSeekError = e.message;
        debugPrint('DeepSeek generation failed: ${e.message}');
        prophecy = _getFallbackProphecy(fresh, salt: nonce);
        engine = ProphecyEngine.template;
      } catch (e) {
        _lastDeepSeekError = '云端生成失败，请稍后重试';
        debugPrint('DeepSeek generation failed: $e');
        prophecy = _getFallbackProphecy(fresh, salt: nonce);
        engine = ProphecyEngine.template;
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 800));
      prophecy = _getFallbackProphecy(fresh, salt: nonce);
      engine = ProphecyEngine.template;
    }

    prophecy = ProphecyNormalizer.normalizeProphecy(prophecy);
    final distinct = _ensureDistinctProphecy(
      prophecy,
      previous: previous,
      sensor: fresh,
      salt: nonce,
    );
    if (distinct != prophecy &&
        (engine == ProphecyEngine.qwen || engine == ProphecyEngine.deepseek)) {
      engine = ProphecyEngine.template;
    }
    prophecy = distinct;

    _lastProphecyEngine = engine;
    _currentProphecy = prophecy;

    _loading = false;
    notifyListeners();
    return prophecy;
  }

  /// MLX 路径：结构化 chat + 传感器锚定质量门，不合格最多重试 1 次
  Future<String> _generateMlxWithQualityGate(
    SensorData sensor, {
    required int nonce,
  }) async {
    Future<String?> generate(int salt) async {
      final chat = ProphecyPromptBuilder.buildMlxChat(
        sensor,
        nonce: nonce + salt,
      );
      final raw = await _bridge.generateProphecy(
        systemPrompt: chat.system,
        userPrompt: chat.user,
      );
      if (ProphecyNormalizer.isMlxProphecy(raw, sensor)) {
        return ProphecyNormalizer.normalizeProphecy(raw);
      }
      return null;
    }

    return (await generate(0)) ?? (await generate(1000)) ?? '';
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

  /// 收藏当前展示的废话；已收藏则返回 false
  Future<bool> likeCurrentProphecy(SensorData sensor) async {
    final text = _currentProphecy;
    if (text.isEmpty || isCurrentFavorited) return false;

    _favorites.insert(
      0,
      ProphecyRecord.fromSensor(
        text: text,
        battery: sensor.battery,
        brightness: sensor.brightness,
        steps: sensor.steps,
        isMoving: sensor.isMoving,
        volume: sensor.isRealVolume ? sensor.volume : null,
        ambientLight:
            sensor.isRealAmbientLight || sensor.isEstimatedAmbientLight
                ? sensor.ambientLight
                : null,
      ),
    );
    if (_favorites.length > _maxFavorites) {
      _favorites.removeLast();
    }
    await _saveFavorites();
    notifyListeners();
    return true;
  }

  Future<void> clearFavorites() async {
    _favorites.clear();
    await _saveFavorites();
    notifyListeners();
  }

  Future<void> deleteFavorite(int i) async {
    if (i >= 0 && i < _favorites.length) {
      _favorites.removeAt(i);
      await _saveFavorites();
      notifyListeners();
    }
  }

  String getLoadingText(int s) => _animalLoading[s % _animalLoading.length];
}
