// lib/core/services/project_service.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../errors/app_exception.dart';
import '../models/cost_entry.dart';
import '../models/phase.dart';
import '../models/project.dart';
import '../models/project_document.dart';
import '../models/project_update.dart';

class ProjectService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  // ── Projects ──

  /// Stream of all projects owned by [ownerUid], newest first.
  Stream<List<Project>> projectsForOwner(String ownerUid) {
    return _db
        .collection('projects')
        .where('ownerUid', isEqualTo: ownerUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => Project.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  /// Stream of all projects assigned to [builderUid], newest first.
  /// Uses the `assignedPmUid + createdAt` composite index.
  Stream<List<Project>> projectsForBuilder(String builderUid) {
    return _db
        .collection('projects')
        .where('assignedPmUid', isEqualTo: builderUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => Project.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  /// Stream of a single project doc.
  Stream<Project?> projectStream(String projectId) {
    return _db
        .collection('projects')
        .doc(projectId)
        .withConverter<Project?>(
          fromFirestore: (s, _) => s.exists ? Project.fromDoc(s) : null,
          toFirestore: (_, __) => {},
        )
        .snapshots()
        .map((s) => s.data());
  }

  /// Create a new project. Returns the new doc ID.
  Future<String> createProject(Project project) async {
    try {
      final ref = _db.collection('projects').doc();
      await ref.set(project.toMap());
      return ref.id;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Update mutable fields of a project.
  Future<void> updateProject(
    String projectId,
    Map<String, dynamic> fields,
  ) async {
    try {
      await _db.collection('projects').doc(projectId).update({
        ...fields,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Delete a project root doc (sub-collections cleaned up by Cloud Function in prod).
  Future<void> deleteProject(String projectId) async {
    try {
      await _db.collection('projects').doc(projectId).delete();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> assignPm(
    String projectId, {
    required String pmUid,
    required String pmName,
  }) =>
      updateProject(projectId, {
        'assignedPmUid': pmUid,
        'assignedPmName': pmName,
      });

  Future<void> removePm(String projectId) =>
      updateProject(projectId, {
        'assignedPmUid': FieldValue.delete(),
        'assignedPmName': FieldValue.delete(),
      });

  // ── Phases ──

  Stream<List<Phase>> phasesStream(String projectId) {
    return _db
        .collection('projects')
        .doc(projectId)
        .collection('phases')
        .orderBy('order')
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => Phase.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  Future<String> addPhase(String projectId, Phase phase) async {
    try {
      final ref = _db
          .collection('projects')
          .doc(projectId)
          .collection('phases')
          .doc();
      await ref.set(phase.toMap());
      return ref.id;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> updatePhase(
    String projectId,
    String phaseId,
    Map<String, dynamic> fields,
  ) async {
    try {
      await _db
          .collection('projects')
          .doc(projectId)
          .collection('phases')
          .doc(phaseId)
          .update(fields);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> deletePhase(String projectId, String phaseId) async {
    try {
      await _db
          .collection('projects')
          .doc(projectId)
          .collection('phases')
          .doc(phaseId)
          .delete();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  // ── Cost entries ──

  Stream<List<CostEntry>> costEntriesStream(String projectId) {
    return _db
        .collection('projects')
        .doc(projectId)
        .collection('costs')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => CostEntry.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  /// Add a cost entry and atomically update the project's `amountSpent`.
  Future<void> addCostEntry(String projectId, CostEntry entry) async {
    try {
      final projectRef = _db.collection('projects').doc(projectId);
      final entryRef = projectRef.collection('costs').doc();

      await _db.runTransaction((tx) async {
        final snap = await tx.get(projectRef);
        final current =
            (snap.data()?['amountSpent'] as num?)?.toDouble() ?? 0;
        tx.set(entryRef, entry.toMap());
        tx.update(projectRef, {
          'amountSpent': current + entry.amountGhs,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> deleteCostEntry(
    String projectId,
    String entryId,
    double amountGhs,
  ) async {
    try {
      final projectRef = _db.collection('projects').doc(projectId);
      final entryRef = projectRef.collection('costs').doc(entryId);

      await _db.runTransaction((tx) async {
        final snap = await tx.get(projectRef);
        final current =
            (snap.data()?['amountSpent'] as num?)?.toDouble() ?? 0;
        tx.delete(entryRef);
        tx.update(projectRef, {
          'amountSpent': (current - amountGhs).clamp(0, double.infinity),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  // ── Updates / Notes ──

  Stream<List<ProjectUpdate>> updatesStream(String projectId) {
    return _db
        .collection('projects')
        .doc(projectId)
        .collection('updates')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => ProjectUpdate.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  Future<void> addUpdate({
    required String projectId,
    required String authorUid,
    required String text,
    List<String> photoUrls = const [],
    double? costDelta,
  }) async {
    try {
      final update = ProjectUpdate(
        id: '',
        authorUid: authorUid,
        text: text,
        photoUrls: photoUrls,
        costDelta: costDelta,
        createdAt: DateTime.now(),
      );

      final projectRef = _db.collection('projects').doc(projectId);
      final updateRef = projectRef.collection('updates').doc();

      if (costDelta != null && costDelta != 0) {
        await _db.runTransaction((tx) async {
          final snap = await tx.get(projectRef);
          final current =
              (snap.data()?['amountSpent'] as num?)?.toDouble() ?? 0;
          tx.set(updateRef, update.toMap());
          tx.update(projectRef, {
            'amountSpent': (current + costDelta).clamp(0, double.infinity),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });
      } else {
        await updateRef.set(update.toMap());
        await projectRef.update({'updatedAt': FieldValue.serverTimestamp()});
      }
    } catch (e) {
      throw AppException.from(e);
    }
  }

  // ── Estimates ──

  /// Stream of estimates attached to this project, newest first.
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> estimatesStream(
    String projectId,
  ) {
    return _db
        .collection('projects')
        .doc(projectId)
        .collection('estimates')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>());
  }

  /// Copy an estimate doc into this project's estimates sub-collection.
  Future<void> linkEstimate(
    String projectId,
    Map<String, dynamic> data,
  ) async {
    try {
      final ref = _db
          .collection('projects')
          .doc(projectId)
          .collection('estimates')
          .doc();
      await ref.set({
        ...data,
        'linkedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Remove an estimate from this project.
  Future<void> deleteEstimate(String projectId, String estimateId) async {
    try {
      await _db
          .collection('projects')
          .doc(projectId)
          .collection('estimates')
          .doc(estimateId)
          .delete();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  // ── Documents ──

  Stream<List<ProjectDocument>> documentsStream(String projectId) {
    return _db
        .collection('projects')
        .doc(projectId)
        .collection('documents')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => ProjectDocument.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  Future<String> uploadDocument({
    required String projectId,
    required String uploaderUid,
    required File file,
    required String fileName,
    required DocumentCategory category,
    String? displayName,
    String? contentType,
  }) async {
    try {
      final storagePath =
          'project_uploads/$projectId/documents/$fileName';
      final ref = _storage.ref(storagePath);
      final metadata = contentType != null
          ? SettableMetadata(contentType: contentType)
          : null;
      final task = metadata != null
          ? await ref.putFile(file, metadata)
          : await ref.putFile(file);
      final url = await task.ref.getDownloadURL();

      final docRef = _db
          .collection('projects')
          .doc(projectId)
          .collection('documents')
          .doc();

      final sizeBytes = await file.length();
      final name =
          (displayName != null && displayName.isNotEmpty) ? displayName : fileName;
      await docRef.set(ProjectDocument(
        id: docRef.id,
        uploaderUid: uploaderUid,
        name: name,
        url: url,
        category: category,
        storagePath: storagePath,
        contentType: contentType,
        sizeBytes: sizeBytes,
        createdAt: DateTime.now(),
      ).toMap(),);

      return url;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> deleteDocument(
    String projectId,
    String docId, {
    String? storagePath,
  }) async {
    try {
      if (storagePath != null) {
        try {
          await _storage.ref(storagePath).delete();
        } catch (e) {
          debugPrint('ProjectService: Storage delete skipped — $e');
        }
      }
      await _db
          .collection('projects')
          .doc(projectId)
          .collection('documents')
          .doc(docId)
          .delete();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  // ── Photo upload ──

  Future<List<String>> uploadUpdatePhotos({
    required String projectId,
    required String updateId,
    required List<File> files,
  }) async {
    final urls = <String>[];
    for (final file in files) {
      final name = file.path.split('/').last;
      final ref =
          _storage.ref('project_uploads/$projectId/updates/$updateId/$name');
      try {
        await ref.putFile(file);
        urls.add(await ref.getDownloadURL());
      } catch (e) {
        debugPrint('ProjectService: photo upload failed for $name — $e');
      }
    }
    return urls;
  }

  /// Upload completion proof photos for a phase.
  /// Returns a list of download URLs for successfully uploaded photos.
  Future<List<String>> uploadPhaseCompletionPhotos({
    required String projectId,
    required String phaseId,
    required List<File> files,
  }) async {
    final urls = <String>[];
    for (final file in files) {
      final ext = file.path.split('.').last.toLowerCase();
      final name = '${const Uuid().v4()}.$ext';
      final ref = _storage.ref(
        'project_uploads/$projectId/phase_completions/$phaseId/$name',
      );
      try {
        await ref.putFile(file, SettableMetadata(contentType: 'image/$ext'));
        urls.add(await ref.getDownloadURL());
      } catch (e) {
        debugPrint('ProjectService: phase photo upload failed — $e');
      }
    }
    return urls;
  }

  /// Upload a receipt photo for a cost entry.
  /// Returns the download URL. Throws [AppException] on failure.
  Future<String> uploadReceiptPhoto({
    required String projectId,
    required String receiptId,
    required File file,
  }) async {
    try {
      final ext = file.path.split('.').last.toLowerCase();
      final ref = _storage.ref(
        'project_uploads/$projectId/receipts/$receiptId.$ext',
      );
      await ref.putFile(file, SettableMetadata(contentType: 'image/$ext'));
      return await ref.getDownloadURL();
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
