// lib/core/models/project_document.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum DocumentVisibility {
  all,
  ownerOnly,
  ownerAndObservers;

  String get firestoreValue => switch (this) {
        DocumentVisibility.all => 'all',
        DocumentVisibility.ownerOnly => 'ownerOnly',
        DocumentVisibility.ownerAndObservers => 'ownerAndObservers',
      };

  String get label => switch (this) {
        DocumentVisibility.all => 'All members',
        DocumentVisibility.ownerOnly => 'Owner only',
        DocumentVisibility.ownerAndObservers => 'Owner & observers',
      };

  static DocumentVisibility fromString(String? value) => switch (value) {
        'ownerOnly' => DocumentVisibility.ownerOnly,
        'ownerAndObservers' => DocumentVisibility.ownerAndObservers,
        _ => DocumentVisibility.all,
      };
}

enum DocumentCategory {
  architecturalDrawing,
  structuralDrawing,
  landTitle,
  indenture,
  permit,
  boq,
  receipt,
  contract,
  other;

  String get label => switch (this) {
        DocumentCategory.architecturalDrawing => 'Architectural Drawing',
        DocumentCategory.structuralDrawing => 'Structural Drawing',
        DocumentCategory.landTitle => 'Land Title',
        DocumentCategory.indenture => 'Indenture / Deed',
        DocumentCategory.permit => 'Building Permit',
        DocumentCategory.boq => 'Bill of Quantities',
        DocumentCategory.receipt => 'Receipt / Invoice',
        DocumentCategory.contract => 'Contract',
        DocumentCategory.other => 'Other',
      };

  String get firestoreValue => switch (this) {
        DocumentCategory.architecturalDrawing => 'architecturalDrawing',
        DocumentCategory.structuralDrawing => 'structuralDrawing',
        DocumentCategory.landTitle => 'landTitle',
        DocumentCategory.indenture => 'indenture',
        DocumentCategory.permit => 'permit',
        DocumentCategory.boq => 'boq',
        DocumentCategory.receipt => 'receipt',
        DocumentCategory.contract => 'contract',
        DocumentCategory.other => 'other',
      };

  IconData get icon => switch (this) {
        DocumentCategory.architecturalDrawing => Icons.architecture,
        DocumentCategory.structuralDrawing => Icons.engineering,
        DocumentCategory.landTitle => Icons.landscape,
        DocumentCategory.indenture => Icons.gavel,
        DocumentCategory.permit => Icons.approval,
        DocumentCategory.boq => Icons.format_list_numbered,
        DocumentCategory.receipt => Icons.receipt_long,
        DocumentCategory.contract => Icons.handshake,
        DocumentCategory.other => Icons.attach_file,
      };

  static DocumentCategory fromString(String? value) => switch (value) {
        'architecturalDrawing' => DocumentCategory.architecturalDrawing,
        'structuralDrawing' => DocumentCategory.structuralDrawing,
        'landTitle' => DocumentCategory.landTitle,
        'indenture' => DocumentCategory.indenture,
        'permit' => DocumentCategory.permit,
        'boq' => DocumentCategory.boq,
        'receipt' => DocumentCategory.receipt,
        'contract' => DocumentCategory.contract,
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
    this.expiresAt,
    this.visibility = DocumentVisibility.all,
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

  /// Optional expiry date (for permits, land titles, etc.)
  final DateTime? expiresAt;

  /// Who can see this document.
  final DocumentVisibility visibility;

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  bool get expiresWithin30Days =>
      expiresAt != null &&
      !isExpired &&
      expiresAt!.isBefore(DateTime.now().add(const Duration(days: 30)));

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
      expiresAt: (d['expiresAt'] as Timestamp?)?.toDate(),
      visibility: DocumentVisibility.fromString(d['visibility'] as String?),
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
        if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
        'visibility': visibility.firestoreValue,
      };
}
