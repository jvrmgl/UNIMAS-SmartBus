import 'package:device_info_plus/device_info_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';

class DeviceService {
  static const String _boxName = 'device_settings';
  static const String _deviceIdKey = 'device_id';
  late Box _box;

  Future<void> initialize() async {
    _box = await Hive.openBox(_boxName);
  }

  /// Get or generate a unique device ID
  Future<String> getDeviceId() async {
    String? savedId = _box.get(_deviceIdKey);
    
    if (savedId != null && savedId.isNotEmpty) {
      return savedId;
    }

    // Generate new device ID based on device info
    final deviceInfo = DeviceInfoPlugin();
    String newDeviceId;

    try {
      // This will work on most platforms
      final androidInfo = await deviceInfo.androidInfo;
      newDeviceId = androidInfo.id; // Uses Android device ID
    } catch (e) {
      // Fallback to timestamp-based ID if device info fails
      newDeviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
    }

    // Save for future use
    await _box.put(_deviceIdKey, newDeviceId);
    return newDeviceId;
  }

  /// Clear device settings (for testing)
  Future<void> clearDeviceId() async {
    await _box.delete(_deviceIdKey);
  }
}
