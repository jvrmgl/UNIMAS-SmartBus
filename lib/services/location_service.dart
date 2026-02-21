import 'package:geolocator/geolocator.dart';

class LocationService {
  // Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  // Request location permissions
  static Future<LocationPermission> requestLocationPermission() async {
    return await Geolocator.requestPermission();
  }

  // Check current permission status
  static Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  // Get current position
  static Future<Position?> getCurrentPosition() async {
    try {
      final permission = await checkPermission();
      
      if (permission == LocationPermission.denied) {
        final newPermission = await requestLocationPermission();
        if (newPermission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Permissions are denied forever, cannot request again.
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
    } catch (e) {
      print('Error getting current position: $e');
      return null;
    }
  }

  // Stream position updates
  static Stream<Position> getPositionStream({
    int distanceFilter = 10, // Update every 10 meters
    int intervalInSeconds = 10, // Update every 10 seconds
  }) {
    // Use AndroidSettings for better compatibility
    final androidSettings = AndroidSettings(
      accuracy: LocationAccuracy.high, // Good balance of accuracy and battery
      distanceFilter: 10,
      forceLocationManager: false, // Use FusedLocationProvider (better)
      intervalDuration: const Duration(seconds: 10),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationText: 'SmartBus is tracking your location for real-time bus updates',
        notificationTitle: 'Location Tracking Active',
        enableWakeLock: true,
      ),
    );

    return Geolocator.getPositionStream(
      locationSettings: androidSettings,
    );
  }

  // Calculate distance between two coordinates
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  // Open location settings
  static Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  // Open app settings
  static Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }
}
