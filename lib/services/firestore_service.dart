import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/bus_model.dart';
import '../models/route_model.dart';
import '../models/bus_stop_model.dart';
import '../models/report_model.dart';
import '../models/announcement_model.dart';
import '../models/user_model.dart';
import '../models/schedule_image_model.dart';
import '../models/student_trip_model.dart';

class StudentDeviceBindingResult {
  final bool isAllowed;
  final bool requiresTransfer;
  final String? message;

  const StudentDeviceBindingResult._({
    required this.isAllowed,
    required this.requiresTransfer,
    this.message,
  });

  const StudentDeviceBindingResult.allowed({String? message})
      : this._(isAllowed: true, requiresTransfer: false, message: message);

  const StudentDeviceBindingResult.transferRequired({String? message})
      : this._(
          isAllowed: false,
          requiresTransfer: true,
          message:
              message ?? 'This account is already linked to another device.',
        );

  const StudentDeviceBindingResult.denied({String? message})
      : this._(
          isAllowed: false,
          requiresTransfer: false,
          message: message ?? 'Unable to verify account device.',
        );
}

class FirestoreService {
  FirestoreService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _injectedFunctions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions? _injectedFunctions;

  FirebaseFunctions get _functions =>
      _injectedFunctions ??
      FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  // ============ BUS OPERATIONS ============

  // Get all buses
  Future<List<Bus>> getBuses() async {
    try {
      final snapshot = await _firestore.collection('buses').get();
      return snapshot.docs.map((doc) => Bus.fromMap(doc.data())).toList();
    } catch (e) {
      return [];
    }
  }

  // Get single bus
  Future<Bus?> getBus(String busId) async {
    try {
      final doc = await _firestore.collection('buses').doc(busId).get();
      if (doc.exists) {
        return Bus.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Stream real-time bus location updates
  Stream<Bus?> getBusStream(String busId) {
    return _firestore.collection('buses').doc(busId).snapshots().map((doc) {
      if (doc.exists) {
        return Bus.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    });
  }

  // Stream all buses in real-time
  Stream<List<Bus>> getBusesStream() {
    return _firestore.collection('buses').snapshots().map(
          (snapshot) =>
              snapshot.docs.map((doc) => Bus.fromMap(doc.data())).toList(),
        );
  }

  // Update bus location and occupancy
  Future<String?> updateBusLocation({
    required String busId,
    required double latitude,
    required double longitude,
    required int currentOccupancy,
  }) async {
    try {
      await _firestore.collection('buses').doc(busId).update({
        'latitude': latitude,
        'longitude': longitude,
        'currentOccupancy': currentOccupancy,
        'lastUpdated': DateTime.now().toIso8601String(),
      });
      return null; // Success
    } catch (e) {
      return 'Error updating bus location: $e';
    }
  }

  // Update bus occupancy only
  Future<String?> updateBusOccupancy({
    required String busId,
    required int currentOccupancy,
  }) async {
    try {
      await _firestore.collection('buses').doc(busId).update({
        'currentOccupancy': currentOccupancy,
      });
      return null; // Success
    } catch (e) {
      return 'Error updating bus occupancy: $e';
    }
  }

  // Add new bus
  Future<String?> addBus(Bus bus) async {
    try {
      await _firestore.collection('buses').doc(bus.busId).set(bus.toMap());
      return null;
    } catch (e) {
      return 'Error adding bus: $e';
    }
  }

  // Update bus
  Future<String?> updateBus(Bus bus) async {
    try {
      await _firestore.collection('buses').doc(bus.busId).update(bus.toMap());
      return null;
    } catch (e) {
      return 'Error updating bus: $e';
    }
  }

  // Delete bus
  Future<String?> deleteBus(String busId) async {
    try {
      await _firestore.collection('buses').doc(busId).delete();
      return null;
    } catch (e) {
      return 'Error deleting bus: $e';
    }
  }

  // Update active status for a bus.
  // [adminName] is stored on the document so the Cloud Function
  // 'onBusActivated' can include it in the driver push notification.
  Future<String?> setBusActiveStatus({
    required String busId,
    required bool isActive,
    String? adminName,
  }) async {
    try {
      await _firestore.collection('buses').doc(busId).update({
        'isActive': isActive,
        // Reset occupancy when deactivating so stale counts are cleared
        if (!isActive) 'currentOccupancy': 0,
        // When admin activates: store their name so the CF can notify the driver.
        // When driver self-starts OR deactivates: DELETE the field entirely
        // (not just null) so no stale admin name can ever trigger a false push.
        if (isActive && adminName != null)
          'activatedByAdminName': adminName
        else
          'activatedByAdminName': FieldValue.delete(),
        'lastUpdated': DateTime.now().toIso8601String(),
      });

      // Always clear stranded student state when a bus is set inactive,
      // regardless of whether the driver app is still running.
      if (!isActive) {
        await Future.wait([
          clearBusActiveSessions(busId),
          completeAllBusStudentTrips(busId),
        ]);
      }
      return null;
    } catch (e) {
      return 'Error updating bus status: $e';
    }
  }

  // Assign driver to bus
  Future<String?> assignDriverToBus({
    required String busId,
    required String driverId,
    required String driverName,
  }) async {
    try {
      await _firestore.collection('buses').doc(busId).update({
        'driverId': driverId,
        'driverName': driverName,
        'lastUpdated': DateTime.now().toIso8601String(),
      });
      return null;
    } catch (e) {
      return 'Error assigning driver: $e';
    }
  }

  // Remove driver from bus.
  // Also deactivates the bus and resets occupancy so that the driver's
  // DriverShiftProvider stream detects the isActive flip and automatically
  // calls endShift() — stopping GPS tracking and clearing active sessions.
  Future<String?> removeDriverFromBus(String busId) async {
    try {
      await _firestore.collection('buses').doc(busId).update({
        'driverId': null,
        'driverName': null,
        'isActive': false,
        'currentOccupancy': 0,
        'activatedByAdminName': FieldValue.delete(),
        'lastUpdated': DateTime.now().toIso8601String(),
      });

      // Driver unassignment also ends active passenger sessions/trips.
      await Future.wait([
        clearBusActiveSessions(busId),
        completeAllBusStudentTrips(busId),
      ]);
      return null;
    } catch (e) {
      return 'Error removing driver: $e';
    }
  }

  // Assign route to bus
  Future<String?> assignRouteToBus({
    required String busId,
    required String routeId,
  }) async {
    try {
      await _firestore.collection('buses').doc(busId).update({
        'assignedRoute': routeId,
        'lastUpdated': DateTime.now().toIso8601String(),
      });
      return null;
    } catch (e) {
      return 'Error assigning route: $e';
    }
  }

  // Remove route assignment from bus
  Future<String?> removeRouteFromBus(String busId) async {
    try {
      await _firestore.collection('buses').doc(busId).update({
        'assignedRoute': null,
        'lastUpdated': DateTime.now().toIso8601String(),
      });
      return null;
    } catch (e) {
      return 'Error removing route assignment: $e';
    }
  }

  // ============ ROUTE OPERATIONS ============

  // Get all routes
  Future<List<BusRoute>> getRoutes() async {
    try {
      final snapshot = await _firestore.collection('routes').get();
      return snapshot.docs.map((doc) => BusRoute.fromMap(doc.data())).toList();
    } catch (e) {
      return [];
    }
  }

  // Get single route
  Future<BusRoute?> getRoute(String routeId) async {
    try {
      final doc = await _firestore.collection('routes').doc(routeId).get();
      if (doc.exists) {
        return BusRoute.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Add new route
  Future<String?> addRoute(BusRoute route) async {
    try {
      await _firestore
          .collection('routes')
          .doc(route.routeId)
          .set(route.toMap());
      return null;
    } catch (e) {
      return 'Error adding route: $e';
    }
  }

  // Update route
  Future<String?> updateRoute(BusRoute route) async {
    try {
      await _firestore
          .collection('routes')
          .doc(route.routeId)
          .update(route.toMap());
      return null;
    } catch (e) {
      return 'Error updating route: $e';
    }
  }

  // Update route stops
  Future<String?> updateRouteStops({
    required String routeId,
    required List<String> stopIds,
  }) async {
    try {
      await _firestore.collection('routes').doc(routeId).update({
        'stopIds': stopIds,
      });
      return null;
    } catch (e) {
      return 'Error updating route stops: $e';
    }
  }

  // Trigger backend precompute for all route leg distances.
  Future<String?> recomputeAllRouteLegDistances() async {
    try {
      final callable =
          _functions.httpsCallable('recomputeAllRouteLegDistances');
      await callable.call({});
      return null;
    } catch (e) {
      return 'Error recomputing route leg distances: $e';
    }
  }

  // Delete route and unassign from buses
  Future<String?> deleteRoute(String routeId) async {
    try {
      final busesSnapshot = await _firestore
          .collection('buses')
          .where('assignedRoute', isEqualTo: routeId)
          .get();

      final batch = _firestore.batch();
      for (final busDoc in busesSnapshot.docs) {
        batch.update(busDoc.reference, {
          'assignedRoute': null,
          'lastUpdated': DateTime.now().toIso8601String(),
        });
      }

      batch.delete(_firestore.collection('routes').doc(routeId));
      await batch.commit();
      return null;
    } catch (e) {
      return 'Error deleting route: $e';
    }
  }

  // ============ BUS STOP OPERATIONS ============

  // Get all bus stops
  Future<List<BusStop>> getBusStops() async {
    try {
      final snapshot = await _firestore.collection('bus_stops').get();
      return snapshot.docs.map((doc) => BusStop.fromMap(doc.data())).toList();
    } catch (e) {
      return [];
    }
  }

  // Stream all bus stops in real time
  Stream<List<BusStop>> getBusStopsStream() {
    return _firestore.collection('bus_stops').snapshots().map(
          (snapshot) =>
              snapshot.docs.map((doc) => BusStop.fromMap(doc.data())).toList(),
        );
  }

  // Get single bus stop
  Future<BusStop?> getBusStop(String stopId) async {
    try {
      final doc = await _firestore.collection('bus_stops').doc(stopId).get();
      if (doc.exists) {
        return BusStop.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Add bus stop
  Future<String?> addBusStop(BusStop stop) async {
    try {
      await _firestore
          .collection('bus_stops')
          .doc(stop.stopId)
          .set(stop.toMap());
      return null;
    } catch (e) {
      return 'Error adding bus stop: $e';
    }
  }

  // Update bus stop
  Future<String?> updateBusStop(BusStop stop) async {
    try {
      await _firestore
          .collection('bus_stops')
          .doc(stop.stopId)
          .update(stop.toMap());
      return null;
    } catch (e) {
      return 'Error updating bus stop: $e';
    }
  }

  // Delete bus stop and remove it from all routes
  Future<String?> deleteBusStop(String stopId) async {
    try {
      final routesSnapshot = await _firestore.collection('routes').get();
      final batch = _firestore.batch();

      for (final routeDoc in routesSnapshot.docs) {
        final data = routeDoc.data();
        final stopIds = List<String>.from(data['stopIds'] as List? ?? []);
        if (stopIds.contains(stopId)) {
          stopIds.removeWhere((id) => id == stopId);
          batch.update(routeDoc.reference, {'stopIds': stopIds});
        }
      }

      batch.delete(_firestore.collection('bus_stops').doc(stopId));
      await batch.commit();
      return null;
    } catch (e) {
      return 'Error deleting bus stop: $e';
    }
  }

  // ============ REPORT OPERATIONS ============

  // Get reports by authenticated reporter UID.
  Stream<List<Report>> getReportsByReporterUid(String reporterUid) {
    return _firestore
        .collection('reports')
        .where('reporterUid', isEqualTo: reporterUid)
        .snapshots()
        .map((snapshot) {
      final reports =
          snapshot.docs.map((doc) => Report.fromMap(doc.data())).toList();
      reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return reports;
    });
  }

  // Get reports by device id (legacy).
  Stream<List<Report>> getReportsByDeviceId(String deviceId) {
    return _firestore
        .collection('reports')
        .where('studentId', isEqualTo: deviceId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Report.fromMap(doc.data())).toList();
    });
  }

  // Backward-compatible wrapper.
  Stream<List<Report>> getReportsByStudentId(String studentId) {
    return getReportsByDeviceId(studentId);
  }

  // Stream all reports
  Stream<List<Report>> getReportsStream() {
    return _firestore
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Report.fromMap(doc.data())).toList();
    });
  }

  // Stream single report by ID
  Stream<Report?> getReportStream(String reportId) {
    return _firestore
        .collection('reports')
        .doc(reportId)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return Report.fromMap(doc.data()!);
    });
  }

  // Stream report messages
  Stream<List<ReportMessage>> getReportMessagesStream(String reportId) {
    return _firestore
        .collection('reports')
        .doc(reportId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ReportMessage.fromMap(doc.data()))
          .toList();
    });
  }

  // Add report message
  Future<String?> addReportMessage({
    required String reportId,
    required ReportMessage message,
  }) async {
    try {
      await _firestore
          .collection('reports')
          .doc(reportId)
          .collection('messages')
          .add(message.toMap());
      return null;
    } catch (e) {
      return 'Error adding report message: $e';
    }
  }

  // Submit report
  Future<String?> submitReport(Report report) async {
    try {
      await _firestore
          .collection('reports')
          .doc(report.reportId)
          .set(report.toMap());
      return null;
    } catch (e) {
      return 'Error submitting report: $e';
    }
  }

  // Update report status
  Future<String?> updateReportStatus(String reportId, ReportStatus status,
      {String? adminNotes}) async {
    try {
      final updateData = {
        'status': status.toString().split('.').last,
        'resolvedAt': DateTime.now().toIso8601String(),
      };
      if (adminNotes != null) {
        updateData['adminNotes'] = adminNotes;
      }
      await _firestore.collection('reports').doc(reportId).update(updateData);
      return null;
    } catch (e) {
      return 'Error updating report: $e';
    }
  }

  // ============ ANNOUNCEMENT OPERATIONS ============

  // Get active announcements
  Future<List<Announcement>> getAnnouncements() async {
    try {
      final snapshot = await _firestore
          .collection('announcements')
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs
          .map((doc) => Announcement.fromMap(doc.data()))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Create announcement
  Future<String?> createAnnouncement(Announcement announcement) async {
    try {
      await _firestore
          .collection('announcements')
          .doc(announcement.announcementId)
          .set(announcement.toMap());
      // Cloud Function will automatically send push notification
      return null;
    } catch (e) {
      return 'Error creating announcement: $e';
    }
  }

  // Resend announcement notification via Cloud Function
  Future<String?> resendAnnouncementNotification(String announcementId) async {
    try {
      final callable =
          _functions.httpsCallable('resendAnnouncementNotification');
      await callable.call({'announcementId': announcementId});
      return null;
    } catch (e) {
      return 'Error resending notification: $e';
    }
  }

  // Places API (New) autocomplete via Cloud Function proxy.
  Future<List<String>> fetchPlaceAutocompleteSuggestions(
    String input, {
    int limit = 3,
  }) async {
    try {
      final callable = _functions.httpsCallable('placesAutocompleteNew');
      final response = await callable.call({
        'input': input,
        'limit': limit,
      });

      final data = response.data;
      if (data is! Map) return [];
      final suggestionsRaw = data['suggestions'];
      if (suggestionsRaw is! List) return [];

      return suggestionsRaw
          .whereType<String>()
          .map((text) => text.trim())
          .where((text) => text.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // Places API (New) text search -> coordinates via Cloud Function proxy.
  Future<Map<String, double>?> searchPlaceCoordinates(String query) async {
    try {
      final callable = _functions.httpsCallable('searchPlaceCoordinatesNew');
      final response = await callable.call({'query': query});

      final data = response.data;
      if (data is! Map) return null;
      final location = data['location'];
      if (location is! Map) return null;

      final latitude = (location['latitude'] as num?)?.toDouble();
      final longitude = (location['longitude'] as num?)?.toDouble();
      if (latitude == null || longitude == null) return null;

      return {
        'latitude': latitude,
        'longitude': longitude,
      };
    } catch (_) {
      return null;
    }
  }

  // Stream announcements
  Stream<List<Announcement>> getAnnouncementsStream() {
    return _firestore
        .collection('announcements')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Announcement.fromMap(doc.data()))
          .toList();
    });
  }

  // Delete announcement
  Future<String?> deleteAnnouncement(String announcementId) async {
    try {
      await _firestore.collection('announcements').doc(announcementId).delete();
      return null; // Success
    } catch (e) {
      return 'Error deleting announcement: $e';
    }
  }

  // Get user data from Firestore.
  //
  // If users/{uid} is missing but fallbackEmail matches a legacy profile
  // document (same email, different document id), the profile is copied to
  // users/{uid} to recover from UID drift between Auth and Firestore.
  Future<User?> getUserData(
    String uid, {
    String? fallbackEmail,
  }) async {
    try {
      final directDoc = await _firestore.collection('users').doc(uid).get();
      if (directDoc.exists) {
        final directData = directDoc.data();
        if (directData == null) return null;
        return User.fromMap({
          ...directData,
          'uid': uid,
        });
      }

      final normalizedEmail = fallbackEmail?.trim().toLowerCase();
      if (normalizedEmail == null || normalizedEmail.isEmpty) return null;

      final legacyDoc = await _findUserDocByEmail(normalizedEmail);
      if (legacyDoc == null) return null;

      final legacyData = legacyDoc.data();
      if (legacyData == null) return null;

      final recoveredData = <String, dynamic>{
        ...legacyData,
        'uid': uid,
        'email': (legacyData['email'] as String? ?? normalizedEmail).trim(),
        'normalizedEmail': normalizedEmail,
      };

      await _firestore.collection('users').doc(uid).set(
            recoveredData,
            SetOptions(merge: true),
          );

      return User.fromMap(recoveredData);
    } catch (_) {
      return null;
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findUserDocByEmail(
    String normalizedEmail,
  ) async {
    final byNormalizedEmail = await _firestore
        .collection('users')
        .where('normalizedEmail', isEqualTo: normalizedEmail)
        .limit(1)
        .get();

    if (byNormalizedEmail.docs.isNotEmpty) {
      return byNormalizedEmail.docs.first;
    }

    final byLowercaseEmail = await _firestore
        .collection('users')
        .where('email', isEqualTo: normalizedEmail)
        .limit(1)
        .get();

    if (byLowercaseEmail.docs.isNotEmpty) {
      return byLowercaseEmail.docs.first;
    }

    return null;
  }

  // Check whether an email is already registered as a staff account.
  Future<bool> isEmailRegisteredAsStaff(String email) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      if (normalizedEmail.isEmpty) return false;

      bool isStaffRole(String role) => role == 'admin' || role == 'driver';

      // Fast path for migrated docs: single-field indexed equality lookup.
      final normalizedSnapshot = await _firestore
          .collection('users')
          .where('normalizedEmail', isEqualTo: normalizedEmail)
          .limit(3)
          .get();

      if (normalizedSnapshot.docs.isNotEmpty) {
        for (final doc in normalizedSnapshot.docs) {
          final role = (doc.data()['role'] as String? ?? '').toLowerCase();
          if (isStaffRole(role)) return true;
        }
        return false;
      }

      // Fast fallback for pre-migration docs that only have exact-case email.
      final rawEmail = email.trim();
      final exactSnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: rawEmail)
          .limit(3)
          .get();
      for (final doc in exactSnapshot.docs) {
        final role = (doc.data()['role'] as String? ?? '').toLowerCase();
        if (isStaffRole(role)) return true;
      }

      if (rawEmail != normalizedEmail) {
        final lowercaseSnapshot = await _firestore
            .collection('users')
            .where('email', isEqualTo: normalizedEmail)
            .limit(3)
            .get();
        for (final doc in lowercaseSnapshot.docs) {
          final role = (doc.data()['role'] as String? ?? '').toLowerCase();
          if (isStaffRole(role)) return true;
        }
      }

      // Legacy compatibility fallback: only staff docs, then case-insensitive
      // compare in memory. This path should become rare after migration.
      final legacyStaffSnapshot = await _firestore
          .collection('users')
          .where('role', whereIn: ['admin', 'driver']).get();

      for (final doc in legacyStaffSnapshot.docs) {
        final docEmail =
            (doc.data()['email'] as String? ?? '').trim().toLowerCase();
        if (docEmail == normalizedEmail) {
          return true;
        }
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  Future<StudentDeviceBindingResult> ensureStudentDeviceBinding({
    required String uid,
    required String deviceId,
    bool allowTransfer = false,
  }) async {
    String? previousBoundDeviceId;
    try {
      final userRef = _firestore.collection('users').doc(uid);

      final result = await _firestore
          .runTransaction<StudentDeviceBindingResult>((transaction) async {
        final snapshot = await transaction.get(userRef);
        if (!snapshot.exists || snapshot.data() == null) {
          return const StudentDeviceBindingResult.denied(
            message:
                'Your account profile could not be found. Please contact admin.',
          );
        }

        final data = snapshot.data()!;
        final role = (data['role'] as String? ?? '').toLowerCase();

        // Device binding is only enforced for students.
        if (role != 'student') {
          transaction.set(
            userRef,
            {
              'lastLoginAt': FieldValue.serverTimestamp(),
              'lastLoginDeviceId': deviceId,
            },
            SetOptions(merge: true),
          );
          return const StudentDeviceBindingResult.allowed();
        }

        final boundDeviceId =
            (data['boundDeviceId'] as String?) ?? (data['deviceId'] as String?);

        if (boundDeviceId == null || boundDeviceId.isEmpty) {
          transaction.set(
            userRef,
            {
              'boundDeviceId': deviceId,
              'boundDeviceAt': FieldValue.serverTimestamp(),
              'lastLoginAt': FieldValue.serverTimestamp(),
              'lastLoginDeviceId': deviceId,
            },
            SetOptions(merge: true),
          );
          return const StudentDeviceBindingResult.allowed();
        }

        if (boundDeviceId == deviceId) {
          transaction.set(
            userRef,
            {
              'lastLoginAt': FieldValue.serverTimestamp(),
              'lastLoginDeviceId': deviceId,
            },
            SetOptions(merge: true),
          );
          return const StudentDeviceBindingResult.allowed();
        }

        if (!allowTransfer) {
          return const StudentDeviceBindingResult.transferRequired(
            message:
                'This student account is linked to another device. Continue to transfer it to this device.',
          );
        }

        previousBoundDeviceId = boundDeviceId;
        transaction.set(
          userRef,
          {
            'boundDeviceId': deviceId,
            'lastLoginAt': FieldValue.serverTimestamp(),
            'lastLoginDeviceId': deviceId,
            'lastDeviceTransferAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        return const StudentDeviceBindingResult.allowed();
      });

      if (result.isAllowed) {
        await _backfillStudentOwnership(
          uid: uid,
          currentDeviceId: deviceId,
          oldDeviceId: previousBoundDeviceId,
        );

        if (previousBoundDeviceId != null &&
            previousBoundDeviceId!.isNotEmpty &&
            previousBoundDeviceId != deviceId) {
          await _closeTransferredDeviceSessions(previousBoundDeviceId!);
        }
      }

      return result;
    } catch (_) {
      return const StudentDeviceBindingResult.denied(
        message: 'Unable to verify account device right now. Please try again.',
      );
    }
  }

  Future<void> _backfillStudentOwnership({
    required String uid,
    required String currentDeviceId,
    String? oldDeviceId,
  }) async {
    try {
      final deviceIds = <String>{
        currentDeviceId,
        if (oldDeviceId != null && oldDeviceId.isNotEmpty) oldDeviceId,
      };

      for (final deviceId in deviceIds) {
        final trips = await _firestore
            .collection('student_trips')
            .where('deviceId', isEqualTo: deviceId)
            .get();

        if (trips.docs.isEmpty) continue;

        final batch = _firestore.batch();
        for (final tripDoc in trips.docs) {
          final data = tripDoc.data();
          final tripUid = data['studentUid'] as String?;
          if (tripUid == uid) continue;
          batch.set(
            tripDoc.reference,
            {
              'studentUid': uid,
            },
            SetOptions(merge: true),
          );
        }
        await batch.commit();
      }
    } catch (_) {
      // Best effort only.
    }
  }

  Future<void> _closeTransferredDeviceSessions(String previousDeviceId) async {
    try {
      final activeSessions = await _firestore
          .collection('device_bus_sessions')
          .where('deviceId', isEqualTo: previousDeviceId)
          .where('status', isEqualTo: 'active')
          .get();

      final activeTrips = await _firestore
          .collection('student_trips')
          .where('deviceId', isEqualTo: previousDeviceId)
          .where('status', isEqualTo: 'active')
          .get();

      final batch = _firestore.batch();
      var hasWrites = false;

      for (final doc in activeSessions.docs) {
        hasWrites = true;
        batch.update(doc.reference, {
          'status': 'completed',
          'tappedOutAt': FieldValue.serverTimestamp(),
          'closedByDeviceTransfer': true,
        });
      }

      for (final doc in activeTrips.docs) {
        hasWrites = true;
        batch.update(doc.reference, {
          'status': 'completed',
          'offBoardedAt': FieldValue.serverTimestamp(),
          'closedByDeviceTransfer': true,
        });
      }

      if (hasWrites) {
        await batch.commit();
      }
    } catch (_) {
      // Best effort only.
    }
  }

  // Get all users with a given role
  Future<List<User>> getUsersByRole(UserRole role) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: role.toString().split('.').last)
          .get();
      return snapshot.docs.map((doc) => User.fromMap(doc.data())).toList();
    } catch (e) {
      return [];
    }
  }

  // Update user role
  Future<String?> updateUserRole({
    required String uid,
    required UserRole role,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'role': role.toString().split('.').last,
      });
      return null;
    } catch (e) {
      return 'Error updating user role: $e';
    }
  }

  // Update user profile information
  Future<String?> updateUserProfile({
    required String uid,
    required String fullName,
    required String email,
  }) async {
    try {
      final updateData = {
        'fullName': fullName,
        'email': email,
        'normalizedEmail': email.trim().toLowerCase(),
      };
      await _firestore.collection('users').doc(uid).update(updateData);
      return null;
    } catch (e) {
      return 'Error updating user profile: $e';
    }
  }

  // Delete user profile document and clear bus assignments if driver
  Future<String?> deleteUserProfile(String uid) async {
    try {
      final busesSnapshot = await _firestore
          .collection('buses')
          .where('driverId', isEqualTo: uid)
          .get();

      final batch = _firestore.batch();
      for (final busDoc in busesSnapshot.docs) {
        batch.update(busDoc.reference, {
          'driverId': null,
          'driverName': null,
          'lastUpdated': DateTime.now().toIso8601String(),
        });
      }

      batch.delete(_firestore.collection('users').doc(uid));
      await batch.commit();
      return null;
    } catch (e) {
      return 'Error deleting user profile: $e';
    }
  }

  // ============ SCHEDULE IMAGE OPERATIONS ============

  // Get all active schedule images sorted by order
  Future<List<ScheduleImage>> getScheduleImages() async {
    try {
      final snapshot = await _firestore
          .collection('schedule_images')
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();
      return snapshot.docs
          .map((doc) => ScheduleImage.fromMap(doc.data()))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Add new schedule image
  Future<String?> addScheduleImage(ScheduleImage scheduleImage) async {
    try {
      await _firestore
          .collection('schedule_images')
          .doc(scheduleImage.imageId)
          .set(scheduleImage.toMap());
      return null;
    } catch (e) {
      return 'Error adding schedule image: $e';
    }
  }

  // Update schedule image
  Future<String?> updateScheduleImage(ScheduleImage scheduleImage) async {
    try {
      await _firestore
          .collection('schedule_images')
          .doc(scheduleImage.imageId)
          .update(scheduleImage.toMap());
      return null;
    } catch (e) {
      return 'Error updating schedule image: $e';
    }
  }

  // Delete schedule image
  Future<String?> deleteScheduleImage(String imageId) async {
    try {
      await _firestore.collection('schedule_images').doc(imageId).delete();
      return null;
    } catch (e) {
      return 'Error deleting schedule image: $e';
    }
  }

  // Stream schedule images for real-time updates
  Stream<List<ScheduleImage>> streamScheduleImages() {
    return _firestore
        .collection('schedule_images')
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ScheduleImage.fromMap(doc.data()))
            .where((image) => image.isActive)
            .toList());
  }

  // ============ DEVICE BUS SESSION OPERATIONS ============

  // Check if device has an active bus session
  Future<String?> getDeviceActiveBusId(String deviceId) async {
    try {
      final snapshot = await _firestore
          .collection('device_bus_sessions')
          .where('deviceId', isEqualTo: deviceId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data()['busId'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Tap into a bus
  Future<String?> tapInToBus(String deviceId, String busId) async {
    try {
      // Check if device already has an active session
      final existingSession = await getDeviceActiveBusId(deviceId);
      if (existingSession != null && existingSession != busId) {
        return 'You are already tapped into another bus';
      }

      // Create new session
      final sessionId = '${deviceId}_${DateTime.now().millisecondsSinceEpoch}';
      await _firestore.collection('device_bus_sessions').doc(sessionId).set({
        'sessionId': sessionId,
        'deviceId': deviceId,
        'busId': busId,
        'status': 'active',
        'tappedInAt': FieldValue.serverTimestamp(),
        'tappedOutAt': null,
      });

      return null; // Success
    } catch (e) {
      return 'Error: $e';
    }
  }

  // Tap out from bus
  Future<String?> tapOutFromBus(String deviceId) async {
    try {
      // Find active session
      final snapshot = await _firestore
          .collection('device_bus_sessions')
          .where('deviceId', isEqualTo: deviceId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return 'No active session found';
      }

      // Update session to completed
      await _firestore
          .collection('device_bus_sessions')
          .doc(snapshot.docs.first.id)
          .update({
        'status': 'completed',
        'tappedOutAt': FieldValue.serverTimestamp(),
      });

      return null; // Success
    } catch (e) {
      return 'Error: $e';
    }
  }

  // Close all active device sessions for a specific bus (called when driver ends shift)
  Future<void> clearBusActiveSessions(String busId) async {
    try {
      final snapshot = await _firestore
          .collection('device_bus_sessions')
          .where('busId', isEqualTo: busId)
          .where('status', isEqualTo: 'active')
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'status': 'completed',
          'tappedOutAt': FieldValue.serverTimestamp(),
          'closedByShiftEnd': true,
        });
      }
      if (snapshot.docs.isNotEmpty) {
        await batch.commit();
      }
    } catch (e) {
      // ignore
    }
  }

  // Best-effort safeguard: close active session/trip when app is terminated
  // or when client-side reconciliation detects stale active state.
  Future<String?> autoTapOutStudentSession({
    required String deviceId,
    String? studentUid,
    String reason = 'safeguard',
    bool decrementBusOccupancy = true,
  }) async {
    try {
      final activeSessionsSnapshot = await _firestore
          .collection('device_bus_sessions')
          .where('deviceId', isEqualTo: deviceId)
          .where('status', isEqualTo: 'active')
          .get();

      final busSessionCounts = <String, int>{};
      for (final doc in activeSessionsSnapshot.docs) {
        final busId = doc.data()['busId'] as String?;
        if (busId != null && busId.isNotEmpty) {
          busSessionCounts[busId] = (busSessionCounts[busId] ?? 0) + 1;
        }
      }

      QuerySnapshot<Map<String, dynamic>> activeTripsSnapshot;
      if (studentUid != null && studentUid.isNotEmpty) {
        activeTripsSnapshot = await _firestore
            .collection('student_trips')
            .where('studentUid', isEqualTo: studentUid)
            .where('status', isEqualTo: 'active')
            .get();

        // Legacy fallback for trips without studentUid.
        if (activeTripsSnapshot.docs.isEmpty) {
          activeTripsSnapshot = await _firestore
              .collection('student_trips')
              .where('deviceId', isEqualTo: deviceId)
              .where('status', isEqualTo: 'active')
              .get();
        }
      } else {
        activeTripsSnapshot = await _firestore
            .collection('student_trips')
            .where('deviceId', isEqualTo: deviceId)
            .where('status', isEqualTo: 'active')
            .get();
      }

      if (activeSessionsSnapshot.docs.isEmpty &&
          activeTripsSnapshot.docs.isEmpty) {
        return null;
      }

      final batch = _firestore.batch();
      for (final sessionDoc in activeSessionsSnapshot.docs) {
        batch.update(sessionDoc.reference, {
          'status': 'completed',
          'tappedOutAt': FieldValue.serverTimestamp(),
          'closedBySafeguard': true,
          'safeguardReason': reason,
        });
      }

      for (final tripDoc in activeTripsSnapshot.docs) {
        batch.update(tripDoc.reference, {
          'status': 'completed',
          'offBoardedAt': FieldValue.serverTimestamp(),
          'closedBySafeguard': true,
          'safeguardReason': reason,
        });
      }

      await batch.commit();

      if (decrementBusOccupancy) {
        for (final entry in busSessionCounts.entries) {
          await _decrementBusOccupancySafely(entry.key, entry.value);
        }
      }

      return null;
    } catch (e) {
      return 'Error auto tapping out student session: $e';
    }
  }

  // Reconcile stale student state: an active trip must be backed by an
  // active session on an active bus. If not, auto-complete stale data.
  Future<bool> reconcileStudentActiveState({
    required String deviceId,
    String? studentUid,
  }) async {
    try {
      final activeTrip = await getActiveTrip(
        deviceId,
        studentUid: studentUid,
      );
      if (activeTrip == null) return false;

      final activeSessionBusId = await getDeviceActiveBusId(deviceId);
      final shouldCloseBecauseMissingSession =
          activeSessionBusId == null || activeSessionBusId.isEmpty;

      if (shouldCloseBecauseMissingSession) {
        await autoTapOutStudentSession(
          deviceId: deviceId,
          studentUid: studentUid,
          reason: 'reconcile_missing_session',
          decrementBusOccupancy: false,
        );
        return true;
      }

      final sessionBus = await getBus(activeSessionBusId);
      final sessionBusInactive = sessionBus == null || !sessionBus.isActive;
      final tripBusMismatch = activeTrip.busId != activeSessionBusId;

      if (!sessionBusInactive && !tripBusMismatch) {
        return false;
      }

      await autoTapOutStudentSession(
        deviceId: deviceId,
        studentUid: studentUid,
        reason: sessionBusInactive
            ? 'reconcile_inactive_bus'
            : 'reconcile_trip_session_mismatch',
        decrementBusOccupancy: !sessionBusInactive,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _decrementBusOccupancySafely(
      String busId, int decrementBy) async {
    if (decrementBy <= 0) return;
    await _firestore.runTransaction((transaction) async {
      final busRef = _firestore.collection('buses').doc(busId);
      final snapshot = await transaction.get(busRef);
      if (!snapshot.exists) return;

      final currentOccupancy =
          (snapshot.data()?['currentOccupancy'] as num?)?.toInt() ?? 0;
      final nextOccupancy = (currentOccupancy - decrementBy).clamp(0, 9999);

      transaction.update(busRef, {
        'currentOccupancy': nextOccupancy,
        'lastUpdated': DateTime.now().toIso8601String(),
      });
    });
  }

  // ============ STUDENT TRIP OPERATIONS ============

  // Create a new trip when student taps in
  Future<String?> createStudentTrip({
    required String deviceId,
    required String busId,
    String? studentUid,
  }) async {
    try {
      // Get bus details
      final bus = await getBus(busId);
      if (bus == null) {
        return 'Bus not found';
      }

      // Get route name if assigned
      String? routeName;
      if (bus.assignedRoute != null) {
        final route = await getRoute(bus.assignedRoute!);
        routeName = route?.routeName;
      }

      // Create trip
      final tripId = '${deviceId}_${DateTime.now().millisecondsSinceEpoch}';
      final trip = StudentTrip(
        tripId: tripId,
        deviceId: deviceId,
        studentUid: studentUid,
        busId: busId,
        busNumber: bus.busNumber,
        busRegistrationNumber: bus.registrationNumber,
        routeId: bus.assignedRoute,
        routeName: routeName,
        boardedAt: DateTime.now(),
        offBoardedAt: null,
        status: 'active',
      );

      await _firestore
          .collection('student_trips')
          .doc(tripId)
          .set(trip.toMap());
      return null; // Success
    } catch (e) {
      return 'Error: $e';
    }
  }

  // Close all active student trips for a bus (called when driver ends shift)
  Future<void> completeAllBusStudentTrips(String busId) async {
    try {
      final snapshot = await _firestore
          .collection('student_trips')
          .where('busId', isEqualTo: busId)
          .where('status', isEqualTo: 'active')
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'offBoardedAt': FieldValue.serverTimestamp(),
          'status': 'completed',
          'closedByShiftEnd': true,
        });
      }
      if (snapshot.docs.isNotEmpty) {
        await batch.commit();
      }
    } catch (e) {
      // ignore — best-effort cleanup
    }
  }

  // Complete a trip when student taps out
  Future<String?> completeStudentTrip(
    String deviceId, {
    String? studentUid,
  }) async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot;

      if (studentUid != null && studentUid.isNotEmpty) {
        snapshot = await _firestore
            .collection('student_trips')
            .where('studentUid', isEqualTo: studentUid)
            .where('status', isEqualTo: 'active')
            .limit(1)
            .get();

        if (snapshot.docs.isEmpty) {
          snapshot = await _firestore
              .collection('student_trips')
              .where('deviceId', isEqualTo: deviceId)
              .where('status', isEqualTo: 'active')
              .limit(1)
              .get();
        }
      } else {
        snapshot = await _firestore
            .collection('student_trips')
            .where('deviceId', isEqualTo: deviceId)
            .where('status', isEqualTo: 'active')
            .limit(1)
            .get();
      }

      if (snapshot.docs.isEmpty) {
        return null; // No active trip, that's okay
      }

      // Update trip to completed
      await _firestore
          .collection('student_trips')
          .doc(snapshot.docs.first.id)
          .update({
        'offBoardedAt': FieldValue.serverTimestamp(),
        'status': 'completed',
      });

      return null; // Success
    } catch (e) {
      return 'Error: $e';
    }
  }

  // Get device's active trip
  Future<StudentTrip?> getActiveTrip(
    String deviceId, {
    String? studentUid,
  }) async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot;

      if (studentUid != null && studentUid.isNotEmpty) {
        snapshot = await _firestore
            .collection('student_trips')
            .where('studentUid', isEqualTo: studentUid)
            .where('status', isEqualTo: 'active')
            .limit(1)
            .get();

        if (snapshot.docs.isEmpty) {
          snapshot = await _firestore
              .collection('student_trips')
              .where('deviceId', isEqualTo: deviceId)
              .where('status', isEqualTo: 'active')
              .limit(1)
              .get();
        }
      } else {
        snapshot = await _firestore
            .collection('student_trips')
            .where('deviceId', isEqualTo: deviceId)
            .where('status', isEqualTo: 'active')
            .limit(1)
            .get();
      }

      if (snapshot.docs.isNotEmpty) {
        return StudentTrip.fromMap(snapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Stream device's trips (active first, then past trips)
  Stream<List<StudentTrip>> streamStudentTrips(
    String deviceId, {
    String? studentUid,
  }) {
    return _firestore.collection('student_trips').snapshots().map((snapshot) {
      final trips = snapshot.docs
          .map((doc) => StudentTrip.fromMap(doc.data()))
          .where((trip) {
        final matchesUid = studentUid != null &&
            studentUid.isNotEmpty &&
            trip.studentUid == studentUid;
        final matchesDevice = trip.deviceId == deviceId;
        return matchesUid || matchesDevice;
      }).toList();

      // Sort in Dart: active trips first, then by boardedAt descending
      trips.sort((a, b) {
        // Active trips come first
        if (a.status == 'active' && b.status != 'active') return -1;
        if (a.status != 'active' && b.status == 'active') return 1;
        // Then sort by boardedAt (newest first)
        return b.boardedAt.compareTo(a.boardedAt);
      });

      return trips;
    });
  }

  // ── Notification Templates ──────────────────────────────────────────────────

  /// Returns all template overrides stored in Firestore.
  /// Falls back to an empty map if the collection is missing or on error.
  Future<Map<String, Map<String, String>>> getNotificationTemplates() async {
    try {
      final snap = await _firestore.collection('notification_templates').get();
      return {
        for (final doc in snap.docs)
          doc.id: {
            'title': doc.data()['title'] as String? ?? '',
            'body': doc.data()['body'] as String? ?? '',
          }
      };
    } catch (_) {
      return {};
    }
  }

  /// Writes (or overwrites) a single notification template in Firestore.
  Future<String?> updateNotificationTemplate(
      String templateId, String title, String body) async {
    try {
      await _firestore
          .collection('notification_templates')
          .doc(templateId)
          .set({
        'title': title,
        'body': body,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      return null;
    } catch (e) {
      return 'Error updating template: $e';
    }
  }

  // Get count of completed trips today
  Stream<int> getTodayCompletedTripsCountStream() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return _firestore
        .collection('student_trips')
        .where('status', isEqualTo: 'completed')
        .where('offBoardedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('offBoardedAt',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
