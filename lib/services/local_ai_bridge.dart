import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_ai/flutter_local_ai.dart';

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
    required int battery,
    required int brightness,
    required int steps,
    required bool isMoving,
    required int ambientLight,
    required String timeHint,
    required String dayPhase,
  }) async {
    if (!_modelAvailable || !_initialized) return null;

    final prompt = _buildPrompt(
      battery: battery,
      brightness: brightness,
      steps: steps,
      isMoving: isMoving,
      ambientLight: ambientLight,
      timeHint: timeHint,
      dayPhase: dayPhase,
    );

    try {
      final config = GenerationConfig(
        maxTokens: 80,
        temperature: 0.9,
      );
      final AiResponse response = await _ai.generate(prompt, config: config);
      final text = response.text.trim();
      if (text.isEmpty) return null;
      return text;
    } catch (e) {
      debugPrint('AI generate failed: $e');
      return null;
    }
  }

  /// 构造 prompt，把传感器数据描述成场景
  String _buildPrompt({
    required int battery,
    required int brightness,
    required int steps,
    required bool isMoving,
    required int ambientLight,
    required String timeHint,
    required String dayPhase,
  }) {
    return '''你是一个有趣、无厘头的废话预言家。
请根据以下传感器数据生成一条简短（不超过 50 字）、有趣、带有禅意或无厘头风格的预言。

当前用户状态：
- 时间：$dayPhase · $timeHint
- 手机电量：$battery%
- 屏幕亮度：$brightness%
- 今日步数：$steps 步
- 身体状态：${isMoving ? "正在移动" : "静止"}
- 环境光线：$ambientLight lux

要求：
- 语气轻松幽默，带点哲理
- 使用中文
- 不超过 50 字
- 不要以「你」开头，直接说出预言''';
  }

  @override
  void dispose() {
    super.dispose();
  }
}
