// lib/core/models/project_document.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum DocumentCategory {
  landTitle,
  indenture,
  permit,
  receipt,
  other;

  String get label => switch (this) {
        DocumentCategory.landTitle => 'Land Title',
        DocumentCategory.indenture => 'Indenture',
        DocumentCategory.permit => 'Permit',
        DocumentCategory.receipt => 'Receipt',
        DocumentCategory.other => 'Other',
      };

  String get firestoreValue => switch (this) {
        DocumentCategory.landTitle => 'landTitle',
        DocumentCategory.indenture => 'indenture',
        DocumentCategory.permit => 'permit',
        DocumentCategory.receipt => 'receipt',
        DocumentCategory.other => 'other',
      };

  static DocumentCategory fromString(String? value) => switch (value) {
        'landTitle' => DocumentCategory.landTitle,
        'indenture' => DocumentCategory.indenture,
        'permit' => DocumentCategory.permit,
        'receipt' => DocumentCategory.receipt,
        _ => DocumentCategory.other,
      };
}

class ProjectDocument {
  const ProjectDocument({
    required this.id,
    required this.uploaderUid,
    required this.name,
    required this.url,
    required this.createdAt,
    this.category = DocumentCategory.other,
    this.storagePath,
    this.contentType,
    this.sizeBytes,
  });

  final String id;
  final String uploaderUid;
  final String name;
  final String url;
  final DocumentCategory category;
  final String? storagePath;
  final String? contentType;
  final int? sizeBytes;
  final DateTime createdAt;

  factory ProjectDocument.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc,) {
    final d = doc.data() ?? {};
    return ProjectDocument(
      id: doc.id,
      uploaderUid: d['uploaderUid'] as String? ?? '',
      name: d['name'] as String? ?? '',
      url: d['url'] as String? ?? '',
      category: DocumentCategory.fromString(d['category'] as String?),
      storagePath: d['storagePath'] as String?,
      contentType: d['contentType'] as String?,
      sizeBytes: (d['sizeBytes'] as num?)?.toInt(),
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'uploaderUid': uploaderUid,
        'name': name,
        'url': url,
        'category': category.firestoreValue,
        if (storagePath != null) 'storagePath': storagePath,
        if (contentType != null) 'contentType': contentType,
        if (sizeBytes != null) 'sizeBytes': sizeBytes,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
