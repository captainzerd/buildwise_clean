// lib/core/services/telemetry.dart
import 'logger_service.dart';

class Telemetry {
  Telemetry({this.enabled = true});

  /// Singleton used by some call-sites (e.g., Telemetry.I.logEvent(...))
  static final Telemetry I = Telemetry();

  final bool enabled;

  Future<void> logEvent(String name, {Map<String, Object?>? params}) async {
    if (!enabled) return;
    // Hook Firebase later; keep analyzer happy and side-effect minimal.
    LoggerService.info('[telemetry] $name ${params ?? {}}');
  }
}
