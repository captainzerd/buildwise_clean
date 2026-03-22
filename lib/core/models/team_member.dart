// lib/core/models/team_member.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class TeamMember {
  const TeamMember({
    required this.uid,
    required this.displayName,
    required this.role,
    required this.joinedAt,
    this.avatarUrl,
    this.permissionTier = 'collaborator',
  });

  final String uid;

  /// Display name of the team member.
  final String displayName;

  /// Role label: 'pm' | 'contractor' | 'architect' | 'engineer' |
  /// 'inspector' | 'electrician' | 'plumber' | 'other'
  final String role;

  final DateTime joinedAt;
  final String? avatarUrl;

  /// Permission tier: 'collaborator' (can write phases/costs/updates) or
  /// 'observer' (read-only + chat). Defaults to 'collaborator'.
  /// Auto-assigned: inspector/other → 'observer'; all others → 'collaborator'.
  final String permissionTier;

  factory TeamMember.fromMap(Map<String, dynamic> d) => TeamMember(
        uid: d['uid'] as String? ?? '',
        displayName: d['displayName'] as String? ?? '',
        role: d['role'] as String? ?? 'other',
        joinedAt: (d['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        avatarUrl: d['avatarUrl'] as String?,
        permissionTier: d['permissionTier'] as String? ?? 'collaborator',
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'displayName': displayName,
        'role': role,
        'joinedAt': Timestamp.fromDate(joinedAt),
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        'permissionTier': permissionTier,
      };

  TeamMember copyWith({
    String? displayName,
    String? role,
    String? avatarUrl,
    String? permissionTier,
  }) =>
      TeamMember(
        uid: uid,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
        joinedAt: joinedAt,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        permissionTier: permissionTier ?? this.permissionTier,
      );
}

/// Returns the default permission tier for a given role.
/// inspector/other → 'observer'; all others → 'collaborator'.
String defaultPermissionTierForRole(String role) {
  return (role == 'inspector' || role == 'other') ? 'observer' : 'collaborator';
}

/// Role options for the team member picker.
const teamRoles = [
  ('pm', 'Project Manager'),
  ('contractor', 'Contractor'),
  ('architect', 'Architect'),
  ('engineer', 'Engineer'),
  ('inspector', 'Inspector'),
  ('electrician', 'Electrician'),
  ('plumber', 'Plumber'),
  ('other', 'Other'),
];
