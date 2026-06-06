import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void initTestBindings() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
}

/// Mock 所有传感器相关的 MethodChannel，防止测试时调用真实平台
void mockAllPlatformChannels() {
  initTestBindings();

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('flutter_local_ai'),
    (methodCall) async {
      if (methodCall.method == 'isAvailable') return false;
      return null;
    },
  );

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

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('dev.flutter.pigeon.sensors_plus'),
    (methodCall) async {
      return null;
    },
  );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('method_channel'),
    (methodCall) async {
      if (methodCall.method == 'getStepCount') return 1234;
      return null;
    },
  );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('com.kurenai7968.volume_controller.method'),
    (methodCall) async {
      if (methodCall.method == 'getVolume') return 0.65;
      return null;
    },
  );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockStreamHandler(
    const EventChannel('com.kurenai7968.volume_controller.volume_listener_event'),
    MockStreamHandler.inline(
      onListen: (arguments, events) {
        events.success(0.65);
      },
    ),
  );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('light'),
    (methodCall) async {
      if (methodCall.method == 'getAuthorizationStatus') return 'authorized';
      if (methodCall.method == 'requestAuthorization') return 'authorized';
      return null;
    },
  );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockStreamHandler(
    const EventChannel('light.eventChannel'),
    MockStreamHandler.inline(
      onListen: (arguments, events) {
        events.success(320);
      },
    ),
  );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('com.nonsense_prophet/ml'),
    (methodCall) async {
      throw MissingPluginException('no ml plugin');
    },
  );
}

/// 清除所有 mock
void clearAllMocks() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('flutter_local_ai'),
    null,
  );
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
    const MethodChannel('method_channel'),
    null,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('com.kurenai7968.volume_controller.method'),
    null,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockStreamHandler(
    const EventChannel('com.kurenai7968.volume_controller.volume_listener_event'),
    null,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('light'),
    null,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockStreamHandler(
    const EventChannel('light.eventChannel'),
    null,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('com.nonsense_prophet/ml'),
    null,
  );
}
