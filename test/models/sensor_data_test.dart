import 'package:flutter_test/flutter_test.dart';
import 'package:nonsense_prophet/models/prophecy_record.dart';
import 'package:nonsense_prophet/models/sensor_data.dart';

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

    test('timeHintFor / dayPhaseFor 应正确对应时段', () {
      expect(
        SensorData.timeHintFor(DateTime(2026, 6, 5, 3, 0)),
        '凌晨发呆模式',
      );
      expect(
        SensorData.dayPhaseFor(DateTime(2026, 6, 5, 3, 0)),
        '夜晚',
      );
      expect(
        SensorData.timeHintFor(DateTime(2026, 6, 5, 9, 0)),
        '上午搬砖中',
      );
      expect(
        SensorData.dayPhaseFor(DateTime(2026, 6, 5, 9, 0)),
        '早晨',
      );
    });

    test('withCurrentTimeHints() 应刷新时间字段', () {
      final data = SensorData(
        timestamp: DateTime(2020, 1, 1),
        timeHint: '旧',
        dayPhase: '旧',
      );
      final fresh = data.withCurrentTimeHints();
      expect(fresh.timeHint, isNot('旧'));
      expect(fresh.dayPhase, isNot('旧'));
      expect(fresh.timestamp.year, greaterThanOrEqualTo(2020));
    });

    test('copyWith() 应只覆盖指定字段', () {
      final data = SensorData.mock();
      final steps10k = data.copyWith(steps: 10000);
      expect(steps10k.steps, equals(10000));
      expect(steps10k.battery, equals(data.battery));
      expect(steps10k.brightness, equals(data.brightness));
      expect(steps10k.timestamp, equals(data.timestamp));
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
      expect(modified.brightness, data.brightness);
    });
  });

  group('ProphecyRecord 模型', () {
    test('fromJson / toJson 序列化', () {
      final record = ProphecyRecord(
        text: '测试预言',
        battery: 80,
        brightness: 60,
        steps: 5000,
        isMoving: false,
        time: DateTime(2026, 6, 5, 14, 30).millisecondsSinceEpoch,
      );

      final restored = ProphecyRecord.fromJson(record.toJson());
      expect(restored.text, record.text);
      expect(restored.battery, record.battery);
      expect(restored.brightness, record.brightness);
      expect(restored.steps, record.steps);
      expect(restored.isMoving, record.isMoving);
      expect(restored.time, record.time);
    });
  });
}
