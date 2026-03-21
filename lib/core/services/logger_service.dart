// lib/core/services/logger_service.dart
//
// Structured logger wrapping Sentry. In debug mode prints to console.
// In release mode sends events to Sentry for production observability.
//
// Usage:
//   LoggerService.warning('Sync retry', error: e, stackTrace: st);
//   LoggerService.error('Payment failed', error: e, stackTrace: st);

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class LoggerService {
  LoggerService._();

  static void info(String message, {Map<String, dynamic>? extras}) {
    if (kDebugMode) {
      debugPrint('[INFO] $message');
      return;
    }
    Sentry.addBreadcrumb(
      Breadcrumb(
        message: message,
        level: SentryLevel.info,
        data: extras,
      ),
    );
  }

  static void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extras,
  }) {
    if (kDebugMode) {
      debugPrint('[WARN] $message${error != null ? ': $error' : ''}');
      return;
    }
    Sentry.captureMessage(
      message,
      level: SentryLevel.warning,
      hint: extras != null ? Hint.withMap(extras.map((k, v) => MapEntry(k, v))) : null,
    );
    if (error != null) {
      Sentry.captureException(error, stackTrace: stackTrace);
    }
  }

  static void error(
    String message, {
    required Object error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extras,
  }) {
    if (kDebugMode) {
      debugPrint('[ERROR] $message: $error');
      if (stackTrace != null) debugPrint(stackTrace.toString());
      return;
    }
    Sentry.captureException(
      error,
      stackTrace: stackTrace,
      hint: extras != null ? Hint.withMap(extras.map((k, v) => MapEntry(k, v))) : null,
    );
  }

  static void fatal(
    String message, {
    required Object error,
    StackTrace? stackTrace,
  }) {
    if (kDebugMode) {
      debugPrint('[FATAL] $message: $error');
      if (stackTrace != null) debugPrint(stackTrace.toString());
      return;
    }
    Sentry.captureException(
      error,
      stackTrace: stackTrace,
      hint: Hint.withMap({'level': 'fatal', 'message': message}),
    );
  }
}
