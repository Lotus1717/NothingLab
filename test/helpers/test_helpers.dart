/// 测试辅助工具

import 'package:flutter/services.dart';

/// Mock 所有传感器相关的 MethodChannel，防止测试时调用真实平台
void mockAllPlatformChannels() {
  // battery_plus
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('dev.flutter.pigeon.battery_plus'),
    (methodCall) async {
      switch (methodCall.method) {
        case 'getBatteryLevel':
          return 75;
        case 'getBatteryState':
          return 'charging';
        default:
          return null;
      }
    },
  );

  // sensors_plus (accelerometer)
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('dev.flutter.pigeon.sensors_plus'),
    (methodCall) async {
      return null; // 静默处理
    },
  );

  // pedometer_2 通道 （根据 pub 包版本可能不同）
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('pedometer_2'),
    (methodCall) async {
      return null;
    },
  );

  // 通用 fallback
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('com.nonsense_prophet/ml'),
    (methodCall) async {
      return null;
    },
  );
}

/// 清除所有 mock
void clearAllMocks() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('dev.flutter.pigeon.battery_plus'),
    null,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('dev.flutter.pigeon.sensors_plus'),
    null,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('pedometer_2'),
    null,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('com.nonsense_prophet/ml'),
    null,
  );
}
