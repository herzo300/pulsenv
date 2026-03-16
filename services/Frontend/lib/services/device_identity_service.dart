import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class DeviceIdentityService {
  DeviceIdentityService._();

  static final DeviceIdentityService instance = DeviceIdentityService._();
  static const String _deviceIdKey = 'runtime_device_id_v1';

  Future<String?> getCurrentDeviceIdOrNull() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey)?.trim();
    if (existing == null || existing.isEmpty) {
      return null;
    }
    return existing;
  }

  Future<String> getOrCreateDeviceId() async {
    final existing = await getCurrentDeviceIdOrNull();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final prefs = await SharedPreferences.getInstance();
    final deviceId = _generateDeviceId();
    await prefs.setString(_deviceIdKey, deviceId);
    return deviceId;
  }

  Future<String> regenerateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = _generateDeviceId();
    await prefs.setString(_deviceIdKey, deviceId);
    return deviceId;
  }

  String _generateDeviceId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return 'soobshio-$hex';
  }
}
