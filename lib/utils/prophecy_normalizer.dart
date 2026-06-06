import '../config/prophecy_style.dart';

/// 统一清洗 AI 输出并做质量门判断
class ProphecyNormalizer {
  ProphecyNormalizer._();

  static final _chatMlTokens = RegExp(
    r'<\|im_start\|>(?:system|user|assistant)?|<\|im_end\|>|<\|redacted_im_end\|>|<\|endoftext\|>',
  );

  static final _assistantPrefix = RegExp(r'^assistant\s*[\n:：]*');

  static final _forbiddenPrefixes = RegExp(
    r'^(预言[：:]\s*|好的[，,]\s*|作为预言家[，,]\s*|我是[^，,。]*[，,]\s*)',
  );

  static final _hasChinese = RegExp(r'[\u4e00-\u9fff]');

  static final _hasEnglish = RegExp(r'[a-zA-Z]');

  static final _hasEmoji = RegExp(
    r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
    unicode: true,
  );

  static final _sensorAnchors = RegExp(
    r'电量|步数|亮度|屏幕|移动|静止|环境|光线|勒克斯|%|时段|早晨|中午|下午|傍晚|夜晚|手机|状态|温度|多巴胺|音量|分贝',
  );

  static final _hasNumber = RegExp(r'\d');

  /// trim、去 token/前缀/引号，按标点优先截断到 maxChars
  static String normalizeProphecy(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return '';

    text = text.replaceAll(_chatMlTokens, '').trim();
    text = text.replaceAll(_assistantPrefix, '').trim();
    text = text.replaceAll(RegExp(r'^["「『]|["」』]$'), '');
    while (_forbiddenPrefixes.hasMatch(text)) {
      text = text.replaceFirst(_forbiddenPrefixes, '').trim();
    }

    if (text.length <= ProphecyStyle.maxChars) return text;
    return _truncateAtPunctuation(text, ProphecyStyle.maxChars);
  }

  static String _truncateAtPunctuation(String text, int maxLen) {
    final punct = RegExp(r'[，。！？、；]');
    var best = maxLen;
    for (var i = 0; i < text.length && i < maxLen; i++) {
      if (punct.hasMatch(text[i])) best = i + 1;
    }
    if (best < ProphecyStyle.minChars) best = maxLen;
    return text.substring(0, best.clamp(0, text.length));
  }

  /// 长度、中文、无违规前缀；建议含传感器锚定或数字
  static bool isAcceptableProphecy(String text) {
    if (text.isEmpty) return false;
    if (text.length < ProphecyStyle.minChars ||
        text.length > ProphecyStyle.maxChars) {
      return false;
    }
    if (!_hasChinese.hasMatch(text)) return false;
    if (_hasEnglish.hasMatch(text)) return false;
    if (_hasEmoji.hasMatch(text)) return false;
    if (_forbiddenPrefixes.hasMatch(text)) return false;

    return _sensorAnchors.hasMatch(text) || _hasNumber.hasMatch(text);
  }

  /// 放宽门：有中文、长度合规即可，避免小模型输出被误判后回退模板
  static bool isSoftAcceptableProphecy(String text) {
    if (text.isEmpty) return false;
    if (text.length < ProphecyStyle.minChars ||
        text.length > ProphecyStyle.maxChars) {
      return false;
    }
    if (!_hasChinese.hasMatch(text)) return false;
    if (_hasEnglish.hasMatch(text)) return false;
    if (_hasEmoji.hasMatch(text)) return false;
    if (_forbiddenPrefixes.hasMatch(text)) return false;
    return true;
  }
}
