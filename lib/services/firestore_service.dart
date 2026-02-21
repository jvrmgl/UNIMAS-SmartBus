import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bus_model.dart';
import '../models/route_model.dart';
import '../models/bus_stop_model.dart';
import '../models/schedule_model.dart';
import '../models/trip_model.dart';
import '../models/report_model.dart';
import '../models/announcement_model.dart';
import '../models/user_model.dart';
import '../models/schedule_image_model.dart';
import '../models/student_trip_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============ BUS OPERATIONS ============

  // Get all buses
  Future<List<Bus>> getBuses() async {
    try {
      print('🔵 Fetching buses from Firebase...');
      final snapshot = await _firestore.collection('buses').get();
      print('📦 Got ${snapshot.docs.length} bus documents');
      
      final buses = snapshot.docs.map((doc) {
        print('🚌 Processing bus: ${doc.id}');
        print('   Data: ${doc.data()}');
        return Bus.fromMap(doc.data());
      }).toList();
      
      print('✅ Successfully parsed ${buses.length} buses');
      return buses;
    } catch (e) {
      print('❌ Error getting buses: $e');
      print('   Stack trace: ${StackTrace.current}');
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
      print('Error getting bus: $e');
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

  // Update active status for a bus
  Future<String?> setBusActiveStatus({
    required String busId,
    required bool isActive,
  }) async {
    try {
      await _firestore.collection('buses').doc(busId).update({
        'isActive': isActive,
        'lastUpdated': DateTime.now().toIso8601String(),
      });
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

  // Remove driver from bus
  Future<String?> removeDriverFromBus(String busId) async {
    try {
      await _firestore.collection('buses').doc(busId).update({
        'driverId': null,
        'driverName': null,
        'lastUpdated': DateTime.now().toIso8601String(),
      });
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

  // Remove a driver assignment from all buses
  Future<String?> unassignDriverFromAllBuses(String driverId) async {
    try {
      final snapshot = await _firestore
          .collection('buses')
          .where('driverId', isEqualTo: driverId)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'driverId': null,
          'driverName': null,
          'lastUpdated': DateTime.now().toIso8601String(),
        });
      }
      await batch.commit();
      return null;
    } catch (e) {
      return 'Error unassigning driver from buses: $e';
    }
  }

  // ============ ROUTE OPERATIONS ============

  // Get all routes
  Future<List<BusRoute>> getRoutes() async {
    try {
      print('🔵 Fetching routes from Firebase...');
      final snapshot = await _firestore.collection('routes').get();
      print('📦 Got ${snapshot.docs.length} route documents');
      
      final routes = snapshot.docs.map((doc) {
        print('🛣️  Processing route: ${doc.id}');
        print('   Data: ${doc.data()}');
        return BusRoute.fromMap(doc.data());
      }).toList();
      
      print('✅ Successfully parsed ${routes.length} routes');
      return routes;
    } catch (e) {
      print('❌ Error getting routes: $e');
      print('   Stack trace: ${StackTrace.current}');
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
      print('Error getting route: $e');
      return null;
    }
  }

  // Add new route
  Future<String?> addRoute(BusRoute route) async {
    try {
      await _firestore.collection('routes').doc(route.routeId).set(route.toMap());
      return null;
    } catch (e) {
      return 'Error adding route: $e';
    }
  }

  // Update route
  Future<String?> updateRoute(BusRoute route) async {
    try {
      await _firestore.collection('routes').doc(route.routeId).update(route.toMap());
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
      return snapshot.docs
          .map((doc) => BusStop.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting bus stops: $e');
      return [];
    }
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
      print('Error getting bus stop: $e');
      return null;
    }
  }

  // Add bus stop
  Future<String?> addBusStop(BusStop stop) async {
    try {
      await _firestore.collection('bus_stops').doc(stop.stopId).set(stop.toMap());
      return null;
    } catch (e) {
      return 'Error adding bus stop: $e';
    }
  }

  // Update bus stop
  Future<String?> updateBusStop(BusStop stop) async {
    try {
      await _firestore.collection('bus_stops').doc(stop.stopId).update(stop.toMap());
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

  // ============ SCHEDULE OPERATIONS ============

  // Get schedules for a route
  Future<List<BusSchedule>> getSchedulesForRoute(String routeId) async {
    try {
      final snapshot = await _firestore
          .collection('schedules')
          .where('routeId', isEqualTo: routeId)
          .get();
      return snapshot.docs
          .map((doc) => BusSchedule.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting schedules: $e');
      return [];
    }
  }

  // Get all schedules
  Future<List<BusSchedule>> getSchedules() async {
    try {
      final snapshot = await _firestore.collection('schedules').get();
      return snapshot.docs
          .map((doc) => BusSchedule.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting schedules: $e');
      return [];
    }
  }

  // Add schedule
  Future<String?> addSchedule(BusSchedule schedule) async {
    try {
      await _firestore.collection('schedules').doc(schedule.scheduleId).set(schedule.toMap());
      return null;
    } catch (e) {
      return 'Error adding schedule: $e';
    }
  }

  // ============ TRIP OPERATIONS ============

  // Create trip
  Future<String?> createTrip(Trip trip) async {
    try {
      await _firestore.collection('trips').doc(trip.tripId).set(trip.toMap());
      return null;
    } catch (e) {
      return 'Error creating trip: $e';
    }
  }

  // Update trip status
  Future<String?> updateTripStatus(String tripId, TripStatus status) async {
    try {
      await _firestore.collection('trips').doc(tripId).update({
        'status': status.toString().split('.').last,
        'endTime': DateTime.now().toIso8601String(),
      });
      return null;
    } catch (e) {
      return 'Error updating trip: $e';
    }
  }

  // Get active trips for a bus
  Future<List<Trip>> getActiveTripsByBus(String busId) async {
    try {
      final snapshot = await _firestore
          .collection('trips')
          .where('busId', isEqualTo: busId)
          .where('status', whereIn: ['scheduled', 'inProgress'])
          .get();
      return snapshot.docs
          .map((doc) => Trip.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting active trips: $e');
      return [];
    }
  }

  // Get completed trips (recent history)
  Future<List<Trip>> getCompletedTrips({int limit = 10}) async {
    try {
      print('🔵 Fetching completed trips...');
      final snapshot = await _firestore
          .collection('trips')
          .where('status', isEqualTo: 'completed')
          .orderBy('endTime', descending: true)
          .limit(limit)
          .get();
      
      final trips = snapshot.docs
          .map((doc) => Trip.fromMap(doc.data()))
          .toList();
      
      print('✅ Got ${trips.length} completed trips');
      return trips;
    } catch (e) {
      print('❌ Error getting completed trips: $e');
      return [];
    }
  }

  // ============ REPORT OPERATIONS ============

  // Get all reports
  Future<List<Report>> getReports() async {
    try {
      final snapshot = await _firestore.collection('reports').get();
      return snapshot.docs
          .map((doc) => Report.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting reports: $e');
      return [];
    }
  }

  // Get reports by student/device id
  Stream<List<Report>> getReportsByStudentId(String studentId) {
    return _firestore
        .collection('reports')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Report.fromMap(doc.data()))
          .toList();
    });
  }

  // Stream all reports
  Stream<List<Report>> getReportsStream() {
    return _firestore.collection('reports').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Report.fromMap(doc.data()))
          .toList();
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
      await _firestore.collection('reports').doc(report.reportId).set(report.toMap());
      return null;
    } catch (e) {
      return 'Error submitting report: $e';
    }
  }

  // Update report status
  Future<String?> updateReportStatus(String reportId, ReportStatus status, {String? adminNotes}) async {
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
      print('Error getting announcements: $e');
      return [];
    }
  }

  // Create announcement
  Future<String?> createAnnouncement(Announcement announcement) async {
    try {
      await _firestore.collection('announcements').doc(announcement.announcementId).set(announcement.toMap());
      return null;
    } catch (e) {
      return 'Error creating announcement: $e';
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

  // Get user data from Firestore
  Future<User?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return User.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
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
      print('Error getting users by role: $e');
      return [];
    }
  }

  // Create user profile
  Future<String?> createUserProfile(User user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set(user.toMap());
      return null;
    } catch (e) {
      return 'Error creating user profile: $e';
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
    String? phoneNumber,
  }) async {
    try {
      final updateData = {
        'fullName': fullName,
        'email': email,
        'phoneNumber': phoneNumber ?? '',
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
      print('🖼️ Fetching schedule images from Firebase...');
      final snapshot = await _firestore
          .collection('schedule_images')
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();
      
      print('📦 Got ${snapshot.docs.length} schedule image documents');
      
      final images = snapshot.docs.map((doc) {
        print('🖼️ Processing image: ${doc.id}');
        print('   Data: ${doc.data()}');
        return ScheduleImage.fromMap(doc.data());
      }).toList();
      
      print('✅ Successfully parsed ${images.length} schedule images');
      return images;
    } catch (e) {
      print('❌ Error getting schedule images: $e');
      print('   Stack trace: ${StackTrace.current}');
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
      await _firestore
          .collection('schedule_images')
          .doc(imageId)
          .delete();
      return null;
    } catch (e) {
      return 'Error deleting schedule image: $e';
    }
  }

  // Stream schedule images for real-time updates
  Stream<List<ScheduleImage>> streamScheduleImages() {
    print('📡 Starting schedule images stream...');
    return _firestore
        .collection('schedule_images')
        .orderBy('order')
        .snapshots()
        .map((snapshot) {
          print('📡 Stream update: ${snapshot.docs.length} schedule images');
          return snapshot.docs
              .map((doc) {
                try {
                  print('   Processing: ${doc.id}');
                  return ScheduleImage.fromMap(doc.data());
                } catch (e) {
                  print('   ❌ Error parsing ${doc.id}: $e');
                  rethrow;
                }
              })
              .where((image) => image.isActive) // Filter active images in code
              .toList();
        }).handleError((error) {
          print('❌ Stream error: $error');
          return <ScheduleImage>[];
        });
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
      print('Error getting device active bus: $e');
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
      print('Error tapping in: $e');
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
      print('Error tapping out: $e');
      return 'Error: $e';
    }
  }

  // Stream device's active bus session
  Stream<String?> streamDeviceActiveBusId(String deviceId) {
    return _firestore
        .collection('device_bus_sessions')
        .where('deviceId', isEqualTo: deviceId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data()['busId'] as String?;
      }
      return null;
    });
  }

  // ============ STUDENT TRIP OPERATIONS ============

  // Create a new trip when student taps in
  Future<String?> createStudentTrip({
    required String deviceId,
    required String busId,
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
        busId: busId,
        busNumber: bus.busNumber,
        busRegistrationNumber: bus.registrationNumber,
        routeId: bus.assignedRoute,
        routeName: routeName,
        boardedAt: DateTime.now(),
        offBoardedAt: null,
        status: 'active',
      );

      await _firestore.collection('student_trips').doc(tripId).set(trip.toMap());
      print('✅ Created trip: $tripId');
      return null; // Success
    } catch (e) {
      print('❌ Error creating trip: $e');
      return 'Error: $e';
    }
  }

  // Complete a trip when student taps out
  Future<String?> completeStudentTrip(String deviceId) async {
    try {
      // Find active trip
      final snapshot = await _firestore
          .collection('student_trips')
          .where('deviceId', isEqualTo: deviceId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        print('⚠️ No active trip found for device: $deviceId');
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

      print('✅ Completed trip: ${snapshot.docs.first.id}');
      return null; // Success
    } catch (e) {
      print('❌ Error completing trip: $e');
      return 'Error: $e';
    }
  }

  // Get device's active trip
  Future<StudentTrip?> getActiveTrip(String deviceId) async {
    try {
      final snapshot = await _firestore
          .collection('student_trips')
          .where('deviceId', isEqualTo: deviceId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return StudentTrip.fromMap(snapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      print('❌ Error getting active trip: $e');
      return null;
    }
  }

  // Stream device's trips (active first, then past trips)
  Stream<List<StudentTrip>> streamStudentTrips(String deviceId) {
    return _firestore
        .collection('student_trips')
        .where('deviceId', isEqualTo: deviceId)
        .snapshots()
        .map((snapshot) {
      final trips = snapshot.docs
          .map((doc) => StudentTrip.fromMap(doc.data()))
          .toList();
      
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

  // Get a single trip by ID
  Future<StudentTrip?> getStudentTrip(String tripId) async {
    try {
      final doc = await _firestore.collection('student_trips').doc(tripId).get();
      if (doc.exists) {
        return StudentTrip.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('❌ Error getting trip: $e');
      return null;
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
        .where('offBoardedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('offBoardedAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}

