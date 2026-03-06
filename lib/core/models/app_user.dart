import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { owner, pm, admin }

// ── Subscription tiers ────────────────────────────────────────────────────────

enum SubscriptionTier { free, pro, business }

extension SubscriptionTierInfo on SubscriptionTier {
  String get label => switch (this) {
        SubscriptionTier.free => 'Free',
        SubscriptionTier.pro => 'Pro',
        SubscriptionTier.business => 'Business',
      };

  String get priceLabel => switch (this) {
        SubscriptionTier.free => 'Free forever',
        SubscriptionTier.pro => 'From GH₵99 / mo',
        SubscriptionTier.business => 'From GH₵249 / mo',
      };

  /// Amount in GHS pesewas (× 100) for Paystack — authoritative base price.
  int get amountPesewas => switch (this) {
        SubscriptionTier.free => 0,
        SubscriptionTier.pro => 9900,    // GH₵99 / mo
        SubscriptionTier.business => 24900, // GH₵249 / mo
      };

  /// USD fallback cents for Stripe when FX rates are unavailable.
  int get amountUsdCents => switch (this) {
        SubscriptionTier.free => 0,
        SubscriptionTier.pro => 1400,    // $14 / mo
        SubscriptionTier.business => 2500, // $25 / mo
      };

  bool get canAccessAnalytics => this != SubscriptionTier.free;
  bool get canExportPdf => this != SubscriptionTier.free;
  bool get canListInMarketplace => this == SubscriptionTier.business;
  int get maxProjects => switch (this) {
        SubscriptionTier.free => 2,
        SubscriptionTier.pro => 999,
        SubscriptionTier.business => 999,
      };

  static SubscriptionTier fromString(String? s) => switch (s) {
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
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'displayName': displayName,
        'role': role.name,
        'emailVerified': emailVerified,
        'createdAt': Timestamp.fromDate(createdAt),
        'subscriptionTier': subscriptionTier.name,
        if (phone != null) 'phone': phone,
        if (photoUrl != null) 'photoUrl': photoUrl,
      };

  AppUser copyWith({
    String? displayName,
    UserRole? role,
    bool? emailVerified,
    String? phone,
    String? photoUrl,
    SubscriptionTier? subscriptionTier,
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
      );

  static UserRole _roleFromString(String? s) => switch (s) {
        'pm' => UserRole.pm,
        'admin' => UserRole.admin,
        _ => UserRole.owner,
      };
}
