class AppConstants {
  // App Info
  static const String appName = 'UNIMAS SmartBus';
  static const String appVersion = '1.0.0';

  // Google Maps
  static const String googleMapsApiKey = 'AIzaSyAWTeFEWb1hHmYND6zNIHlMcxJz-gPyGKI';
  static const double defaultMapZoom = 15.0;

  // Location
  static const int locationUpdateIntervalSeconds = 5;
  static const int locationDistanceFilterMeters = 0;

  // Bus occupancy thresholds
  static const double busNearCapacityThreshold = 80.0; // percentage

  // Timeouts
  static const int requestTimeoutSeconds = 30;
  static const int locationTimeoutSeconds = 60;

  // Firebase collections
  static const String usersCollection = 'users';
  static const String busesCollection = 'buses';
  static const String routesCollection = 'routes';
  static const String busStopsCollection = 'bus_stops';
  static const String schedulesCollection = 'schedules';
  static const String tripsCollection = 'trips';
  static const String reportsCollection = 'reports';
  static const String announcementsCollection = 'announcements';

  // FCM Topics
  static const String announcementsTopic = 'announcements';
  static const String serviceNotificationsTopic = 'service_notifications';

  // Route status
  static const List<String> routeStatuses = ['active', 'inactive', 'maintenance'];

  // Default coordinates (UNIMAS campus center - placeholder)
  static const double unimascampusLatitude = 1.4521;
  static const double unimascampusLongitude = 110.8047;

  // Navigation routes
  static const String loginRoute = '/login';
  static const String signupRoute = '/signup';
  static const String studentDashboardRoute = '/student';
  static const String driverDashboardRoute = '/driver';
  static const String adminDashboardRoute = '/admin';
  static const String splashRoute = '/';
}
