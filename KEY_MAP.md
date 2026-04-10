# UNIMAS SmartBus Key Map

Last updated: 2026-04-11

## Active Key Assignments

### 1) Android App Map Key
- Key label: Map Functions (New)
- Key value suffix: ...jESek
- Full key starts with: AIzaSyCsy...
- Project: UNIMAS SmartBus
- Intended use: Android map rendering in app
- Restriction model: Android apps
- API scope: Maps SDK for Android (and only app-side APIs you need)
- Local config location: android/local.properties
- Variable: GOOGLE_MAPS_API_KEY

### 2) Cloud Functions Places Key
- Key label: Places API (New)
- Key value suffix: ...uxJq8
- Full key starts with: AIzaSyAwNW...
- Project: UNIMAS SmartBus
- Intended use: server-side Places API (New) calls in Firebase Functions
- Restriction model: None (application restriction)
- API scope: Places API (New)
- Local config location: functions/.env.unimas-smartbus
- Variable: GOOGLE_MAPS_API_KEY

### 3) Legacy Key (Retired)
- Key label: Maps API (Old)
- Key value suffix: ...2sa2A
- Status: Do not use in active config

## Current File Mapping (This Workspace)

- android/local.properties -> AIzaSyCsy...jESek
- functions/.env.unimas-smartbus -> AIzaSyAwNW...uxJq8

## Why Two Keys Are Required

- Android-restricted keys cannot be used by server-side HTTP requests.
- Places API (New) calls from Cloud Functions require a server-side key that is not Android-app restricted.

## Second Device Sync Steps

1. Set android/local.properties GOOGLE_MAPS_API_KEY to AIzaSyCsy...jESek.
2. Set functions/.env.unimas-smartbus GOOGLE_MAPS_API_KEY to AIzaSyAwNW...uxJq8.
3. Deploy backend after updating env:

   firebase.cmd deploy --only functions:placesAutocompleteNew,functions:searchPlaceCoordinatesNew --project unimas-smartbus --force --non-interactive

## Security Notes

- Do not commit real secrets to source control.
- If any key is exposed publicly, rotate it and update this map.
- Keep key roles separate (app key vs server key) to avoid API_KEY_ANDROID_APP_BLOCKED errors.