import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unimas_smartbus/models/bus_model.dart';
import 'package:unimas_smartbus/services/firestore_service.dart';

void main() {
  group('FirestoreService shift cleanup safeguards', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = FirestoreService(firestore: firestore);
    });

    Future<void> seedBus({
      required String busId,
      required bool isActive,
      required int occupancy,
      String? driverId,
      String? driverName,
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
        driverId: driverId,
        driverName: driverName,
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
    }) async {
      await firestore.collection('student_trips').doc(tripId).set({
        'tripId': tripId,
        'deviceId': deviceId,
        'studentUid': 'student-1',
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

    test('setBusActiveStatus(false) resets occupancy and clears active state',
        () async {
      await seedBus(busId: 'bus-1', isActive: true, occupancy: 12);
      await seedActiveSession(
        sessionId: 'session-1',
        deviceId: 'device-1',
        busId: 'bus-1',
      );
      await seedActiveSession(
        sessionId: 'session-2',
        deviceId: 'device-2',
        busId: 'bus-1',
      );
      await seedActiveTrip(
        tripId: 'trip-1',
        deviceId: 'device-1',
        busId: 'bus-1',
      );
      await seedActiveTrip(
        tripId: 'trip-2',
        deviceId: 'device-2',
        busId: 'bus-1',
      );

      final result = await service.setBusActiveStatus(
        busId: 'bus-1',
        isActive: false,
      );

      expect(result, isNull);

      final bus = await firestore.collection('buses').doc('bus-1').get();
      expect(bus.data()!['isActive'], false);
      expect(bus.data()!['currentOccupancy'], 0);

      final sessions = await firestore
          .collection('device_bus_sessions')
          .where('busId', isEqualTo: 'bus-1')
          .get();
      expect(sessions.docs.length, 2);
      for (final doc in sessions.docs) {
        final data = doc.data();
        expect(data['status'], 'completed');
        expect(data['closedByShiftEnd'], true);
        expect(data['tappedOutAt'], isNotNull);
      }

      final trips = await firestore
          .collection('student_trips')
          .where('busId', isEqualTo: 'bus-1')
          .get();
      expect(trips.docs.length, 2);
      for (final doc in trips.docs) {
        final data = doc.data();
        expect(data['status'], 'completed');
        expect(data['closedByShiftEnd'], true);
        expect(data['offBoardedAt'], isNotNull);
      }
    });

    test('setBusActiveStatus(true) keeps active sessions and records admin',
        () async {
      await seedBus(busId: 'bus-1', isActive: false, occupancy: 0);
      await seedActiveSession(
        sessionId: 'session-1',
        deviceId: 'device-1',
        busId: 'bus-1',
      );
      await seedActiveTrip(
        tripId: 'trip-1',
        deviceId: 'device-1',
        busId: 'bus-1',
      );

      final result = await service.setBusActiveStatus(
        busId: 'bus-1',
        isActive: true,
        adminName: 'Admin A',
      );

      expect(result, isNull);

      final bus = await firestore.collection('buses').doc('bus-1').get();
      expect(bus.data()!['isActive'], true);
      expect(bus.data()!['activatedByAdminName'], 'Admin A');

      final session =
          await firestore.collection('device_bus_sessions').doc('session-1').get();
      final trip = await firestore.collection('student_trips').doc('trip-1').get();
      expect(session.data()!['status'], 'active');
      expect(trip.data()!['status'], 'active');
    });

    test('removeDriverFromBus deactivates bus and clears active states',
        () async {
      await seedBus(
        busId: 'bus-1',
        isActive: true,
        occupancy: 6,
        driverId: 'driver-1',
        driverName: 'Driver One',
      );
      await seedActiveSession(
        sessionId: 'session-1',
        deviceId: 'device-1',
        busId: 'bus-1',
      );
      await seedActiveTrip(
        tripId: 'trip-1',
        deviceId: 'device-1',
        busId: 'bus-1',
      );

      final result = await service.removeDriverFromBus('bus-1');

      expect(result, isNull);

      final bus = await firestore.collection('buses').doc('bus-1').get();
      expect(bus.data()!['driverId'], isNull);
      expect(bus.data()!['driverName'], isNull);
      expect(bus.data()!['isActive'], false);
      expect(bus.data()!['currentOccupancy'], 0);

      final session =
          await firestore.collection('device_bus_sessions').doc('session-1').get();
      final trip = await firestore.collection('student_trips').doc('trip-1').get();
      expect(session.data()!['status'], 'completed');
      expect(session.data()!['closedByShiftEnd'], true);
      expect(trip.data()!['status'], 'completed');
      expect(trip.data()!['closedByShiftEnd'], true);
    });
  });
}
