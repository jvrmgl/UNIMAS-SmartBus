import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unimas_smartbus/models/bus_model.dart';
import 'package:unimas_smartbus/services/firestore_service.dart';

void main() {
  group('FirestoreService reconcile and safeguard flows', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = FirestoreService(firestore: firestore);
    });

    Future<void> seedBus({
      required String busId,
      required int occupancy,
      bool isActive = true,
    }) async {
      final bus = Bus(
        busId: busId,
        busNumber: 'B1',
        registrationNumber: 'QAB1234',
        capacity: 40,
        currentOccupancy: occupancy,
        lastUpdated: DateTime.now(),
        isActive: isActive,
        latitude: 1.5,
        longitude: 110.3,
      );
      await firestore.collection('buses').doc(busId).set(bus.toMap());
    }

    Future<void> seedActiveSession({
      required String sessionId,
      required String deviceId,
      required String busId,
    }) async {
      await firestore.collection('device_bus_sessions').doc(sessionId).set({
        'sessionId': sessionId,
        'deviceId': deviceId,
        'busId': busId,
        'status': 'active',
        'tappedInAt': Timestamp.now(),
        'tappedOutAt': null,
      });
    }

    Future<void> seedActiveTrip({
      required String tripId,
      required String deviceId,
      required String busId,
      String? studentUid,
    }) async {
      await firestore.collection('student_trips').doc(tripId).set({
        'tripId': tripId,
        'deviceId': deviceId,
        'studentUid': studentUid,
        'busId': busId,
        'busNumber': 'B1',
        'busRegistrationNumber': 'QAB1234',
        'routeId': null,
        'routeName': null,
        'boardedAt': Timestamp.now(),
        'offBoardedAt': null,
        'status': 'active',
      });
    }

    test('autoTapOut closes active records and decrements occupancy', () async {
      await seedBus(busId: 'bus-1', occupancy: 5);
      await seedActiveSession(
        sessionId: 'session-1',
        deviceId: 'device-1',
        busId: 'bus-1',
      );
      await seedActiveSession(
        sessionId: 'session-2',
        deviceId: 'device-1',
        busId: 'bus-1',
      );
      await seedActiveTrip(
        tripId: 'trip-1',
        deviceId: 'device-1',
        busId: 'bus-1',
        studentUid: 'student-1',
      );

      final result = await service.autoTapOutStudentSession(
        deviceId: 'device-1',
        studentUid: 'student-1',
        reason: 'unit_test',
      );

      expect(result, isNull);

      final completedSessions = await firestore
          .collection('device_bus_sessions')
          .where('deviceId', isEqualTo: 'device-1')
          .where('status', isEqualTo: 'completed')
          .get();
      expect(completedSessions.docs.length, 2);
      for (final doc in completedSessions.docs) {
        final data = doc.data();
        expect(data['closedBySafeguard'], true);
        expect(data['safeguardReason'], 'unit_test');
        expect(data['tappedOutAt'], isNotNull);
      }

      final trip = await firestore.collection('student_trips').doc('trip-1').get();
      expect(trip.data()!['status'], 'completed');
      expect(trip.data()!['closedBySafeguard'], true);
      expect(trip.data()!['safeguardReason'], 'unit_test');
      expect(trip.data()!['offBoardedAt'], isNotNull);

      final bus = await firestore.collection('buses').doc('bus-1').get();
      expect(bus.data()!['currentOccupancy'], 3);
    });

    test('autoTapOut can skip occupancy decrement when requested', () async {
      await seedBus(busId: 'bus-1', occupancy: 4);
      await seedActiveSession(
        sessionId: 'session-1',
        deviceId: 'device-1',
        busId: 'bus-1',
      );
      await seedActiveTrip(
        tripId: 'trip-1',
        deviceId: 'device-1',
        busId: 'bus-1',
        studentUid: 'student-1',
      );

      final result = await service.autoTapOutStudentSession(
        deviceId: 'device-1',
        studentUid: 'student-1',
        reason: 'no_decrement',
        decrementBusOccupancy: false,
      );

      expect(result, isNull);
      final bus = await firestore.collection('buses').doc('bus-1').get();
      expect(bus.data()!['currentOccupancy'], 4);
    });

    test('reconcile closes stale trip when active session is missing', () async {
      await seedActiveTrip(
        tripId: 'trip-1',
        deviceId: 'device-1',
        busId: 'bus-1',
        studentUid: 'student-1',
      );

      final changed = await service.reconcileStudentActiveState(
        deviceId: 'device-1',
        studentUid: 'student-1',
      );

      expect(changed, true);
      final trip = await firestore.collection('student_trips').doc('trip-1').get();
      expect(trip.data()!['status'], 'completed');
      expect(trip.data()!['closedBySafeguard'], true);
      expect(trip.data()!['safeguardReason'], 'reconcile_missing_session');
    });

    test('reconcile leaves state unchanged when trip and session are aligned',
        () async {
      await seedBus(busId: 'bus-1', occupancy: 8, isActive: true);
      await seedActiveSession(
        sessionId: 'session-1',
        deviceId: 'device-1',
        busId: 'bus-1',
      );
      await seedActiveTrip(
        tripId: 'trip-1',
        deviceId: 'device-1',
        busId: 'bus-1',
        studentUid: 'student-1',
      );

      final changed = await service.reconcileStudentActiveState(
        deviceId: 'device-1',
        studentUid: 'student-1',
      );

      expect(changed, false);
      final session =
          await firestore.collection('device_bus_sessions').doc('session-1').get();
      final trip = await firestore.collection('student_trips').doc('trip-1').get();
      expect(session.data()!['status'], 'active');
      expect(trip.data()!['status'], 'active');
    });

    test('reconcile closes stale state on inactive bus without decrement', () async {
      await seedBus(busId: 'bus-1', occupancy: 7, isActive: false);
      await seedActiveSession(
        sessionId: 'session-1',
        deviceId: 'device-1',
        busId: 'bus-1',
      );
      await seedActiveTrip(
        tripId: 'trip-1',
        deviceId: 'device-1',
        busId: 'bus-1',
        studentUid: 'student-1',
      );

      final changed = await service.reconcileStudentActiveState(
        deviceId: 'device-1',
        studentUid: 'student-1',
      );

      expect(changed, true);

      final session =
          await firestore.collection('device_bus_sessions').doc('session-1').get();
      final trip = await firestore.collection('student_trips').doc('trip-1').get();
      final bus = await firestore.collection('buses').doc('bus-1').get();

      expect(session.data()!['status'], 'completed');
      expect(session.data()!['safeguardReason'], 'reconcile_inactive_bus');
      expect(trip.data()!['status'], 'completed');
      expect(trip.data()!['safeguardReason'], 'reconcile_inactive_bus');
      expect(bus.data()!['currentOccupancy'], 7);
    });

    test('reconcile closes mismatch and decrements active session bus occupancy',
        () async {
      await seedBus(busId: 'bus-1', occupancy: 9, isActive: true);
      await seedBus(busId: 'bus-2', occupancy: 11, isActive: true);
      await seedActiveSession(
        sessionId: 'session-1',
        deviceId: 'device-1',
        busId: 'bus-1',
      );
      await seedActiveTrip(
        tripId: 'trip-1',
        deviceId: 'device-1',
        busId: 'bus-2',
        studentUid: 'student-1',
      );

      final changed = await service.reconcileStudentActiveState(
        deviceId: 'device-1',
        studentUid: 'student-1',
      );

      expect(changed, true);

      final session =
          await firestore.collection('device_bus_sessions').doc('session-1').get();
      final trip = await firestore.collection('student_trips').doc('trip-1').get();
      final sessionBus = await firestore.collection('buses').doc('bus-1').get();
      final tripBus = await firestore.collection('buses').doc('bus-2').get();

      expect(session.data()!['status'], 'completed');
      expect(session.data()!['safeguardReason'], 'reconcile_trip_session_mismatch');
      expect(trip.data()!['status'], 'completed');
      expect(trip.data()!['safeguardReason'], 'reconcile_trip_session_mismatch');
      expect(sessionBus.data()!['currentOccupancy'], 8);
      expect(tripBus.data()!['currentOccupancy'], 11);
    });
  });
}
