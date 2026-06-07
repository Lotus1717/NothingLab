/// DeepSeek 相关常量（密钥仅存服务端，客户端走代理）
class DeepSeekConfig {
  DeepSeekConfig._();

  static const model = 'deepseek-chat';

  /// 每设备每日云端调用上限（由代理服务器强制执行）
  static const dailyLimit = 50;
}
