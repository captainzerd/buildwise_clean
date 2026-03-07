# WyseBrix

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Flavours

WyseBrix ships three flavours: **dev**, **staging**, and **prod**.

### Running a flavour

| Flavour | Command |
|---------|---------|
| Dev (default) | `flutter run -t lib/main_dev.dart` |
| Staging | `flutter run --dart-define=ENV=staging -t lib/main_staging.dart` |
| Prod | `flutter run --dart-define=ENV=prod -t lib/main_prod.dart` |

Build examples:
```bash
flutter build apk --dart-define=ENV=staging -t lib/main_staging.dart
flutter build apk --dart-define=ENV=prod    -t lib/main_prod.dart
```

### Firebase config files

Place the real Firebase config files here (they are gitignored — never commit secrets):

| Platform | Dev | Staging | Prod |
|----------|-----|---------|------|
| Android | `android/app/src/dev/google-services.json` | `android/app/src/staging/google-services.json` | `android/app/google-services.json` |
| iOS | `ios/Firebase/Dev/GoogleService-Info.plist` | `ios/Firebase/Staging/GoogleService-Info.plist` | `ios/Runner/GoogleService-Info.plist` |

The placeholder files in `android/app/src/dev/`, `android/app/src/staging/`, `ios/Firebase/Dev/`, and `ios/Firebase/Staging/` contain `TODO` markers — replace them with the real files from the Firebase console for each project.
