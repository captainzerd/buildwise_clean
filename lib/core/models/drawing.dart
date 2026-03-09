// lib/core/models/drawing.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class DrawingAnnotation {
  const DrawingAnnotation({
    required this.id,
    required this.x,
    required this.y,
    required this.comment,
    required this.authorUid,
    required this.authorName,
    required this.createdAt,
  });

  final String id;
  final String comment;
  final String authorUid;
  final String authorName;
  final double x;
  final double y;
  final DateTime createdAt;

  factory DrawingAnnotation.fromMap(Map<String, dynamic> m) {
    return DrawingAnnotation(
      id: m['id'] as String? ?? '',
      x: (m['x'] as num?)?.toDouble() ?? 0.0,
      y: (m['y'] as num?)?.toDouble() ?? 0.0,
      comment: m['comment'] as String? ?? '',
      authorUid: m['authorUid'] as String? ?? '',
      authorName: m['authorName'] as String? ?? '',
      createdAt: m['createdAt'] is Timestamp
          ? (m['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'x': x,
        'y': y,
        'comment': comment,
        'authorUid': authorUid,
        'authorName': authorName,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

@immutable
class Drawing {
  const Drawing({
    required this.id,
    required this.name,
    required this.fileUrl,
    required this.fileType,
    required this.uploadedBy,
    required this.uploadedByName,
    required this.uploadedAt,
    this.annotations = const [],
  });

  final String id;
  final String name;
  final String fileUrl;
  final String fileType; // 'image' | 'pdf'
  final String uploadedBy;
  final String uploadedByName;
  final DateTime uploadedAt;
  final List<DrawingAnnotation> annotations;

  factory Drawing.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data()!;
    final rawAnnotations = m['annotations'];
    final annotations = rawAnnotations is List
        ? rawAnnotations
            .whereType<Map<String, dynamic>>()
            .map(DrawingAnnotation.fromMap)
            .toList()
        : <DrawingAnnotation>[];
    return Drawing(
      id: doc.id,
      name: m['name'] as String? ?? '',
      fileUrl: m['fileUrl'] as String? ?? '',
      fileType: m['fileType'] as String? ?? 'image',
      uploadedBy: m['uploadedBy'] as String? ?? '',
      uploadedByName: m['uploadedByName'] as String? ?? '',
      uploadedAt: m['uploadedAt'] is Timestamp
          ? (m['uploadedAt'] as Timestamp).toDate()
          : DateTime.now(),
      annotations: annotations,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'fileUrl': fileUrl,
        'fileType': fileType,
        'uploadedBy': uploadedBy,
        'uploadedByName': uploadedByName,
        'uploadedAt': Timestamp.fromDate(uploadedAt),
        'annotations': annotations.map((a) => a.toMap()).toList(),
      };
}
