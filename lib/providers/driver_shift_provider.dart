import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bus_model.dart';
import '../services/driver_tracking_service.dart';
import '../services/firestore_service.dart';

/// Manages driver shift state and location tracking
class DriverShiftProvider extends ChangeNotifier {
  DriverShiftProvider({
    FirestoreService? firestoreService,
    DriverTrackingService? trackingService,
    FirebaseFirestore? firestore,
  })  : _firestoreService = firestoreService ?? FirestoreService(),
        _trackingService = trackingService ?? DriverTrackingService(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirestoreService _firestoreService;
  final DriverTrackingService _trackingService;
  final FirebaseFirestore _firestore;

  Bus? _assignedBus;
  bool _isOnShift = false;
  bool _isStartingShift = false;
  bool _isAutoStartingShift = false;
  String? _error;
  String? _driverUid;
  StreamSubscription<Bus?>? _assignedBusSubscription;

  Bus? get assignedBus => _assignedBus;
  bool get isOnShift => _isOnShift;
  bool get isTracking => _trackingService.isTracking;
  String? get error => _error;
  bool get hasAssignedBus => _assignedBus != null;

  /// Subscribe to real-time updates for the assigned bus.
  /// Automatically starts/ends the shift when an admin remotely
  /// activates or deactivates the bus.
  void _subscribeToBus(String busId) {
    _assignedBusSubscription?.cancel();
    _assignedBusSubscription =
        _firestoreService.getBusStream(busId).listen((bus) {
      if (bus == null) return;

      _assignedBus = bus;
      notifyListeners();

      // Keep local shift state aligned with Firestore truth.
      // This also handles app relaunch where bus is already active.
      if (bus.isActive && !_isOnShift) {
        _autoStartShift();
      }
      // Admin deactivated the bus → auto-end tracking
      if (!bus.isActive && _isOnShift) {
        endShift();
      }
    });
  }

  /// Called when the admin remotely activates this driver's bus.
  /// Starts GPS tracking and marks the shift as active without
  /// calling setBusActiveStatus (it's already true in Firestore).
  /// Guards against racing with the driver's own [startShift] call.
  Future<void> _autoStartShift() async {
    if (_assignedBus == null ||
        _isOnShift ||
        _trackingService.isTracking ||
        _isStartingShift ||
        _isAutoStartingShift) {
      return;
    }

    _isAutoStartingShift = true;
    try {
      await _trackingService.startTracking(
        busId: _assignedBus!.busId,
        updateIntervalSeconds: 10,
        onError: (error) {
          _error = error;
          notifyListeners();
        },
      );
      _isOnShift = true;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to auto-start shift: $e';
      notifyListeners();
    } finally {
      _isAutoStartingShift = false;
    }
  }

  /// Initialize driver with their UID.
  /// If a different driver was previously using this provider instance
  /// (same device, different account), all prior state is cleared first
  /// so Driver B never inherits Driver A's shift or bus.
  void setDriverUid(String uid) {
    if (_driverUid != null && _driverUid != uid) {
      // New driver on same device — wipe state from previous session.
      _assignedBusSubscription?.cancel();
      _assignedBusSubscription = null;
      if (_trackingService.isTracking) {
        _trackingService.stopTracking();
      }
      _assignedBus = null;
      _isOnShift = false;
      _error = null;
    }
    _driverUid = uid;
    _checkAssignedBus();
  }

  /// Check if admin has already assigned a bus to this driver.
  /// Explicitly clears [_assignedBus] when no bus is found so that a new
  /// driver never inherits a stale assignment from a previous session.
  Future<void> _checkAssignedBus() async {
    if (_driverUid == null) return;

    try {
      final buses = await _firestoreService.getBuses();
      final assigned = buses.where((bus) => bus.driverId == _driverUid).firstOrNull;
      
      if (assigned != null) {
        _assignedBus = assigned;
        _subscribeToBus(assigned.busId); // live updates

        // App may have relaunched while bus remained active in Firestore.
        // Resume tracking so local state cannot drift to "ended" incorrectly.
        if (assigned.isActive && !_isOnShift) {
          _autoStartShift();
        }
      } else {
        // No bus assigned to this driver — clear any stale assignment.
        _assignedBus = null;
        if (_trackingService.isTracking) {
          _trackingService.stopTracking();
        }
        _isOnShift = false;
      }
      notifyListeners();
    } catch (e) {
      _error = 'Failed to check assigned bus: $e';
      notifyListeners();
    }
  }

  /// Driver manually selects a bus (if not already assigned by admin)
  Future<bool> selectBus(Bus bus, String driverName) async {
    if (_driverUid == null) return false;

    try {
      // Check if bus is already taken by another driver
      final buses = await _firestoreService.getBuses();
      final existing = buses.where((b) => b.busId == bus.busId).firstOrNull;
      
      if (existing?.driverId != null && existing?.driverId != _driverUid) {
        _error = 'Bus is already assigned to another driver';
        notifyListeners();
        return false;
      }

      // Update bus with driver assignment
      await _firestore.collection('buses').doc(bus.busId).update({
        'driverId': _driverUid,
        'driverName': driverName,
      });

      _assignedBus = bus.copyWith(
        driverId: _driverUid,
        driverName: driverName,
      );
      _subscribeToBus(bus.busId); // live updates
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to select bus: $e';
      notifyListeners();
      return false;
    }
  }

  /// Release current bus assignment
  Future<void> releaseBus() async {
    if (_assignedBus == null) return;
    _assignedBusSubscription?.cancel();
    _assignedBusSubscription = null;

    if (_isOnShift) {
      await endShift();
    }

    try {
      await _firestore
          .collection('buses')
          .doc(_assignedBus!.busId)
          .update({
        'driverId': null,
        'driverName': null,
        'isActive': false,
      });

      _assignedBus = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to release bus: $e';
      notifyListeners();
    }
  }

  /// Start shift - activates GPS tracking.
  /// Sets [_isOnShift] true immediately (optimistic) so the Firestore stream
  /// update triggered by setBusActiveStatus cannot race and call _autoStartShift
  /// while this method is still running.
  Future<bool> startShift() async {
    if (_assignedBus == null) {
      _error = 'No bus assigned';
      notifyListeners();
      return false;
    }

    if (_isStartingShift || _isAutoStartingShift) {
      return _isOnShift || _trackingService.isTracking;
    }

    if (_isOnShift) {
      return true; // Already on shift
    }

    _isStartingShift = true;

    // Optimistic: mark as on-shift NOW so the incoming Firestore stream event
    // (from setBusActiveStatus below) won't trigger _autoStartShift in parallel.
    _isOnShift = true;

    try {
      // Set bus as active
      final activationError = await _firestoreService.setBusActiveStatus(
        busId: _assignedBus!.busId,
        isActive: true,
      );
      if (activationError != null) {
        _error = activationError;
        _isOnShift = false; // Revert optimistic flag
        notifyListeners();
        return false;
      }

      // Store error messages from tracking service
      String? trackingError;

      // Start GPS tracking
      await _trackingService.startTracking(
        busId: _assignedBus!.busId,
        updateIntervalSeconds: 10,
        onError: (error) {
          trackingError = error;
          _error = error;
          notifyListeners();
        },
      );

      // Check if tracking started successfully
      if (trackingError != null) {
        // Revert bus to inactive if tracking failed
        await _firestoreService.setBusActiveStatus(
          busId: _assignedBus!.busId,
          isActive: false,
        );
        _isOnShift = false; // Revert optimistic flag
        return false;
      }

      _assignedBus = _assignedBus!.copyWith(
        isActive: true,
        lastUpdated: DateTime.now(),
      );
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to start shift: $e';
      // Ensure bus is inactive if shift start failed
      try {
        await _firestoreService.setBusActiveStatus(
          busId: _assignedBus!.busId,
          isActive: false,
        );
      } catch (_) {}
      notifyListeners();
      return false;
    } finally {
      _isStartingShift = false;
    }
  }

  /// End shift - stops GPS tracking
  Future<void> endShift() async {
    if (_assignedBus == null) return;

    try {
      // Stop GPS tracking first
      if (_trackingService.isTracking) {
        _trackingService.stopTracking();
      }
      
      // Give time for cleanup
      await Future.delayed(const Duration(milliseconds: 500));

      // Set bus offline, reset occupancy and clear any stranded student sessions
      String? deactivationError;
      try {
        await Future.wait([
          _firestore
              .collection('buses')
              .doc(_assignedBus!.busId)
              .update({
            'isActive': false,
            'currentOccupancy': 0,
            'activatedByAdminName': FieldValue.delete(),
            'lastUpdated': DateTime.now().toIso8601String(),
          }),
          _firestoreService.clearBusActiveSessions(_assignedBus!.busId),
          _firestoreService.completeAllBusStudentTrips(_assignedBus!.busId),
        ]);
      } catch (e) {
        deactivationError = 'Error updating bus status: $e';
      }

      if (deactivationError != null) {
        _error = deactivationError;
      }

      _assignedBus = _assignedBus!.copyWith(
        isActive: false,
        currentOccupancy: 0,
        lastUpdated: DateTime.now(),
      );

      _isOnShift = false;
      if (deactivationError == null) {
        _error = null;
      }
      notifyListeners();
    } catch (e) {
      _error = 'Failed to end shift: $e';
      _assignedBus = _assignedBus!.copyWith(
        isActive: false,
        currentOccupancy: 0,
        lastUpdated: DateTime.now(),
      );
      _isOnShift = false;
      notifyListeners();
    }
  }

  /// Optimistically update occupancy locally and write to Firestore.
  /// The live stream will reconcile with the server value.
  Future<void> adjustOccupancy(int newOccupancy) async {
    if (_assignedBus == null) return;
    // Optimistic local update — instant UI response
    _assignedBus = _assignedBus!.copyWith(currentOccupancy: newOccupancy);
    notifyListeners();
    // Background Firestore write
    try {
      await _firestoreService.updateBusOccupancy(
        busId: _assignedBus!.busId,
        currentOccupancy: newOccupancy,
      );
    } catch (e) {
      _error = 'Failed to update occupancy: $e';
      notifyListeners();
    }
  }

  /// Refresh assigned bus data
  Future<void> refreshBusData() async {
    if (_assignedBus == null) return;

    try {
      final doc = await _firestore
          .collection('buses')
          .doc(_assignedBus!.busId)
          .get();

      if (doc.exists) {
        _assignedBus = Bus.fromMap(doc.data()!);
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to refresh bus data: $e';
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Fully resets shift state without making any Firestore calls.
  /// Call this when a user signs out so the next driver starts with a
  /// clean slate. For a graceful end (Firestore bus deactivation) call
  /// [endShift] first, then [clearShiftState].
  void clearShiftState() {
    _assignedBusSubscription?.cancel();
    _assignedBusSubscription = null;
    if (_trackingService.isTracking) {
      _trackingService.stopTracking();
    }
    _assignedBus = null;
    _isOnShift = false;
    _driverUid = null;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _assignedBusSubscription?.cancel();
    _trackingService.dispose();
    super.dispose();
  }
}
