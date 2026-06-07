import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 持久化安装级 device_id，供代理服务器配额追踪
class DeviceIdService {
  static const _key = 'install_device_id_v1';

  Future<String> getDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(_key);
      if (existing != null && existing.length >= 8) {
        return existing;
      }
      final id = _generateUuid();
      await prefs.setString(_key, id);
      return id;
    } catch (e) {
      debugPrint('DeviceIdService getDeviceId failed: $e');
      return _generateUuid();
    }
  }

  static String _generateUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
        '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }
}
