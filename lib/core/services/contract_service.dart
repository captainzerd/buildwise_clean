import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/widgets.dart' show TableHelper;

import '../errors/app_exception.dart';
import '../models/builder_contract.dart';

class ContractService {
  final _db = FirebaseFirestore.instance;
  final _col = FirebaseFirestore.instance.collection('contracts');

  // ── Read ──

  /// Stream all contracts for a project visible to [currentUserUid].
  /// Filters by memberUids so the query aligns with the security rule
  /// (rule: request.auth.uid in resource.data.memberUids).
  Stream<List<BuilderContract>> contractsForProject(
    String projectId,
    String currentUserUid,
  ) {
    return _col
        .where('memberUids', arrayContains: currentUserUid)
        .where('projectId', isEqualTo: projectId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => BuilderContract.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  /// Stream of the most recent active/pending contract for a project.
  Stream<BuilderContract?> activeContractStream(
    String projectId,
    String currentUserUid,
  ) {
    return contractsForProject(projectId, currentUserUid).map(
      (list) => list.where((c) {
        return c.status == ContractStatus.pendingBuilder ||
            c.status == ContractStatus.active;
      }).firstOrNull,
    );
  }

  /// Stream all contracts where [uid] is a member (owner or builder).
  /// Used for portfolio-level analytics.
  Stream<List<BuilderContract>> contractsForMember(String uid) {
    return _col
        .where('memberUids', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => BuilderContract.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  /// Stream contracts pending this builder's signature.
  Stream<List<BuilderContract>> pendingForBuilder(String builderUid) {
    return _col
        .where('builderUid', isEqualTo: builderUid)
        .where('status', isEqualTo: ContractStatus.pendingBuilder.firestoreValue)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => BuilderContract.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  // ── Write ──

  /// Owner creates + signs a contract in one step (status: pendingBuilder).
  Future<String> createContract(BuilderContract contract) async {
    try {
      final ref = _col.doc();
      await ref.set(contract.toMap());
      return ref.id;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Builder accepts: signs contract and assigns themselves to the project.
  Future<void> builderAccept({
    required BuilderContract contract,
    required String signatureName,
  }) async {
    try {
      final now = DateTime.now();
      final batch = _db.batch();

      // Update contract
      batch.update(_col.doc(contract.id), {
        'status': ContractStatus.active.firestoreValue,
        'builderSignatureName': signatureName,
        'builderSignedAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      // Assign builder to project
      batch.update(
        _db.collection('projects').doc(contract.projectId),
        {
          'assignedPmUid': contract.builderUid,
          'assignedPmName': contract.builderName,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Builder declines the contract.
  Future<void> builderDecline(String contractId) async {
    try {
      await _col.doc(contractId).update({
        'status': ContractStatus.declined.firestoreValue,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Toggle a milestone to paid. Uses a transaction to avoid race conditions.
  Future<void> markMilestonePaid(
    String contractId,
    String milestoneId,
  ) =>
      _toggleMilestone(contractId, milestoneId, paid: true);

  /// Toggle a milestone back to unpaid.
  Future<void> unmarkMilestonePaid(
    String contractId,
    String milestoneId,
  ) =>
      _toggleMilestone(contractId, milestoneId, paid: false);

  Future<void> _toggleMilestone(
    String contractId,
    String milestoneId, {
    required bool paid,
  }) async {
    try {
      final ref = _col.doc(contractId);
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final data = snap.data() ?? {};
        final rawList = (data['milestones'] as List?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        final updated = rawList.map((m) {
          if ((m['id'] as String? ?? '') != milestoneId) return m;
          return {
            ...m,
            'isPaid': paid,
            if (paid) 'paidAt': Timestamp.fromDate(DateTime.now()),
            if (!paid) 'paidAt': null,
          };
        }).toList();
        // Remove null paidAt entries
        final cleaned = updated.map((m) {
          final copy = Map<String, dynamic>.from(m);
          if (copy['paidAt'] == null) copy.remove('paidAt');
          return copy;
        }).toList();
        tx.update(ref, {
          'milestones': cleaned,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Builder requests payment release for a milestone.
  Future<void> requestMilestoneRelease(
    String contractId,
    String milestoneId,
  ) async {
    try {
      final ref = _col.doc(contractId);
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final rawList = ((snap.data() ?? {})['milestones'] as List?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        final updated = rawList.map((m) {
          if ((m['id'] as String?) != milestoneId) return m;
          return {
            ...m,
            'approvalStatus':
                MilestoneApprovalStatus.pendingRelease.firestoreValue,
          };
        }).toList();
        tx.update(ref, {
          'milestones': updated,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Owner releases (approves) a milestone payment.
  Future<void> releaseMilestonePayment(
    String contractId,
    String milestoneId,
    String releasedByName,
  ) async {
    try {
      final ref = _col.doc(contractId);
      final now = DateTime.now();
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final rawList = ((snap.data() ?? {})['milestones'] as List?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        final updated = rawList.map((m) {
          if ((m['id'] as String?) != milestoneId) return m;
          return {
            ...m,
            'approvalStatus':
                MilestoneApprovalStatus.released.firestoreValue,
            'releasedAt': Timestamp.fromDate(now),
            'releasedByName': releasedByName,
            'isPaid': true,
            'paidAt': Timestamp.fromDate(now),
          };
        }).toList();
        tx.update(ref, {
          'milestones': updated,
          'updatedAt': Timestamp.fromDate(now),
        });
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Owner releases the retention amount.
  Future<void> releaseRetention(String contractId) async {
    try {
      await _col.doc(contractId).update({
        'retentionReleasedAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Owner cancels a pending contract.
  Future<void> ownerCancel(String contractId) async {
    try {
      await _col.doc(contractId).update({
        'status': ContractStatus.cancelled.firestoreValue,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Builder signs with a drawn signature (PNG bytes).
  ///
  /// Steps:
  ///  1. Generate a signed-contract PDF embedding the signature image.
  ///  2. Upload the PDF to Storage at `contracts/{id}/signed_contract.pdf`.
  ///  3. Update Firestore with status=active, builderSignatureName,
  ///     builderSignedAt, signedPdfUrl; also assigns builder to project.
  Future<void> uploadSignatureAndSign({
    required BuilderContract contract,
    required String signerName,
    required Uint8List signaturePng,
  }) async {
    try {
      // 1. Build PDF
      final pdf = pw.Document();
      final sigImage = pw.MemoryImage(signaturePng);
      final fmt = NumberFormat('#,##0.00');
      final now = DateTime.now();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (ctx) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Digital Construction Contract',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text('Project: ${contract.projectTitle}'),
            pw.Text('Owner UID: ${contract.ownerUid}'),
            pw.Text('Builder: ${contract.builderName}'),
            if (contract.startDate != null)
              pw.Text(
                'Start: ${DateFormat('d MMM yyyy').format(contract.startDate!)}',
              ),
            if (contract.endDate != null)
              pw.Text(
                'End: ${DateFormat('d MMM yyyy').format(contract.endDate!)}',
              ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Total Amount: GHS ${fmt.format(contract.totalAmountGhs)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Header(level: 1, child: pw.Text('Scope of Work')),
            pw.Text(contract.scope),
            if (contract.milestones.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              pw.Header(level: 1, child: pw.Text('Payment Milestones')),
              TableHelper.fromTextArray(
                headers: ['Description', 'Amount (GHS)'],
                data: contract.milestones
                    .map(
                      (m) => [m.description, fmt.format(m.amountGhs)],
                    )
                    .toList(),
              ),
            ],
            pw.SizedBox(height: 24),
            pw.Header(level: 1, child: pw.Text('Owner Signature')),
            pw.Text('Signed by: ${contract.ownerSignatureName}'),
            pw.Text(
              'Date: ${DateFormat('d MMM yyyy').format(contract.ownerSignedAt)}',
            ),
            pw.SizedBox(height: 24),
            pw.Header(level: 1, child: pw.Text('Builder Signature')),
            pw.Text('Signed by: $signerName'),
            pw.Text(
              'Date: ${DateFormat('d MMM yyyy').format(now)}',
            ),
            pw.SizedBox(height: 8),
            pw.Image(sigImage, width: 200, height: 80, fit: pw.BoxFit.contain),
          ],
        ),
      );

      final pdfBytes = await pdf.save();

      // 2. Upload to Storage
      final storageRef = FirebaseStorage.instance
          .ref('contracts/${contract.id}/signed_contract.pdf');
      await storageRef.putData(
        pdfBytes,
        SettableMetadata(contentType: 'application/pdf'),
      );
      final downloadUrl = await storageRef.getDownloadURL();

      // 3. Update Firestore
      final batch = _db.batch();
      batch.update(_col.doc(contract.id), {
        'status': ContractStatus.active.firestoreValue,
        'builderSignatureName': signerName,
        'builderSignedAt': Timestamp.fromDate(now),
        'signedPdfUrl': downloadUrl,
        'updatedAt': Timestamp.fromDate(now),
      });
      batch.update(
        _db.collection('projects').doc(contract.projectId),
        {
          'assignedPmUid': contract.builderUid,
          'assignedPmName': contract.builderName,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
      await batch.commit();
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
