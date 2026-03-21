// lib/core/services/app_version_service.dart
//
// Checks Firestore `config/app_version` on launch and resume.
// Emits one of three states:
//   - AppVersionState.current   → no action needed
//   - AppVersionState.nudge     → dismissible update banner
//   - AppVersionState.blocked   → non-dismissible hard gate
//
// Firestore document structure:
//   config/app_version {
//     min_version: "1.0.0",
//     recommended_version: "1.1.0",
//     store_url_android: "https://...",
//     store_url_ios: "https://...",
//     message: "Please update to continue."
//   }

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

enum AppVersionState { current, nudge, blocked }

class AppVersionConfig {
  const AppVersionConfig({
    required this.state,
    required this.storeUrl,
    required this.message,
  });
  final AppVersionState state;
  final String storeUrl;
  final String message;
}

class AppVersionService extends ChangeNotifier {
  AppVersionConfig _config = const AppVersionConfig(
    state: AppVersionState.current,
    storeUrl: '',
    message: '',
  );

  AppVersionConfig get config => _config;
  AppVersionState get state => _config.state;

  Future<void> check() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('config')
          .doc('app_version')
          .get();

      if (!snap.exists) return;
      final data = snap.data()!;

      final info = await PackageInfo.fromPlatform();
      final current = _parseVersion(info.version);
      final minVersion = _parseVersion(data['min_version'] as String? ?? '0.0.0');
      final recommended = _parseVersion(data['recommended_version'] as String? ?? '0.0.0');

      final storeUrl = Platform.isIOS
          ? (data['store_url_ios'] as String? ?? '')
          : (data['store_url_android'] as String? ?? '');
      final message = data['message'] as String? ??
          'A new version of WyseBrix is available.';

      AppVersionState newState;
      if (_isBelow(current, minVersion)) {
        newState = AppVersionState.blocked;
      } else if (_isBelow(current, recommended)) {
        newState = AppVersionState.nudge;
      } else {
        newState = AppVersionState.current;
      }

      _config = AppVersionConfig(
        state: newState,
        storeUrl: storeUrl,
        message: message,
      );
      notifyListeners();
    } catch (e) {
      // Version check failures must never crash the app.
      debugPrint('AppVersionService: check failed: $e');
    }
  }

  /// Parse "1.2.3" → [1, 2, 3]
  List<int> _parseVersion(String v) {
    final parts = v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts;
  }

  /// Returns true if [a] is strictly below [b].
  bool _isBelow(List<int> a, List<int> b) {
    for (int i = 0; i < 3; i++) {
      if (a[i] < b[i]) return true;
      if (a[i] > b[i]) return false;
    }
    return false;
  }
}
