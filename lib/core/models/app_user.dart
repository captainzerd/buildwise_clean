import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { owner, pm, admin }

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

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
        UserRole.owner => 'Property Owner',
        UserRole.pm => 'Project Manager',
        UserRole.admin => 'Admin',
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
    this.phone,
    this.photoUrl,
    this.subscriptionTier = SubscriptionTier.free,
    this.projectPassExpiresAt,
  });

  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final bool emailVerified;
  final DateTime createdAt;
  final String? phone;
  final String? photoUrl;
  final SubscriptionTier subscriptionTier;
  /// Set when subscriptionTier == projectPass — access expires after 24 months.
  final DateTime? projectPassExpiresAt;

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
      role: _roleFromString(d['role'] as String?),
      emailVerified: (d['emailVerified'] as bool?) ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      phone: d['phone'] as String?,
      photoUrl: d['photoUrl'] as String?,
      subscriptionTier: SubscriptionTierInfo.fromString(
        d['subscriptionTier'] as String?,
      ),
      projectPassExpiresAt:
          (d['projectPassExpiresAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'displayName': displayName,
        'role': role.name,
        'emailVerified': emailVerified,
        'createdAt': Timestamp.fromDate(createdAt),
        'subscriptionTier': _tierToString(subscriptionTier),
        if (phone != null) 'phone': phone,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (projectPassExpiresAt != null)
          'projectPassExpiresAt': Timestamp.fromDate(projectPassExpiresAt!),
      };

  AppUser copyWith({
    String? displayName,
    UserRole? role,
    bool? emailVerified,
    String? phone,
    String? photoUrl,
    SubscriptionTier? subscriptionTier,
    DateTime? projectPassExpiresAt,
  }) =>
      AppUser(
        uid: uid,
        email: email,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
        emailVerified: emailVerified ?? this.emailVerified,
        createdAt: createdAt,
        phone: phone ?? this.phone,
        photoUrl: photoUrl ?? this.photoUrl,
        subscriptionTier: subscriptionTier ?? this.subscriptionTier,
        projectPassExpiresAt:
            projectPassExpiresAt ?? this.projectPassExpiresAt,
      );

  static String _tierToString(SubscriptionTier t) => switch (t) {
        SubscriptionTier.projectPass => 'project_pass',
        _ => t.name,
      };

  static UserRole _roleFromString(String? s) => switch (s) {
        'pm' => UserRole.pm,
        'admin' => UserRole.admin,
        _ => UserRole.owner,
      };
}
