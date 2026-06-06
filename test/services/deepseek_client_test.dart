import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nonsense_prophet/models/sensor_data.dart';
import 'package:nonsense_prophet/services/deepseek_client.dart';

void main() {
  group('DeepSeekClient', () {
    test('应解析 chat completions 响应', () async {
      final client = DeepSeekClient();
      client.postOverride = (uri, headers, body) async {
        expect(uri.toString(), contains('deepseek.com'));
        expect(headers['Authorization'], 'Bearer sk-test');
        return http.Response.bytes(
          utf8.encode(
            '{"choices":[{"message":{"content":"电量72%时，你的拇指滑屏速度会比平时快1.2倍"}}]}',
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      };

      final result = await client.generate(
        apiKey: 'sk-test',
        sensor: SensorData.mock(),
        nonce: 1,
      );

      expect(result, '电量72%时，你的拇指滑屏速度会比平时快1.2倍');
    });

    test('空密钥应返回 null', () async {
      final client = DeepSeekClient();
      final result = await client.generate(
        apiKey: '  ',
        sensor: SensorData.mock(),
        nonce: 1,
      );
      expect(result, isNull);
    });

    test('401 应抛出密钥无效异常', () async {
      final client = DeepSeekClient();
      client.postOverride = (_, __, ___) async => http.Response('unauthorized', 401);

      expect(
        () => client.generate(
          apiKey: 'sk-bad',
          sensor: SensorData.mock(),
          nonce: 1,
        ),
        throwsA(isA<DeepSeekException>()),
      );
    });
  });
}
