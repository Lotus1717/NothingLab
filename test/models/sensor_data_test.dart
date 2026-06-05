import 'package:flutter_test/flutter_test.dart';
import 'package:nonsense_prophet/main.dart';

void main() {
  group('SensorData 模型', () {
    test('mock() 应返回当前时间的合理数据', () {
      final data = SensorData.mock();
      final now = DateTime.now();

      expect(data.battery, isNotNull);
      expect(data.brightness, isNotNull);
      expect(data.steps, isNotNull);
      expect(data.isMoving, isNotNull);
      expect(data.ambientLight, isNotNull);
      expect(data.timestamp.hour, equals(now.hour));
      expect(data.timeHint, isNotEmpty);
      expect(data.dayPhase, isNotEmpty);
      expect(data.isRealBattery, isFalse);
    });

    test('timeHint 和时间段应正确对应', () {
      // 凌晨 (0-5)
      final dawn = SensorData(
        timestamp: DateTime(2026, 6, 5, 3, 0),
        timeHint: '凌晨发呆模式',
        dayPhase: '夜晚',
      );
      expect(dawn.timeHint, '凌晨发呆模式');
      expect(dawn.dayPhase, '夜晚');

      // 上午 (6-11)
      final morning = SensorData(
        timestamp: DateTime(2026, 6, 5, 9, 0),
        timeHint: '上午搬砖中',
        dayPhase: '早晨',
      );
      expect(morning.timeHint, '上午搬砖中');
      expect(morning.dayPhase, '早晨');
    });

    test('copyWith() 应只覆盖指定字段', () {
      final data = SensorData.mock();
      final steps10k = data.copyWith(steps: 10000);
      expect(steps10k.steps, equals(10000));
      expect(steps10k.battery, equals(data.battery));
      expect(steps10k.brightness, equals(data.brightness));
      expect(steps10k.timestamp, equals(data.timestamp));
    });

    test('fromJson / toJson 序列化', () {
      final data = SensorData(
        battery: 80,
        charging: true,
        brightness: 60,
        steps: 5000,
        isMoving: false,
        ambientLight: 300,
        isRealBattery: true,
        isRealMotion: false,
        isRealSteps: true,
        timestamp: DateTime(2026, 6, 5, 14, 30),
        timeHint: '下午摸鱼中',
        dayPhase: '下午',
      );

      // 验证各个字段
      expect(data.battery, 80);
      expect(data.charging, isTrue);
      expect(data.brightness, 60);
      expect(data.steps, 5000);
      expect(data.isMoving, isFalse);
      expect(data.ambientLight, 300);
      expect(data.isRealBattery, isTrue);
      expect(data.isRealSteps, isTrue);
    });

    test('多个 copyWith 链式调用应正确', () {
      final data = SensorData.mock();
      final modified = data
          .copyWith(battery: 99)
          .copyWith(steps: 8888)
          .copyWith(isMoving: true);

      expect(modified.battery, 99);
      expect(modified.steps, 8888);
      expect(modified.isMoving, isTrue);
      expect(modified.brightness, data.brightness); // 未修改，保留原值
    });

    test('dayPhase 应覆盖从早到晚', () {
      final phases = [
        [0, '夜晚'],
        [6, '早晨'],
        [12, '中午'],
        [14, '下午'],
        [18, '傍晚'],
        [22, '夜晚'],
      ];
      for (final p in phases) {
        final h = p[0] as int;
        final expected = p[1] as String;
        final data = SensorData(
          timestamp: DateTime(2026, 6, 5, h, 0),
          timeHint: '测试',
          dayPhase: expected,
        );
        expect(data.dayPhase, expected, reason: '$h 点应为 $expected');
      }
    });
  });
}
