import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'constants/app_theme.dart';
import 'constants/app_constants.dart';
import 'providers/auth_provider.dart';
import 'providers/bus_provider.dart';
import 'providers/route_provider.dart';
import 'providers/location_provider.dart';
import 'providers/announcement_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/driver_shift_provider.dart';
import 'providers/dashboard_nav_provider.dart';
import 'services/device_service.dart';
import 'services/local_storage_service.dart';
import 'services/notification_service.dart';
import 'providers/notification_prefs_provider.dart';
import 'screens/auth/splash_screen.dart';
import 'services/smart_notification_service.dart';
import 'utils/app_navigator.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/guest/guest_home_screen.dart';
import 'screens/driver/driver_home_screen.dart';
import 'screens/admin/admin_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // FlutterFire options in this repo are currently configured for Android.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());

  unawaited(_initializeBackgroundServices());
}

Future<void> _initializeBackgroundServices() async {
  try {
    final deviceService = DeviceService();
    final localStorageService = LocalStorageService();
    final notificationService = NotificationService();

    await Future.wait([
      deviceService.initialize(),
      localStorageService.initialize(),
    ]);

    await notificationService.initializeNotifications();
    await notificationService.subscribeToBusAnnouncements();
    // Save device FCM token so Cloud Functions can target this device
    await notificationService.saveDeviceToken();
  } catch (_) {
    // Keep startup resilient even if optional background services fail.
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BusProvider()),
        ChangeNotifierProvider(create: (_) => RouteProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => AnnouncementProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => DriverShiftProvider()),
        ChangeNotifierProvider(create: (_) => DashboardNavProvider()),
        ChangeNotifierProvider(create: (_) => NotificationPrefsProvider()),
        ChangeNotifierProvider(create: (_) => SmartNotificationService()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: AppConstants.appName,
            navigatorKey: navigatorKey,
            scaffoldMessengerKey: scaffoldMessengerKey,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            debugShowCheckedModeBanner: false,
            // Clamp system font scaling to 1.2× max — prevents extreme
            // accessibility sizes from breaking fixed-height layouts while
            // still honouring user font preferences up to 20% larger.
            builder: (context, child) {
              final mqData = MediaQuery.of(context);
              return MediaQuery(
                data: mqData.copyWith(
                  textScaler: mqData.textScaler.clamp(maxScaleFactor: 1.2),
                ),
                child: child!,
              );
            },
            home: const SplashScreen(),
            routes: {
              '/splash': (context) => const SplashScreen(),
              '/login': (context) => const LoginScreen(),
              '/signup': (context) => const SignUpScreen(),
              '/guest': (context) => const GuestHomeScreen(initialIndex: 0),
              '/student': (context) => const GuestHomeScreen(initialIndex: 1),
              '/driver': (context) => const DriverHomeScreen(),
              '/admin': (context) => const AdminHomeScreen(),
            },
          );
        },
      ),
    );
  }
}
