import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nonsense_prophet/services/prophecy_generator.dart';

void main() {
  const channel = MethodChannel('com.nonsense_prophet/ml');
  late ProphecyGeneratorBridge bridge;

  setUp(() {
    bridge = ProphecyGeneratorBridge();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null); // 清除 mock
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('ProphecyGeneratorBridge', () {
    test('isLoaded 应返回 false 当平台不支持', () async {
      expect(await bridge.isLoaded(), isFalse);
    });

    test('isLoaded 应返回 true 当平台支持且已加载', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
        if (methodCall.method == 'isLoaded') return true;
        return null;
      });
      expect(await bridge.isLoaded(), isTrue);
    });

    test('getLoadProgress 应返回 0 当平台不支持', () async {
      expect(await bridge.getLoadProgress(), 0.0);
    });

    test('generateProphecy 应返回默认消息当平台不支持', () async {
      final result = await bridge.generateProphecy(
        battery: 50,
        brightness: 60,
        steps: 3000,
        isMoving: true,
        ambientLight: 200,
        timeHint: '下午摸鱼中',
        dayPhase: '下午',
      );
      expect(result, contains('🤖'));
    });

    test('generateProphecy 应正常返回预言', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
        if (methodCall.method == 'generateProphecy') {
          return '🐱 你的猫会在3分钟后挠你的拖鞋';
        }
        return null;
      });

      final result = await bridge.generateProphecy(
        battery: 50,
        brightness: 60,
        steps: 3000,
        isMoving: true,
        ambientLight: 200,
        timeHint: '下午摸鱼中',
        dayPhase: '下午',
      );
      expect(result, '🐱 你的猫会在3分钟后挠你的拖鞋');
    });

    test('generateProphecy 参数应正确传递给 native', () async {
      Map<String, dynamic>? capturedArgs;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
        if (methodCall.method == 'generateProphecy') {
          capturedArgs = methodCall.arguments as Map<String, dynamic>;
          return '测试预言';
        }
        return null;
      });

      await bridge.generateProphecy(
        battery: 42,
        brightness: 75,
        steps: 1234,
        isMoving: false,
        ambientLight: 300,
        timeHint: '中午懒洋洋',
        dayPhase: '中午',
      );

      expect(capturedArgs, isNotNull);
      expect(capturedArgs!['battery'], 42);
      expect(capturedArgs!['brightness'], 75);
      expect(capturedArgs!['steps'], 1234);
      expect(capturedArgs!['isMoving'], false);
      expect(capturedArgs!['ambientLight'], 300);
      expect(capturedArgs!['timeHint'], '中午懒洋洋');
      expect(capturedArgs!['dayPhase'], '中午');
    });

    test('isDownloading 应返回 false 当平台不支持', () async {
      expect(await bridge.isDownloading(), isFalse);
    });

    test('loadModel 应优雅处理平台异常', () async {
      // 平台不支持时不会抛出异常（catch 内部处理）
      await bridge.loadModel();
    });

    test('unloadModel 不应抛出异常', () async {
      await bridge.unloadModel();
    });
  });
}
