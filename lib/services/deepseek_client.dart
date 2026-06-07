import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/deepseek_config.dart';
import '../config/prophecy_style.dart';
import '../models/sensor_data.dart';
import '../utils/prophecy_prompt_builder.dart';

class DeepSeekException implements Exception {
  DeepSeekException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// DeepSeek Chat Completions 客户端
class DeepSeekClient {
  DeepSeekClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  /// 测试用：绕过真实 HTTP
  @visibleForTesting
  Future<http.Response> Function(
    Uri uri,
    Map<String, String> headers,
    String body,
  )? postOverride;

  Future<String?> generate({
    required String apiKey,
    required SensorData sensor,
    required int nonce,
    double temperature = ProphecyStyle.temperature,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) return null;

    final chat = ProphecyPromptBuilder.buildMlxChat(sensor, nonce: nonce);
    const apiBase = 'https://api.deepseek.com';
    const chatPath = '/chat/completions';
    const timeoutSeconds = 30;
    final uri = Uri.parse('$apiBase$chatPath');
    final body = jsonEncode({
      'model': DeepSeekConfig.model,
      'messages': [
        {'role': 'system', 'content': chat.system},
        {'role': 'user', 'content': chat.user},
      ],
      'temperature': temperature,
      'max_tokens': ProphecyStyle.maxTokens,
      'stream': false,
    });
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $key',
    };

    try {
      final response = postOverride != null
          ? await postOverride!(uri, headers, body)
          : await _http
              .post(uri, headers: headers, body: body)
              .timeout(const Duration(seconds: timeoutSeconds));

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw DeepSeekException('API 密钥无效或已过期', statusCode: response.statusCode);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw DeepSeekException(
          'DeepSeek 请求失败（${response.statusCode}）',
          statusCode: response.statusCode,
        );
      }

      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final choices = decoded['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) return null;

      final message = choices.first as Map<String, dynamic>;
      final content = (message['message'] as Map<String, dynamic>?)?['content'];
      if (content is! String || content.trim().isEmpty) return null;
      return content.trim();
    } on DeepSeekException {
      rethrow;
    } catch (e) {
      debugPrint('DeepSeek generate failed: $e');
      throw DeepSeekException('网络异常，请检查连接后重试');
    }
  }
}
