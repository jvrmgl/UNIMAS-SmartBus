import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Persists per-user notification preferences to Hive.
/// Every toggle maps directly to one Cloud Function behaviour:
///   - busApproaching   → checkApproachingBuses CF sends FCM to this device
///   - tapOutReminder   → sendTapOutReminders CF sends FCM after 30 min
///   - autoDetectWaiting → SmartNotificationService auto-creates waiting record
///   - driverShiftReminder → sendDriverShiftReminders CF targets this driver
class NotificationPrefsProvider extends ChangeNotifier {
  static const _boxName = 'notif_prefs';

  bool _busApproaching = true;
  bool _tapOutReminder = true;
  bool _autoDetectWaiting = true;
  bool _driverShiftReminder = true;

  bool get busApproaching => _busApproaching;
  bool get tapOutReminder => _tapOutReminder;
  bool get autoDetectWaiting => _autoDetectWaiting;
  bool get driverShiftReminder => _driverShiftReminder;

  Future<void> load() async {
    final box = await Hive.openBox(_boxName);
    _busApproaching =
        box.get('busApproaching', defaultValue: true) as bool;
    _tapOutReminder =
        box.get('tapOutReminder', defaultValue: true) as bool;
    _autoDetectWaiting =
        box.get('autoDetectWaiting', defaultValue: true) as bool;
    _driverShiftReminder =
        box.get('driverShiftReminder', defaultValue: true) as bool;
    notifyListeners();
  }

  Future<void> setBusApproaching(bool v) async {
    _busApproaching = v;
    notifyListeners();
    await _save('busApproaching', v);
  }

  Future<void> setTapOutReminder(bool v) async {
    _tapOutReminder = v;
    notifyListeners();
    await _save('tapOutReminder', v);
  }

  Future<void> setAutoDetectWaiting(bool v) async {
    _autoDetectWaiting = v;
    notifyListeners();
    await _save('autoDetectWaiting', v);
  }

  Future<void> setDriverShiftReminder(bool v) async {
    _driverShiftReminder = v;
    notifyListeners();
    await _save('driverShiftReminder', v);
  }

  Future<void> _save(String key, bool value) async {
    final box = await Hive.openBox(_boxName);
    await box.put(key, value);
  }
}
