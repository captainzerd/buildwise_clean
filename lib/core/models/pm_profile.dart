// lib/core/models/pm_profile.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum PmRole { architect, contractor, engineer, surveyor }

extension PmRoleLabel on PmRole {
  String get label => switch (this) {
        PmRole.architect => 'Architect',
        PmRole.contractor => 'Contractor',
        PmRole.engineer => 'Engineer',
        PmRole.surveyor => 'Quantity Surveyor',
      };

  String get firestoreValue => switch (this) {
        PmRole.architect => 'architect',
        PmRole.contractor => 'contractor',
        PmRole.engineer => 'engineer',
        PmRole.surveyor => 'surveyor',
      };
}

PmRole pmRoleFromString(String? s) => switch (s) {
      'contractor' => PmRole.contractor,
      'engineer' => PmRole.engineer,
      'surveyor' => PmRole.surveyor,
      _ => PmRole.architect,
    };

@immutable
class PmProfile {
  const PmProfile({
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
  });

  final String uid;
  final String displayName;
  final PmRole role;
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

  factory PmProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return PmProfile(
      uid: doc.id,
      displayName: d['displayName'] as String? ?? '',
      role: pmRoleFromString(d['role'] as String?),
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
      };

  PmProfile copyWith({
    String? displayName,
    PmRole? role,
    String? bio,
    String? phone,
    String? location,
    String? region,
    List<String>? specializations,
    bool? isActive,
    int? yearsExperience,
  }) =>
      PmProfile(
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
      );
}
