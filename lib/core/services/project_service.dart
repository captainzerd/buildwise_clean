// lib/core/services/project_service.dart
import 'dart:io';

import 'package:async/async.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../errors/app_exception.dart';
import '../models/audit_event.dart';
import '../models/cost_entry.dart';
import '../models/phase.dart';
import '../models/project.dart';
import '../models/project_document.dart';
import '../models/project_update.dart';
import '../models/team_member.dart';
import '../repositories/i_project_repository.dart';
import 'audit_service.dart';

class ProjectService implements IProjectRepository {
  /// [db] and [storage] are optional; defaults to Firebase singletons.
  /// Pass explicit instances in tests to avoid requiring Firebase.initializeApp().
  ProjectService({FirebaseFirestore? db, FirebaseStorage? storage})
      : _db = db ?? FirebaseFirestore.instance,
        _storageOverride = storage;

  final FirebaseFirestore _db;
  final FirebaseStorage? _storageOverride;

  // Lazily falls back to FirebaseStorage.instance only when a storage method is called.
  FirebaseStorage get _storage => _storageOverride ?? FirebaseStorage.instance;

  // ── Projects ──

  // ── Cursor-based pagination ──

  /// Fetch a single page of projects owned by [ownerUid], newest first.
  /// Returns a tuple of (results, cursor) where cursor is the last document
  /// snapshot used to fetch the *next* page. Null cursor means no more pages.
  Future<(List<Project>, DocumentSnapshot?)> fetchOwnerProjectsPage(
    String ownerUid, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    var query = _db
        .collection('projects')
        .where('ownerUid', isEqualTo: ownerUid)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snap = await query.get();
    final docs = snap.docs;
    final projects = docs
        .map(
            (d) => Project.fromDoc(d as DocumentSnapshot<Map<String, dynamic>>),)
        .toList();
    final cursor = docs.isNotEmpty && docs.length >= limit ? docs.last : null;
    return (projects, cursor);
  }

  /// Fetch one page of projects for [builderUid].
  /// Merges `assignedPmUid` and `teamMemberUids` queries, deduplicates by ID.
  Future<(List<Project>, DocumentSnapshot?)> fetchBuilderProjectsPage(
    String builderUid, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    // True cursor-based pagination across two independent Firestore queries
    // is not possible (cursors are query-specific). Builders typically have
    // few projects, so we do a full fetch from both queries and merge in memory.
    final results = await Future.wait([
      _db
          .collection('projects')
          .where('assignedPmUid', isEqualTo: builderUid)
          .orderBy('createdAt', descending: true)
          .limit(limit * 2)
          .get(),
      _db
          .collection('projects')
          .where('teamMemberUids', arrayContains: builderUid)
          .orderBy('createdAt', descending: true)
          .limit(limit * 2)
          .get(),
    ]);

    final seen = <String>{};
    final merged = <Project>[];
    for (final snap in results) {
      for (final doc in snap.docs) {
        if (seen.add(doc.id)) {
          merged.add(
            Project.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>),
          );
        }
      }
    }
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Return null cursor — builder list is small enough for a full fetch.
    // _loadMore will see cursor == null and set _hasMore = false.
    return (merged.take(limit).toList(), null);
  }

  /// Stream of projects owned by [ownerUid], newest first.
  /// [limit] controls page size — increase to load more (triggers re-subscription).
  @override
  Stream<List<Project>> projectsForOwner(String ownerUid, {int limit = 20}) {
    return _db
        .collection('projects')
        .where('ownerUid', isEqualTo: ownerUid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
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

  /// Stream of projects assigned to or team-member'd by [builderUid], newest first.
  /// Merges `assignedPmUid` and `teamMemberUids` queries, deduplicates by ID.
  /// [limit] controls page size — increase to load more.
  @override
  Stream<List<Project>> projectsForBuilder(
    String builderUid, {
    int limit = 20,
  }) {
    final s1 = _db
        .collection('projects')
        .where('assignedPmUid', isEqualTo: builderUid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
    final s2 = _db
        .collection('projects')
        .where('teamMemberUids', arrayContains: builderUid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();

    return StreamZip([s1, s2]).map((snaps) {
      final seen = <String>{};
      final merged = <Project>[];
      for (final snap in snaps) {
        for (final doc in snap.docs) {
          if (seen.add(doc.id)) {
            merged.add(
              Project.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>),
            );
          }
        }
      }
      merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return merged;
    });
  }

  /// Stream of a single project doc.
  @override
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
  @override
  Future<String> createProject(Project project) async {
    try {
      final ref = _db.collection('projects').doc();
      await ref.set(project.toMap());
      return ref.id;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Save a frozen BOQ snapshot to `projects/{id}/boq/default`.
  /// [items] is a list of BoqItem maps (from BoqItem.toMap()).
  Future<void> saveBoq(
    String projectId,
    List<Map<String, dynamic>> items,
    double floorAreaSqm,
  ) async {
    try {
      await _db
          .collection('projects')
          .doc(projectId)
          .collection('boq')
          .doc('default')
          .set({
        'savedAt': FieldValue.serverTimestamp(),
        'floorAreaSqm': floorAreaSqm,
        'items': items,
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Update mutable fields of a project.
  @override
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
  @override
  Future<void> deleteProject(String projectId) async {
    try {
      await _db.collection('projects').doc(projectId).delete();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> setBudgetAlertThreshold(
    String projectId,
    double threshold,
  ) =>
      updateProject(projectId, {'budgetAlertThreshold': threshold});

  // ── Team members ──────────────────────────────────────────────────────────

  /// Stream projects where [uid] is in the teamMemberUids array.
  Stream<List<Project>> projectsForTeamMember(
    String uid, {
    int limit = 20,
  }) {
    return _db
        .collection('projects')
        .where('teamMemberUids', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
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

  /// Add a team member to a project. Updates both teamMembers list and
  /// the teamMemberUids array used for Firestore array-contains queries.
  /// Also updates collaboratorUids or observerUids based on permissionTier.
  Future<void> addTeamMember(String projectId, TeamMember member) async {
    final isObserver = member.permissionTier == 'observer';
    await _db.collection('projects').doc(projectId).update({
      'teamMembers': FieldValue.arrayUnion([member.toMap()]),
      'teamMemberUids': FieldValue.arrayUnion([member.uid]),
      if (isObserver)
        'observerUids': FieldValue.arrayUnion([member.uid])
      else
        'collaboratorUids': FieldValue.arrayUnion([member.uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remove a team member by uid from a project. Reads the current teamMembers
  /// list, filters out the member, then writes back atomically.
  Future<void> removeTeamMember(String projectId, String memberUid) async {
    final snap = await _db.collection('projects').doc(projectId).get();
    final raw = (snap.data()?['teamMembers'] as List?)?.cast<Map>() ?? const [];
    final updated = raw
        .map((m) => Map<String, dynamic>.from(m))
        .where((m) => m['uid'] != memberUid)
        .toList();
    await _db.collection('projects').doc(projectId).update({
      'teamMembers': updated,
      'teamMemberUids': FieldValue.arrayRemove([memberUid]),
      'collaboratorUids': FieldValue.arrayRemove([memberUid]),
      'observerUids': FieldValue.arrayRemove([memberUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Updates a project's budget and writes an audit log entry.
  Future<void> updateProjectBudget(
    String projectId,
    double newBudget, {
    String? actorUid,
    String? actorName,
    String? ownerUid,
  }) async {
    await updateProject(projectId, {'budget': newBudget});
    if (actorUid != null && actorName != null) {
      await AuditService().logEvent(
        projectId: projectId,
        type: AuditEventType.projectStatusChanged,
        actorUid: actorUid,
        actorName: actorName,
        description: 'Budget amended to GHS ${newBudget.toStringAsFixed(2)}',
        ownerUid: ownerUid,
      );
    }
  }

  @override
  Future<void> assignPm(
    String projectId, {
    required String pmUid,
    required String pmName,
  }) =>
      updateProject(projectId, {
        'assignedPmUid': pmUid,
        'assignedPmName': pmName,
      });

  @override
  Future<void> removePm(String projectId) => updateProject(projectId, {
        'assignedPmUid': FieldValue.delete(),
        'assignedPmName': FieldValue.delete(),
      });

  // ── Phases ──

  @override
  Stream<List<Phase>> phasesStream(String projectId, {int limit = 50}) {
    return _db
        .collection('projects')
        .doc(projectId)
        .collection('phases')
        .orderBy('order')
        .limit(limit)
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

  @override
  Future<String> addPhase(String projectId, Phase phase) async {
    try {
      final ref =
          _db.collection('projects').doc(projectId).collection('phases').doc();
      await ref.set(phase.toMap());
      return ref.id;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  @override
  Future<void> updatePhase(
    String projectId,
    String phaseId,
    Map<String, dynamic> fields,
  ) async {
    try {
      // Auto-inject actualStartDate when transitioning to inProgress
      if (fields['status'] == PhaseStatus.inProgress.firestoreValue) {
        fields.putIfAbsent(
          'actualStartDate',
          () => FieldValue.serverTimestamp(),
        );
      }
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

  @override
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

  @override
  Future<void> submitPhaseForApproval(
    String projectId,
    String phaseId,
  ) async {
    try {
      await _db
          .collection('projects')
          .doc(projectId)
          .collection('phases')
          .doc(phaseId)
          .update({'status': PhaseStatus.pendingApproval.firestoreValue});
    } catch (e) {
      throw AppException.from(e);
    }
  }

  @override
  Future<void> approvePhase(String projectId, String phaseId) async {
    try {
      await _db
          .collection('projects')
          .doc(projectId)
          .collection('phases')
          .doc(phaseId)
          .update({
        'status': PhaseStatus.completed.firestoreValue,
        'rejectionComment': FieldValue.delete(),
        'actualEndDate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Computes overall project progress as a weighted percentage (by estimated cost).
  /// Falls back to simple average when no phases have estimated costs.
  static double overallProgressPercent(List<Phase> phases) {
    if (phases.isEmpty) return 0;
    final totalCost =
        phases.fold<double>(0, (s, p) => s + (p.estimatedCostGhs ?? 0));
    if (totalCost == 0) {
      return phases.fold<double>(0, (s, p) => s + p.percentComplete) /
          phases.length;
    }
    return phases.fold<double>(
          0,
          (s, p) => s + (p.estimatedCostGhs ?? 0) * p.percentComplete,
        ) /
        totalCost;
  }

  @override
  Future<void> rejectPhase(
    String projectId,
    String phaseId, {
    String? comment,
  }) async {
    try {
      await _db
          .collection('projects')
          .doc(projectId)
          .collection('phases')
          .doc(phaseId)
          .update({
        'status': PhaseStatus.inProgress.firestoreValue,
        if (comment != null && comment.isNotEmpty) 'rejectionComment': comment,
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  // ── Cost entries ──

  @override
  Stream<List<CostEntry>> costEntriesStream(String projectId, {int limit = 50}) {
    return _db
        .collection('projects')
        .doc(projectId)
        .collection('costs')
        .orderBy('createdAt', descending: true)
        .limit(limit)
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
  @override

  /// Returns the number of cost entries for [projectId] (used for free-tier gate).
  Future<int> costEntryCount(String projectId) async {
    final snap = await _db
        .collection('projects')
        .doc(projectId)
        .collection('costs')
        .count()
        .get();
    return snap.count ?? 0;
  }

  @override
  Future<void> addCostEntry(String projectId, CostEntry entry) async {
    try {
      final projectRef = _db.collection('projects').doc(projectId);
      final entryRef = projectRef.collection('costs').doc();

      await _db.runTransaction((tx) async {
        final snap = await tx.get(projectRef);
        final current = (snap.data()?['amountSpent'] as num?)?.toDouble() ?? 0;
        tx.set(entryRef, entry.toMap());
        tx.update(projectRef, {
          'amountSpent': current + entry.amountGhs,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (entry.phaseId != null && entry.phaseId!.isNotEmpty) {
          final phaseRef = projectRef.collection('phases').doc(entry.phaseId);
          final phaseSnap = await tx.get(phaseRef);
          final cur =
              (phaseSnap.data()?['actualCostGhs'] as num?)?.toDouble() ?? 0;
          tx.update(phaseRef, {'actualCostGhs': cur + entry.amountGhs});
        }
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  @override
  Future<void> deleteCostEntry(
    String projectId,
    String entryId,
    double amountGhs, {
    String? phaseId,
  }) async {
    try {
      final projectRef = _db.collection('projects').doc(projectId);
      final entryRef = projectRef.collection('costs').doc(entryId);

      await _db.runTransaction((tx) async {
        final snap = await tx.get(projectRef);
        final current = (snap.data()?['amountSpent'] as num?)?.toDouble() ?? 0;
        tx.delete(entryRef);
        tx.update(projectRef, {
          'amountSpent': (current - amountGhs).clamp(0, double.infinity),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (phaseId != null && phaseId.isNotEmpty) {
          final phaseRef = projectRef.collection('phases').doc(phaseId);
          final phaseSnap = await tx.get(phaseRef);
          final cur =
              (phaseSnap.data()?['actualCostGhs'] as num?)?.toDouble() ?? 0;
          tx.update(phaseRef, {
            'actualCostGhs': (cur - amountGhs).clamp(0, double.infinity),
          });
        }
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  // ── Updates / Notes ──

  @override
  Stream<List<ProjectUpdate>> updatesStream(String projectId, {int limit = 50}) {
    return _db
        .collection('projects')
        .doc(projectId)
        .collection('updates')
        .orderBy('createdAt', descending: true)
        .limit(limit)
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

  @override
  Future<void> addUpdate({
    required String projectId,
    required String authorUid,
    required String text,
    List<String> photoUrls = const [],
    double? costDelta,
    double? photoLat,
    double? photoLng,
  }) async {
    try {
      final update = ProjectUpdate(
        id: '',
        authorUid: authorUid,
        text: text,
        photoUrls: photoUrls,
        costDelta: costDelta,
        createdAt: DateTime.now(),
        photoLat: photoLat,
        photoLng: photoLng,
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

  Stream<List<ProjectDocument>> documentsStream(String projectId, {int limit = 50}) {
    return _db
        .collection('projects')
        .doc(projectId)
        .collection('documents')
        .orderBy('createdAt', descending: true)
        .limit(limit)
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
    DateTime? expiresAt,
    DocumentVisibility visibility = DocumentVisibility.all,
  }) async {
    try {
      final storagePath = 'project_uploads/$projectId/documents/$fileName';
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
      final name = (displayName != null && displayName.isNotEmpty)
          ? displayName
          : fileName;
      await docRef.set(
        ProjectDocument(
          id: docRef.id,
          uploaderUid: uploaderUid,
          name: name,
          url: url,
          category: category,
          storagePath: storagePath,
          contentType: contentType,
          sizeBytes: sizeBytes,
          createdAt: DateTime.now(),
          expiresAt: expiresAt,
          visibility: visibility,
        ).toMap(),
      );

      return url;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Save a pre-built [ProjectDocument] into the project's documents
  /// sub-collection. Use this when the file has already been uploaded to
  /// Storage and only the Firestore record needs to be created.
  Future<void> addDocument(String projectId, ProjectDocument doc) async {
    try {
      final ref = _db
          .collection('projects')
          .doc(projectId)
          .collection('documents')
          .doc();
      await ref.set(doc.toMap());
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

  /// Compresses [file] to JPEG (max 1280px wide, quality 75) and returns the
  /// compressed bytes. Falls back to the original file bytes on any error so
  /// the upload always succeeds.
  Future<Uint8List> _compressPhoto(File file) async {
    try {
      final tmpDir = await getTemporaryDirectory();
      final ext = p.extension(file.path).toLowerCase();
      final format = ext == '.png' ? CompressFormat.png : CompressFormat.jpeg;
      final targetPath = p.join(
        tmpDir.path,
        '${const Uuid().v4()}${ext.isEmpty ? '.jpg' : ext}',
      );
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 75,
        minWidth: 1280,
        minHeight: 1,
        format: format,
        keepExif: false,
      );
      if (result != null) return await result.readAsBytes();
    } catch (e) {
      debugPrint('ProjectService: compression failed — $e');
    }
    return await file.readAsBytes();
  }

  Future<List<String>> uploadUpdatePhotos({
    required String projectId,
    required String updateId,
    required List<File> files,
  }) async {
    final urls = <String>[];
    for (final file in files) {
      final name = '${const Uuid().v4()}.jpg';
      final ref =
          _storage.ref('project_uploads/$projectId/updates/$updateId/$name');
      try {
        final bytes = await _compressPhoto(file);
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
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
      final name = '${const Uuid().v4()}.jpg';
      final ref = _storage.ref(
        'project_uploads/$projectId/phase_completions/$phaseId/$name',
      );
      try {
        final bytes = await _compressPhoto(file);
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
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
      final name = '${const Uuid().v4()}.jpg';
      final ref = _storage.ref(
        'project_uploads/$projectId/receipts/$name',
      );
      final bytes = await _compressPhoto(file);
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
