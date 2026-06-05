import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 与 iOS 原生 MLX 模型通信的桥梁
class ProphecyGeneratorBridge {
  static const _channel = MethodChannel('com.nonsense_prophet/ml');

  /// 模型是否已加载
  /// 原生 MLX 插件是否存在于当前平台
  Future<bool> isPlatformSupported() async {
    try {
      await _channel.invokeMethod('isLoaded');
      return true;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isLoaded() async {
    try {
      return await _channel.invokeMethod('isLoaded') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 模型加载进度 (0.0 ~ 1.0)
  Future<double> getLoadProgress() async {
    try {
      return await _channel.invokeMethod('getLoadProgress') ?? 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  /// 是否正在下载
  Future<bool> isDownloading() async {
    try {
      return await _channel.invokeMethod('isDownloading') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 开始加载模型（首次会下载，后续从缓存加载）
  Future<void> loadModel() async {
    try {
      await _channel.invokeMethod('loadModel');
    } on PlatformException catch (e) {
      debugPrint('Model load failed: ${e.message}');
    } catch (e) {
      debugPrint('Model load failed: $e');
    }
  }

  /// 生成预言
  Future<String> generateProphecy({
    required int battery,
    required int brightness,
    required int steps,
    required bool isMoving,
    required int ambientLight,
    required String timeHint,
    required String dayPhase,
  }) async {
    try {
      final result = await _channel.invokeMethod<String>('generateProphecy', {
        'battery': battery,
        'brightness': brightness,
        'steps': steps,
        'isMoving': isMoving,
        'ambientLight': ambientLight,
        'timeHint': timeHint,
        'dayPhase': dayPhase,
      });
      return result ?? '🤖 预言生成失败，再来一次？';
    } on PlatformException catch (e) {
      return '🤖 梦境信号不好… ${e.message}';
    } catch (_) {
      return '🤖 预言生成失败，再来一次？';
    }
  }

  /// 卸载模型释放内存
  Future<void> unloadModel() async {
    try {
      await _channel.invokeMethod('unloadModel');
    } catch (_) {}
  }
}
