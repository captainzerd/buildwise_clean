import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../errors/app_exception.dart';
import '../models/builder_profile.dart';

class BuilderProfileService extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;

  // ── Read ──

  /// Live stream of a single builder profile (own or another user's).
  Stream<BuilderProfile?> profileStream(String uid) {
    return _db
        .collection('pm_profiles')
        .doc(uid)
        .withConverter<BuilderProfile?>(
          fromFirestore: (s, _) =>
              s.exists ? BuilderProfile.fromDoc(s) : null,
          toFirestore: (_, __) => {},
        )
        .snapshots()
        .map((s) => s.data());
  }

  /// Stream of all active builder profiles, sorted by rating descending.
  Stream<List<BuilderProfile>> listActive() {
    return _db
        .collection('pm_profiles')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => BuilderProfile.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList()
            ..sort((a, b) => b.averageRating.compareTo(a.averageRating)),
        );
  }

  // ── Write ──

  /// Create or fully overwrite a builder profile doc (upsert).
  Future<void> createOrUpdate(BuilderProfile profile) async {
    try {
      await _db
          .collection('pm_profiles')
          .doc(profile.uid)
          .set(profile.toMap(), SetOptions(merge: true));
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Submit a review. Updates averageRating and reviewCount atomically.
  Future<void> addReview({
    required String builderUid,
    required String reviewerUid,
    required double rating,
    String comment = '',
  }) async {
    try {
      final profileRef = _db.collection('pm_profiles').doc(builderUid);
      final reviewRef = profileRef.collection('reviews').doc(reviewerUid);

      await _db.runTransaction((tx) async {
        final snap = await tx.get(profileRef);
        final d = snap.data() ?? {};
        final count = (d['reviewCount'] as num?)?.toInt() ?? 0;
        final avg = (d['averageRating'] as num?)?.toDouble() ?? 0.0;

        final newCount = count + 1;
        final newAvg = ((avg * count) + rating) / newCount;

        tx.set(reviewRef, {
          'reviewerUid': reviewerUid,
          'rating': rating,
          'comment': comment,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.update(profileRef, {
          'reviewCount': newCount,
          'averageRating': newAvg,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      debugPrint('BuilderProfileService.addReview error: $e');
      throw AppException.from(e);
    }
  }
}
