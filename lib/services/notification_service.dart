import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSubscription;

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
      debugPrint('FCM Token: $token');
    }

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
            'shift_reminder'].contains(msgType);
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

    // Handle background messages
    _onMessageOpenedAppSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint('Message clicked!');
      }
      // Handle message click
    });

    _isInitialized = true;
  }

  Future<void> disposeNotifications() async {
    await _onMessageSubscription?.cancel();
    await _onMessageOpenedAppSubscription?.cancel();
    _onMessageSubscription = null;
    _onMessageOpenedAppSubscription = null;
    _isInitialized = false;
  }

  // Get FCM token
  Future<String?> getFCMToken() async {
    return await _firebaseMessaging.getToken();
  }

  /// Persist the device FCM token to Firestore so Cloud Functions can send
  /// targeted notifications. Pass [userId] for authenticated users.
  Future<void> saveDeviceToken({String? userId}) async {
    try {
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
        'userId': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also save under userId so driver shift reminder CF can look up by UID
      if (userId != null) {
        await db.collection('device_tokens').doc(userId).set({
          'fcmToken': token,
          'deviceId': deviceId,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('NotificationService: saveDeviceToken error: $e');
    }
  }

  /// Show a local push notification on the bus_updates channel.
  /// Called when the app receives a foreground FCM message from the smart-
  /// notification Cloud Functions.
  Future<void> showSmartNotification(String title, String body) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'bus_updates',
          'Bus Updates',
          channelDescription: 'Approaching bus, tap-out reminders, and shift alerts',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
      ),
    );
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

  // Subscribe to route notifications
  Future<void> subscribeToRoute(String routeId) async {
    await subscribeToTopic('route_$routeId');
  }

  // Subscribe to bus announcements
  Future<void> subscribeToBusAnnouncements() async {
    await subscribeToTopic('announcements');
  }

  // Subscribe to service notifications
  Future<void> subscribeToServiceNotifications() async {
    await subscribeToTopic('service_notifications');
  }
}
