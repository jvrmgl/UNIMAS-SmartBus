import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';

class DeviceService {
  // Singleton pattern
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal();

  static const String _boxName = 'device_settings';
  static const String _deviceIdKey = 'device_id';
  Box? _box;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return; // Already initialized
    
    try {
      _box = await Hive.openBox(_boxName);
      _isInitialized = true;
      debugPrint('✅ DeviceService initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing DeviceService: $e');
      rethrow;
    }
  }

  /// Get or generate a unique device ID
  Future<String> getDeviceId() async {
    // Ensure initialized
    if (!_isInitialized || _box == null) {
      await initialize();
    }

    String? savedId = _box!.get(_deviceIdKey);
    
    if (savedId != null && savedId.isNotEmpty) {
      return savedId;
    }

    // Generate new device ID based on device info
    final deviceInfo = DeviceInfoPlugin();
    String newDeviceId;

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        newDeviceId = androidInfo.id; // Uses Android device ID
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        newDeviceId = iosInfo.identifierForVendor ?? 'ios_${DateTime.now().millisecondsSinceEpoch}';
      } else {
        // Fallback for other platforms
        newDeviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (e) {
      debugPrint('⚠️ Error getting device info: $e');
      // Fallback to timestamp-based ID if device info fails
      newDeviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
    }

    // Save for future use
    await _box!.put(_deviceIdKey, newDeviceId);
    return newDeviceId;
  }

  /// Clear device settings (for testing)
  Future<void> clearDeviceId() async {
    if (!_isInitialized || _box == null) {
      await initialize();
    }
    await _box!.delete(_deviceIdKey);
  }
}
