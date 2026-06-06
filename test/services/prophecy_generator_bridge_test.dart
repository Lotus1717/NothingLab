import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nonsense_prophet/services/prophecy_generator.dart';

import '../helpers/test_helpers.dart';

void main() {
  const channel = MethodChannel('com.nonsense_prophet/ml');
  late ProphecyGeneratorBridge bridge;

  setUp(() {
    initTestBindings();
    bridge = ProphecyGeneratorBridge();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
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

    test('generateProphecy 应返回空字符串当平台不支持', () async {
      final result = await bridge.generateProphecy(prompt: '测试 prompt');
      expect(result, isEmpty);
    });

    test('generateProphecy 应正常返回预言', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
        if (methodCall.method == 'generateProphecy') {
          return '电量50%时，你的拇指滑屏速度会比平时快1.2倍';
        }
        return null;
      });

      final result = await bridge.generateProphecy(prompt: '测试 prompt');
      expect(result, '电量50%时，你的拇指滑屏速度会比平时快1.2倍');
    });

    test('generateProphecy 应将 prompt 传递给 native', () async {
      Map<String, dynamic>? capturedArgs;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
        if (methodCall.method == 'generateProphecy') {
          capturedArgs = Map<String, dynamic>.from(
            methodCall.arguments as Map<dynamic, dynamic>,
          );
          return '测试预言';
        }
        return null;
      });

      const testPrompt = '<|im_start|>system\n废话预言家\n<|im_start|>assistant';
      await bridge.generateProphecy(prompt: testPrompt);

      expect(capturedArgs, isNotNull);
      expect(capturedArgs!['prompt'], testPrompt);
    });

    test('isDownloading 应返回 false 当平台不支持', () async {
      expect(await bridge.isDownloading(), isFalse);
    });

    test('loadModel 平台异常时应向上抛出', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
        if (methodCall.method == 'loadModel') {
          throw PlatformException(
            code: 'MODEL_LOAD_ERROR',
            message: 'The Internet connection appears to be offline.',
          );
        }
        return null;
      });
      expect(bridge.loadModel(), throwsA(isA<PlatformException>()));
    });

    test('unloadModel 不应抛出异常', () async {
      await bridge.unloadModel();
    });
  });
}
