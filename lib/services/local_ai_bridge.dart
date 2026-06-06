import 'package:flutter/foundation.dart';
import 'package:flutter_local_ai/flutter_local_ai.dart';

import '../config/prophecy_style.dart';

/// [FlutterLocalAi] 的封装层
/// 处理模型加载、卸载、预言生成，不可用时回退到本地逻辑
class LocalAiBridge extends ChangeNotifier {
  final FlutterLocalAi _ai = FlutterLocalAi();

  bool _initialized = false;
  bool _modelAvailable = false;
  bool _loading = false;
  double _progress = 0;

  bool get initialized => _initialized;
  bool get modelAvailable => _modelAvailable;
  bool get loading => _loading;
  double get progress => _progress;

  /// 检查本地 AI 是否可用并尝试初始化
  Future<void> initialize() async {
    if (_initialized) return;
    _loading = true;
    notifyListeners();

    try {
      _modelAvailable = await _ai.isAvailable();
      if (_modelAvailable) {
        await _ai.initialize();
      }
    } catch (e) {
      debugPrint('Local AI init failed: $e');
      _modelAvailable = false;
    } finally {
      _initialized = true;
      _loading = false;
      notifyListeners();
    }
  }

  /// 使用本地 AI 生成预言
  /// 返回 null 表示 AI 不可用或生成失败
  Future<String?> generate({
    required String prompt,
    double temperature = ProphecyStyle.temperature,
  }) async {
    if (!_modelAvailable || !_initialized) return null;

    try {
      final config = GenerationConfig(
        maxTokens: ProphecyStyle.maxTokens,
        temperature: temperature,
      );
      final AiResponse response =
          await _ai.generateText(prompt: prompt, config: config);
      final text = response.text.trim();
      if (text.isEmpty) return null;
      return text;
    } catch (e) {
      debugPrint('AI generate failed: $e');
      return null;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
