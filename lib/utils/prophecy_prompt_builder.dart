import '../models/sensor_data.dart';

/// MLX 对话 prompt（system + user，由原生侧套 Chat 模板）
class MlxChatPrompt {
  const MlxChatPrompt({required this.system, required this.user});

  final String system;
  final String user;
}

/// 唯一 prompt 源：短 prompt，避免模型复述题面
class ProphecyPromptBuilder {
  ProphecyPromptBuilder._();

  static const _fewShotExamples = [
    '电量72%时，你的拇指滑屏速度会比平时快1.2倍',
    '你接下来的三分钟内会突然想起一件无关紧要的小事',
    '今天你会在电梯里和陌生人交换一个意味深长的眼神',
  ];

  static String _sensorFacts(SensorData sensor) {
    final battery = sensor.battery ?? 50;
    final motion = sensor.isMoving ? '移动' : '静止';
    final light = sensor.isRealAmbientLight || sensor.isEstimatedAmbientLight
        ? '，光线${sensor.ambientLight}勒克斯'
        : '';
    return '电量$battery%，亮度${sensor.brightness}%，音量${sensor.volume}%，'
        '步数${sensor.steps}，$motion，${sensor.dayPhase}$light';
  }

  /// 苹果本地 / 通用：短 completion，不把上一句写进 prompt
  static String buildPrompt(SensorData sensor, {int? nonce}) {
    final salt = nonce ?? 0;
    return '''写一条中文废话预言：第二人称「你」，32-42字，冷幽默荒诞，只输出预言正文。

可参考（不必写入正文）数据：${_sensorFacts(sensor)}
风格参考：${_fewShotExamples[salt % _fewShotExamples.length]}''';
  }

  /// MLX：system 约束格式，user 只给数据
  static MlxChatPrompt buildMlxChat(SensorData sensor, {int? nonce}) {
    final salt = nonce ?? 0;
    const system = '''你是废话预言家。写一句中文废话预言。
要求：32-42字；第二人称「你」；冷幽默荒诞；可不提及传感器数据。
禁止：解释、题面复述、出现「上一句」「传感器」「当前状态」「写一条」等词。
只输出预言正文一行。''';

    final user = '可参考数据：${_sensorFacts(sensor)}\n'
        '风格参考：${_fewShotExamples[salt % _fewShotExamples.length]}';

    return MlxChatPrompt(system: system, user: user);
  }
}
