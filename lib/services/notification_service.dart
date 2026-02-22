import 'dart:async';
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
        _localNotifications.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          message.notification!.title ?? 'New Announcement',
          message.notification!.body ?? 'Tap to view details',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'announcements',
              'Announcements',
              channelDescription: 'Notifications for bus announcements',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: DarwinNotificationDetails(
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
