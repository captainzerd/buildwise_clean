import 'package:flutter/material.dart';
import 'package:wysebrix/wysebrix.dart';
import 'emulator_setup.dart';

/// Bootstrap the app in test mode, pointing Firebase at emulators.
Future<void> bootstrapTestApp() async {
  await configureEmulators();
}

/// Returns the root widget for integration tests.
Widget testAppWidget() {
  return const WyseBrixApp(useCloud: true);
}
