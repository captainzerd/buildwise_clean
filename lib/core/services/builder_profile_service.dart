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

  /// Stream of verified builder profiles (isVerified == true),
  /// sorted by trustScore descending.
  Stream<List<BuilderProfile>> verifiedBuildersStream() {
    return _db
        .collection('pm_profiles')
        .where('isVerified', isEqualTo: true)
        .limit(200)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => BuilderProfile.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList()
            ..sort((a, b) => b.trustScore.compareTo(a.trustScore)),
        );
  }

  /// Stream of all active builder profiles, sorted by trustScore descending.
  Stream<List<BuilderProfile>> listActive() {
    return _db
        .collection('pm_profiles')
        .where('isActive', isEqualTo: true)
        .limit(200)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => BuilderProfile.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList()
            ..sort((a, b) => b.trustScore.compareTo(a.trustScore)),
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

  /// Submit a 5-dimension review. All 5 scores required (1–5).
  /// Overall rating = average of the 5 dimensions.
  /// Automatically updates trustScore and reputation scores after write.
  Future<void> addReview({
    required String builderUid,
    required String reviewerUid,
    required double quality,
    required double timeliness,
    required double communication,
    required double value,
    required double safety,
    String comment = '',
  }) async {
    final overallRating =
        (quality + timeliness + communication + value + safety) / 5.0;
    try {
      final profileRef = _db.collection('pm_profiles').doc(builderUid);
      final reviewRef = profileRef.collection('reviews').doc(reviewerUid);

      await _db.runTransaction((tx) async {
        final snap = await tx.get(profileRef);
        final d = snap.data() ?? {};
        final count = (d['reviewCount'] as num?)?.toInt() ?? 0;
        final avg = (d['averageRating'] as num?)?.toDouble() ?? 0.0;

        final newCount = count + 1;
        final newAvg = ((avg * count) + overallRating) / newCount;

        tx.set(reviewRef, {
          'reviewerUid': reviewerUid,
          'rating': overallRating,
          'quality': quality,
          'timeliness': timeliness,
          'communication': communication,
          'value': value,
          'safety': safety,
          'comment': comment,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.update(profileRef, {
          'reviewCount': newCount,
          'averageRating': newAvg,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      // Recompute trust + reputation scores after review is committed
      await updateTrustScore(builderUid);
    } catch (e) {
      debugPrint('BuilderProfileService.addReview error: $e');
      throw AppException.from(e);
    }
  }

  /// Recomputes and writes the trust score for [builderUid].
  ///
  /// Breakdown (100 pts total — Ghana-specific):
  ///   - ID verified (users.idVerificationStatus == 'verified')        → +15
  ///   - Business registered (businessRegStatus == 'verified')          → +10
  ///   - NCA / Licence verified (licenceVerificationStatus == 'verified')→ +20
  ///   - Insurance valid & not expired (insuranceStatus == 'verified')  → +15
  ///   - (averageRating / 5) × 20                                       → max +20
  ///   - min(reviewCount, 10) × 1                                       → max +10
  ///   - min(projectsCompleted, 5) × 1                                  → max +5
  ///   - Profile completeness (bio+phone+photo+region)                  → +5
  ///
  /// Also computes projectSuccessScore and safetyComplianceScore from
  /// average timeliness and safety review dimensions respectively.
  Future<void> updateTrustScore(String builderUid) async {
    try {
      final profileSnap =
          await _db.collection('pm_profiles').doc(builderUid).get();
      if (!profileSnap.exists) return;

      final d = profileSnap.data() ?? {};
      final userSnap =
          await _db.collection('users').doc(builderUid).get();
      final ud = userSnap.data() ?? {};

      int score = 0;

      // 1. ID verified (+15)
      if ((ud['idVerificationStatus'] as String?) == 'verified') score += 15;

      // 2. Business registration verified (+10)
      if ((d['businessRegStatus'] as String?) == 'verified') score += 10;

      // 3. NCA / Licence verified (+20)
      if ((d['licenceVerificationStatus'] as String?) == 'verified') {
        score += 20;
      }

      // 4. Insurance valid (+15) — must be verified AND not expired
      final insStatus = d['insuranceStatus'] as String? ?? 'unverified';
      if (insStatus == 'verified') {
        final pliExpiry =
            (d['insurancePliExpiry'] as Timestamp?)?.toDate();
        final expired =
            pliExpiry != null && pliExpiry.isBefore(DateTime.now());
        if (!expired) score += 15;
      }

      // 5. Rating score (max +20)
      final avg = (d['averageRating'] as num?)?.toDouble() ?? 0.0;
      score += ((avg / 5.0) * 20).round();

      // 6. Review count (max +10)
      final reviewCount = (d['reviewCount'] as num?)?.toInt() ?? 0;
      score += reviewCount.clamp(0, 10);

      // 7. Projects completed (max +5)
      final projects = (d['projectsCompleted'] as num?)?.toInt() ?? 0;
      score += projects.clamp(0, 5);

      // 8. Profile completeness (+5)
      final hasBio = (d['bio'] as String?)?.isNotEmpty == true;
      final hasPhone = d['phone'] != null;
      final hasPhoto = d['photoUrl'] != null;
      final hasRegion = (d['region'] as String?)?.isNotEmpty == true;
      if (hasBio && hasPhone && hasPhoto && hasRegion) score += 5;

      score = score.clamp(0, 100);

      // ── Compute reputation scores from reviews ──
      double projectSuccessScore = 0.0;
      double safetyComplianceScore = 0.0;

      if (reviewCount > 0) {
        final reviewsSnap = await _db
            .collection('pm_profiles')
            .doc(builderUid)
            .collection('reviews')
            .get();

        if (reviewsSnap.docs.isNotEmpty) {
          double totalTimeliness = 0;
          double totalSafety = 0;
          for (final r in reviewsSnap.docs) {
            final rd = r.data();
            totalTimeliness +=
                (rd['timeliness'] as num?)?.toDouble() ?? 0.0;
            totalSafety += (rd['safety'] as num?)?.toDouble() ?? 0.0;
          }
          final count = reviewsSnap.docs.length;
          projectSuccessScore =
              ((totalTimeliness / count) / 5.0 * 100).clamp(0, 100);
          safetyComplianceScore =
              ((totalSafety / count) / 5.0 * 100).clamp(0, 100);
        }
      }

      // Write to both pm_profiles and users docs
      await _db.collection('pm_profiles').doc(builderUid).update({
        'trustScore': score,
        'projectSuccessScore': projectSuccessScore,
        'safetyComplianceScore': safetyComplianceScore,
      });
      await _db
          .collection('users')
          .doc(builderUid)
          .update({'trustScore': score});
    } catch (e) {
      debugPrint('BuilderProfileService.updateTrustScore: $e');
    }
  }
}
