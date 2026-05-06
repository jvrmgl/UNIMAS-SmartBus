# UNIMAS SmartBus Key Map

Last updated: 2026-05-06

## Active Key Assignments

### 1) Unified Maps + Web Services Key
- Key label: Map Functions (New)
- Key value suffix: ...jESek
- Full key starts with: AIzaSyCsy...
- Project: UNIMAS SmartBus
- Intended use: map rendering + Directions/Places/Geocoding HTTP calls + Cloud Functions
- Restriction model: None (application restriction)
- API scope: Maps SDK for Android/iOS, Directions API, Places API (New), Geocoding API
- Local config locations: android/local.properties, env.json, functions/.env.unimas-smartbus
- Variable: GOOGLE_MAPS_API_KEY

### 2) Legacy Key (Retired)
- Key label: Places API (New)
- Key value suffix: ...uxJq8
- Full key starts with: AIzaSyAwNW...
- Status: Deprecated (safe to delete if unified key works everywhere)

### 3) Legacy Key (Retired)
- Key label: Maps API (Old)
- Key value suffix: ...2sa2A
- Status: Do not use in active config

## Current File Mapping (This Workspace)

- android/local.properties -> AIzaSyCsy...jESek
- env.json -> AIzaSyCsy...jESek
- functions/.env.unimas-smartbus -> AIzaSyCsy...jESek

## Why Teams Sometimes Split Keys

- Android/iOS SDK keys can be app-restricted, which blocks HTTP web services.
- Separate keys let you isolate quota and apply least-privilege restrictions.

## Second Device Sync Steps

1. Set android/local.properties GOOGLE_MAPS_API_KEY to AIzaSyCsy...jESek.
2. Set env.json GOOGLE_MAPS_API_KEY to AIzaSyCsy...jESek.
3. Set functions/.env.unimas-smartbus GOOGLE_MAPS_API_KEY to AIzaSyCsy...jESek.
4. Deploy backend after updating env:

   firebase.cmd deploy --only functions:placesAutocompleteNew,functions:searchPlaceCoordinatesNew --project unimas-smartbus --force --non-interactive

## Security Notes

- Do not commit real secrets to source control.
- If any key is exposed publicly, rotate it and update this map.
- If you re-add restrictions later, consider splitting keys again.