/// 云端预言代理服务器配置
class ProxyConfig {
  ProxyConfig._();

  static const baseUrl = 'https://tanmystudio.site';
  static const prophecyPath = '/v1/prophecy';
  static const quotaPath = '/v1/quota';
  static const useProxy = true;
  static const timeoutSeconds = 30;
}
