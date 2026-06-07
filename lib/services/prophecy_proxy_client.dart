import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/proxy_config.dart';
import '../models/sensor_data.dart';

class ProphecyProxyResult {
  const ProphecyProxyResult({
    required this.prophecy,
    required this.quotaUsed,
    required this.quotaRemaining,
    required this.engine,
    required this.dailyLimit,
  });

  final String prophecy;
  final int quotaUsed;
  final int quotaRemaining;
  final String engine;
  final int dailyLimit;
}

class QuotaInfo {
  const QuotaInfo({
    required this.used,
    required this.remaining,
    required this.dailyLimit,
  });

  final int used;
  final int remaining;
  final int dailyLimit;
}

class QuotaExceededException implements Exception {
  QuotaExceededException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProxyException implements Exception {
  ProxyException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// 云端预言代理客户端（POST /v1/prophecy、GET /v1/quota）
class ProphecyProxyClient {
  ProphecyProxyClient({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  /// 测试用：绕过真实 HTTP
  @visibleForTesting
  Future<http.Response> Function(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    String? body,
  })? requestOverride;

  Future<ProphecyProxyResult> generateProphecy({
    required String deviceId,
    required SensorData sensor,
    required int nonce,
  }) async {
    final uri = Uri.parse('${ProxyConfig.baseUrl}${ProxyConfig.prophecyPath}');
    final body = jsonEncode({
      'device_id': deviceId,
      'nonce': nonce,
      'sensor': _sensorToJson(sensor),
    });
    const headers = {'Content-Type': 'application/json'};

    try {
      final response = requestOverride != null
          ? await requestOverride!(
              'POST',
              uri,
              headers: headers,
              body: body,
            )
          : await _http
              .post(uri, headers: headers, body: body)
              .timeout(
                const Duration(seconds: ProxyConfig.timeoutSeconds),
              );

      if (response.statusCode == 429) {
        throw QuotaExceededException(_detailMessage(response));
      }
      if (response.statusCode == 502 || response.statusCode == 503) {
        throw ProxyException(
          _detailMessage(response),
          statusCode: response.statusCode,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ProxyException(
          '代理请求失败（${response.statusCode}）',
          statusCode: response.statusCode,
        );
      }

      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final prophecy = (decoded['prophecy'] as String?)?.trim() ?? '';
      if (prophecy.isEmpty) {
        throw ProxyException('代理返回空预言');
      }
      return ProphecyProxyResult(
        prophecy: prophecy,
        quotaUsed: decoded['quota_used'] as int? ?? 0,
        quotaRemaining: decoded['quota_remaining'] as int? ?? 0,
        engine: decoded['engine'] as String? ?? 'deepseek',
        dailyLimit: decoded['daily_limit'] as int? ?? 50,
      );
    } on QuotaExceededException {
      rethrow;
    } on ProxyException {
      rethrow;
    } catch (e) {
      debugPrint('ProphecyProxyClient generate failed: $e');
      throw ProxyException('网络异常，请检查连接后重试');
    }
  }

  Future<QuotaInfo?> fetchQuota({required String deviceId}) async {
    final uri = Uri.parse('${ProxyConfig.baseUrl}${ProxyConfig.quotaPath}')
        .replace(queryParameters: {'device_id': deviceId});

    try {
      final response = requestOverride != null
          ? await requestOverride!('GET', uri)
          : await _http
              .get(uri)
              .timeout(
                const Duration(seconds: ProxyConfig.timeoutSeconds),
              );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return QuotaInfo(
        used: decoded['used'] as int? ?? 0,
        remaining: decoded['remaining'] as int? ?? 0,
        dailyLimit: decoded['daily_limit'] as int? ?? 50,
      );
    } catch (e) {
      debugPrint('ProphecyProxyClient fetchQuota failed: $e');
      return null;
    }
  }

  static Map<String, dynamic> _sensorToJson(SensorData sensor) {
    return {
      'battery': sensor.battery,
      'charging': sensor.charging,
      'brightness': sensor.brightness,
      'volume': sensor.volume,
      'steps': sensor.steps,
      'is_moving': sensor.isMoving,
      'ambient_light': sensor.ambientLight,
      'is_real_battery': sensor.isRealBattery,
      'is_real_volume': sensor.isRealVolume,
      'is_real_motion': sensor.isRealMotion,
      'is_real_steps': sensor.isRealSteps,
      'is_real_ambient_light': sensor.isRealAmbientLight,
      'is_estimated_ambient_light': sensor.isEstimatedAmbientLight,
      'time_hint': sensor.timeHint,
      'day_phase': sensor.dayPhase,
      'timestamp': sensor.timestamp.toUtc().toIso8601String(),
    };
  }

  static String _detailMessage(http.Response response) {
    try {
      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final detail = decoded['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
    } catch (_) {}
    return '云端生成失败，请稍后重试';
  }
}
