# Copilot Instructions for UNIMAS SmartBus

## Big picture architecture
- Flutter app with role-based UX (`student`, `driver`, `admin`) using Provider + Firebase.
- App startup is centralized in `lib/main.dart`: Firebase + Hive init, then `MultiProvider`, then route-based role navigation.
- Role routing is resolved in `lib/screens/auth/splash_screen.dart` via `AuthProvider.isInitialized` + `currentUser.role`.
- Service boundary: UI/Providers call `lib/services/firestore_service.dart` for most Firestore/Cloud Functions operations.
- Cloud Functions live in `functions/index.js` and run in region `asia-southeast1`; Dart side uses `FirebaseFunctions.instanceFor(region: 'asia-southeast1')`.

## Data and realtime flow patterns
- Firestore collections are stable and centralized in `lib/constants/app_constants.dart` (`users`, `buses`, `routes`, `bus_stops`, `schedules`, `trips`, `reports`, `announcements`).
- Realtime updates are stream-first for active views: e.g., `BusProvider.listenToBuses()` + `FirestoreService.getBusesStream()`.
- Driver shift state is reactive to bus document changes (`lib/providers/driver_shift_provider.dart`): admin toggles `buses.isActive`, provider auto-starts/ends tracking.
- Driver GPS updates are emitted by `lib/services/driver_tracking_service.dart` to `buses/{busId}` (`latitude`, `longitude`, `lastUpdated`).
- Notification preferences are local (Hive) in `lib/providers/notification_prefs_provider.dart`; Cloud Functions behavior maps to these toggles.

## Notifications and Cloud Functions coupling
- Keep notification channel/topic names consistent: `announcements` and `bus_updates` in `lib/services/notification_service.dart` and `functions/index.js`.
- Device tokens are stored in Firestore `device_tokens` by both `deviceId` and `userId` documents; preserve this dual-write contract.
- Smart notification records use `waiting_students` and `device_bus_sessions`; scheduled functions read these for approaching-bus/tap-out reminders.
- If adding callable functions, enforce auth/role checks server-side (see admin checks in `deleteAuthUserByUid` and `resendAnnouncementNotification`).

## Project-specific coding conventions
- Provider pattern here uses explicit loading/error flags and immediate `notifyListeners()` around async transitions.
- Many service methods return `String?` where `null` means success; keep this contract when extending service APIs.
- Use optimistic UI updates where already established (e.g., occupancy update in `DriverShiftProvider.adjustOccupancy`) and let streams reconcile.
- Preserve startup resilience: background service init in `main.dart` intentionally catches and swallows optional-service failures.
- Prefer extending existing providers/services before creating new architectural layers.

## Developer workflows
- Install deps: `flutter pub get`
- Run app: `flutter run`
- Analyze: `flutter analyze`
- Test: `flutter test`
- Cloud Functions local setup: `cd functions && npm install`
- Cloud Functions deploy: `firebase deploy --only functions`

## High-value file map
- Entry + DI: `lib/main.dart`
- Auth/role bootstrap: `lib/providers/auth_provider.dart`, `lib/screens/auth/splash_screen.dart`
- Firestore + callable access: `lib/services/firestore_service.dart`
- Driver shift/tracking: `lib/providers/driver_shift_provider.dart`, `lib/services/driver_tracking_service.dart`
- Push notifications: `lib/services/notification_service.dart`, `lib/services/smart_notification_service.dart`, `functions/index.js`
- Setup docs used by maintainers: `README.md`, `SETUP_GUIDE.md`, `PUSH_NOTIFICATIONS_SETUP.md`