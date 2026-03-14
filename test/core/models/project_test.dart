// test/core/models/project_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wysebrix/core/models/project.dart';

void main() {
  group('Project model', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
    });

    final baseProject = Project(
      id: '',
      ownerUid: 'uid123',
      ownerName: 'Jane Doe',
      title: 'My House',
      description: 'A beautiful 3-bedroom',
      location: 'Tema, Community 9',
      region: 'Greater Accra',
      budget: 350000,
      amountSpent: 50000,
      status: ProjectStatus.active,
      createdAt: DateTime(2025, 1, 15),
      updatedAt: DateTime(2025, 2, 1),
    );

    test('toMap contains all required fields', () {
      final map = baseProject.toMap();
      expect(map['ownerUid'], 'uid123');
      expect(map['ownerName'], 'Jane Doe');
      expect(map['title'], 'My House');
      expect(map['description'], 'A beautiful 3-bedroom');
      expect(map['location'], 'Tema, Community 9');
      expect(map['region'], 'Greater Accra');
      expect(map['budget'], 350000.0);
      expect(map['amountSpent'], 50000.0);
      expect(map['status'], 'active');
    });

    test('toMap omits null optional fields', () {
      final project = Project(
        id: '',
        ownerUid: 'uid1',
        title: 'Minimal',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final map = project.toMap();
      expect(map.containsKey('ownerName'), isFalse);
      expect(map.containsKey('description'), isFalse);
      expect(map.containsKey('location'), isFalse);
      expect(map.containsKey('assignedPmUid'), isFalse);
    });

    test('round-trips through Firestore correctly', () async {
      final ref = fakeFirestore.collection('projects').doc();
      await ref.set(baseProject.toMap());

      final snap = await ref.get();
      final parsed = Project.fromDoc(snap);

      expect(parsed.ownerUid, baseProject.ownerUid);
      expect(parsed.title, baseProject.title);
      expect(parsed.description, baseProject.description);
      expect(parsed.location, baseProject.location);
      expect(parsed.region, baseProject.region);
      expect(parsed.budget, baseProject.budget);
      expect(parsed.amountSpent, baseProject.amountSpent);
      expect(parsed.status, ProjectStatus.active);
    });

    test('fromDoc defaults missing fields safely', () async {
      final ref = fakeFirestore.collection('projects').doc();
      await ref.set({'ownerUid': 'uid1', 'title': 'Min'});

      final snap = await ref.get();
      final parsed = Project.fromDoc(snap);

      expect(parsed.budget, 0.0);
      expect(parsed.amountSpent, 0.0);
      expect(parsed.status, ProjectStatus.planning);
      expect(parsed.region, '');
      expect(parsed.description, isNull);
    });

    test('projectStatusFromString handles all valid values', () {
      expect(projectStatusFromString('planning'), ProjectStatus.planning);
      expect(projectStatusFromString('active'), ProjectStatus.active);
      expect(projectStatusFromString('paused'), ProjectStatus.paused);
      expect(projectStatusFromString('completed'), ProjectStatus.completed);
      expect(projectStatusFromString(null), ProjectStatus.planning);
      expect(projectStatusFromString('unknown'), ProjectStatus.planning);
    });

    test('copyWith updates only specified fields', () {
      final updated = baseProject.copyWith(
        title: 'Updated Title',
        status: ProjectStatus.completed,
      );
      expect(updated.title, 'Updated Title');
      expect(updated.status, ProjectStatus.completed);
      expect(updated.ownerUid, baseProject.ownerUid);
      expect(updated.budget, baseProject.budget);
    });

    test('status labels are non-empty', () {
      for (final s in ProjectStatus.values) {
        expect(s.label, isNotEmpty);
        expect(s.firestoreValue, isNotEmpty);
      }
    });
  });
}
