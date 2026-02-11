# UNIMAS SmartBus - Setup Guide

This guide will help you set up the UNIMAS SmartBus application from scratch.

## Prerequisites

Before starting, ensure you have the following installed:
- Flutter SDK (3.6.0+)
- Dart SDK
- Android SDK (for Android development)
- Xcode (for iOS development)
- Git

## Step 1: Firebase Project Setup

### 1.1 Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project"
3. Enter project name: "UNIMAS SmartBus"
4. Accept the terms and create the project
5. Wait for the project to be created

### 1.2 Enable Required Services

1. In the Firebase Console, go to **Build** section
2. Enable the following services:
   - **Authentication**: Enable Email/Password sign-in method
   - **Cloud Firestore**: Create database in production mode
   - **Realtime Database**: Create database in production mode
   - **Cloud Messaging**: Automatically available

## Step 2: Configure Firebase for Flutter

### 2.1 Firebase Configuration Status

✅ **Already Configured**

Firebase has been successfully configured for this project:
- ✅ `lib/firebase_options.dart` is present with credentials
- ✅ `android/app/google-services.json` is configured for Android
- ✅ Firebase project: `unimas-smartbus`

**Note**: If you need to reconfigure Firebase or set up iOS, run:
```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

For Android development only, you can proceed to **Step 3: Google Maps API Setup**.

## Step 3: Google Maps API Setup

### 3.1 Enable Google Maps API

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select your Firebase project
3. On the left sidebar, click **hamburger menu** (≡) → **APIs & Services** → **Library**
4. Search for and enable the following APIs (click each one and press **Enable**):
   - **Maps SDK for Android**
   - **Maps SDK for iOS**
   - **Maps JavaScript API**

### 3.2 Create an API Key

1. Go to **Credentials** in Google Cloud Console
2. Click **Create Credentials** > **API Key**
3. Copy your API key

### 3.3 Configure API Key for Android

Edit `android/app/src/main/AndroidManifest.xml` and add:

```xml
<application>
    ...
    <meta-data
        android:name="com.google.android.geo.API_KEY"
        android:value="YOUR_API_KEY_HERE"/>
</application>
```

### 3.4 Configure API Key for iOS

Edit `ios/Runner/Info.plist` and add:

```xml
<key>com.google.ios.apiKey</key>
<string>YOUR_API_KEY_HERE</string>
```

### 3.5 Update App Constants

Update `lib/constants/app_constants.dart`:

```dart
static const String googleMapsApiKey = 'YOUR_API_KEY_HERE';
```

## Step 4: Environment Setup

### 4.1 Update Dependencies

```bash
flutter pub get
```

### 4.2 Clear Build Cache (if needed)

```bash
flutter clean
flutter pub get
```

## Step 5: Run the Application

### 5.1 Run on Android Emulator

```bash
flutter run -d emulator-5554
```

Or for a specific device:

```bash
flutter run
```

### 5.2 Run on iOS Simulator

```bash
flutter run -d simulator
```

### 5.3 Run on Physical Device

```bash
flutter run
```

## Step 6: Firebase Database Rules

### 6.1 Firestore Security Rules

In Firebase Console, go to **Firestore Database** > **Rules** and update:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
    
    // Buses collection - readable by all authenticated users
    match /buses/{busId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid in get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'driver';
    }
    
    // Routes collection - readable by all
    match /routes/{routeId} {
      allow read: if request.auth != null;
      allow write: if get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Bus stops - readable by all
    match /bus_stops/{stopId} {
      allow read: if request.auth != null;
      allow write: if get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Schedules
    match /schedules/{scheduleId} {
      allow read: if request.auth != null;
      allow write: if get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Trips
    match /trips/{tripId} {
      allow read, write: if request.auth != null;
    }
    
    // Reports
    match /reports/{reportId} {
      allow create: if request.auth != null;
      allow read, update: if request.auth.uid == resource.data.studentId || 
                             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Announcements
    match /announcements/{announcementId} {
      allow read: if request.auth != null;
      allow write: if get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
  }
}
```

## Step 7: Initialize Sample Data (Optional)

You can add sample data via Firebase Console:

### 7.1 Add a Sample Bus

1. Go to [Firebase Console](https://console.firebase.google.com/) and select **unimas-smartbus** project
2. On the left sidebar, click **Build** → **Firestore Database**
3. Click **Start collection** (or **+ Add collection**)
4. Enter collection ID: `buses`
5. Click **Next**
6. Click **Auto ID** to generate a document ID
7. Add the following fields by clicking **Add field** for each:
   - `busId` (string): `bus001`
   - `busNumber` (string): `B001`
   - `registrationNumber` (string): `WMK 1234`
   - `model` (string): `Scania K360`
   - `capacity` (number): `50`
   - `currentOccupancy` (number): `25`
   - `isActive` (boolean): `true`
   - `latitude` (number): `1.4521`
   - `longitude` (number): `110.8047`
   - `lastUpdated` (timestamp): Current time or any date
8. Click **Save**

**Reference Data** (if copying manually):
```json
{
  "busId": "bus001",
  "busNumber": "B001",
  "registrationNumber": "WMK 1234",
  "model": "Scania K360",
  "capacity": 50,
  "currentOccupancy": 25,
  "isActive": true,
  "latitude": 1.4521,
  "longitude": 110.8047,
  "lastUpdated": "2026-02-11T10:00:00.000Z"
}
```

### 7.2 Add a Sample Route

1. In **Firestore Database**, click **+ Add collection**
2. Enter collection ID: `routes`
3. Click **Next**
4. Click **Auto ID** to generate a document ID
5. Add the following fields:
   - `routeId` (string): `route001`
   - `routeName` (string): `Main Campus to Residential`
   - `routeCode` (string): `R1`
   - `stopIds` (array): Add items `stop001`, `stop002`, `stop003`
   - `estimatedDuration` (number): `30`
   - `isActive` (boolean): `true`
   - `description` (string): `Main route connecting main campus with residential areas`
   - `createdAt` (timestamp): Current time or any date
6. Click **Save**

**Reference Data**:
```json
{
  "routeId": "route001",
  "routeName": "Main Campus to Residential",
  "routeCode": "R1",
  "stopIds": ["stop001", "stop002", "stop003"],
  "estimatedDuration": 30,
  "isActive": true,
  "description": "Main route connecting main campus with residential areas",
  "createdAt": "2026-01-01T00:00:00.000Z"
}
```

## Step 8: Testing the Application

### 8.1 Create Test Accounts

Using the Firebase Console:

1. Go to **Authentication**
2. Click **Add user**
3. Create accounts with different roles:
   - **Student**: student@unimas.edu.my / password123
   - **Driver**: driver@unimas.edu.my / password123
   - **Admin**: admin@unimas.edu.my / password123

### 8.2 Manual Testing

1. Launch the app
2. Sign in with test accounts
3. Verify role-based screens appear
4. Test available features

## Troubleshooting

### Firebase Connection Error

**Problem**: `PlatformException(firebase_auth/error, ..)`

**Solution**:
- Verify Firebase project is active
- Check `firebase_options.dart` has correct credentials
- Run `flutterfire configure` again

### Google Maps Not Displaying

**Problem**: Map shows blank or error

**Solution**:
- Verify API key is correct
- Check API key restrictions
- Ensure Maps SDK is enabled in Google Cloud Console
- Verify platform-specific configurations

### Location Permission Denied

**Problem**: Can't access device location

**Solution**:
- Check app permissions in device settings
- Manually grant permissions
- Run app with location enabled

### Flutter Version Issues

**Problem**: `Error: The current Dart SDK version is...`

**Solution**:
```bash
flutter upgrade
flutter pub get
flutter clean
```

## Next Steps

After successful setup:

1. **Customize app theme** in `lib/constants/app_theme.dart`
2. **Update app constants** in `lib/constants/app_constants.dart`
3. **Implement additional screens** for specific features
4. **Add comprehensive error handling**
5. **Implement unit and widget tests**
6. **Set up CI/CD pipeline**
7. **Deploy to Firebase Hosting** (for web version)

## Additional Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Firebase Docs](https://firebase.google.com/docs)
- [Google Maps API Docs](https://developers.google.com/maps/documentation)
- [Provider Package](https://pub.dev/packages/provider)

## Support

If you encounter any issues:

1. Check the troubleshooting section above
2. Review Flutter and Firebase documentation
3. Check project logs: `flutter logs`
4. Search Stack Overflow with error message
5. Contact your supervisor or development team
