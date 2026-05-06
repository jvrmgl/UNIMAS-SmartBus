# UNIMAS SmartBus

A Flutter-based real-time campus bus tracking and monitoring application for Universiti Malaysia Sarawak (UNIMAS).

## Overview

UNIMAS SmartBus is a mobile application designed to enhance the campus transportation experience by providing real-time bus tracking, estimated arrival times (ETA), and occupancy information. The application serves three user roles:

- **Students**: View real-time bus locations, schedules, routes, and occupancy
- **Drivers**: Manage trips, update GPS location, and manage bus occupancy
- **Admins**: Monitor operations, manage buses, drivers, routes, schedules, and reports

## Features

### Student Features
- Real-time bus location tracking on interactive maps
- View bus estimated arrival times (ETA)
- Check bus occupancy and availability
- View bus routes and schedules
- Search and filter bus stops
- Receive service announcements and notifications
- Submit reports for issues (cleanliness, safety, delays)
- View routing suggestions

### Driver Features
- Start/end bus trips
- Update real-time GPS location
- Update bus occupancy information
- View assigned routes and schedules
- Access driver profile management
- Receive route notifications
- View passenger statistics

### Admin Features
- Monitor real-time bus operations dashboard
- Manage bus fleet information
- Manage driver accounts and licenses
- Create and manage bus routes
- Update bus schedules
- Create service announcements
- Review and manage user reports
- View system analytics and statistics
- Manage system settings

## Tech Stack

- **Frontend**: Flutter 3.x (Dart)
- **Backend**: Firebase
  - Firebase Authentication
  - Cloud Firestore (Database)
  - Firebase Realtime Database
  - Firebase Cloud Messaging (Notifications)
- **APIs**: Google Maps API
- **State Management**: Provider
- **Location Services**: Geolocator
- **HTTP Client**: http

## Project Structure

```
lib/
├── models/                 # Data models
│   ├── user_model.dart
│   ├── bus_model.dart
│   ├── route_model.dart
│   ├── bus_stop_model.dart
│   ├── schedule_model.dart
│   ├── trip_model.dart
│   ├── report_model.dart
│   └── announcement_model.dart
├── screens/               # UI screens
│   ├── auth/             # Authentication screens
│   ├── student/          # Student feature screens
│   ├── driver/           # Driver feature screens
│   └── admin/            # Admin dashboard screens
├── providers/            # State management (Provider)
├── services/             # Business logic & external services
│   ├── auth_service.dart
│   ├── firestore_service.dart
│   ├── location_service.dart
│   └── notification_service.dart
├── widgets/              # Reusable UI components
├── constants/            # App constants & theme
└── utils/                # Utility functions
```

## Getting Started

### Prerequisites

- Flutter SDK (3.6.0 or higher)
- Dart SDK
- Firebase project setup
- Google Maps API key
- Android SDK (for Android development)
- Xcode (for iOS development)

### Installation Steps

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd unimas_smartbus
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   ```bash
   # Install FlutterFire CLI
   dart pub global activate flutterfire_cli
   
   # Configure Firebase for your platforms
   flutterfire configure
   ```

4. **Add Google Maps Web Services Key (Dart defines)**
   - Copy `env.json.example` to `env.json` and set `GOOGLE_MAPS_API_KEY`
   - Run with `flutter run --dart-define-from-file=env.json`
   - For iOS map rendering, continue with the platform key setup below

5. **Update Firebase Configuration**
   - The `flutterfire configure` command generates `lib/firebase_options.dart`
   - Verify all Firebase settings are correct

6. **Update Google Maps API Key**
   - In `android/app/src/main/AndroidManifest.xml`:
     ```xml
     <meta-data
         android:name="com.google.android.geo.API_KEY"
         android:value="YOUR_API_KEY"/>
     ```
   - In `ios/Runner/Info.plist`:
     ```xml
     <key>io.flutter.embedded_views_preview</key>
     <true/>
     ```

### Running the App

**Development**
```bash
flutter run --dart-define-from-file=env.json
```

**Release Build**
```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

## Firebase Setup

### Collections Structure

1. **users**
   - Stores user profiles (students, drivers, admins)
   - Fields: email, normalizedEmail, fullName, role, createdAt

2. **buses**
   - Stores bus information and real-time location
   - Fields: busNumber, capacity, latitude, longitude, occupancy

3. **routes**
   - Stores bus route information
   - Fields: routeName, routeCode, stopIds, estimatedDuration

4. **bus_stops**
   - Stores bus stop details
   - Fields: stopName, latitude, longitude, facilities

5. **schedules**
   - Stores bus schedules
   - Fields: routeId, busId, driverId, departureTime, arrivalTime

6. **trips**
   - Stores active and completed trips
   - Fields: busId, driverId, routeId, status, startTime, endTime

7. **reports**
   - Stores user reports
   - Fields: category, description, status, createdAt, resolvedAt

8. **announcements**
   - Stores service announcements
   - Fields: title, description, type, affectedRoutes, expiryDate

### Firebase Security Rules

Ensure proper security rules are set in Firebase Console for each collection.

## API Endpoints

The app uses Firebase Realtime Database and Firestore for data synchronization.

## Key Implementation Details

### Real-Time Bus Tracking
- GPS location updates every 5 seconds
- Stream-based real-time updates using Firestore listeners
- WebSocket connections for instant data sync

### User Authentication
- Email/password authentication via Firebase Auth
- Role-based access control
- Session persistence

### Notifications
- Firebase Cloud Messaging (FCM) for push notifications
- Topic-based subscriptions for routes and announcements
- In-app notification handling

### Location Services
- Geolocator for GPS tracking
- Background location updates for drivers
- Distance calculation for ETA

## Development Guidelines

### Code Style
- Follow Dart style guide
- Use meaningful variable names
- Add comments for complex logic
- Keep functions focused and testable

### State Management
- Use Provider for state management
- Create separate providers for each feature
- Avoid deeply nested providers

### Error Handling
- Always handle Firebase exceptions
- Show user-friendly error messages
- Log errors for debugging

## Testing

```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test
```

## Deployment

### Versioning
Use a new build number for every APK or AAB you distribute to testers. A simple rule is:
- `1.0.1+2` for the next test build
- `1.0.1+3` for the build after that

Keep a small release note for each build so you can tell which APK is on which device.

### Android Deployment
```bash
# Optional but recommended before packaging a fresh release
flutter clean
flutter pub get

# Build signed APK
flutter build apk --release

# Build App Bundle for Play Store
flutter build appbundle --release
```

To produce a proper release APK, create `android/key.properties` with your release keystore details and keep the keystore file private.

### iOS Deployment
```bash
# Build for iOS
flutter build ios --release

# Archive for App Store
open ios/Runner.xcworkspace
```

## Future Enhancements

1. **Advanced Features**
   - Advanced route optimization algorithms
   - Real-time crowding predictions
   - Payment integration for tickets
   - Accessibility features
   - Offline mode support

2. **Performance Improvements**
   - Database query optimization
   - Caching strategies
   - Image optimization
   - App size reduction

3. **Additional Platforms**
   - Web version using Flutter Web
   - Desktop apps (Windows, macOS, Linux)
   - Smartwatch integration

## Troubleshooting

### Common Issues

1. **Firebase Connection Issues**
   - Verify Firebase project is active
   - Check internet connection
   - Validate Firebase configuration

2. **Location Permission Issues**
   - Check app permissions in device settings
   - Request permissions in app settings
   - Ensure location service is enabled

3. **Map Not Displaying**
   - Verify Google Maps API key
   - Check API key restrictions
   - Ensure correct platform configuration

## Contributing

1. Create a feature branch
2. Commit changes with clear messages
3. Push to the repository
4. Submit a pull request

## License

This project is part of the Final Year Project for UNIMAS.

## Contact

For questions or support, contact the development team or your supervisor.

## References

- [Flutter Documentation](https://flutter.dev/docs)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Google Maps API Documentation](https://developers.google.com/maps)
- [Provider Package Documentation](https://pub.dev/packages/provider)
