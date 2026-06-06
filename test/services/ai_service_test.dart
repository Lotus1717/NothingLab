import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nonsense_prophet/config/preferred_engine.dart';
import 'package:nonsense_prophet/models/sensor_data.dart';
import 'package:nonsense_prophet/services/ai_service.dart';
import 'package:nonsense_prophet/services/deepseek_client.dart';
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
      expect(aiService.favorites, isEmpty);
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
      expect(aiService.loading, isFalse);
      expect(aiService.favorites, isEmpty);
    });

    test('generateProphecy 不应自动写入收藏', () async {
      final sensor = SensorData.mock();
      await aiService.generateProphecy(sensor);

      expect(aiService.favorites, isEmpty);
    });

    test('连续生成相同传感器数据时不应重复上一条', () async {
      final sensor = SensorData.mock();
      final first = await aiService.generateProphecy(sensor);
      final second = await aiService.generateProphecy(sensor);

      expect(second, isNotEmpty);
      expect(second, isNot(equals(first)));
    });

    test('currentProphecy 应更新为最新预言', () async {
      final sensor = SensorData.mock();
      final prophecy = await aiService.generateProphecy(sensor);
      expect(aiService.currentProphecy, equals(prophecy));
    });
  });

  group('AiService 收藏管理', () {
    test('likeCurrentProphecy 应加入收藏', () async {
      final sensor = SensorData.mock();
      await aiService.generateProphecy(sensor);
      final liked = await aiService.likeCurrentProphecy(sensor);

      expect(liked, isTrue);
      expect(aiService.favorites.length, equals(1));
      expect(aiService.favorites[0].text, aiService.currentProphecy);
      expect(aiService.isCurrentFavorited, isTrue);
    });

    test('重复喜欢同一条应返回 false', () async {
      final sensor = SensorData.mock();
      await aiService.generateProphecy(sensor);
      await aiService.likeCurrentProphecy(sensor);
      final again = await aiService.likeCurrentProphecy(sensor);

      expect(again, isFalse);
      expect(aiService.favorites.length, equals(1));
    });

    test('clearFavorites 应清空所有收藏', () async {
      final sensor = SensorData.mock();
      await aiService.generateProphecy(sensor);
      await aiService.likeCurrentProphecy(sensor);
      await aiService.generateProphecy(sensor);
      await aiService.likeCurrentProphecy(sensor);
      expect(aiService.favorites.length, 2);

      await aiService.clearFavorites();
      expect(aiService.favorites, isEmpty);
    });

    test('deleteFavorite 应删除指定索引', () async {
      final sensor = SensorData.mock();
      await aiService.generateProphecy(sensor);
      await aiService.likeCurrentProphecy(sensor);
      final secondSensor = sensor.copyWith(battery: 99);
      await aiService.generateProphecy(secondSensor);
      await aiService.likeCurrentProphecy(secondSensor);

      expect(aiService.favorites.length, 2);
      final secondText = aiService.favorites[0].text;

      await aiService.deleteFavorite(0);
      expect(aiService.favorites.length, 1);
      expect(aiService.favorites[0].text, isNot(equals(secondText)));
    });

    test('deleteFavorite 越界不应抛异常', () async {
      await aiService.deleteFavorite(0);
      await aiService.deleteFavorite(-1);
      await aiService.deleteFavorite(100);
    });
  });

  group('AiService 本地预言', () {
    test('getLoadingText 应循环返回不同加载文案', () {
      final texts = List.generate(10, (i) => aiService.getLoadingText(i));
      final unique = texts.toSet();
      expect(unique.length, greaterThan(1));
    });
  });

  group('AiService 与 ML 模型集成', () {
    test('选择千问时应使用 MLX 生成', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
        switch (methodCall.method) {
          case 'isLoaded':
            return true;
          case 'generateProphecy':
            return '电量50%时，你的拇指滑屏速度会比平时快1.2倍';
          default:
            return null;
        }
      });

      await aiService.checkModelAvailability();
      await aiService.setPreferredEngine(PreferredEngine.qwen);
      expect(aiService.modelLoaded, isTrue);

      final sensor = SensorData.mock();
      final prophecy = await aiService.generateProphecy(sensor);

      expect(prophecy, contains('电量'));
      expect(prophecy.length, lessThanOrEqualTo(45));
      expect(aiService.plannedProphecyEngine, ProphecyEngine.qwen);
    });

    test('选择苹果本地时应优先于千问', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter_local_ai'),
        (methodCall) async {
          if (methodCall.method == 'isAvailable') return true;
          if (methodCall.method == 'initialize') return null;
          if (methodCall.method == 'generateText') {
            return {'text': '电量50%时，系统本地模型说你下一口呼吸会重0.002克'};
          }
          return null;
        },
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
        switch (methodCall.method) {
          case 'isLoaded':
            return true;
          case 'generateProphecy':
            return '电量72%时，你的拇指滑屏速度会比平时快1.2倍';
          default:
            return null;
        }
      });

      await aiService.checkModelAvailability();
      await aiService.setPreferredEngine(PreferredEngine.apple);

      final sensor = SensorData.mock();
      final prophecy = await aiService.generateProphecy(sensor);

      expect(prophecy, contains('电量50%'));
      expect(aiService.plannedProphecyEngine, ProphecyEngine.localAi);
    });

    test('选择 DeepSeek 时应使用云端生成', () async {
      final client = DeepSeekClient();
      client.postOverride = (_, __, ___) async {
        return http.Response.bytes(
          utf8.encode(
            '{"choices":[{"message":{"content":"你今天会在三分钟后突然想起一件无关紧要的小事"}}]}',
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      };
      aiService.dispose();
      aiService = AiService(deepseekClient: client);

      await aiService.setDeepSeekApiKey('sk-test');
      await aiService.setPreferredEngine(PreferredEngine.deepseek);

      final sensor = SensorData.mock();
      final prophecy = await aiService.generateProphecy(sensor);

      expect(prophecy, contains('三分钟'));
      expect(aiService.plannedProphecyEngine, ProphecyEngine.deepseek);
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

      expect(prophecy, isNotEmpty);
    });
  });
}
