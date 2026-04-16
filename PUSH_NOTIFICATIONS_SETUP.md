# Push Notifications Setup Guide

## Overview
Your app now sends push notifications to all users when:
1. An admin creates a new announcement (automatic)
2. An admin resends an existing announcement (manual via "Resend" button)

## How It Works

### Client Side (Flutter App)
- **Automatic subscription**: All users are subscribed to the `announcements` FCM topic when the app starts
- **NotificationService**: Handles FCM token registration and topic subscriptions
- **In-app handling**: Shows notifications even when the app is in foreground

### Backend (Cloud Functions)
- **sendAnnouncementNotification**: Firestore trigger that sends push notification when a new announcement document is created
- **resendAnnouncementNotification**: Callable function that manually sends notification for existing announcements

## Deployment Instructions

### Prerequisites
1. Firebase CLI installed: `npm install -g firebase-tools`
2. Logged in to Firebase: `firebase login`

### Deploy Cloud Functions

1. **Navigate to functions directory**:
   ```bash
   cd functions
   ```

2. **Install dependencies** (if not already done):
   ```bash
   npm install
   ```

3. **Deploy to Firebase**:
   ```bash
   firebase deploy --only functions
   ```

   Or deploy specific functions:
   ```bash
   firebase deploy --only functions:sendAnnouncementNotification,functions:resendAnnouncementNotification
   ```

4. **Verify deployment**:
   - Go to [Firebase Console](https://console.firebase.google.com)
   - Select your project
   - Navigate to **Functions** section
   - You should see:
     - `sendAnnouncementNotification` (Firestore trigger)
     - `resendAnnouncementNotification` (HTTPS callable)
     - `deleteAuthUserByUid` (existing function)

## Testing Push Notifications

### Test 1: Create New Announcement
1. Log in as admin
2. Go to **Notifications Management**
3. Tap **Create Notification** button
4. Fill in:
   - Type: Select any type (Emergency, Maintenance, Route, Service)
   - Title: "Test Push Notification"
   - Message: "This is a test notification"
5. Tap **Send**
6. **Expected result**: All users subscribed to `announcements` topic receive push notification on their home screen

### Test 2: Resend Existing Announcement
1. In **Notifications Management** screen
2. Tap the three-dot menu on any announcement
3. Select **Resend**
4. Confirm in the dialog
5. **Expected result**: Push notification sent to all users again

### Test 3: Background/Foreground Handling
- **App in background**: Notification appears in system notification tray, tapping opens the app
- **App in foreground**: Notification handled by `FirebaseMessaging.onMessage` listener (console log shown)
- **App closed**: Notification still received via FCM background handler

## Notification Payload Structure

```json
{
  "notification": {
    "title": "Announcement Title",
    "body": "Announcement description text",
    "sound": "default"
  },
  "data": {
    "type": "announcement",
    "announcementId": "ann_1234567890",
    "announcementType": "emergency",
    "click_action": "FLUTTER_NOTIFICATION_CLICK"
  }
}
```

## Android Configuration

### Required Permissions (already in `android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

### Notification Channels
Android 8.0+ requires notification channels. These are auto-created by Firebase Messaging plugin.

## iOS Configuration

### Required Capabilities (already configured):
1. Push Notifications capability enabled
2. Background Modes → Remote notifications
3. APNs key uploaded to Firebase Console

## Troubleshooting

### Issue: Notifications not received
**Solutions**:
1. Verify Cloud Functions are deployed: `firebase functions:list`
2. Check Firebase Console → Functions → Logs for errors
3. Verify user is subscribed to topic:
   ```dart
   await NotificationService().subscribeToBusAnnouncements();
   ```
4. Check FCM token is generated:
   ```dart
  String? token = await FirebaseMessaging.instance.getToken();
   print('FCM Token: $token');
   ```

### Issue: "Permission denied" error
**Solution**: Ensure the admin role check in Cloud Function is working correctly. The function verifies:
```javascript
requesterDoc.data()?.role !== 'admin'
```

### Issue: Cloud Function deployment fails
**Solutions**:
1. Check Node.js version: `node --version` (should be v20)
2. Verify you're in the correct project: `firebase use --list`
3. Switch project if needed: `firebase use <project-id>`
4. Check functions/package.json has correct dependencies

### Issue: Notifications work on Android but not iOS
**Solutions**:
1. Verify APNs authentication key is uploaded to Firebase
2. Check iOS app capabilities include Push Notifications
3. Test on real device (iOS simulator doesn't support push notifications)
4. Verify production APNs certificate if testing production build

## Code Changes Made

### 1. Cloud Functions (`functions/index.js`)
- Added `sendAnnouncementNotification` - auto-sends on document create
- Added `resendAnnouncementNotification` - callable function for manual resend

### 2. Main App (`lib/main.dart`)
- Initialized `NotificationService` in `main()`
- Auto-subscribe users to `announcements` topic on app start

### 3. Firestore Service (`lib/services/firestore_service.dart`)
- Added `resendAnnouncementNotification()` method
- Imports `cloud_functions` package

### 4. Notifications Screen (`lib/screens/admin/notifications_management_screen.dart`)
- Updated `_resendNotification()` to call Cloud Function
- Removed "coming soon" placeholder

## FCM Topics

Currently using:
- **`announcements`**: All app users (students, drivers, admins)

Future expansion options:
- `route_<routeId>`: Route-specific notifications
- `drivers`: Driver-only notifications
- `students`: Student-only notifications
- `emergency`: High-priority emergency alerts

## Performance & Cost

### Firebase Free Tier Limits (Spark Plan)
- Cloud Functions: 125K invocations/month, 40K GB-seconds/month
- Cloud Messaging: Unlimited messages

### Blaze Plan (Pay as you go)
- Cloud Functions: $0.40 per million invocations
- FCM: Free unlimited messages

**Estimated usage for 1000 users with 10 announcements/day:**
- Functions: ~10 invocations/day = 300/month (well within free tier)
- FCM messages: 10,000/day = 300,000/month (free)

## Security Rules

Cloud Functions implement role-based security:
- Only authenticated users receive notifications (via topic subscription)
- Only admins can trigger resend (verified in Cloud Function)
- Firestore rules should restrict announcement creation to admins only

## Next Steps

1. **Deploy functions**: `cd functions && firebase deploy --only functions`
2. **Test notifications**: Create a test announcement as admin
3. **Monitor logs**: Check Firebase Console → Functions → Logs
4. **Iterate**: Adjust notification content, add images, custom sounds, etc.

## Advanced Features (Optional)

### Add Notification Images
Update Cloud Function payload:
```javascript
notification: {
  title: announcement.title,
  body: announcement.description,
  imageUrl: announcement.imageUrls?.[0], // First image if exists
}
```

### Add Custom Sound
Place sound file in `android/app/src/main/res/raw/` and reference:
```javascript
notification: {
  sound: 'notification_sound.mp3',
}
```

### Priority Levels
For emergency announcements:
```javascript
android: {
  priority: 'high',
},
apns: {
  headers: {
    'apns-priority': '10',
  },
},
```

## Support

If issues persist:
1. Check [Firebase Documentation](https://firebase.google.com/docs/cloud-messaging)
2. Review [Cloud Functions Logs](https://console.firebase.google.com/project/_/functions/logs)
3. Enable debug logging: `FirebaseMessaging.setAutoInitEnabled(true)`
