// lib/core/services/risk_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/risk_item.dart';

class RiskService {
  final _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> _col(String projectId) =>
      _db.collection('projects').doc(projectId).collection('risks');

  /// Stream all risks for a project, ordered by risk score desc.
  Stream<List<RiskItem>> risksStream(String projectId) {
    return _col(projectId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => RiskItem.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList()
            ..sort((a, b) => b.riskScore.compareTo(a.riskScore)),
        );
  }

  /// Stream the count of open high/critical risks (score >= 9, status == open).
  Stream<int> openHighRiskCountStream(String projectId) {
    return _col(projectId)
        .where('status', isEqualTo: 'open')
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => RiskItem.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .where((r) => r.riskScore >= 9)
              .length,
        );
  }

  Future<String> addRisk(String projectId, RiskItem risk) async {
    final id = _uuid.v4();
    final data = risk.toMap()
      ..['projectId'] = projectId
      ..['createdAt'] = FieldValue.serverTimestamp();
    await _col(projectId).doc(id).set(data);
    return id;
  }

  Future<void> updateRisk(
    String projectId,
    String riskId,
    Map<String, dynamic> fields,
  ) async {
    await _col(projectId).doc(riskId).update(fields);
  }

  Future<void> deleteRisk(String projectId, String riskId) async {
    await _col(projectId).doc(riskId).delete();
  }
}
