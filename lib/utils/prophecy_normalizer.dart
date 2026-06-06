import '../config/prophecy_style.dart';
import '../models/sensor_data.dart';

/// 统一清洗 AI 输出并做质量门判断
class ProphecyNormalizer {
  ProphecyNormalizer._();

  static final _chatMlTokens = RegExp(
    r'<\|im_start\|>(?:system|user|assistant)?|<\|im_end\|>|<\|endoftext\|>',
  );

  static final _assistantPrefix = RegExp(r'^assistant\s*[\n:：]*');

  static final _forbiddenPrefixes = RegExp(
    r'^(预言[：:]\s*|好的[，,]\s*|作为预言家[，,]\s*|我是[^，,。]*[，,]\s*|写一条[^，。]*[，,]\s*)',
  );

  static final _hasChinese = RegExp(r'[\u4e00-\u9fff]');

  static final _hasEnglish = RegExp(r'[a-zA-Z]');

  static final _hasEmoji = RegExp(
    r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
    unicode: true,
  );

  /// 模型复述 prompt / 元指令
  static final _promptEcho = RegExp(
    r'上一句[是为：:]|上一句预言|当前传感器|当前状态|传感器数据|写一条|写一句|必须写|编号\d|'
    r'^示例[：:]|^参考[：:]|^数据[：:]|预言家|根据.*数据写|只输出|禁止|要求[：:]',
  );

  static final _promptLeakMarkers = [
    '<|im_start|>',
    '<|im_end|>',
    '传感器数据',
    '当前传感器',
    '当前状态',
    '参考格式',
    '请根据',
    '写一条',
    '写一句',
    '示例',
    '参考：',
    '数据：',
    '上一句',
    '编号',
    '预言：',
    'user\n',
    'assistant\n',
    'system\n',
  ];

  /// 是否像在复述题面或元指令（应拒绝或重试）
  static bool isPromptEcho(String text) {
    final t = text.trim();
    if (t.isEmpty) return true;
    if (_promptEcho.hasMatch(t)) return true;
    if (t.startsWith('数据：') || t.startsWith('参考：')) return true;
    return false;
  }

  /// trim、去 token/前缀/引号，按标点优先截断到 maxChars
  static String normalizeProphecy(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return '';

    text = text.replaceAll(_chatMlTokens, '').trim();
    text = text.replaceAll(_assistantPrefix, '').trim();
    text = text.replaceAll(RegExp(r'[\r\n]+'), '，');
    text = text.replaceAll(RegExp(r'\s{2,}'), '');

    for (final marker in _promptLeakMarkers) {
      if (marker.isEmpty) continue;
      final idx = text.indexOf(marker);
      if (idx > 0) {
        text = text.substring(0, idx).trim();
      }
    }

    text = text.replaceAll(RegExp(r'^["「『]|["」』]$'), '');
    while (_forbiddenPrefixes.hasMatch(text)) {
      text = text.replaceFirst(_forbiddenPrefixes, '').trim();
    }

    text = _stripLeadingMeta(text);
    text = _firstSentence(text);
    text = text.replaceAll(RegExp(r'[，、；]+$'), '');
    if (text.isEmpty) return '';

    if (text.length <= ProphecyStyle.maxChars) return text;
    return _truncateAtPunctuation(text, ProphecyStyle.maxChars);
  }

  static String _stripLeadingMeta(String text) {
    final patterns = [
      RegExp(r'^上一句[是为：:]\s*'),
      RegExp(r'^当前状态[是为：:]\s*'),
      RegExp(r'^当前传感器[：:]\s*'),
      RegExp(r'^数据[：:]\s*'),
      RegExp(r'^参考[：:]\s*'),
    ];
    for (final p in patterns) {
      if (p.hasMatch(text)) {
        text = text.replaceFirst(p, '').trim();
      }
    }
    return text;
  }

  static String _firstSentence(String text) {
    final end = RegExp(r'[。！？]');
    final match = end.firstMatch(text);
    if (match != null) {
      final candidate = text.substring(0, match.end).trim();
      if (candidate.length >= ProphecyStyle.minChars) return candidate;
    }
    return text.trim();
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

  /// 长度、中文、无违规前缀（不必含传感器数据）
  static bool isAcceptableProphecy(String text) =>
      isSoftAcceptableProphecy(text);

  /// MLX 专用：清洗后符合基本废话格式即可
  static bool isMlxProphecy(String text, SensorData sensor) {
    final cleaned = normalizeProphecy(text);
    return isSoftAcceptableProphecy(cleaned);
  }

  /// 放宽门：有中文、长度合规即可
  static bool isSoftAcceptableProphecy(String text) {
    if (text.isEmpty || isPromptEcho(text)) return false;
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
