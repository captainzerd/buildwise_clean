# Production Firebase Config

Files in this directory are injected by CI from GitHub Secrets.
Never commit actual config files here.

## Project ID: building-estimator (permanent — cannot be renamed)
## Display name: Update to "WyseBrix Production" in Firebase Console → Project Settings → General

## Files needed:
- `google-services.json` — from Firebase Console: building-estimator → Android app
- `GoogleService-Info.plist` — from Firebase Console: building-estimator → iOS app

## GitHub Secrets required:
- `GOOGLE_SERVICES_JSON_PROD` — raw google-services.json content
- `GOOGLE_SERVICES_PLIST_PROD` — raw GoogleService-Info.plist content
- `FIREBASE_TOKEN_PROD` — firebase login:ci token for building-estimator
- `FIREBASE_TOKEN_STAGING` — firebase login:ci token for wysebrix-staging
