import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ── Professional Types ─────────────────────────────────────────────────────

enum ProfessionalType {
  homeowner,
  contractor,
  architect,
  engineer,
  inspector,
  materialSupplier,
  realEstateDeveloper,
  bankLender,
  governmentRegulator,
  admin,
}

extension ProfessionalTypeInfo on ProfessionalType {
  String get label => switch (this) {
        ProfessionalType.homeowner => 'Homeowner',
        ProfessionalType.contractor => 'Contractor',
        ProfessionalType.architect => 'Architect',
        ProfessionalType.engineer => 'Engineer',
        ProfessionalType.inspector => 'Inspector',
        ProfessionalType.materialSupplier => 'Material Supplier',
        ProfessionalType.realEstateDeveloper => 'Real Estate Developer',
        ProfessionalType.bankLender => 'Bank / Mortgage Lender',
        ProfessionalType.governmentRegulator => 'Government Regulator',
        ProfessionalType.admin => 'Admin',
      };

  String get subtitle => switch (this) {
        ProfessionalType.homeowner => 'Building or renovating your home',
        ProfessionalType.contractor => 'Construction and building works',
        ProfessionalType.architect => 'Architectural design services',
        ProfessionalType.engineer =>
          'Civil, structural or MEP engineering',
        ProfessionalType.inspector => 'Building inspections and quality control',
        ProfessionalType.materialSupplier =>
          'Supply building materials and equipment',
        ProfessionalType.realEstateDeveloper =>
          'Real estate development and investment',
        ProfessionalType.bankLender => 'Mortgage and construction financing',
        ProfessionalType.governmentRegulator =>
          'Regulatory and compliance oversight',
        ProfessionalType.admin => 'Platform administrator',
      };

  IconData get icon => switch (this) {
        ProfessionalType.homeowner => Icons.home_outlined,
        ProfessionalType.contractor => Icons.construction,
        ProfessionalType.architect => Icons.architecture,
        ProfessionalType.engineer => Icons.engineering,
        ProfessionalType.inspector => Icons.fact_check_outlined,
        ProfessionalType.materialSupplier => Icons.store_outlined,
        ProfessionalType.realEstateDeveloper => Icons.apartment_outlined,
        ProfessionalType.bankLender => Icons.account_balance_outlined,
        ProfessionalType.governmentRegulator => Icons.gavel_outlined,
        ProfessionalType.admin => Icons.admin_panel_settings_outlined,
      };

  static ProfessionalType fromString(String? s) => switch (s) {
        'contractor' => ProfessionalType.contractor,
        'architect' => ProfessionalType.architect,
        'engineer' => ProfessionalType.engineer,
        'inspector' => ProfessionalType.inspector,
        'materialSupplier' => ProfessionalType.materialSupplier,
        'realEstateDeveloper' => ProfessionalType.realEstateDeveloper,
        'bankLender' => ProfessionalType.bankLender,
        'governmentRegulator' => ProfessionalType.governmentRegulator,
        'admin' => ProfessionalType.admin,
        'owner' => ProfessionalType.homeowner,      // legacy Firestore migration
        'pm' => ProfessionalType.contractor,        // legacy Firestore migration
        _ => ProfessionalType.homeowner,
      };

  /// Professionals offer services and appear in the builder/PM marketplace.
  bool get isProfessional => switch (this) {
        ProfessionalType.contractor ||
        ProfessionalType.architect ||
        ProfessionalType.engineer ||
        ProfessionalType.inspector ||
        ProfessionalType.materialSupplier =>
          true,
        // homeowner, realEstateDeveloper, bankLender, governmentRegulator → isClient
        // admin → isAdmin
        _ => false,
      };

  /// Clients primarily create projects and hire professionals.
  /// Covers: homeowner, realEstateDeveloper, bankLender, governmentRegulator.
  bool get isClient => !isProfessional && !isAdmin;

  bool get isAdmin => this == ProfessionalType.admin;
}

// ── ID Verification Status ─────────────────────────────────────────────────

enum IdVerificationStatus { unverified, pending, verified, rejected }

extension IdVerificationStatusInfo on IdVerificationStatus {
  String get label => switch (this) {
        IdVerificationStatus.unverified => 'Unverified',
        IdVerificationStatus.pending => 'Pending Review',
        IdVerificationStatus.verified => 'Verified',
        IdVerificationStatus.rejected => 'Rejected',
      };

  static IdVerificationStatus fromString(String? s) => switch (s) {
        'pending' => IdVerificationStatus.pending,
        'verified' => IdVerificationStatus.verified,
        'rejected' => IdVerificationStatus.rejected,
        _ => IdVerificationStatus.unverified,
      };
}

// ── Subscription tiers ────────────────────────────────────────────────────────

enum SubscriptionTier { free, projectPass, pro, business }

extension SubscriptionTierInfo on SubscriptionTier {
  String get label => switch (this) {
        SubscriptionTier.free => 'Free',
        SubscriptionTier.projectPass => 'Project Pass',
        SubscriptionTier.pro => 'Pro',
        SubscriptionTier.business => 'Business',
      };

  String get priceLabel => switch (this) {
        SubscriptionTier.free => 'Free forever',
        SubscriptionTier.projectPass => 'GH₵349 one-time',
        SubscriptionTier.pro => 'From GH₵99 / mo',
        SubscriptionTier.business => 'From GH₵249 / mo',
      };

  /// Amount in GHS pesewas (× 100) for Paystack — authoritative base price.
  int get amountPesewas => switch (this) {
        SubscriptionTier.free => 0,
        SubscriptionTier.projectPass => 34900, // GH₵349 one-time
        SubscriptionTier.pro => 9900,           // GH₵99 / mo
        SubscriptionTier.business => 24900,     // GH₵249 / mo
      };

  /// USD fallback cents for Stripe when FX rates are unavailable.
  int get amountUsdCents => switch (this) {
        SubscriptionTier.free => 0,
        SubscriptionTier.projectPass => 2900, // ~$29 one-time
        SubscriptionTier.pro => 1400,          // $14 / mo
        SubscriptionTier.business => 2500,     // $25 / mo
      };

  // ── Feature gates ─────────────────────────────────────────────────────────

  /// Full analytics dashboard requires Pro or Business.
  bool get canAccessAnalytics =>
      this == SubscriptionTier.pro || this == SubscriptionTier.business;

  /// PDF / CSV export requires Project Pass, Pro, or Business.
  bool get canExportPdf => this != SubscriptionTier.free;

  /// Photo uploads require Project Pass, Pro, or Business.
  bool get canUploadPhotos => this != SubscriptionTier.free;

  /// Contracts require Project Pass, Pro, or Business.
  bool get canUseContracts => this != SubscriptionTier.free;

  /// Marketplace listing requires Business tier.
  bool get canListInMarketplace => this == SubscriptionTier.business;

  /// Maximum number of active projects (free = 1, others = unlimited).
  int get maxProjects => switch (this) {
        SubscriptionTier.free => 1,
        SubscriptionTier.projectPass => 1,
        SubscriptionTier.pro => 999,
        SubscriptionTier.business => 999,
      };

  /// Maximum cost entries per project on the free tier.
  int get maxCostEntriesPerProject => switch (this) {
        SubscriptionTier.free => 5,
        _ => 999999,
      };

  static SubscriptionTier fromString(String? s) => switch (s) {
        'project_pass' => SubscriptionTier.projectPass,
        'pro' => SubscriptionTier.pro,
        'business' => SubscriptionTier.business,
        _ => SubscriptionTier.free,
      };
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.emailVerified,
    required this.createdAt,
    this.firstName,
    this.lastName,
    this.phone,
    this.photoUrl,
    this.subscriptionTier = SubscriptionTier.free,
    this.projectPassExpiresAt,
    this.phoneVerified = false,
    this.phoneVerifiedAt,
    this.idVerificationStatus = IdVerificationStatus.unverified,
    this.trustScore = 0,
    this.twoFactorEnabled = false,
  });

  final String uid;
  final String email;
  final String displayName;
  final ProfessionalType role;
  final bool emailVerified;
  final DateTime createdAt;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? photoUrl;
  final SubscriptionTier subscriptionTier;
  /// Set when subscriptionTier == projectPass — access expires after 24 months.
  final DateTime? projectPassExpiresAt;
  final bool phoneVerified;
  final DateTime? phoneVerifiedAt;
  final IdVerificationStatus idVerificationStatus;
  /// Trust score 0–100 computed from verification status, reviews, etc.
  final int trustScore;
  final bool twoFactorEnabled;

  /// True if Project Pass is active and not yet expired.
  bool get isProjectPassActive =>
      subscriptionTier == SubscriptionTier.projectPass &&
      (projectPassExpiresAt?.isAfter(DateTime.now()) ?? false);

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AppUser(
      uid: doc.id,
      email: (d['email'] as String?) ?? '',
      displayName: (d['displayName'] as String?) ?? '',
      role: ProfessionalTypeInfo.fromString(d['role'] as String?),
      emailVerified: (d['emailVerified'] as bool?) ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      firstName: d['firstName'] as String?,
      lastName: d['lastName'] as String?,
      phone: d['phone'] as String?,
      photoUrl: d['photoUrl'] as String?,
      subscriptionTier: SubscriptionTierInfo.fromString(
        d['subscriptionTier'] as String?,
      ),
      projectPassExpiresAt:
          (d['projectPassExpiresAt'] as Timestamp?)?.toDate(),
      phoneVerified: (d['phoneVerified'] as bool?) ?? false,
      phoneVerifiedAt: (d['phoneVerifiedAt'] as Timestamp?)?.toDate(),
      idVerificationStatus: IdVerificationStatusInfo.fromString(
        d['idVerificationStatus'] as String?,
      ),
      trustScore: (d['trustScore'] as num?)?.toInt() ?? 0,
      twoFactorEnabled: (d['twoFactorEnabled'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'displayName': displayName,
        'role': role.name,
        'emailVerified': emailVerified,
        'createdAt': Timestamp.fromDate(createdAt),
        'subscriptionTier': _tierToString(subscriptionTier),
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
        if (phone != null) 'phone': phone,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (projectPassExpiresAt != null)
          'projectPassExpiresAt': Timestamp.fromDate(projectPassExpiresAt!),
        'phoneVerified': phoneVerified,
        if (phoneVerifiedAt != null)
          'phoneVerifiedAt': Timestamp.fromDate(phoneVerifiedAt!),
        'idVerificationStatus': idVerificationStatus.name,
        'trustScore': trustScore,
        'twoFactorEnabled': twoFactorEnabled,
      };

  AppUser copyWith({
    String? displayName,
    ProfessionalType? role,
    bool? emailVerified,
    String? firstName,
    String? lastName,
    String? phone,
    String? photoUrl,
    SubscriptionTier? subscriptionTier,
    DateTime? projectPassExpiresAt,
    bool? phoneVerified,
    DateTime? phoneVerifiedAt,
    IdVerificationStatus? idVerificationStatus,
    int? trustScore,
    bool? twoFactorEnabled,
  }) =>
      AppUser(
        uid: uid,
        email: email,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
        emailVerified: emailVerified ?? this.emailVerified,
        createdAt: createdAt,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        phone: phone ?? this.phone,
        photoUrl: photoUrl ?? this.photoUrl,
        subscriptionTier: subscriptionTier ?? this.subscriptionTier,
        projectPassExpiresAt:
            projectPassExpiresAt ?? this.projectPassExpiresAt,
        phoneVerified: phoneVerified ?? this.phoneVerified,
        phoneVerifiedAt: phoneVerifiedAt ?? this.phoneVerifiedAt,
        idVerificationStatus:
            idVerificationStatus ?? this.idVerificationStatus,
        trustScore: trustScore ?? this.trustScore,
        twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      );

  static String _tierToString(SubscriptionTier t) => switch (t) {
        SubscriptionTier.projectPass => 'project_pass',
        _ => t.name,
      };

}
