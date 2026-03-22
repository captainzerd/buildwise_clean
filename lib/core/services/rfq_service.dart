// lib/core/services/rfq_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../errors/app_exception.dart';
import '../models/rfq_request.dart';

class RfqService {
  final _col = FirebaseFirestore.instance.collection('rfq_requests');

  /// Stream all RFQs for a project (owner view).
  Stream<List<RfqRequest>> ownerRfqsStream(String projectId) {
    return _col
        .where('projectId', isEqualTo: projectId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => RfqRequest.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  /// Stream all RFQs sent to a vendor (vendor inbox).
  Stream<List<RfqRequest>> vendorRfqsStream(String vendorId) {
    return _col
        .where('vendorId', isEqualTo: vendorId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => RfqRequest.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  /// Create a new RFQ. Returns the new doc ID.
  Future<String> createRfq(RfqRequest rfq) async {
    try {
      final ref = _col.doc();
      await ref.set(rfq.toMap());
      return ref.id;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Owner accepts a responded RFQ.
  Future<void> acceptRfq(String rfqId) async {
    try {
      await _col.doc(rfqId).update({
        'status': RfqStatus.accepted.firestoreValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Owner declines a responded RFQ.
  Future<void> declineRfq(String rfqId) async {
    try {
      await _col.doc(rfqId).update({
        'status': RfqStatus.declined.firestoreValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Vendor responds to an RFQ with text and optional amount.
  Future<void> respondToRfq(
    String rfqId, {
    required String responseText,
    double? quotedAmountGhs,
  }) async {
    try {
      await _col.doc(rfqId).update({
        'status': RfqStatus.responded.firestoreValue,
        'responseText': responseText,
        if (quotedAmountGhs != null) 'quotedAmountGhs': quotedAmountGhs,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
