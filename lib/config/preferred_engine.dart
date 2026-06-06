/// 用户选择的废话生成途径
enum PreferredEngine {
  apple,
  qwen,
  deepseek,
  template;

  String get label => switch (this) {
        PreferredEngine.apple => '苹果本地',
        PreferredEngine.qwen => '千问',
        PreferredEngine.deepseek => 'DeepSeek',
        PreferredEngine.template => '模板库',
      };

  String get storageValue => name;

  static PreferredEngine? fromStorage(String? raw) => switch (raw) {
        'apple' => PreferredEngine.apple,
        'qwen' => PreferredEngine.qwen,
        'deepseek' => PreferredEngine.deepseek,
        'template' => PreferredEngine.template,
        _ => null,
      };

  /// 设置页始终展示全部选项，可用性在副标题说明
  static const List<PreferredEngine> all = [
    PreferredEngine.apple,
    PreferredEngine.qwen,
    PreferredEngine.deepseek,
    PreferredEngine.template,
  ];
}
