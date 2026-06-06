import 'package:flutter_test/flutter_test.dart';
import 'package:nonsense_prophet/services/sensor_service.dart';

import '../helpers/test_helpers.dart';

void main() {
  setUpAll(() {
    mockAllPlatformChannels();
  });

  tearDownAll(() {
    clearAllMocks();
  });

  group('SensorService 步数逻辑', () {
    test('startOfToday 应返回当天零点', () {
      final start = SensorService.startOfToday(DateTime(2026, 6, 6, 15, 30));
      expect(start, DateTime(2026, 6, 6));
    });

    test('applyAndroidStreamStep 首次事件应记录基线', () {
      expect(
        SensorService.applyAndroidStreamStep(
          bootBaseline: null,
          currentTodaySteps: 0,
          streamStep: 120,
          hasRealSteps: false,
        ),
        120,
      );
    });

    test('applyAndroidStreamStep 增量应累加到今日步数', () {
      expect(
        SensorService.applyAndroidStreamStep(
          bootBaseline: 120,
          currentTodaySteps: 800,
          streamStep: 125,
          hasRealSteps: true,
        ),
        805,
      );
    });

    test('applyAndroidStreamStep 无增量时不更新', () {
      expect(
        SensorService.applyAndroidStreamStep(
          bootBaseline: 120,
          currentTodaySteps: 800,
          streamStep: 120,
          hasRealSteps: true,
        ),
        isNull,
      );
    });

    test('初始数据步数未接入时应为占位状态', () {
      final service = SensorService();
      expect(service.data.steps, 0);
      expect(service.data.isRealSteps, isFalse);
      expect(service.data.volume, 50);
      expect(service.data.isRealVolume, isFalse);
    });

    test('volumePercentFromLevel 应将 0-1 转为百分比', () {
      expect(SensorService.volumePercentFromLevel(0.0), 0);
      expect(SensorService.volumePercentFromLevel(0.655), 66);
      expect(SensorService.volumePercentFromLevel(1.0), 100);
    });

    test('ambientLuxFromReading 应过滤无效读数', () {
      expect(SensorService.ambientLuxFromReading(-1), isNull);
      expect(SensorService.ambientLuxFromReading(0), 0);
      expect(SensorService.ambientLuxFromReading(320), 320);
      expect(SensorService.ambientLuxFromReading(120000), 100000);
    });

    test('estimateAmbientLuxFromBrightness 应根据屏幕亮度粗估照度', () {
      expect(SensorService.estimateAmbientLuxFromBrightness(0), 30);
      expect(SensorService.estimateAmbientLuxFromBrightness(50), 330);
      expect(SensorService.estimateAmbientLuxFromBrightness(100), 630);
    });

    test('初始数据环境光线未接入时应为占位状态', () {
      final service = SensorService();
      expect(service.data.ambientLight, 0);
      expect(service.data.isRealAmbientLight, isFalse);
    });
  });
}
