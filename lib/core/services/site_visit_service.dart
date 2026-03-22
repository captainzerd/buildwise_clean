// lib/core/services/site_visit_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../errors/app_exception.dart';
import '../models/site_visit.dart';

class SiteVisitService extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String projectId) => _db
      .collection('projects')
      .doc(projectId)
      .collection('site_visits');

  Stream<List<SiteVisit>> visitsStream(String projectId) {
    return _col(projectId)
        .orderBy('scheduledAt', descending: false)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => SiteVisit.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  Future<void> scheduleVisit(SiteVisit visit) async {
    try {
      final ref = _col(visit.projectId).doc();
      await ref.set(
        SiteVisit(
          id: ref.id,
          projectId: visit.projectId,
          scheduledByUid: visit.scheduledByUid,
          scheduledByName: visit.scheduledByName,
          scheduledAt: visit.scheduledAt,
          purpose: visit.purpose,
          status: VisitStatus.scheduled,
          notes: visit.notes,
          createdAt: DateTime.now(),
        ).toMap(),
      );
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> markCompleted(
    String projectId,
    String visitId, {
    String? notes,
  }) async {
    try {
      await _col(projectId).doc(visitId).update({
        'status': VisitStatus.completed.firestoreValue,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> cancelVisit(String projectId, String visitId) async {
    try {
      await _col(projectId).doc(visitId).update({
        'status': VisitStatus.cancelled.firestoreValue,
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
