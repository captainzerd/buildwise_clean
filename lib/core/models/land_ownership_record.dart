// lib/core/models/land_ownership_record.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum LandTitleType {
  leasehold('leasehold', 'Leasehold'),
  freehold('freehold', 'Freehold'),
  customaryLand('customary_land', 'Customary Land'),
  governmentLease('government_lease', 'Government Lease'),
  indenture('indenture', 'Indenture'),
  other('other', 'Other');

  const LandTitleType(this.firestoreValue, this.label);
  final String firestoreValue;
  final String label;

  static LandTitleType fromString(String v) =>
      values.firstWhere((e) => e.firestoreValue == v, orElse: () => other);
}

enum LandOwnershipStatus {
  notStarted('not_started', 'Not Started'),
  inProgress('in_progress', 'In Progress'),
  verified('verified', 'Verified'),
  disputed('disputed', 'Disputed');

  const LandOwnershipStatus(this.firestoreValue, this.label);
  final String firestoreValue;
  final String label;

  static LandOwnershipStatus fromString(String v) => values.firstWhere(
        (e) => e.firestoreValue == v,
        orElse: () => notStarted,
      );
}

class LandOwnershipRecord {
  LandOwnershipRecord({
    required this.id,
    required this.projectId,
    required this.ownerUid,
    this.titleType = LandTitleType.other,
    this.status = LandOwnershipStatus.notStarted,
    this.titleDeedNumber,
    this.plotNumber,
    this.locality,
    this.region,
    this.landArea,
    this.landAreaUnit = 'acres',
    this.registrationDate,
    this.titleDeedUrl,
    this.siteMapUrl,
    this.encumbrances,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String projectId;
  final String ownerUid;
  final LandTitleType titleType;
  final LandOwnershipStatus status;
  final String? titleDeedNumber;
  final String? plotNumber;
  final String? locality;
  final String? region;
  final double? landArea;
  final String landAreaUnit;
  final DateTime? registrationDate;
  final String? titleDeedUrl;
  final String? siteMapUrl;
  final String? encumbrances;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  factory LandOwnershipRecord.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data()!;
    return LandOwnershipRecord(
      id: doc.id,
      projectId: d['projectId'] as String? ?? '',
      ownerUid: d['ownerUid'] as String? ?? '',
      titleType: LandTitleType.fromString(d['titleType'] as String? ?? ''),
      status: LandOwnershipStatus.fromString(d['status'] as String? ?? ''),
      titleDeedNumber: d['titleDeedNumber'] as String?,
      plotNumber: d['plotNumber'] as String?,
      locality: d['locality'] as String?,
      region: d['region'] as String?,
      landArea: (d['landArea'] as num?)?.toDouble(),
      landAreaUnit: d['landAreaUnit'] as String? ?? 'acres',
      registrationDate: d['registrationDate'] == null
          ? null
          : DateTime.tryParse(d['registrationDate'] as String),
      titleDeedUrl: d['titleDeedUrl'] as String?,
      siteMapUrl: d['siteMapUrl'] as String?,
      encumbrances: d['encumbrances'] as String?,
      notes: d['notes'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'ownerUid': ownerUid,
        'titleType': titleType.firestoreValue,
        'status': status.firestoreValue,
        if (titleDeedNumber != null) 'titleDeedNumber': titleDeedNumber,
        if (plotNumber != null) 'plotNumber': plotNumber,
        if (locality != null) 'locality': locality,
        if (region != null) 'region': region,
        if (landArea != null) 'landArea': landArea,
        'landAreaUnit': landAreaUnit,
        if (registrationDate != null)
          'registrationDate': registrationDate!.toIso8601String(),
        if (titleDeedUrl != null) 'titleDeedUrl': titleDeedUrl,
        if (siteMapUrl != null) 'siteMapUrl': siteMapUrl,
        if (encumbrances != null) 'encumbrances': encumbrances,
        if (notes != null) 'notes': notes,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  LandOwnershipRecord copyWith({
    LandTitleType? titleType,
    LandOwnershipStatus? status,
    String? titleDeedNumber,
    String? plotNumber,
    String? locality,
    String? region,
    double? landArea,
    String? landAreaUnit,
    DateTime? registrationDate,
    String? titleDeedUrl,
    String? siteMapUrl,
    String? encumbrances,
    String? notes,
  }) =>
      LandOwnershipRecord(
        id: id,
        projectId: projectId,
        ownerUid: ownerUid,
        titleType: titleType ?? this.titleType,
        status: status ?? this.status,
        titleDeedNumber: titleDeedNumber ?? this.titleDeedNumber,
        plotNumber: plotNumber ?? this.plotNumber,
        locality: locality ?? this.locality,
        region: region ?? this.region,
        landArea: landArea ?? this.landArea,
        landAreaUnit: landAreaUnit ?? this.landAreaUnit,
        registrationDate: registrationDate ?? this.registrationDate,
        titleDeedUrl: titleDeedUrl ?? this.titleDeedUrl,
        siteMapUrl: siteMapUrl ?? this.siteMapUrl,
        encumbrances: encumbrances ?? this.encumbrances,
        notes: notes ?? this.notes,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
