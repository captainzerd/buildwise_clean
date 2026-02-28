// lib/core/models/phase.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum PhaseStatus { pending, inProgress, completed }

extension PhaseStatusLabel on PhaseStatus {
  String get label => switch (this) {
        PhaseStatus.pending => 'Pending',
        PhaseStatus.inProgress => 'In Progress',
        PhaseStatus.completed => 'Completed',
      };

  String get firestoreValue => switch (this) {
        PhaseStatus.pending => 'pending',
        PhaseStatus.inProgress => 'in_progress',
        PhaseStatus.completed => 'completed',
      };
}

PhaseStatus phaseStatusFromString(String? s) => switch (s) {
      'in_progress' => PhaseStatus.inProgress,
      'completed' => PhaseStatus.completed,
      _ => PhaseStatus.pending,
    };

@immutable
class Phase {
  const Phase({
    required this.id,
    required this.name,
    required this.order,
    required this.status,
    required this.createdAt,
    this.notes,
    this.estimatedCostGhs,
    this.actualCostGhs,
    this.startDate,
    this.endDate,
    this.completionPhotoUrls = const [],
  });

  final String id;
  final String name;
  final int order;
  final PhaseStatus status;
  final String? notes;
  final double? estimatedCostGhs;
  final double? actualCostGhs;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime createdAt;
  final List<String> completionPhotoUrls;

  factory Phase.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Phase(
      id: doc.id,
      name: d['name'] as String? ?? '',
      order: (d['order'] as num?)?.toInt() ?? 0,
      status: phaseStatusFromString(d['status'] as String?),
      notes: d['notes'] as String?,
      estimatedCostGhs: (d['estimatedCostGhs'] as num?)?.toDouble(),
      actualCostGhs: (d['actualCostGhs'] as num?)?.toDouble(),
      startDate: (d['startDate'] as Timestamp?)?.toDate(),
      endDate: (d['endDate'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completionPhotoUrls:
          (d['completionPhotoUrls'] as List?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'order': order,
        'status': status.firestoreValue,
        if (notes != null) 'notes': notes,
        if (estimatedCostGhs != null) 'estimatedCostGhs': estimatedCostGhs,
        if (actualCostGhs != null) 'actualCostGhs': actualCostGhs,
        if (startDate != null) 'startDate': Timestamp.fromDate(startDate!),
        if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
        'createdAt': Timestamp.fromDate(createdAt),
        if (completionPhotoUrls.isNotEmpty)
          'completionPhotoUrls': completionPhotoUrls,
      };

  Phase copyWith({
    String? name,
    int? order,
    PhaseStatus? status,
    String? notes,
    double? estimatedCostGhs,
    double? actualCostGhs,
  }) =>
      Phase(
        id: id,
        name: name ?? this.name,
        order: order ?? this.order,
        status: status ?? this.status,
        notes: notes ?? this.notes,
        estimatedCostGhs: estimatedCostGhs ?? this.estimatedCostGhs,
        actualCostGhs: actualCostGhs ?? this.actualCostGhs,
        startDate: startDate,
        endDate: endDate,
        createdAt: createdAt,
      );
}
