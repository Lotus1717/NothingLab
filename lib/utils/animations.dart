import 'package:flutter/scheduler.dart';

/// 测试环境下关闭无限循环动画，避免 `pumpAndSettle` 超时。
bool get areUiAnimationsEnabled {
  final binding = SchedulerBinding.instance;
  return binding.runtimeType.toString() !=
      'AutomatedTestWidgetsFlutterBinding';
}
