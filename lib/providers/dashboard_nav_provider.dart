import 'package:flutter/material.dart';

/// Thin provider that lets the map screen request a tab change in the
/// StudentDashboardScreen without tightly coupling the two widgets.
class DashboardNavProvider extends ChangeNotifier {
  int? _pendingDashboardTab;
  bool _switchToHome = false;
  bool _switchToMap = false;
  double? _pendingMapLatitude;
  double? _pendingMapLongitude;

  /// Non-null when a specific dashboard tab should be activated.
  int? get pendingDashboardTab => _pendingDashboardTab;

  /// True when GuestHomeScreen should switch its bottom nav to the Dashboard.
  bool get shouldSwitchToHome => _switchToHome;

  /// True when GuestHomeScreen should switch its bottom nav to the Map.
  bool get shouldSwitchToMap => _switchToMap;

  /// Non-null when GuestMapScreen should animate to a specific location.
  double? get pendingMapLatitude => _pendingMapLatitude;
  double? get pendingMapLongitude => _pendingMapLongitude;

  /// Request navigation to [tab] index in StudentDashboardScreen.
  void navigateToDashboardTab(int tab) {
    _pendingDashboardTab = tab;
    _switchToHome = true;
    notifyListeners();
  }

  /// Switch to the Map tab and animate the map camera to [lat]/[lng].
  void navigateToMapWithFocus(double lat, double lng) {
    _pendingMapLatitude = lat;
    _pendingMapLongitude = lng;
    _switchToMap = true;
    notifyListeners();
  }

  /// Called by GuestHomeScreen after it has processed the home switch.
  void consumeHomeSwitch() {
    _switchToHome = false;
  }

  /// Called by GuestHomeScreen after it has processed the map switch.
  void consumeMapSwitch() {
    _switchToMap = false;
  }

  /// Called by GuestMapScreen after it has animated to the requested location.
  void consumeMapFocus() {
    _pendingMapLatitude = null;
    _pendingMapLongitude = null;
  }

  /// Called by StudentDashboardScreen after it has processed the tab change.
  void consumeDashboardTab() {
    _pendingDashboardTab = null;
  }
}
