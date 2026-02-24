import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/bus_stop_model.dart';

/// Handles:
///   1. Saving the device FCM token to Firestore so Cloud Functions can
///      send targeted push notifications (tap-out reminders, bus approaching,
///      driver shift reminders).
///   2. Auto-detecting when a student has been stationary near a bus stop for
///      [waitConfirmMinutes] consecutive minutes and registering them as
///      "waiting" in Firestore.
///   3. Manual "I'm waiting here" registration and cancellation.
class SmartNotificationService extends ChangeNotifier {
  final _firestore = FirebaseFirestore.instance;
  final _messaging = FirebaseMessaging.instance;

  // ── Config ──────────────────────────────────────────────────────────────────
  static const double _stopRadiusMeters = 60.0;
  static const int waitConfirmMinutes = 5;
  static const double _autoCancelRadiusMeters = 200.0;

  // ── State ───────────────────────────────────────────────────────────────────
  bool _initialized = false;
  String? _deviceId;

  // Waiting state
  bool _isWaiting = false;
  String? _waitingDocId;
  String? _waitingStopId;
  String? _waitingStopName;

  // Auto-detection state
  String? _candidateStopId;
  DateTime? _firstSeenNearStop;

  bool get isWaiting => _isWaiting;
  String? get waitingStopId => _waitingStopId;
  String? get waitingStopName => _waitingStopName;

  // ── Init ────────────────────────────────────────────────────────────────────

  /// Call once when the app starts. Pass [userId] for authenticated users
  /// (drivers/admins) so the Cloud Function can look up their token by UID.
  Future<void> initialize(String deviceId, {String? userId}) async {
    if (_initialized) return;
    _deviceId = deviceId;
    _initialized = true;
    await _saveToken(deviceId, userId: userId);
  }

  Future<void> _saveToken(String deviceId, {String? userId}) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      // Save under deviceId (used by tap-out reminder and waiting student notifs)
      await _firestore.collection('device_tokens').doc(deviceId).set({
        'fcmToken': token,
        'userId': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also save under userId so driver shift reminder can target by driverId
      if (userId != null) {
        await _firestore.collection('device_tokens').doc(userId).set({
          'fcmToken': token,
          'deviceId': deviceId,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('SmartNotificationService: error saving token: $e');
    }
  }

  // ── Location update ─────────────────────────────────────────────────────────

  /// Call this from the map screen whenever the user's location changes.
  /// [autoDetect] comes from [NotificationPrefsProvider.autoDetectWaiting].
  Future<void> onLocationUpdate(
    Position position,
    List<BusStop> stops,
    bool autoDetect,
  ) async {
    if (!autoDetect) return;

    // Find nearest active stop within the confirm radius
    BusStop? nearby;
    double minDist = _stopRadiusMeters;
    for (final stop in stops) {
      final d = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        stop.latitude,
        stop.longitude,
      );
      if (d < minDist) {
        minDist = d;
        nearby = stop;
      }
    }

    if (nearby != null) {
      if (_candidateStopId == nearby.stopId) {
        // Still at same stop – check if we've been here long enough
        final elapsed = DateTime.now().difference(_firstSeenNearStop!);
        if (elapsed.inMinutes >= waitConfirmMinutes && !_isWaiting) {
          await markWaitingAtStop(nearby);
        }
      } else {
        // Switched stop or first sighting – start the clock
        _candidateStopId = nearby.stopId;
        _firstSeenNearStop = DateTime.now();
      }
    } else {
      // Not near any stop
      if (_isWaiting && _waitingStopId != null) {
        // Auto-cancel if the student has moved far from their waiting stop
        BusStop? ws;
        for (final stop in stops) {
          if (stop.stopId == _waitingStopId) {
            ws = stop;
            break;
          }
        }
        if (ws != null) {
          final d = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            ws.latitude,
            ws.longitude,
          );
          if (d > _autoCancelRadiusMeters) {
            await cancelWaiting();
          }
        }
      }
      _candidateStopId = null;
      _firstSeenNearStop = null;
    }
  }

  // ── Manual mark ─────────────────────────────────────────────────────────────

  Future<void> markWaitingAtStop(BusStop stop) async {
    if (_isWaiting || _deviceId == null) return;
    try {
      final token = await _messaging.getToken();
      final docRef = await _firestore.collection('waiting_students').add({
        'deviceId': _deviceId,
        'stopId': stop.stopId,
        'stopName': stop.stopName,
        'latitude': stop.latitude,
        'longitude': stop.longitude,
        'fcmToken': token ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'waiting',
        'notifiedAt': null,
      });
      _waitingDocId = docRef.id;
      _waitingStopId = stop.stopId;
      _waitingStopName = stop.stopName;
      _isWaiting = true;
      notifyListeners();
    } catch (e) {
      debugPrint('SmartNotificationService: error marking waiting: $e');
    }
  }

  Future<void> cancelWaiting() async {
    if (_waitingDocId != null) {
      try {
        await _firestore
            .collection('waiting_students')
            .doc(_waitingDocId)
            .update({
          'status': 'departed',
          'departedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('SmartNotificationService: error cancelling waiting: $e');
      }
    }
    _waitingDocId = null;
    _waitingStopId = null;
    _waitingStopName = null;
    _isWaiting = false;
    _candidateStopId = null;
    _firstSeenNearStop = null;
    notifyListeners();
  }
}
