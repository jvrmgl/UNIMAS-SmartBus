import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unimas_smartbus/models/bus_model.dart';
import 'package:unimas_smartbus/providers/driver_shift_provider.dart';
import 'package:unimas_smartbus/services/driver_tracking_service.dart';
import 'package:unimas_smartbus/services/firestore_service.dart';

class FakeFirestoreService extends FirestoreService {
  FakeFirestoreService() : super(firestore: FakeFirebaseFirestore());

  final List<Bus> buses = [];
  final List<String> clearedSessionBusIds = [];
  final List<String> completedTripBusIds = [];
  final List<Map<String, dynamic>> activationCalls = [];
  String? setBusActiveStatusError;

  final Map<String, StreamController<Bus?>> _controllers = {};

  @override
  Future<List<Bus>> getBuses() async => List<Bus>.from(buses);

  @override
  Stream<Bus?> getBusStream(String busId) {
    final controller = _controllers.putIfAbsent(
      busId,
      () => StreamController<Bus?>.broadcast(),
    );
    return controller.stream;
  }

  void emitBusUpdate(Bus bus) {
    final controller = _controllers.putIfAbsent(
      bus.busId,
      () => StreamController<Bus?>.broadcast(),
    );
    controller.add(bus);
  }

  @override
  Future<String?> setBusActiveStatus({
    required String busId,
    required bool isActive,
    String? adminName,
  }) async {
    activationCalls.add({
      'busId': busId,
      'isActive': isActive,
      'adminName': adminName,
    });
    return setBusActiveStatusError;
  }

  @override
  Future<void> clearBusActiveSessions(String busId) async {
    clearedSessionBusIds.add(busId);
  }

  @override
  Future<void> completeAllBusStudentTrips(String busId) async {
    completedTripBusIds.add(busId);
  }

  Future<void> disposeControllers() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
    _controllers.clear();
  }
}

class FakeDriverTrackingService implements DriverTrackingService {
  bool _isTracking = false;
  int startCalls = 0;
  int stopCalls = 0;
  bool failToStart = false;
  String? startErrorMessage;

  @override
  bool get isTracking => _isTracking;

  @override
  Future<void> startTracking({
    required String busId,
    int updateIntervalSeconds = 10,
    Function(String error)? onError,
  }) async {
    startCalls++;
    if (failToStart) {
      onError?.call(startErrorMessage ?? 'tracking failed');
      return;
    }

    _isTracking = true;
    if (startErrorMessage != null) {
      onError?.call(startErrorMessage!);
    }
  }

  @override
  void stopTracking() {
    stopCalls++;
    _isTracking = false;
  }

  @override
  void dispose() {
    _isTracking = false;
  }
}

void main() {
  group('DriverShiftProvider', () {
    late FakeFirebaseFirestore firestore;
    late FakeFirestoreService firestoreService;
    late FakeDriverTrackingService trackingService;
    late DriverShiftProvider provider;

    Bus buildAssignedBus({
      String busId = 'bus-1',
      bool isActive = false,
      int occupancy = 0,
      String driverId = 'driver-1',
      String driverName = 'Driver One',
    }) {
      return Bus(
        busId: busId,
        busNumber: 'B1',
        registrationNumber: 'QAB1234',
        capacity: 40,
        currentOccupancy: occupancy,
        lastUpdated: DateTime.now(),
        isActive: isActive,
        latitude: 1.5,
        longitude: 110.3,
        driverId: driverId,
        driverName: driverName,
      );
    }

    setUp(() {
      firestore = FakeFirebaseFirestore();
      firestoreService = FakeFirestoreService();
      trackingService = FakeDriverTrackingService();
      provider = DriverShiftProvider(
        firestoreService: firestoreService,
        trackingService: trackingService,
        firestore: firestore,
      );
    });

    tearDown(() async {
      provider.dispose();
      await firestoreService.disposeControllers();
    });

    test('startShift fails when no bus is assigned', () async {
      final started = await provider.startShift();

      expect(started, false);
      expect(provider.isOnShift, false);
      expect(provider.error, 'No bus assigned');
      expect(trackingService.startCalls, 0);
    });

    test('startShift fails when bus activation fails', () async {
      final bus = buildAssignedBus(isActive: false);
      firestoreService.buses.add(bus);
      firestoreService.setBusActiveStatusError = 'activation failed';

      provider.setDriverUid('driver-1');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final started = await provider.startShift();

      expect(provider.hasAssignedBus, true);
      expect(started, false);
      expect(provider.isOnShift, false);
      expect(provider.error, 'activation failed');
      expect(trackingService.startCalls, 0);
    });

    test('startShift succeeds and starts tracking', () async {
      final bus = buildAssignedBus(isActive: false);
      firestoreService.buses.add(bus);

      provider.setDriverUid('driver-1');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final started = await provider.startShift();

      expect(started, true);
      expect(provider.isOnShift, true);
      expect(provider.error, isNull);
      expect(trackingService.startCalls, 1);
      expect(firestoreService.activationCalls.length, 1);
      expect(firestoreService.activationCalls.first['busId'], 'bus-1');
      expect(firestoreService.activationCalls.first['isActive'], true);
    });

    test('endShift stops tracking and clears active sessions/trips', () async {
      final bus = buildAssignedBus(isActive: false, occupancy: 9);
      firestoreService.buses.add(bus);
      await firestore.collection('buses').doc(bus.busId).set(bus.toMap());

      provider.setDriverUid('driver-1');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final started = await provider.startShift();
      expect(started, true);
      expect(provider.isOnShift, true);

      await provider.endShift();

      final busDoc = await firestore.collection('buses').doc(bus.busId).get();
      expect(provider.isOnShift, false);
      expect(trackingService.isTracking, false);
      expect(trackingService.stopCalls, greaterThanOrEqualTo(1));
      expect(firestoreService.clearedSessionBusIds, contains(bus.busId));
      expect(firestoreService.completedTripBusIds, contains(bus.busId));
      expect(busDoc.data()!['isActive'], false);
      expect(busDoc.data()!['currentOccupancy'], 0);
    });

    test('reacts to admin bus activation through stream', () async {
      final bus = buildAssignedBus(isActive: false);
      firestoreService.buses.add(bus);

      provider.setDriverUid('driver-1');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      firestoreService.emitBusUpdate(bus.copyWith(isActive: true));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(provider.isOnShift, true);
      expect(trackingService.startCalls, 1);
      expect(provider.assignedBus?.isActive, true);
    });

    test('clearShiftState resets provider and tracking state', () async {
      final bus = buildAssignedBus(isActive: false);
      firestoreService.buses.add(bus);

      provider.setDriverUid('driver-1');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await provider.startShift();

      provider.clearShiftState();

      expect(provider.hasAssignedBus, false);
      expect(provider.isOnShift, false);
      expect(provider.error, isNull);
      expect(trackingService.isTracking, false);
    });
  });
}
