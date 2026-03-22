// lib/core/utils/permission_handler.dart
//
// Handles camera and location permission requests with graceful degradation.
// Camera denied → show SnackBar with "Open Settings" button.
// Location denied → silently omit (location is supplementary, never blocks upload).

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class AppPermissionHandler {
  AppPermissionHandler._();

  /// Requests camera permission. Returns true if granted.
  /// If permanently denied, shows a SnackBar with an "Open Settings" button.
  static Future<bool> requestCamera(BuildContext context) async {
    final status = await Permission.camera.request();
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied && context.mounted) {
      _showSettingsPrompt(context, 'Camera');
    }
    return false;
  }

  /// Requests location permission. Returns true if granted.
  /// Never shows an error — location is best-effort and never blocks the user.
  static Future<bool> requestLocation(BuildContext context) async {
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  /// Shows a SnackBar informing the user that [permissionName] is required,
  /// with an "Open Settings" action that deep-links to the app settings page.
  static void _showSettingsPrompt(BuildContext context, String permissionName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$permissionName access is required. Please enable it in Settings.',
        ),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Open Settings',
          onPressed: openAppSettings,
        ),
      ),
    );
  }
}
