// lib/core/services/telemetry.dart
import 'package:flutter/foundation.dart';

class Telemetry {
  Telemetry({this.enabled = true});

  /// Singleton used by some call-sites (e.g., Telemetry.I.logEvent(...))
  static final Telemetry I = Telemetry();

  final bool enabled;

  Future<void> logEvent(String name, {Map<String, Object?>? params}) async {
    if (!enabled) return;
    // Hook Firebase later; keep analyzer happy and side-effect minimal.
    debugPrint('[telemetry] $name ${params ?? {}}');
  }
}
