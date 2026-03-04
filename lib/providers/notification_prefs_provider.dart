import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Persists per-user notification preferences to Hive.
/// Every toggle maps directly to one Cloud Function behaviour:
///   - busApproaching   → checkApproachingBuses CF sends FCM to this device
///   - tapOutReminder   → sendTapOutReminders CF sends FCM after 30 min
///   - autoDetectWaiting → SmartNotificationService auto-creates waiting record
///   - driverShiftReminder → sendDriverShiftReminders CF targets this driver
///
/// Preferences are scoped per user: Hive box name is `notif_prefs_<uid>`
/// so two drivers sharing a device each keep their own settings.
class NotificationPrefsProvider extends ChangeNotifier {
  // UID of the currently loaded user.  Null until [load] is called.
  String? _currentUid;

  bool _busApproaching = true;
  bool _tapOutReminder = true;
  bool _autoDetectWaiting = true;
  bool _driverShiftReminder = true;

  bool get busApproaching => _busApproaching;
  bool get tapOutReminder => _tapOutReminder;
  bool get autoDetectWaiting => _autoDetectWaiting;
  bool get driverShiftReminder => _driverShiftReminder;

  String _boxName(String uid) => 'notif_prefs_$uid';

  /// Load preferences for [uid].  Safe to call on every login — if the
  /// same UID is already loaded nothing changes; a new UID opens its own
  /// isolated Hive box.
  Future<void> load(String uid) async {
    _currentUid = uid;
    final box = await Hive.openBox(_boxName(uid));
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

  /// Resets in-memory preferences to defaults without writing to Hive.
  /// Call on sign-out so the UI shows safe defaults while the next user
  /// loads their own preferences.
  void resetToDefaults() {
    _currentUid = null;
    _busApproaching = true;
    _tapOutReminder = true;
    _autoDetectWaiting = true;
    _driverShiftReminder = true;
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
    if (_currentUid == null) return; // no user loaded yet
    final box = await Hive.openBox(_boxName(_currentUid!));
    await box.put(key, value);
  }
}
