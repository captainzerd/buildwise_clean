import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum BuilderRole { architect, contractor, engineer, surveyor, general }

extension BuilderRoleLabel on BuilderRole {
  String get label => switch (this) {
        BuilderRole.architect => 'Architect',
        BuilderRole.contractor => 'Contractor',
        BuilderRole.engineer => 'Engineer',
        BuilderRole.surveyor => 'Quantity Surveyor',
        BuilderRole.general => 'General Builder',
      };

  String get firestoreValue => switch (this) {
        BuilderRole.architect => 'architect',
        BuilderRole.contractor => 'contractor',
        BuilderRole.engineer => 'engineer',
        BuilderRole.surveyor => 'surveyor',
        BuilderRole.general => 'general',
      };
}

BuilderRole builderRoleFromString(String? s) => switch (s) {
      'contractor' => BuilderRole.contractor,
      'engineer' => BuilderRole.engineer,
      'surveyor' => BuilderRole.surveyor,
      'general' => BuilderRole.general,
      _ => BuilderRole.architect,
    };

/// Predefined trade tags that align with estimate cost categories and
/// vendor specialisations. Used for estimate → vendor matching.
const kBuilderTrades = [
  'Materials',
  'Labour',
  'Equipment',
  'Electricals',
  'Plumbing',
  'Roofing',
  'Tiling & Flooring',
  'Painting',
  'Professional Services',
  'Landscaping',
];

@immutable
class BuilderProfile {
  const BuilderProfile({
    required this.uid,
    required this.displayName,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
    this.bio = '',
    this.phone,
    this.email,
    this.photoUrl,
    this.location,
    this.region = '',
    this.specializations = const [],
    this.isActive = true,
    this.averageRating = 0.0,
    this.reviewCount = 0,
    this.yearsExperience,
    // New Sprint 4 fields
    this.availableForHire = true,
    this.minimumBudgetGhs,
    this.preferredRegions = const [],
    this.portfolioImageUrls = const [],
    this.projectsCompleted = 0,
    this.isVerified = false,
    this.whatsappNumber,
  });

  final String uid;
  final String displayName;
  final BuilderRole role;
  final String bio;
  final String? phone;
  final String? email;
  final String? photoUrl;
  final String? location;
  final String region;
  final List<String> specializations;
  final bool isActive;
  final double averageRating;
  final int reviewCount;
  final int? yearsExperience;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Sprint 4 additions
  final bool availableForHire;
  final double? minimumBudgetGhs;
  final List<String> preferredRegions;
  final List<String> portfolioImageUrls;
  final int projectsCompleted;
  final bool isVerified;
  final String? whatsappNumber;

  factory BuilderProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return BuilderProfile(
      uid: doc.id,
      displayName: d['displayName'] as String? ?? '',
      role: builderRoleFromString(d['role'] as String?),
      bio: d['bio'] as String? ?? '',
      phone: d['phone'] as String?,
      email: d['email'] as String?,
      photoUrl: d['photoUrl'] as String?,
      location: d['location'] as String?,
      region: d['region'] as String? ?? '',
      specializations:
          (d['specializations'] as List?)?.cast<String>() ?? const [],
      isActive: d['isActive'] as bool? ?? true,
      averageRating: (d['averageRating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (d['reviewCount'] as num?)?.toInt() ?? 0,
      yearsExperience: (d['yearsExperience'] as num?)?.toInt(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      availableForHire: d['availableForHire'] as bool? ?? true,
      minimumBudgetGhs: (d['minimumBudgetGhs'] as num?)?.toDouble(),
      preferredRegions:
          (d['preferredRegions'] as List?)?.cast<String>() ?? const [],
      portfolioImageUrls:
          (d['portfolioImageUrls'] as List?)?.cast<String>() ?? const [],
      projectsCompleted: (d['projectsCompleted'] as num?)?.toInt() ?? 0,
      isVerified: d['isVerified'] as bool? ?? false,
      whatsappNumber: d['whatsappNumber'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'role': role.firestoreValue,
        'bio': bio,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (location != null) 'location': location,
        'region': region,
        'specializations': specializations,
        'isActive': isActive,
        'averageRating': averageRating,
        'reviewCount': reviewCount,
        if (yearsExperience != null) 'yearsExperience': yearsExperience,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'availableForHire': availableForHire,
        if (minimumBudgetGhs != null) 'minimumBudgetGhs': minimumBudgetGhs,
        'preferredRegions': preferredRegions,
        'portfolioImageUrls': portfolioImageUrls,
        'projectsCompleted': projectsCompleted,
        'isVerified': isVerified,
        if (whatsappNumber != null) 'whatsappNumber': whatsappNumber,
      };

  BuilderProfile copyWith({
    String? displayName,
    BuilderRole? role,
    String? bio,
    String? phone,
    String? location,
    String? region,
    List<String>? specializations,
    bool? isActive,
    int? yearsExperience,
    bool? availableForHire,
    double? minimumBudgetGhs,
    List<String>? preferredRegions,
    List<String>? portfolioImageUrls,
    int? projectsCompleted,
    String? whatsappNumber,
  }) =>
      BuilderProfile(
        uid: uid,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
        bio: bio ?? this.bio,
        phone: phone ?? this.phone,
        email: email,
        photoUrl: photoUrl,
        location: location ?? this.location,
        region: region ?? this.region,
        specializations: specializations ?? this.specializations,
        isActive: isActive ?? this.isActive,
        averageRating: averageRating,
        reviewCount: reviewCount,
        yearsExperience: yearsExperience ?? this.yearsExperience,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        availableForHire: availableForHire ?? this.availableForHire,
        minimumBudgetGhs: minimumBudgetGhs ?? this.minimumBudgetGhs,
        preferredRegions: preferredRegions ?? this.preferredRegions,
        portfolioImageUrls: portfolioImageUrls ?? this.portfolioImageUrls,
        projectsCompleted: projectsCompleted ?? this.projectsCompleted,
        isVerified: isVerified,
        whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      );
}
