// lib/core/services/project_template_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/project_template.dart';

class ProjectTemplateService {
  ProjectTemplateService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('project_templates');

  /// Real-time stream of all templates owned by [ownerUid].
  Stream<List<ProjectTemplate>> templatesStream(String ownerUid) =>
      _col
          .where('ownerUid', isEqualTo: ownerUid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (s) => s.docs
                .map(
                  (d) => ProjectTemplate.fromDoc(
                    d as DocumentSnapshot<Map<String, dynamic>>,
                  ),
                )
                .toList(),
          );

  /// Save a new template document.
  Future<String> saveTemplate(ProjectTemplate template) async {
    final ref = await _col.add(template.toMap());
    return ref.id;
  }

  /// Delete a template by ID.
  Future<void> deleteTemplate(String templateId) =>
      _col.doc(templateId).delete();
}
