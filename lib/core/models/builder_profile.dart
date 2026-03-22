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

/// NCA contractor classes used by the National Construction Authority, Ghana.
/// G = general contractor, D = specialist, K = sub-contractor.
const kNcaClasses = [
  'G1', 'G2', 'G3', 'G4', 'G5', 'G6', 'G7', 'G8',
  'D1', 'D2', 'D3', 'D4', 'D5', 'D6', 'D7', 'D8',
  'K1', 'K2', 'K3', 'K4', 'K5',
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
    this.availableForHire = true,
    this.minimumBudgetGhs,
    this.preferredRegions = const [],
    this.portfolioImageUrls = const [],
    this.projectsCompleted = 0,
    this.isVerified = false,
    this.whatsappNumber,
    this.graTin,
    this.giaNumber,
    this.gioeNumber,
    this.gredaMembership,
    this.ghanaCardNumber,
    this.verifiedAt,
    this.contractorGrade,
    this.licenceDocUrls = const {},
    this.licenceVerificationStatus = 'unverified',
    this.licenceVerifiedAt,
    this.trustScore = 0,
    // Business registration (Registrar General's Department)
    this.businessRegNumber,
    this.businessRegUrl,
    this.businessRegStatus = 'unverified',
    // NCA License (National Construction Authority)
    this.ncaLicenseNumber,
    this.ncaClass,
    // Insurance
    this.insurancePliUrl,
    this.insurancePliExpiry,
    this.insurancePiiUrl,
    this.insurancePiiExpiry,
    this.insuranceStatus = 'unverified',
    // Reputation scores (computed from reviews)
    this.projectSuccessScore = 0.0,
    this.safetyComplianceScore = 0.0,
    this.disputeCount = 0,
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

  final bool availableForHire;
  final double? minimumBudgetGhs;
  final List<String> preferredRegions;
  final List<String> portfolioImageUrls;
  final int projectsCompleted;
  final bool isVerified;
  final String? whatsappNumber;
  final String? graTin;
  final String? giaNumber;
  final String? gioeNumber;
  final String? gredaMembership;
  final String? ghanaCardNumber;
  final DateTime? verifiedAt;
  final String? contractorGrade;

  /// Keys: 'gia' | 'gioe' | 'greda' | 'nca'. Values: download URLs.
  final Map<String, String> licenceDocUrls;
  final String licenceVerificationStatus; // unverified | pending | verified | rejected
  final DateTime? licenceVerifiedAt;
  final int trustScore;

  // ── Business Registration (Registrar General's Department / DTIID) ──────────
  /// Certificate of Incorporation number (e.g. CS-123456789)
  final String? businessRegNumber;

  /// Firebase Storage URL of uploaded certificate of incorporation document.
  final String? businessRegUrl;

  /// 'unverified' | 'pending' | 'verified' | 'rejected'
  final String businessRegStatus;

  // ── NCA Licence (National Construction Authority) ────────────────────────────
  /// NCA registration/licence number.
  final String? ncaLicenseNumber;

  /// NCA class: 'G1'–'G8' (general), 'D1'–'D8' (specialist), 'K1'–'K5' (sub-contractor).
  final String? ncaClass;

  // ── Insurance ────────────────────────────────────────────────────────────────
  /// Public Liability Insurance document URL.
  final String? insurancePliUrl;

  /// PLI expiry date.
  final DateTime? insurancePliExpiry;

  /// Professional Indemnity Insurance document URL.
  final String? insurancePiiUrl;

  /// PII expiry date.
  final DateTime? insurancePiiExpiry;

  /// 'unverified' | 'pending' | 'verified' | 'expired'
  final String insuranceStatus;

  // ── Reputation Scores (computed, 0–100) ─────────────────────────────────────
  /// Average timeliness rating × 20. Updated after each review.
  final double projectSuccessScore;

  /// Average safety rating × 20. Updated after each review.
  final double safetyComplianceScore;

  /// Count of variation order escalations / formal disputes.
  final int disputeCount;

  // ── Computed helpers ─────────────────────────────────────────────────────────

  /// True if insurance is verified AND not expired.
  bool get isInsuranceValid {
    if (insuranceStatus != 'verified') return false;
    if (insurancePliExpiry != null &&
        insurancePliExpiry!.isBefore(DateTime.now())) {
      return false;
    }
    return true;
  }

  /// True if NCA licence document is in the licenceDocUrls map AND licence is verified.
  bool get isNcaVerified =>
      licenceVerificationStatus == 'verified' &&
      licenceDocUrls.containsKey('nca');

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
      graTin: d['graTin'] as String?,
      giaNumber: d['giaNumber'] as String?,
      gioeNumber: d['gioeNumber'] as String?,
      gredaMembership: d['gredaMembership'] as String?,
      ghanaCardNumber: d['ghanaCardNumber'] as String?,
      verifiedAt: (d['verifiedAt'] as Timestamp?)?.toDate(),
      contractorGrade: d['contractorGrade'] as String?,
      licenceDocUrls:
          (d['licenceDocUrls'] as Map<String, dynamic>?)
              ?.cast<String, String>() ??
              const {},
      licenceVerificationStatus:
          d['licenceVerificationStatus'] as String? ?? 'unverified',
      licenceVerifiedAt: (d['licenceVerifiedAt'] as Timestamp?)?.toDate(),
      trustScore: (d['trustScore'] as num?)?.toInt() ?? 0,
      // Business registration
      businessRegNumber: d['businessRegNumber'] as String?,
      businessRegUrl: d['businessRegUrl'] as String?,
      businessRegStatus: d['businessRegStatus'] as String? ?? 'unverified',
      // NCA
      ncaLicenseNumber: d['ncaLicenseNumber'] as String?,
      ncaClass: d['ncaClass'] as String?,
      // Insurance
      insurancePliUrl: d['insurancePliUrl'] as String?,
      insurancePliExpiry: (d['insurancePliExpiry'] as Timestamp?)?.toDate(),
      insurancePiiUrl: d['insurancePiiUrl'] as String?,
      insurancePiiExpiry: (d['insurancePiiExpiry'] as Timestamp?)?.toDate(),
      insuranceStatus: d['insuranceStatus'] as String? ?? 'unverified',
      // Reputation scores
      projectSuccessScore:
          (d['projectSuccessScore'] as num?)?.toDouble() ?? 0.0,
      safetyComplianceScore:
          (d['safetyComplianceScore'] as num?)?.toDouble() ?? 0.0,
      disputeCount: (d['disputeCount'] as num?)?.toInt() ?? 0,
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
        if (graTin != null) 'graTin': graTin,
        if (giaNumber != null) 'giaNumber': giaNumber,
        if (gioeNumber != null) 'gioeNumber': gioeNumber,
        if (gredaMembership != null) 'gredaMembership': gredaMembership,
        if (ghanaCardNumber != null) 'ghanaCardNumber': ghanaCardNumber,
        if (verifiedAt != null) 'verifiedAt': Timestamp.fromDate(verifiedAt!),
        if (contractorGrade != null) 'contractorGrade': contractorGrade,
        'licenceDocUrls': licenceDocUrls,
        'licenceVerificationStatus': licenceVerificationStatus,
        if (licenceVerifiedAt != null)
          'licenceVerifiedAt': Timestamp.fromDate(licenceVerifiedAt!),
        'trustScore': trustScore,
        // Business registration
        if (businessRegNumber != null) 'businessRegNumber': businessRegNumber,
        if (businessRegUrl != null) 'businessRegUrl': businessRegUrl,
        'businessRegStatus': businessRegStatus,
        // NCA
        if (ncaLicenseNumber != null) 'ncaLicenseNumber': ncaLicenseNumber,
        if (ncaClass != null) 'ncaClass': ncaClass,
        // Insurance
        if (insurancePliUrl != null) 'insurancePliUrl': insurancePliUrl,
        if (insurancePliExpiry != null)
          'insurancePliExpiry': Timestamp.fromDate(insurancePliExpiry!),
        if (insurancePiiUrl != null) 'insurancePiiUrl': insurancePiiUrl,
        if (insurancePiiExpiry != null)
          'insurancePiiExpiry': Timestamp.fromDate(insurancePiiExpiry!),
        'insuranceStatus': insuranceStatus,
        // Reputation scores
        'projectSuccessScore': projectSuccessScore,
        'safetyComplianceScore': safetyComplianceScore,
        'disputeCount': disputeCount,
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
    String? graTin,
    String? giaNumber,
    String? gioeNumber,
    String? gredaMembership,
    String? ghanaCardNumber,
    String? contractorGrade,
    Map<String, String>? licenceDocUrls,
    String? licenceVerificationStatus,
    DateTime? licenceVerifiedAt,
    int? trustScore,
    String? businessRegNumber,
    String? businessRegUrl,
    String? businessRegStatus,
    String? ncaLicenseNumber,
    String? ncaClass,
    String? insurancePliUrl,
    DateTime? insurancePliExpiry,
    String? insurancePiiUrl,
    DateTime? insurancePiiExpiry,
    String? insuranceStatus,
    double? projectSuccessScore,
    double? safetyComplianceScore,
    int? disputeCount,
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
        graTin: graTin ?? this.graTin,
        giaNumber: giaNumber ?? this.giaNumber,
        gioeNumber: gioeNumber ?? this.gioeNumber,
        gredaMembership: gredaMembership ?? this.gredaMembership,
        ghanaCardNumber: ghanaCardNumber ?? this.ghanaCardNumber,
        verifiedAt: verifiedAt,
        contractorGrade: contractorGrade ?? this.contractorGrade,
        licenceDocUrls: licenceDocUrls ?? this.licenceDocUrls,
        licenceVerificationStatus:
            licenceVerificationStatus ?? this.licenceVerificationStatus,
        licenceVerifiedAt: licenceVerifiedAt ?? this.licenceVerifiedAt,
        trustScore: trustScore ?? this.trustScore,
        businessRegNumber: businessRegNumber ?? this.businessRegNumber,
        businessRegUrl: businessRegUrl ?? this.businessRegUrl,
        businessRegStatus: businessRegStatus ?? this.businessRegStatus,
        ncaLicenseNumber: ncaLicenseNumber ?? this.ncaLicenseNumber,
        ncaClass: ncaClass ?? this.ncaClass,
        insurancePliUrl: insurancePliUrl ?? this.insurancePliUrl,
        insurancePliExpiry: insurancePliExpiry ?? this.insurancePliExpiry,
        insurancePiiUrl: insurancePiiUrl ?? this.insurancePiiUrl,
        insurancePiiExpiry: insurancePiiExpiry ?? this.insurancePiiExpiry,
        insuranceStatus: insuranceStatus ?? this.insuranceStatus,
        projectSuccessScore: projectSuccessScore ?? this.projectSuccessScore,
        safetyComplianceScore:
            safetyComplianceScore ?? this.safetyComplianceScore,
        disputeCount: disputeCount ?? this.disputeCount,
      );
}
