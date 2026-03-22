import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wysebrix/core/services/project_service.dart';

void main() {
  test('fetchBuilderProjectsPage includes teamMemberUids projects', () async {
    final db = FakeFirebaseFirestore();
    // Project where builder is assignedPmUid
    await db.collection('projects').doc('p1').set({
      'ownerUid': 'owner1',
      'title': 'P1',
      'assignedPmUid': 'builder1',
      'teamMemberUids': <String>[],
      'collaboratorUids': <String>[],
      'observerUids': <String>[],
      'createdAt': DateTime(2024),
      'updatedAt': DateTime(2024),
      'status': 'active',
      'budget': 0,
      'estimateTotalGhs': 0,
      'amountSpent': 0,
      'region': '',
      'currency': 'GHS',
      'currencySymbol': 'GH₵',
      'budgetAlertThreshold': 0.8,
      'teamMembers': <Map>[],
      'contingencyGhs': 0,
      'schemaVersion': 1,
    });
    // Project where builder is only in teamMemberUids
    await db.collection('projects').doc('p2').set({
      'ownerUid': 'owner2',
      'title': 'P2',
      'assignedPmUid': null,
      'teamMemberUids': ['builder1'],
      'collaboratorUids': <String>[],
      'observerUids': <String>[],
      'createdAt': DateTime(2024),
      'updatedAt': DateTime(2024),
      'status': 'active',
      'budget': 0,
      'estimateTotalGhs': 0,
      'amountSpent': 0,
      'region': '',
      'currency': 'GHS',
      'currencySymbol': 'GH₵',
      'budgetAlertThreshold': 0.8,
      'teamMembers': <Map>[],
      'contingencyGhs': 0,
      'schemaVersion': 1,
    });

    final svc = ProjectService(db: db);
    final (projects, _) = await svc.fetchBuilderProjectsPage('builder1');

    expect(projects.map((p) => p.id), containsAll(['p1', 'p2']));
    expect(projects.length, 2); // no duplicates
  });

  test('fetchBuilderProjectsPage deduplicates project in both assignedPmUid and teamMemberUids', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('projects').doc('p1').set({
      'ownerUid': 'owner1',
      'title': 'P1',
      'assignedPmUid': 'builder1',
      'teamMemberUids': ['builder1'], // appears in BOTH queries
      'collaboratorUids': <String>[],
      'observerUids': <String>[],
      'createdAt': DateTime(2024),
      'updatedAt': DateTime(2024),
      'status': 'active',
      'budget': 0,
      'estimateTotalGhs': 0,
      'amountSpent': 0,
      'region': '',
      'currency': 'GHS',
      'currencySymbol': 'GH₵',
      'budgetAlertThreshold': 0.8,
      'teamMembers': <Map>[],
      'contingencyGhs': 0,
      'schemaVersion': 1,
    });

    final svc = ProjectService(db: db);
    final (projects, _) = await svc.fetchBuilderProjectsPage('builder1');

    expect(projects.length, 1); // no duplicates
    expect(projects.first.id, 'p1');
  });

  test('fetchBuilderProjectsPage returns projects sorted newest-first', () async {
    final db = FakeFirebaseFirestore();
    final older = DateTime(2023, 1, 1);
    final newer = DateTime(2024, 6, 1);

    await db.collection('projects').doc('old').set({
      'ownerUid': 'owner1',
      'title': 'Old',
      'assignedPmUid': 'builder1',
      'teamMemberUids': <String>[],
      'collaboratorUids': <String>[],
      'observerUids': <String>[],
      'createdAt': older,
      'updatedAt': older,
      'status': 'active',
      'budget': 0,
      'estimateTotalGhs': 0,
      'amountSpent': 0,
      'region': '',
      'currency': 'GHS',
      'currencySymbol': 'GH₵',
      'budgetAlertThreshold': 0.8,
      'teamMembers': <Map>[],
      'contingencyGhs': 0,
      'schemaVersion': 1,
    });
    await db.collection('projects').doc('new').set({
      'ownerUid': 'owner2',
      'title': 'New',
      'assignedPmUid': null,
      'teamMemberUids': ['builder1'],
      'collaboratorUids': <String>[],
      'observerUids': <String>[],
      'createdAt': newer,
      'updatedAt': newer,
      'status': 'active',
      'budget': 0,
      'estimateTotalGhs': 0,
      'amountSpent': 0,
      'region': '',
      'currency': 'GHS',
      'currencySymbol': 'GH₵',
      'budgetAlertThreshold': 0.8,
      'teamMembers': <Map>[],
      'contingencyGhs': 0,
      'schemaVersion': 1,
    });

    final svc = ProjectService(db: db);
    final (projects, _) = await svc.fetchBuilderProjectsPage('builder1');

    expect(projects.first.id, 'new');
    expect(projects.last.id, 'old');
  });

  test('projectsForBuilder stream includes assignedPmUid and teamMemberUids projects', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('projects').doc('p1').set({
      'ownerUid': 'owner1',
      'title': 'P1',
      'assignedPmUid': 'builder1',
      'teamMemberUids': <String>[],
      'collaboratorUids': <String>[],
      'observerUids': <String>[],
      'createdAt': DateTime(2024, 6, 1),
      'updatedAt': DateTime(2024, 6, 1),
      'status': 'active',
      'budget': 0,
      'estimateTotalGhs': 0,
      'amountSpent': 0,
      'region': '',
      'currency': 'GHS',
      'currencySymbol': 'GH₵',
      'budgetAlertThreshold': 0.8,
      'teamMembers': <Map>[],
      'contingencyGhs': 0,
      'schemaVersion': 1,
    });
    await db.collection('projects').doc('p2').set({
      'ownerUid': 'owner2',
      'title': 'P2',
      'assignedPmUid': null,
      'teamMemberUids': ['builder1'],
      'collaboratorUids': <String>[],
      'observerUids': <String>[],
      'createdAt': DateTime(2024, 1, 1),
      'updatedAt': DateTime(2024, 1, 1),
      'status': 'active',
      'budget': 0,
      'estimateTotalGhs': 0,
      'amountSpent': 0,
      'region': '',
      'currency': 'GHS',
      'currencySymbol': 'GH₵',
      'budgetAlertThreshold': 0.8,
      'teamMembers': <Map>[],
      'contingencyGhs': 0,
      'schemaVersion': 1,
    });

    final svc = ProjectService(db: db);
    final stream = svc.projectsForBuilder('builder1');
    final projects = await stream.first;

    expect(projects.map((p) => p.id), containsAll(['p1', 'p2']));
    expect(projects.length, 2);
    expect(projects.first.id, 'p1'); // p1 newer, appears first
  });
}
