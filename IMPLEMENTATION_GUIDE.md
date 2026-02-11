# UNIMAS SmartBus - Implementation Guide

## Project Status

This guide provides an overview of the completed implementation and outlines the next steps for development.

## Completed Components ✓

### 1. Project Structure
- ✓ Complete folder organization with clear separation of concerns
- ✓ Models, services, providers, screens, widgets, utils, and constants folders
- ✓ Organized screen structure by user role (student, driver, admin)

### 2. Data Models
- ✓ User and DriverProfile models with role-based access
- ✓ Bus model with occupancy calculations
- ✓ BusRoute model with stop management
- ✓ BusStop model with facility information
- ✓ BusSchedule model for route scheduling
- ✓ Trip model for trip management
- ✓ Report model with categorization
- ✓ Announcement model with type and routing

### 3. Services
- ✓ AuthService - Firebase authentication (sign up, sign in, password reset)
- ✓ FirestoreService - Complete CRUD operations for all data models
- ✓ LocationService - GPS tracking with streaming updates
- ✓ NotificationService - Firebase Cloud Messaging setup

### 4. State Management (Provider)
- ✓ AuthProvider - User authentication state
- ✓ BusProvider - Bus data and location updates
- ✓ RouteProvider - Route and bus stop management
- ✓ LocationProvider - Real-time location tracking
- ✓ AnnouncementProvider - Service announcements

### 5. UI Screens
- ✓ SplashScreen - App initialization
- ✓ LoginScreen - User authentication
- ✓ SignupScreen - Account creation with role selection
- ✓ StudentDashboardScreen - Main student interface with tabs
- ✓ DriverDashboardScreen - Driver feature dashboard
- ✓ AdminDashboardScreen - Admin management interface

### 6. Theme & Constants
- ✓ AppTheme - Complete theme with colors, typography, and widget styling
- ✓ AppConstants - App configuration and Firebase references

### 7. Utilities
- ✓ Helper functions for formatting and validation
- ✓ Common reusable widgets (LoadingWidget, EmptyStateWidget, etc.)

### 8. Documentation
- ✓ Comprehensive README with features and setup instructions
- ✓ Detailed SETUP_GUIDE for Firebase and Google Maps configuration
- ✓ This implementation guide

## Remaining Tasks

### Phase 1: Map Integration (High Priority)

**Bus Tracking Map Screen**
- [ ] Integrate Google Maps Flutter plugin
- [ ] Display real-time bus locations on map
- [ ] Show bus stops and routes
- [ ] Add map controls (zoom, pan, search)
- [ ] Implement bus info windows with occupancy details

**Files to create:**
- `lib/screens/student/bus_map_screen.dart`
- `lib/screens/student/bus_details_screen.dart`
- `lib/providers/map_provider.dart`

### Phase 2: Location Tracking (High Priority)

**Driver Location Updates**
- [ ] Implement background location service
- [ ] Update bus location every 5 seconds
- [ ] Handle permission management
- [ ] Stop tracking when trip ends

**Files to create:**
- `lib/screens/driver/active_trip_screen.dart`
- `lib/screens/driver/location_tracking_service.dart`
- `lib/services/background_location_service.dart`

### Phase 3: Advanced Features

**Student Features**
- [ ] Search nearby bus stops
- [ ] Get directions to bus stops
- [ ] ETA calculations and display
- [ ] Tap in/out of bus (QR code or NFC)
- [ ] Report issues interface
- [ ] Favorites/bookmarks

**Files to create:**
- `lib/screens/student/search_stops_screen.dart`
- `lib/screens/student/report_issue_screen.dart`
- `lib/screens/student/eta_screen.dart`

**Driver Features**
- [ ] Trip management (start/end)
- [ ] Occupancy updates
- [ ] Route navigation
- [ ] Message driver feature

**Files to create:**
- `lib/screens/driver/trip_management_screen.dart`
- `lib/screens/driver/occupancy_management_screen.dart`

**Admin Features**
- [ ] Bus management CRUD
- [ ] Driver management
- [ ] Route management
- [ ] Schedule management
- [ ] Announcement creation
- [ ] Report management
- [ ] Analytics dashboard

**Files to create:**
- `lib/screens/admin/buses_management_screen.dart`
- `lib/screens/admin/drivers_management_screen.dart`
- `lib/screens/admin/routes_management_screen.dart`
- `lib/screens/admin/schedules_management_screen.dart`
- `lib/screens/admin/announcements_management_screen.dart`
- `lib/screens/admin/reports_management_screen.dart`
- `lib/screens/admin/analytics_screen.dart`

### Phase 4: Notifications

- [ ] Setup Firebase Cloud Messaging properly
- [ ] Create notification handlers
- [ ] Test push notifications
- [ ] Local notifications for ETA alerts

**Files to create:**
- `lib/services/notification_handler.dart`

### Phase 5: Testing & Optimization

- [ ] Unit tests for models and services
- [ ] Widget tests for screens
- [ ] Integration tests
- [ ] Performance optimization
- [ ] App size optimization

### Phase 6: Deployment

- [ ] Configure Firebase Hosting
- [ ] Setup CI/CD pipeline
- [ ] Create build configurations
- [ ] Testing on real devices
- [ ] App Store submission preparation

## Development Workflow

### 1. Before Starting Development

```bash
# Pull latest changes
git pull origin develop

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### 2. Creating New Features

```bash
# Create feature branch
git checkout -b feature/your-feature-name

# Make changes
# Commit with clear messages
git commit -m "feat: add feature description"

# Push to repository
git push origin feature/your-feature-name
```

### 3. Code Quality Guidelines

- Follow Dart style guide
- Use meaningful variable and function names
- Add comments for complex logic
- Handle all exceptions
- Test your code locally
- Request code review before merge

## Key Implementation Notes

### Firebase Firestore Queries

For efficient queries, follow these patterns:

```dart
// Get all buses
final buses = await firestore.collection('buses').get();

// Get bus with specific ID
final bus = await firestore.collection('buses').doc(busId).get();

// Stream real-time updates
firestore.collection('buses').doc(busId).snapshots().listen((doc) {
  // Handle updates
});

// Query with conditions
final activeTrips = await firestore
    .collection('trips')
    .where('status', isEqualTo: 'inProgress')
    .get();
```

### Real-Time Updates

For real-time bus tracking:

```dart
// In driver service
locationService.getPositionStream().listen((position) {
  firestore.collection('buses').doc(busId).update({
    'latitude': position.latitude,
    'longitude': position.longitude,
    'lastUpdated': DateTime.now().toIso8601String(),
  });
});
```

### Error Handling Pattern

```dart
try {
  // Perform operation
} on FirebaseAuthException catch (e) {
  // Handle Firebase auth errors
  return e.message;
} on FirebaseException catch (e) {
  // Handle Firebase errors
  return e.message;
} catch (e) {
  // Handle generic errors
  return e.toString();
}
```

### State Management Pattern

```dart
class MyProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  
  Future<void> fetchData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Fetch data
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
}
```

## Testing Checklist

### Authentication
- [ ] Sign up new account
- [ ] Sign in with email/password
- [ ] Sign out
- [ ] Reset password
- [ ] Role-based navigation

### Bus Management
- [ ] Fetch and display buses
- [ ] Update bus location
- [ ] Update occupancy
- [ ] View bus details

### Real-Time Updates
- [ ] Location updates stream properly
- [ ] Occupancy updates in real-time
- [ ] Announcements update instantly

### Maps
- [ ] Google Maps loads
- [ ] Bus markers display
- [ ] Stop markers display
- [ ] Routes display on map

### Notifications
- [ ] Push notifications received
- [ ] In-app notifications display
- [ ] Topic subscriptions work

## Performance Considerations

1. **Database Queries**
   - Use pagination for large lists
   - Index frequently queried fields
   - Limit query results

2. **Real-Time Listeners**
   - Clean up listeners in dispose()
   - Avoid nested listeners
   - Use unsubscribe properly

3. **Images and Assets**
   - Compress images
   - Use lazy loading
   - Cache API responses

4. **Location Updates**
   - Only track when necessary
   - Use appropriate update intervals
   - Stop tracking in background

## Debugging Tips

1. **Firebase Logs**
   ```bash
   flutter logs
   ```

2. **Android Logs**
   ```bash
   adb logcat
   ```

3. **Dart DevTools**
   ```bash
   dart devtools
   ```

4. **Check Firebase Console**
   - Monitor API calls
   - Check database rules
   - Review error messages

## Useful Commands

```bash
# Clean build
flutter clean

# Get dependencies
flutter pub get

# Format code
dart format lib/

# Analyze code
flutter analyze

# Run tests
flutter test

# Build APK
flutter build apk --release

# Build iOS
flutter build ios --release
```

## Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Google Maps Flutter Plugin](https://pub.dev/packages/google_maps_flutter)
- [Provider Package Guide](https://pub.dev/packages/provider)
- [Geolocator Package](https://pub.dev/packages/geolocator)

## Next Immediate Steps

1. **Configure Firebase**
   - Complete Firebase setup as per SETUP_GUIDE.md
   - Create test accounts
   - Add sample bus and route data

2. **Test Current Implementation**
   - Run the app
   - Test login/signup flows
   - Verify provider state management

3. **Implement Google Maps**
   - Add Google Maps screen
   - Display buses on map
   - Show bus stops

4. **Implement Location Tracking**
   - Background location service for drivers
   - Real-time location updates to Firebase

5. **Expand Features**
   - Add advanced student features
   - Complete driver functionality
   - Build admin dashboard

## Support & Contact

For questions or issues:
- Check the documentation and guides
- Review existing code patterns
- Ask your supervisor or team members
- Document issues in project tracker

Good luck with development! 🚀
