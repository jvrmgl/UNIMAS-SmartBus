# Firebase Security Rules Setup

## Issue
You're getting `PERMISSION_DENIED` error when trying to update bus occupancy (tap in/tap out).

## Solution

### 1. Update Firestore Security Rules

Go to **Firebase Console → Firestore Database → Rules** and replace with:

```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users collection
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Buses collection - Allow anyone to update occupancy (tap in/out)
    match /buses/{busId} {
      allow read: if true; // Anyone can read bus data
      allow create, delete: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
      allow update: if true; // Anyone can update occupancy (for tap in/out)
    }
    
    // Routes collection
    match /routes/{routeId} {
      allow read: if true; // Anyone can read
      allow write: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Bus stops collection
    match /bus_stops/{stopId} {
      allow read: if true; // Anyone can read
      allow write: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Schedules collection
    match /schedules/{scheduleId} {
      allow read: if true; // Anyone can read
      allow write: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['admin', 'driver'];
    }
    
    // Trips collection
    match /trips/{tripId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['admin', 'driver'];
    }
    
    // Reports collection
    match /reports/{reportId} {
      allow read: if request.auth != null;
      allow create: if true; // Anyone can create reports (anonymous users)
      allow update, delete: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Announcements collection
    match /announcements/{announcementId} {
      allow read: if true; // Anyone can read
      allow write: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
  }
}
```

### 2. Click "Publish" to apply the rules

### 3. Test the tap in/out functionality again

## Why This Fixes the Issue

The original rules likely had:
```javascript
allow write: if false;
```

The new rules allow:
- ✅ **Anyone** to read bus, route, and stop data
- ✅ **Anyone** to update bus occupancy (tap in/out) - including guests/students
- ✅ **Admins** to manage all data (create/delete buses, routes, etc.)
- ✅ **Drivers** to manage trips and schedules
- ✅ **Anyone** to create reports (anonymous)

## Security Notes

These rules are designed for your app where **Guests = Students**:
1. ✅ Anyone can tap in/out (no login required for basic usage)
2. ✅ Admin-only operations are restricted by role (create/delete buses, routes)
3. ✅ Students/guests can update bus occupancy without authentication
4. ✅ Only admins can create/delete core data (buses, routes, stops)
5. ✅ Only drivers and admins can manage trips and schedules

**Trade-off**: Allowing unauthenticated updates means anyone can tap in/out. This is acceptable if:
- You trust your user base (campus environment)
- Occupancy is approximate (not critical data)
- Convenience > strict authentication

If you need more security in the future, you can add validation rules to prevent abuse (e.g., rate limiting, occupancy bounds).

## Alternative (For Testing Only)

If you want to allow ALL operations during development:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

⚠️ **WARNING**: Do NOT use this in production! It allows anyone to read/write/delete all your data.
