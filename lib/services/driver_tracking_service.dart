import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'location_service.dart';

/// Service to handle continuous GPS tracking for drivers
/// Updates bus location in Firestore every 10 seconds
class DriverTrackingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<Position>? _positionSubscription;
  bool _isTracking = false;
  String? _currentBusId;

  bool get isTracking => _isTracking;

  /// Start tracking driver location and updating bus position
  /// [busId] - The bus being driven
  /// [updateIntervalSeconds] - How often to update (default: 10 seconds)
  Future<void> startTracking({
    required String busId,
    int updateIntervalSeconds = 10,
    Function(String error)? onError,
  }) async {
    // Prevent multiple tracking instances
    if (_isTracking && _currentBusId == busId) {
      debugPrint('⚠️ Tracking already active for bus $busId');
      return;
    }

    // Stop any existing tracking first
    if (_isTracking) {
      debugPrint('🛑 Stopping previous tracking before starting new one');
      stopTracking();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    try {
      // Check if location services are enabled
      final serviceEnabled = await LocationService.isLocationServiceEnabled();
      if (!serviceEnabled) {
        onError?.call('Location services are disabled. Please enable them in settings.');
        return;
      }

      // Check and request permissions
      LocationPermission permission = await LocationService.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await LocationService.requestLocationPermission();
        if (permission == LocationPermission.denied) {
          onError?.call('Location permission denied. Please grant permission to track your location.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        onError?.call('Location permission permanently denied. Please enable it in app settings.');
        return;
      }

      _isTracking = true;
      _currentBusId = busId;
      debugPrint('✅ Starting GPS tracking for bus $busId');

      // Start listening to position updates (single stream only)
      _positionSubscription = LocationService.getPositionStream(
        distanceFilter: 10, // Update when moved 10 meters
        intervalInSeconds: updateIntervalSeconds,
      ).listen(
        (Position position) async {
          if (!_isTracking) return; // Safety check
          
          try {
            await _updateBusLocation(
              busId: busId,
              latitude: position.latitude,
              longitude: position.longitude,
            );
            debugPrint('📍 Location updated: ${position.latitude}, ${position.longitude}');
          } catch (e) {
            debugPrint('❌ Failed to update location: $e');
            onError?.call('Failed to update location: $e');
          }
        },
        onError: (error) {
          debugPrint('❌ GPS error: $error');
          onError?.call('GPS error: $error');
        },
        cancelOnError: false, // Keep stream alive on errors
      );
    } catch (e) {
      debugPrint('❌ Failed to start tracking: $e');
      _isTracking = false;
      _currentBusId = null;
      onError?.call('Failed to start tracking: $e');
    }
  }

  /// Update bus location in Firestore
  Future<void> _updateBusLocation({
    required String busId,
    required double latitude,
    required double longitude,
  }) async {
    await _firestore.collection('buses').doc(busId).update({
      'latitude': latitude,
      'longitude': longitude,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  /// Stop tracking location
  void stopTracking() {
    if (!_isTracking) {
      debugPrint('ℹ️ Tracking already stopped');
      return;
    }

    debugPrint('🛑 Stopping GPS tracking for bus $_currentBusId');
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;
    _currentBusId = null;
  }

  /// Clean up resources
  void dispose() {
    debugPrint('🧹 Disposing DriverTrackingService');
    stopTracking();
  }
}
