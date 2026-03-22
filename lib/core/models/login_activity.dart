import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Stored at `users/{uid}/login_activity/{id}`.
@immutable
class LoginActivity {
  const LoginActivity({
    required this.id,
    required this.timestamp,
    required this.platform,
    required this.signInMethod,
    this.deviceModel,
  });

  final String id;
  final DateTime timestamp;
  /// 'android' | 'ios' | 'web' | 'other'
  final String platform;
  /// 'email' | 'google' | 'phone' | 'other'
  final String signInMethod;
  final String? deviceModel;

  factory LoginActivity.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return LoginActivity(
      id: doc.id,
      timestamp:
          (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      platform: d['platform'] as String? ?? 'other',
      signInMethod: d['signInMethod'] as String? ?? 'email',
      deviceModel: d['deviceModel'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'timestamp': Timestamp.fromDate(timestamp),
        'platform': platform,
        'signInMethod': signInMethod,
        if (deviceModel != null) 'deviceModel': deviceModel,
      };
}
