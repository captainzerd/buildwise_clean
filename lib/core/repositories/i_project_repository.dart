// lib/core/repositories/i_project_repository.dart
//
// Abstract interface for project data access. Concrete implementation:
//   ProjectService (lib/core/services/project_service.dart)
//
// Use this interface in tests to swap the real Firebase implementation
// with a fake or mock.

import '../models/cost_entry.dart';
import '../models/phase.dart';
import '../models/project.dart';
import '../models/project_update.dart';

abstract class IProjectRepository {
  // ── Projects ──────────────────────────────────────────────────────────────

  Stream<List<Project>> projectsForOwner(String ownerUid, {int limit = 20});

  Stream<List<Project>> projectsForBuilder(
    String builderUid, {
    int limit = 20,
  });

  Stream<Project?> projectStream(String projectId);

  Future<String> createProject(Project project);

  Future<void> updateProject(String projectId, Map<String, dynamic> fields);

  Future<void> deleteProject(String projectId);

  Future<void> assignPm(
    String projectId, {
    required String pmUid,
    required String pmName,
  });

  Future<void> removePm(String projectId);

  // ── Phases ────────────────────────────────────────────────────────────────

  Stream<List<Phase>> phasesStream(String projectId, {int limit = 50});

  Future<String> addPhase(String projectId, Phase phase);

  Future<void> updatePhase(
    String projectId,
    String phaseId,
    Map<String, dynamic> fields,
  );

  Future<void> deletePhase(String projectId, String phaseId);

  /// Builder marks a phase as awaiting owner approval.
  Future<void> submitPhaseForApproval(String projectId, String phaseId);

  /// Owner approves a phase that was submitted for approval.
  Future<void> approvePhase(String projectId, String phaseId);

  /// Owner rejects a phase with an optional comment.
  Future<void> rejectPhase(
    String projectId,
    String phaseId, {
    String? comment,
  });

  // ── Cost entries ──────────────────────────────────────────────────────────

  Stream<List<CostEntry>> costEntriesStream(String projectId, {int limit = 50});

  Future<int> costEntryCount(String projectId);

  Future<void> addCostEntry(String projectId, CostEntry entry);

  Future<void> deleteCostEntry(
    String projectId,
    String entryId,
    double amountGhs, {
    String? phaseId,
  });

  // ── Updates ───────────────────────────────────────────────────────────────

  Stream<List<ProjectUpdate>> updatesStream(String projectId, {int limit = 50});

  Future<void> addUpdate({
    required String projectId,
    required String authorUid,
    required String text,
    List<String> photoUrls = const [],
    double? costDelta,
    double? photoLat,
    double? photoLng,
  });
}
