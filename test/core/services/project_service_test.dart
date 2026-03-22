// test/core/services/project_service_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wysebrix/core/models/cost_entry.dart';
import 'package:wysebrix/core/models/phase.dart';
import 'package:wysebrix/core/models/project.dart';
import 'package:wysebrix/core/services/project_service.dart';

Project _makeProject({String title = 'Test Project', double budget = 100000}) {
  final now = DateTime.now();
  return Project(
    id: '',
    ownerUid: 'owner1',
    ownerName: 'Alice',
    title: title,
    region: 'Greater Accra',
    budget: budget,
    createdAt: now,
    updatedAt: now,
  );
}

Phase _makePhase({String name = 'Foundation', int order = 1}) {
  return Phase(
    id: '',
    name: name,
    order: order,
    status: PhaseStatus.pending,
    createdAt: DateTime.now(),
  );
}

CostEntry _makeEntry({double amount = 5000, String category = 'Materials'}) {
  return CostEntry(
    id: '',
    description: 'Test item',
    amountGhs: amount,
    category: category,
    authorUid: 'owner1',
    createdAt: DateTime.now(),
  );
}

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late ProjectService service;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    service = ProjectService(db: fakeFirestore);
  });

  // ── createProject ────────────────────────────────────────────────────────────

  group('createProject', () {
    test('returns a non-empty doc ID', () async {
      final id = await service.createProject(_makeProject());
      expect(id, isNotEmpty);
    });

    test('document is readable after create', () async {
      final id = await service.createProject(_makeProject(title: 'My Home'));
      final snap = await fakeFirestore.collection('projects').doc(id).get();
      expect(snap.exists, isTrue);
      expect(snap.data()!['title'], 'My Home');
      expect(snap.data()!['ownerUid'], 'owner1');
    });

    test('creates multiple projects with unique IDs', () async {
      final id1 = await service.createProject(_makeProject(title: 'P1'));
      final id2 = await service.createProject(_makeProject(title: 'P2'));
      expect(id1, isNot(equals(id2)));
    });
  });

  // ── updateProject ────────────────────────────────────────────────────────────

  group('updateProject', () {
    test('updates specified fields', () async {
      final id = await service.createProject(_makeProject());
      await service.updateProject(id, {'title': 'Renovated', 'budget': 200000});

      final snap = await fakeFirestore.collection('projects').doc(id).get();
      expect(snap.data()!['title'], 'Renovated');
      expect(snap.data()!['budget'], 200000);
    });
  });

  // ── deleteProject ────────────────────────────────────────────────────────────

  group('deleteProject', () {
    test('document no longer exists after delete', () async {
      final id = await service.createProject(_makeProject());
      await service.deleteProject(id);

      final snap = await fakeFirestore.collection('projects').doc(id).get();
      expect(snap.exists, isFalse);
    });
  });

  // ── projectsForOwner ─────────────────────────────────────────────────────────

  group('projectsForOwner', () {
    test('returns only projects for the given ownerUid', () async {
      await service.createProject(_makeProject(title: 'Alice P1'));
      await service.createProject(_makeProject(title: 'Alice P2'));

      final now = DateTime.now();
      await fakeFirestore.collection('projects').add(
            Project(
              id: '',
              ownerUid: 'other_owner',
              title: 'Other',
              region: '',
              createdAt: now,
              updatedAt: now,
            ).toMap(),
          );

      final projects =
          await service.projectsForOwner('owner1', limit: 20).first;
      expect(projects.length, 2);
      expect(projects.every((p) => p.ownerUid == 'owner1'), isTrue);
    });

    test('respects the limit parameter', () async {
      for (var i = 0; i < 5; i++) {
        await service.createProject(_makeProject(title: 'P$i'));
      }
      final projects = await service.projectsForOwner('owner1', limit: 3).first;
      expect(projects.length, lessThanOrEqualTo(3));
    });
  });

  // ── addPhase / phasesStream ──────────────────────────────────────────────────

  group('addPhase', () {
    test('returns a valid phase ID', () async {
      final projectId = await service.createProject(_makeProject());
      final phaseId = await service.addPhase(projectId, _makePhase());
      expect(phaseId, isNotEmpty);
    });

    test('phase appears in phasesStream', () async {
      final projectId = await service.createProject(_makeProject());
      await service.addPhase(projectId, _makePhase(name: 'Substructure'));

      final phases = await service.phasesStream(projectId).first;
      expect(phases.length, 1);
      expect(phases.first.name, 'Substructure');
    });

    test('multiple phases ordered by order field', () async {
      final projectId = await service.createProject(_makeProject());
      await service.addPhase(projectId, _makePhase(name: 'B', order: 2));
      await service.addPhase(projectId, _makePhase(name: 'A', order: 1));

      final phases = await service.phasesStream(projectId).first;
      expect(phases[0].name, 'A');
      expect(phases[1].name, 'B');
    });
  });

  // ── deletePhase ──────────────────────────────────────────────────────────────

  group('deletePhase', () {
    test('phase removed from stream after delete', () async {
      final projectId = await service.createProject(_makeProject());
      final phaseId = await service.addPhase(projectId, _makePhase());
      await service.deletePhase(projectId, phaseId);

      final phases = await service.phasesStream(projectId).first;
      expect(phases, isEmpty);
    });
  });

  // ── addCostEntry ─────────────────────────────────────────────────────────────

  group('addCostEntry', () {
    test('cost appears in stream', () async {
      final projectId = await service.createProject(_makeProject(budget: 50000));
      await service.addCostEntry(projectId, _makeEntry(amount: 12000));

      final entries = await service.costEntriesStream(projectId).first;
      expect(entries.length, 1);
      expect(entries.first.amountGhs, 12000);
    });

    test('amountSpent updated atomically', () async {
      final projectId = await service.createProject(_makeProject());
      await service.addCostEntry(projectId, _makeEntry(amount: 1000));
      await service.addCostEntry(projectId, _makeEntry(amount: 2000));

      final snap =
          await fakeFirestore.collection('projects').doc(projectId).get();
      expect(snap.data()!['amountSpent'], 3000.0);
    });
  });

  // ── deleteCostEntry ──────────────────────────────────────────────────────────

  group('deleteCostEntry', () {
    test('reverses amountSpent on delete', () async {
      final projectId = await service.createProject(_makeProject());
      await service.addCostEntry(projectId, _makeEntry(amount: 5000));

      final entries = await service.costEntriesStream(projectId).first;
      await service.deleteCostEntry(projectId, entries.first.id, 5000);

      final snap =
          await fakeFirestore.collection('projects').doc(projectId).get();
      expect(snap.data()!['amountSpent'], 0.0);
    });

    test('amountSpent does not go below zero', () async {
      final projectId = await service.createProject(_makeProject());
      await service.addCostEntry(projectId, _makeEntry(amount: 100));

      final entries = await service.costEntriesStream(projectId).first;
      await service.deleteCostEntry(projectId, entries.first.id, 9999);

      final snap =
          await fakeFirestore.collection('projects').doc(projectId).get();
      expect(snap.data()!['amountSpent'], 0.0);
    });
  });

  // ── phase approval workflow ──────────────────────────────────────────────────

  group('phase approval workflow', () {
    test('submitForApproval transitions phase to pendingApproval', () async {
      final projectId = await service.createProject(_makeProject());
      final phaseId = await service.addPhase(projectId, _makePhase());

      await service.submitPhaseForApproval(projectId, phaseId);

      final phases = await service.phasesStream(projectId).first;
      expect(phases.first.status, PhaseStatus.pendingApproval);
    });

    test('approvePhase transitions phase to completed', () async {
      final projectId = await service.createProject(_makeProject());
      final phaseId = await service.addPhase(projectId, _makePhase());

      await service.submitPhaseForApproval(projectId, phaseId);
      await service.approvePhase(projectId, phaseId);

      final phases = await service.phasesStream(projectId).first;
      expect(phases.first.status, PhaseStatus.completed);
    });

    test('rejectPhase transitions phase back to inProgress', () async {
      final projectId = await service.createProject(_makeProject());
      final phaseId = await service.addPhase(projectId, _makePhase());

      await service.submitPhaseForApproval(projectId, phaseId);
      await service.rejectPhase(projectId, phaseId, comment: 'Needs rework');

      final phases = await service.phasesStream(projectId).first;
      expect(phases.first.status, PhaseStatus.inProgress);
      expect(phases.first.rejectionComment, 'Needs rework');
    });

    test('rejectPhase without comment stores no rejectionComment', () async {
      final projectId = await service.createProject(_makeProject());
      final phaseId = await service.addPhase(projectId, _makePhase());

      await service.submitPhaseForApproval(projectId, phaseId);
      await service.rejectPhase(projectId, phaseId);

      final phases = await service.phasesStream(projectId).first;
      expect(phases.first.rejectionComment, isNull);
    });
  });

  // ── overallProgressPercent ────────────────────────────────────────────────────

  group('overallProgressPercent', () {
    test('returns 0 for empty list', () {
      expect(ProjectService.overallProgressPercent([]), 0);
    });

    test('returns simple average when no estimated costs', () {
      final phases = [
        Phase(id: '1', name: 'A', order: 1, status: PhaseStatus.pending,
            createdAt: DateTime.now(), percentComplete: 50,),
        Phase(id: '2', name: 'B', order: 2, status: PhaseStatus.pending,
            createdAt: DateTime.now(), percentComplete: 100,),
      ];
      expect(ProjectService.overallProgressPercent(phases), 75);
    });

    test('returns cost-weighted average when estimated costs are set', () {
      final phases = [
        Phase(id: '1', name: 'A', order: 1, status: PhaseStatus.pending,
            createdAt: DateTime.now(), percentComplete: 100,
            estimatedCostGhs: 10000,),
        Phase(id: '2', name: 'B', order: 2, status: PhaseStatus.pending,
            createdAt: DateTime.now(), percentComplete: 0,
            estimatedCostGhs: 90000,),
      ];
      // 10% weighted: (10000*100 + 90000*0) / 100000 = 10
      expect(ProjectService.overallProgressPercent(phases), closeTo(10, 0.001));
    });
  });

  // ── assignPm / removePm ──────────────────────────────────────────────────────

  group('assignPm / removePm', () {
    test('assignPm sets pm fields', () async {
      final projectId = await service.createProject(_makeProject());
      await service.assignPm(projectId, pmUid: 'pm1', pmName: 'Bob');

      final snap =
          await fakeFirestore.collection('projects').doc(projectId).get();
      expect(snap.data()!['assignedPmUid'], 'pm1');
      expect(snap.data()!['assignedPmName'], 'Bob');
    });

    test('removePm clears pm fields', () async {
      final projectId = await service.createProject(_makeProject());
      await service.assignPm(projectId, pmUid: 'pm1', pmName: 'Bob');
      await service.removePm(projectId);

      final snap =
          await fakeFirestore.collection('projects').doc(projectId).get();
      expect(snap.data()!.containsKey('assignedPmUid'), isFalse);
      expect(snap.data()!.containsKey('assignedPmName'), isFalse);
    });
  });
}
