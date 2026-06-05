import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nonsense_prophet/models/sensor_data.dart';
import 'package:nonsense_prophet/services/ai_service.dart';
import '../helpers/test_helpers.dart';

void main() {
  const channel = MethodChannel('com.nonsense_prophet/ml');
  late AiService aiService;

  setUp(() {
    initTestBindings();
    mockAllPlatformChannels();
    aiService = AiService();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  tearDown(() {
    aiService.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('AiService 初始化', () {
    test('初始状态应正确', () {
      expect(aiService.loading, isFalse);
      expect(aiService.modelLoaded, isFalse);
      expect(aiService.isModelAvailable, isFalse);
      expect(aiService.currentProphecy, isEmpty);
      expect(aiService.history, isEmpty);
    });

    test('checkModelAvailability 应标记为不可用（非 iOS 平台）', () async {
      await aiService.checkModelAvailability();
      expect(aiService.isModelAvailable, isFalse);
      expect(aiService.modelLoaded, isFalse);
    });

    test('checkModelAvailability 应识别可用的 ML 模型', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
        if (methodCall.method == 'isLoaded') return false;
        return null;
      });
      await aiService.checkModelAvailability();
      expect(aiService.isModelAvailable, isTrue);
      expect(aiService.modelLoaded, isFalse);
    });
  });

  group('AiService 预言生成', () {
    test('generateProphecy 应生成本地回退预言', () async {
      final sensor = SensorData.mock();
      final prophecy = await aiService.generateProphecy(sensor);

      expect(prophecy, isNotEmpty);
      expect(prophecy, contains(RegExp(r'电量|步数|亮度|状态|移动')));
      expect(aiService.loading, isFalse);
    });

    test('generateProphecy 应记录到历史', () async {
      final sensor = SensorData.mock();
      await aiService.generateProphecy(sensor);

      expect(aiService.history.length, equals(1));
      expect(aiService.history[0].text, isNotEmpty);
    });

    test('多次生成应按倒序排列历史', () async {
      final sensor = SensorData.mock();
      await aiService.generateProphecy(sensor);
      await aiService.generateProphecy(sensor);

      expect(aiService.history.length, equals(2));
    });

    test('历史超过 30 条应自动清理旧记录', () async {
      final sensor = SensorData.mock();
      for (int i = 0; i < 35; i++) {
        await aiService.generateProphecy(sensor);
      }
      expect(aiService.history.length, equals(30));
    });

    test('currentProphecy 应更新为最新预言', () async {
      final sensor = SensorData.mock();
      final prophecy = await aiService.generateProphecy(sensor);
      expect(aiService.currentProphecy, equals(prophecy));
    });
  });

  group('AiService 历史管理', () {
    test('clearHistory 应清空所有记录', () async {
      final sensor = SensorData.mock();
      await aiService.generateProphecy(sensor);
      await aiService.generateProphecy(sensor);
      expect(aiService.history.length, 2);

      await aiService.clearHistory();
      expect(aiService.history, isEmpty);
    });

    test('deleteHistory 应删除指定索引', () async {
      final sensor = SensorData.mock();
      await aiService.generateProphecy(sensor);
      final secondSensor = sensor.copyWith(battery: 99);
      await aiService.generateProphecy(secondSensor);

      expect(aiService.history.length, 2);
      final secondText = aiService.history[0].text;

      await aiService.deleteHistory(0);
      expect(aiService.history.length, 1);
      expect(aiService.history[0].text, isNot(equals(secondText)));
    });

    test('deleteHistory 越界不应抛异常', () async {
      await aiService.deleteHistory(0);
      await aiService.deleteHistory(-1);
      await aiService.deleteHistory(100);
    });
  });

  group('AiService 本地预言', () {
    test('不同传感器数据应生成不同预言', () async {
      final sensorA = SensorData.mock();
      final sensorB = sensorA.copyWith(battery: 10, steps: 99999);

      await aiService.generateProphecy(sensorA);
      aiService.clearHistory();
      await aiService.generateProphecy(sensorB);
    });

    test('预言应包含传感器相关数据', () async {
      final sensor = SensorData.mock();
      final prophecy = await aiService.generateProphecy(sensor);

      final hasSensorRef = prophecy.contains(RegExp(r'电量|步数|亮度|状态|移动'));
      expect(hasSensorRef, isTrue,
          reason: '预言应包括传感器引用，实际: $prophecy');
    });

    test('getLoadingText 应循环返回不同加载文案', () {
      final texts = List.generate(10, (i) => aiService.getLoadingText(i));
      final unique = texts.toSet();
      expect(unique.length, greaterThan(1));
    });
  });

  group('AiService 与 ML 模型集成', () {
    test('ML 模型可用时应优先使用 ML 生成', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
        switch (methodCall.method) {
          case 'isLoaded':
            return true;
          case 'generateProphecy':
            return '🧠 AI 生成的深层预言：你下次眨眼会错过一只蝴蝶';
          default:
            return null;
        }
      });

      await aiService.checkModelAvailability();
      expect(aiService.isModelAvailable, isTrue);
      expect(aiService.modelLoaded, isTrue);

      final sensor = SensorData.mock();
      final prophecy = await aiService.generateProphecy(sensor);

      expect(prophecy, contains('AI'));
      expect(aiService.history.length, equals(1));
    });

    test('ML 模型生成失败时回退到本地', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
        switch (methodCall.method) {
          case 'isLoaded':
            return true;
          case 'generateProphecy':
            throw PlatformException(code: 'ML_FAILED', message: '模型异常');
          default:
            return null;
        }
      });

      await aiService.checkModelAvailability();
      final sensor = SensorData.mock();
      final prophecy = await aiService.generateProphecy(sensor);

      expect(prophecy, contains(RegExp(r'电量|步数|亮度|状态|移动')));
    });
  });
}
