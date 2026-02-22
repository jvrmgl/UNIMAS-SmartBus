import 'package:flutter/material.dart';

/// Thin provider that lets the map screen request a tab change in the
/// StudentDashboardScreen without tightly coupling the two widgets.
class DashboardNavProvider extends ChangeNotifier {
  int? _pendingDashboardTab;
  bool _switchToHome = false;

  /// Non-null when a specific dashboard tab should be activated.
  int? get pendingDashboardTab => _pendingDashboardTab;

  /// True when GuestHomeScreen should switch its bottom nav to the Dashboard.
  bool get shouldSwitchToHome => _switchToHome;

  /// Request navigation to [tab] index in StudentDashboardScreen.
  void navigateToDashboardTab(int tab) {
    _pendingDashboardTab = tab;
    _switchToHome = true;
    notifyListeners();
  }

  /// Called by GuestHomeScreen after it has processed the switch.
  void consumeHomeSwitch() {
    _switchToHome = false;
  }

  /// Called by StudentDashboardScreen after it has processed the tab change.
  void consumeDashboardTab() {
    _pendingDashboardTab = null;
  }
}
