// lib/core/models/project.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'team_member.dart';

enum ProjectStatus { planning, active, paused, completed }

extension ProjectStatusLabel on ProjectStatus {
  String get label => switch (this) {
        ProjectStatus.planning => 'Planning',
        ProjectStatus.active => 'Active',
        ProjectStatus.paused => 'Paused',
        ProjectStatus.completed => 'Completed',
      };

  String get firestoreValue => switch (this) {
        ProjectStatus.planning => 'planning',
        ProjectStatus.active => 'active',
        ProjectStatus.paused => 'paused',
        ProjectStatus.completed => 'completed',
      };
}

ProjectStatus projectStatusFromString(String? s) => switch (s) {
      'active' => ProjectStatus.active,
      'paused' => ProjectStatus.paused,
      'completed' => ProjectStatus.completed,
      _ => ProjectStatus.planning,
    };

@immutable
class Project {
  const Project({
    required this.id,
    required this.ownerUid,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.ownerName,
    this.description,
    this.location,
    this.latitude,
    this.longitude,
    this.projectType,
    this.buildingType,
    this.architecturePlanUrl,
    this.region = '',
    this.currency = 'GHS',
    this.currencySymbol = 'GH₵',
    this.budget = 0,
    this.estimateTotalGhs = 0,
    this.amountSpent = 0,
    this.status = ProjectStatus.planning,
    this.assignedPmUid,
    this.assignedPmName,
    this.teamMembers = const [],
    this.teamMemberUids = const [],
    this.collaboratorUids = const [],
    this.observerUids = const [],
    this.budgetAlertThreshold = 0.8,
    this.schemaVersion = 1,
    this.permitNumber,
    this.permitApprovalDate,
    this.contingencyGhs = 0,
    this.specQuality,
    this.specFoundation,
    this.specSoil,
    this.specRoof,
    this.specMETier,
  });

  final String id;
  final String ownerUid;
  final String? ownerName;
  final String title;
  final String? description;
  final String? location;

  /// GPS coordinates — null if location was entered as text only.
  final double? latitude;
  final double? longitude;

  /// 'residential' | 'commercial' | 'industrial' | 'infrastructure'
  final String? projectType;

  /// 'bungalow' | 'duplex' | 'terraced' | 'apartment_block' |
  /// 'office' | 'warehouse' | 'mixed_use' | 'other'
  final String? buildingType;

  /// Deprecated. Architecture plans are now stored as ProjectDocument
  /// with category: DocumentCategory.architecturalDrawing.
  /// Kept for backward-compatibility with existing Firestore data.
  final String? architecturePlanUrl;

  final String region;
  final String currency;
  final String currencySymbol;
  final double budget;
  final double estimateTotalGhs;
  final double amountSpent;
  final ProjectStatus status;

  /// Legacy single-PM assignment kept for backward-compat Firestore queries.
  final String? assignedPmUid;
  final String? assignedPmName;

  /// Full project team (multi-contractor support).
  final List<TeamMember> teamMembers;

  /// Derived list of UIDs for Firestore array-contains queries.
  final List<String> teamMemberUids;

  /// Members who can write phases/costs/updates (subset of teamMemberUids).
  final List<String> collaboratorUids;

  /// Members who can only read + chat (subset of teamMemberUids).
  final List<String> observerUids;

  final double budgetAlertThreshold;
  final DateTime createdAt;
  final DateTime updatedAt;
  /// Firestore document schema version for forward-compatible migrations.
  final int schemaVersion;
  final String? permitNumber;
  final DateTime? permitApprovalDate;
  final double contingencyGhs;

  /// QS specification fields — optional, populated when creating from estimate.
  final String? specQuality;    // Economy | Standard | Premium
  final String? specFoundation; // Strip | Raft | Pad | Pile
  final String? specSoil;       // Firm | Soft | Waterlogged | Laterite
  final String? specRoof;       // Pitched sheet | Concrete flat | Tile
  final String? specMETier;     // Basic | Enhanced

  // ── Firestore ──

  factory Project.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final membersRaw = (d['teamMembers'] as List?)?.cast<Map>() ?? [];
    return Project(
      id: doc.id,
      ownerUid: d['ownerUid'] as String? ?? '',
      ownerName: d['ownerName'] as String?,
      title: d['title'] as String? ?? '',
      description: d['description'] as String?,
      location: d['location'] as String?,
      latitude: (d['latitude'] as num?)?.toDouble(),
      longitude: (d['longitude'] as num?)?.toDouble(),
      projectType: d['projectType'] as String?,
      buildingType: d['buildingType'] as String?,
      architecturePlanUrl: d['architecturePlanUrl'] as String?,
      region: d['region'] as String? ?? '',
      currency: d['currency'] as String? ?? 'GHS',
      currencySymbol: d['currencySymbol'] as String? ?? 'GH₵',
      budget: (d['budget'] as num?)?.toDouble() ?? 0,
      estimateTotalGhs: (d['estimateTotalGhs'] as num?)?.toDouble() ?? 0,
      amountSpent: (d['amountSpent'] as num?)?.toDouble() ?? 0,
      status: projectStatusFromString(d['status'] as String?),
      assignedPmUid: d['assignedPmUid'] as String?,
      assignedPmName: d['assignedPmName'] as String?,
      teamMembers: membersRaw
          .map((m) => TeamMember.fromMap(Map<String, dynamic>.from(m)))
          .toList(),
      teamMemberUids:
          (d['teamMemberUids'] as List?)?.cast<String>() ?? const [],
      collaboratorUids:
          (d['collaboratorUids'] as List?)?.cast<String>() ?? const [],
      observerUids:
          (d['observerUids'] as List?)?.cast<String>() ?? const [],
      budgetAlertThreshold:
          (d['budgetAlertThreshold'] as num?)?.toDouble() ?? 0.8,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      schemaVersion: (d['schemaVersion'] as num?)?.toInt() ?? 1,
      permitNumber: d['permitNumber'] as String?,
      permitApprovalDate: (d['permitApprovalDate'] as Timestamp?)?.toDate(),
      contingencyGhs: (d['contingencyGhs'] as num?)?.toDouble() ?? 0,
      specQuality: d['specQuality'] as String?,
      specFoundation: d['specFoundation'] as String?,
      specSoil: d['specSoil'] as String?,
      specRoof: d['specRoof'] as String?,
      specMETier: d['specMETier'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'ownerUid': ownerUid,
        if (ownerName != null) 'ownerName': ownerName,
        'title': title,
        if (description != null) 'description': description,
        if (location != null) 'location': location,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (projectType != null) 'projectType': projectType,
        if (buildingType != null) 'buildingType': buildingType,
        if (architecturePlanUrl != null)
          'architecturePlanUrl': architecturePlanUrl,
        'region': region,
        'currency': currency,
        'currencySymbol': currencySymbol,
        'budget': budget,
        'estimateTotalGhs': estimateTotalGhs,
        'amountSpent': amountSpent,
        'status': status.firestoreValue,
        if (assignedPmUid != null) 'assignedPmUid': assignedPmUid,
        if (assignedPmName != null) 'assignedPmName': assignedPmName,
        if (teamMembers.isNotEmpty)
          'teamMembers': teamMembers.map((m) => m.toMap()).toList(),
        'teamMemberUids': teamMemberUids,
        'collaboratorUids': collaboratorUids,
        'observerUids': observerUids,
        'budgetAlertThreshold': budgetAlertThreshold,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'schemaVersion': schemaVersion,
        if (permitNumber != null) 'permitNumber': permitNumber,
        if (permitApprovalDate != null)
          'permitApprovalDate': Timestamp.fromDate(permitApprovalDate!),
        'contingencyGhs': contingencyGhs,
        if (specQuality != null) 'specQuality': specQuality!,
        if (specFoundation != null) 'specFoundation': specFoundation!,
        if (specSoil != null) 'specSoil': specSoil!,
        if (specRoof != null) 'specRoof': specRoof!,
        if (specMETier != null) 'specMETier': specMETier!,
      };

  Project copyWith({
    String? title,
    String? description,
    String? location,
    double? latitude,
    double? longitude,
    String? projectType,
    String? buildingType,
    String? architecturePlanUrl,
    String? region,
    double? budget,
    double? amountSpent,
    ProjectStatus? status,
    String? assignedPmUid,
    String? assignedPmName,
    List<TeamMember>? teamMembers,
    List<String>? teamMemberUids,
    List<String>? collaboratorUids,
    List<String>? observerUids,
    double? budgetAlertThreshold,
    String? permitNumber,
    DateTime? permitApprovalDate,
    double? contingencyGhs,
    String? specQuality,
    String? specFoundation,
    String? specSoil,
    String? specRoof,
    String? specMETier,
  }) =>
      Project(
        id: id,
        ownerUid: ownerUid,
        ownerName: ownerName,
        title: title ?? this.title,
        description: description ?? this.description,
        location: location ?? this.location,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        projectType: projectType ?? this.projectType,
        buildingType: buildingType ?? this.buildingType,
        architecturePlanUrl: architecturePlanUrl ?? this.architecturePlanUrl,
        region: region ?? this.region,
        currency: currency,
        currencySymbol: currencySymbol,
        budget: budget ?? this.budget,
        estimateTotalGhs: estimateTotalGhs,
        amountSpent: amountSpent ?? this.amountSpent,
        status: status ?? this.status,
        assignedPmUid: assignedPmUid ?? this.assignedPmUid,
        assignedPmName: assignedPmName ?? this.assignedPmName,
        teamMembers: teamMembers ?? this.teamMembers,
        teamMemberUids: teamMemberUids ?? this.teamMemberUids,
        collaboratorUids: collaboratorUids ?? this.collaboratorUids,
        observerUids: observerUids ?? this.observerUids,
        budgetAlertThreshold:
            budgetAlertThreshold ?? this.budgetAlertThreshold,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        permitNumber: permitNumber ?? this.permitNumber,
        permitApprovalDate: permitApprovalDate ?? this.permitApprovalDate,
        contingencyGhs: contingencyGhs ?? this.contingencyGhs,
        specQuality: specQuality ?? this.specQuality,
        specFoundation: specFoundation ?? this.specFoundation,
        specSoil: specSoil ?? this.specSoil,
        specRoof: specRoof ?? this.specRoof,
        specMETier: specMETier ?? this.specMETier,
      );
}
