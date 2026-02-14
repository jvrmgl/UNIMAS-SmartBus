import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bus_model.dart';
import '../models/route_model.dart';
import '../models/bus_stop_model.dart';
import '../models/schedule_model.dart';
import '../models/trip_model.dart';
import '../models/report_model.dart';
import '../models/announcement_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============ BUS OPERATIONS ============

  // Get all buses
  Future<List<Bus>> getBuses() async {
    try {
      final snapshot = await _firestore.collection('buses').get();
      return snapshot.docs
          .map((doc) => Bus.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting buses: $e');
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

  // Add new bus
  Future<String?> addBus(Bus bus) async {
    try {
      await _firestore.collection('buses').doc(bus.busId).set(bus.toMap());
      return null;
    } catch (e) {
      return 'Error adding bus: $e';
    }
  }

  // ============ ROUTE OPERATIONS ============

  // Get all routes
  Future<List<BusRoute>> getRoutes() async {
    try {
      final snapshot = await _firestore.collection('routes').get();
      return snapshot.docs
          .map((doc) => BusRoute.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting routes: $e');
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
}
