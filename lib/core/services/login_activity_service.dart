import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/login_activity.dart';

/// Read-only service for `users/{uid}/login_activity`.
class LoginActivityService {
  final _db = FirebaseFirestore.instance;

  /// Stream of up to [limit] most-recent login events.
  Stream<List<LoginActivity>> streamLoginActivity(
    String uid, {
    int limit = 20,
  }) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('login_activity')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => LoginActivity.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }
}
