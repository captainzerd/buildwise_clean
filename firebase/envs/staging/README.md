# Staging Firebase Config

Files in this directory are injected by CI from GitHub Secrets.
Never commit actual config files here.

## Files needed:
- `google-services.json` — from Firebase Console: wysebrix-staging project → Android app
- `GoogleService-Info.plist` — from Firebase Console: wysebrix-staging project → iOS app

## GitHub Secrets required:
- `GOOGLE_SERVICES_JSON_STAGING` — raw google-services.json content
- `GOOGLE_SERVICES_PLIST_STAGING` — raw GoogleService-Info.plist content
- `FIREBASE_TOKEN_STAGING` — firebase login:ci token for wysebrix-staging

## Setup steps:
1. Create a new Firebase project named `wysebrix-staging`
2. Add Android app (package: com.wysebrix.app) — download google-services.json
3. Add iOS app (bundle: com.wysebrix.app) — download GoogleService-Info.plist
4. In GitHub repo Settings → Secrets and variables → Actions:
   - Add GOOGLE_SERVICES_JSON_STAGING with the JSON content
   - Add GOOGLE_SERVICES_PLIST_STAGING with the plist content
5. Set up Firestore, Auth, Storage in wysebrix-staging with same config as prod
6. Deploy firestore.rules to staging: firebase use wysebrix-staging && firebase deploy --only firestore
