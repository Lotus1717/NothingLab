/// 分享图与二维码落地页配置（不含 API 密钥等敏感信息）
class ShareConfig {
  ShareConfig._();

  /// 二维码编码的落地页 URL，可改为应用商店或官网链接
  static const String landingUrl = 'https://nonsense-prophet.app';

  static const String qrLabel = '扫码，听你的手机胡说八道';
  static const String appTagline = '俏皮神谕 · Playful Oracle';

  /// 分享图预言区上方的传播钩子
  static const String shareHook = '我的手机说我…';
}
