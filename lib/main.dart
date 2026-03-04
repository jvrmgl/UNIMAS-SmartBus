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
import 'screens/guest/student_dashboard_screen.dart';
import 'screens/driver/driver_home_screen.dart';
import 'screens/admin/admin_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive for local storage
  await Hive.initFlutter();
  
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
              '/signup': (context) => const SignupScreen(),
              '/guest': (context) => const GuestHomeScreen(),
              '/student': (context) => const StudentDashboardScreen(),
              '/driver': (context) => const DriverHomeScreen(),
              '/admin': (context) => const AdminHomeScreen(),
            },
          );
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}