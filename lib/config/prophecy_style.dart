/// 预言输出风格与生成参数常量
class ProphecyStyle {
  ProphecyStyle._();

  static const int maxChars = 45;
  static const int minChars = 12;
  static const int targetMinChars = 32;
  static const int targetMaxChars = 42;

  static const double temperature = 0.85;
  static const double retryTemperature = 0.7;
  static const double topP = 0.9;
  static const int maxTokens = 64;
}
