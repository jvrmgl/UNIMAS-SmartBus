import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/app_navigator.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSubscription;
  StreamSubscription<String>? _onTokenRefreshSubscription;

  static const AndroidNotificationChannel _announcementsChannel =
      AndroidNotificationChannel(
    'announcements',
    'Announcements',
    description: 'Notifications for bus announcements',
    importance: Importance.high,
  );

  static const AndroidNotificationChannel _busUpdatesChannel =
      AndroidNotificationChannel(
    'bus_updates',
    'Bus Updates',
    description: 'Approaching bus, tap-out reminders, and shift alerts',
    importance: Importance.high,
  );

  // Initialize notifications
  Future<void> initializeNotifications() async {
    if (_isInitialized) return;

    await _onMessageSubscription?.cancel();
    await _onMessageOpenedAppSubscription?.cancel();
    await _onTokenRefreshSubscription?.cancel();

    // Initialize local notifications (for foreground display)
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(initializationSettings);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_announcementsChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_busUpdatesChannel);

    // Request permission
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (kDebugMode) {
      debugPrint(
        'Notification permission status: ${settings.authorizationStatus}',
      );
    }

    // Get FCM token
    String? token = await _firebaseMessaging.getToken();
    if (kDebugMode) {
      final masked = (token != null && token.length > 12)
          ? '${token.substring(0, 6)}...${token.substring(token.length - 6)}'
          : token;
      debugPrint('FCM Token (masked): $masked');
    }

    _onTokenRefreshSubscription =
        _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      if (kDebugMode) {
        final masked = newToken.length > 12
            ? '${newToken.substring(0, 6)}...${newToken.substring(newToken.length - 6)}'
            : newToken;
        debugPrint('FCM token refreshed (masked): $masked');
      }

      try {
        await subscribeToBusAnnouncements();
        await saveDeviceToken();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('NotificationService: token refresh sync failed: $e');
        }
      }
    });

    // Handle foreground messages
    _onMessageSubscription =
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');
      }

      if (message.notification != null) {
        if (kDebugMode) {
          debugPrint(
            'Message also contained a notification: ${message.notification}',
          );
        }
        // Route smart notifications (approaching bus / reminders) to the
        // dedicated bus_updates channel; everything else goes to announcements.
        final msgType = message.data['type'] as String? ?? '';
        final isSmartNotif = ['bus_approaching', 'tap_out_reminder',
            'shift_reminder', 'shift_started'].contains(msgType);
        final channelId = isSmartNotif ? 'bus_updates' : 'announcements';
        final channelName = isSmartNotif ? 'Bus Updates' : 'Announcements';

        _localNotifications.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          message.notification!.title ?? 'Notification',
          message.notification!.body ?? '',
          NotificationDetails(
            android: AndroidNotificationDetails(
              channelId,
              channelName,
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
        );
      }
    });

    // Handle background messages (app open, notification tapped)
    _onMessageOpenedAppSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint('Notification tapped: type=${message.data["type"]}');
      }
      _handleMessageNavigation(message);
    });

    // Handle terminated-state messages (app launched from notification tap).
    // The reactive DriverShiftProvider stream already auto-starts the shift
    // when bus.isActive is true; we only need to navigate to the driver screen.
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        if (kDebugMode) {
          debugPrint('App launched from notification: type=${message.data["type"]}');
        }
        // Defer until the widget tree (and navigatorKey) is ready.
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleMessageNavigation(message);
        });
      }
    });

    // Ensure topic subscription is restored on every app launch.
    await subscribeToBusAnnouncements();

    _isInitialized = true;
  }

  /// Navigate to the appropriate screen based on the notification type.
  void _handleMessageNavigation(RemoteMessage message) {
    final type = message.data['type'] as String? ?? '';
    if (type == 'shift_started') {
      // Bring the driver to their dashboard where the shift auto-starts
      // because DriverShiftProvider detects bus.isActive == true.
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/driver',
        (route) => false,
      );
    }
  }

  /// Persist the device FCM token to Firestore so Cloud Functions can send
  /// targeted notifications. Pass [userId] for authenticated users.
  /// If [userId] is null and there is no authenticated user, the write is
  /// skipped silently (Firestore rules require auth).
  Future<void> saveDeviceToken({String? userId}) async {
    try {
      final effectiveUserId = userId ?? FirebaseAuth.instance.currentUser?.uid;
      // Skip if there is no authenticated user — Firestore rules block the write
      // and the token will be saved again after login via driver_dashboard.
      if (effectiveUserId == null) return;

      final token = await _firebaseMessaging.getToken();
      if (token == null) return;

      // Resolve deviceId
      String? deviceId;
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        deviceId = (await deviceInfo.androidInfo).id;
      } else if (Platform.isIOS) {
        deviceId = (await deviceInfo.iosInfo).identifierForVendor;
      }
      if (deviceId == null) return;

      final db = FirebaseFirestore.instance;
      // Always save under deviceId
      await db.collection('device_tokens').doc(deviceId).set({
        'fcmToken': token,
        'userId': effectiveUserId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also save under userId so driver shift reminder CF can look up by UID
      await db.collection('device_tokens').doc(effectiveUserId).set({
        'fcmToken': token,
        'deviceId': deviceId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('NotificationService: saveDeviceToken error: $e');
    }
  }

  // Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
    if (kDebugMode) {
      debugPrint('Subscribed to topic: $topic');
    }
  }

  // Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
    if (kDebugMode) {
      debugPrint('Unsubscribed from topic: $topic');
    }
  }

  // Subscribe to bus announcements
  Future<void> subscribeToBusAnnouncements() async {
    await subscribeToTopic('announcements');
  }
}
