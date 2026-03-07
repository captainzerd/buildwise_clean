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
}
