import '../models/sensor_data.dart';

/// 唯一 prompt 源：统一风格 spec + few-shot + 传感器上下文
class ProphecyPromptBuilder {
  ProphecyPromptBuilder._();

  static const _styleSpec = '''
你是废话预言家。根据传感器数据写一条中文预言。

风格要求：
- 32–42 字，硬上限 45 字
- 第二人称「你」，允许句首使用
- 冷幽默 + 荒诞因果 + 伪科学精度，不要哲理/禅意腔
- 结构：[传感器锚定]，[荒诞预测]
- 禁止前言、自述、emoji、英文
- 鼓励引用传感器字段并含 1 个伪精度数字
- 只输出预言正文，不要引号或前缀''';

  static const _fewShotExamples = [
    '电量72%时，你的拇指滑屏速度会比平时快1.2倍',
    '今日步数3500步，你的手指比预期早了0.3秒划到下一张图',
    '屏幕亮度60%时，你的下一口呼吸比上一口重0.002克',
  ];

  /// LocalAi 用纯文本 prompt
  static String buildPrompt(SensorData sensor) {
    return '''$_styleSpec

示例：
1. ${_fewShotExamples[0]}
2. ${_fewShotExamples[1]}
3. ${_fewShotExamples[2]}

当前传感器：
- 时段：${sensor.dayPhase} · ${sensor.timeHint}
- 电量：${sensor.battery ?? 50}%
- 屏幕亮度：${sensor.brightness}%
- 今日步数：${sensor.steps} 步
- 身体状态：${sensor.isMoving ? '正在移动' : '静止'}
- 环境光线：${sensor.ambientLight} lux

预言：''';
  }

  /// MLX 用 ChatML 包装
  static String buildChatMLPrompt(SensorData sensor) {
    final userContent = '''根据以下传感器数据写一条预言：

- 时段：${sensor.dayPhase} · ${sensor.timeHint}
- 电量：${sensor.battery ?? 50}%
- 屏幕亮度：${sensor.brightness}%
- 今日步数：${sensor.steps} 步
- 身体状态：${sensor.isMoving ? '正在移动' : '静止'}
- 环境光线：${sensor.ambientLight} lux

示例：
1. ${_fewShotExamples[0]}
2. ${_fewShotExamples[1]}
3. ${_fewShotExamples[2]}''';

    return '''<|im_start|>system
$_styleSpec
<|im_end|>
<|im_start|>user
$userContent
<|im_end|>
<|im_start|>assistant
''';
  }
}
