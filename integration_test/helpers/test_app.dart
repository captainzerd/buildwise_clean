import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:wysebrix/firebase_options.dart';
import 'package:wysebrix/wysebrix.dart';
import 'emulator_setup.dart';

/// Bootstrap the app in test mode, pointing Firebase at emulators.
Future<void> bootstrapTestApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await configureEmulators();
}

/// Returns the root widget for integration tests.
Widget testAppWidget() {
  return const WyseBrixApp(useCloud: true);
}
