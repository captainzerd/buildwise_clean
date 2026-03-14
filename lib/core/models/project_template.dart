// lib/core/models/project_template.dart
//
// A lightweight snapshot of a project's metadata + phases that an owner can
// reuse when creating new projects. Stored at project_templates/{id}.

import 'package:cloud_firestore/cloud_firestore.dart';

class TemplatePhase {
  const TemplatePhase({required this.name, required this.estimatedCostGhs});

  final String name;
  final double estimatedCostGhs;

  factory TemplatePhase.fromMap(Map<String, dynamic> m) => TemplatePhase(
        name: m['name'] as String? ?? '',
        estimatedCostGhs: (m['estimatedCostGhs'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'estimatedCostGhs': estimatedCostGhs,
      };
}

class ProjectTemplate {
  const ProjectTemplate({
    required this.id,
    required this.ownerUid,
    required this.name,
    required this.description,
    required this.region,
    required this.budget,
    required this.phases,
    required this.createdAt,
  });

  final String id;
  final String ownerUid;

  /// Display name for the template (e.g. "3-Bedroom House — Accra").
  final String name;
  final String description;
  final String region;
  final double budget;
  final List<TemplatePhase> phases;
  final DateTime createdAt;

  factory ProjectTemplate.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return ProjectTemplate(
      id: doc.id,
      ownerUid: d['ownerUid'] as String? ?? '',
      name: d['name'] as String? ?? '',
      description: d['description'] as String? ?? '',
      region: d['region'] as String? ?? '',
      budget: (d['budget'] as num?)?.toDouble() ?? 0,
      phases: (d['phases'] as List<dynamic>? ?? [])
          .map((e) => TemplatePhase.fromMap(e as Map<String, dynamic>))
          .toList(),
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'ownerUid': ownerUid,
        'name': name,
        'description': description,
        'region': region,
        'budget': budget,
        'phases': phases.map((p) => p.toMap()).toList(),
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
