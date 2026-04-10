import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unimas_smartbus/models/bus_model.dart';
import 'package:unimas_smartbus/services/firestore_service.dart';

void main() {
  group('FirestoreService student flow', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = FirestoreService(firestore: firestore);
    });

    Future<void> seedBus(String busId) async {
      final bus = Bus(
        busId: busId,
        busNumber: 'B1',
        registrationNumber: 'QAB1234',
        capacity: 40,
        currentOccupancy: 0,
        lastUpdated: DateTime.now(),
        isActive: true,
        latitude: 1.5,
        longitude: 110.3,
      );
      await firestore.collection('buses').doc(busId).set(bus.toMap());
    }

    test('tapInToBus creates active session', () async {
      final result = await service.tapInToBus('device-1', 'bus-1');

      expect(result, isNull);
      final snap = await firestore
          .collection('device_bus_sessions')
          .where('deviceId', isEqualTo: 'device-1')
          .where('status', isEqualTo: 'active')
          .get();
      expect(snap.docs.length, 1);
      expect(snap.docs.first.data()['busId'], 'bus-1');
    });

    test('tapInToBus blocks tapping into another active bus', () async {
      await firestore.collection('device_bus_sessions').doc('session-1').set({
        'sessionId': 'session-1',
        'deviceId': 'device-1',
        'busId': 'bus-1',
        'status': 'active',
        'tappedInAt': Timestamp.now(),
        'tappedOutAt': null,
      });

      final result = await service.tapInToBus('device-1', 'bus-2');

      expect(result, isNotNull);
      expect(result, contains('already tapped'));
      final active = await firestore
          .collection('device_bus_sessions')
          .where('deviceId', isEqualTo: 'device-1')
          .where('status', isEqualTo: 'active')
          .get();
      expect(active.docs.length, 1);
      expect(active.docs.first.data()['busId'], 'bus-1');
    });

    test('tapOutFromBus completes active session', () async {
      await firestore.collection('device_bus_sessions').doc('session-1').set({
        'sessionId': 'session-1',
        'deviceId': 'device-1',
        'busId': 'bus-1',
        'status': 'active',
        'tappedInAt': Timestamp.now(),
        'tappedOutAt': null,
      });

      final result = await service.tapOutFromBus('device-1');

      expect(result, isNull);
      final doc = await firestore.collection('device_bus_sessions').doc('session-1').get();
      expect(doc.data()!['status'], 'completed');
      expect(doc.data()!['tappedOutAt'], isNotNull);
    });

    test('createStudentTrip then completeStudentTrip using studentUid', () async {
      await seedBus('bus-1');

      final createResult = await service.createStudentTrip(
        deviceId: 'device-1',
        busId: 'bus-1',
        studentUid: 'student-1',
      );
      expect(createResult, isNull);

      final activeTrips = await firestore
          .collection('student_trips')
          .where('studentUid', isEqualTo: 'student-1')
          .where('status', isEqualTo: 'active')
          .get();
      expect(activeTrips.docs.length, 1);

      final completeResult = await service.completeStudentTrip(
        'device-1',
        studentUid: 'student-1',
      );
      expect(completeResult, isNull);

      final updated = await firestore
          .collection('student_trips')
          .doc(activeTrips.docs.first.id)
          .get();
      expect(updated.data()!['status'], 'completed');
      expect(updated.data()!['offBoardedAt'], isNotNull);
    });

    test('completeStudentTrip falls back to deviceId for legacy trips', () async {
      await firestore.collection('student_trips').doc('legacy-trip').set({
        'tripId': 'legacy-trip',
        'deviceId': 'legacy-device',
        'studentUid': null,
        'busId': 'bus-1',
        'busNumber': 'B1',
        'busRegistrationNumber': 'QAB1234',
        'routeId': null,
        'routeName': null,
        'boardedAt': Timestamp.now(),
        'offBoardedAt': null,
        'status': 'active',
      });

      final result = await service.completeStudentTrip(
        'legacy-device',
        studentUid: 'new-student-uid',
      );

      expect(result, isNull);
      final updated =
          await firestore.collection('student_trips').doc('legacy-trip').get();
      expect(updated.data()!['status'], 'completed');
      expect(updated.data()!['offBoardedAt'], isNotNull);
    });
  });
}
