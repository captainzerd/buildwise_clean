// lib/core/models/invitation.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum InvitationStatus {
  pending,
  accepted,
  declined,
  expired,
  cancelled;

  String get firestoreValue => name;

  static InvitationStatus fromString(String? s) => switch (s) {
        'accepted' => InvitationStatus.accepted,
        'declined' => InvitationStatus.declined,
        'expired' => InvitationStatus.expired,
        'cancelled' => InvitationStatus.cancelled,
        _ => InvitationStatus.pending,
      };
}

/// A project invitation sent by email.
/// Stored at: invitations/{token}
@immutable
class Invitation {
  const Invitation({
    required this.id,
    required this.projectId,
    required this.projectTitle,
    required this.inviterUid,
    required this.inviterName,
    required this.inviteeEmail,
    required this.role,
    required this.permissionTier,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    this.respondedAt,
  });

  final String id;
  final String projectId;
  final String projectTitle;
  final String inviterUid;
  final String inviterName;

  /// Email address of the person being invited.
  final String inviteeEmail;

  /// Role label: 'pm' | 'contractor' | 'architect' | 'engineer' | etc.
  final String role;

  /// 'collaborator' | 'observer'
  final String permissionTier;

  final InvitationStatus status;

  /// Token expires 7 days after creation.
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime? respondedAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory Invitation.fromDoc(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? {};
    return Invitation(
      id: doc.id,
      projectId: d['projectId'] as String? ?? '',
      projectTitle: d['projectTitle'] as String? ?? '',
      inviterUid: d['inviterUid'] as String? ?? '',
      inviterName: d['inviterName'] as String? ?? '',
      inviteeEmail: d['inviteeEmail'] as String? ?? '',
      role: d['role'] as String? ?? 'other',
      permissionTier: d['permissionTier'] as String? ?? 'collaborator',
      status: InvitationStatus.fromString(d['status'] as String?),
      expiresAt: (d['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(days: 7)),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (d['respondedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'projectTitle': projectTitle,
        'inviterUid': inviterUid,
        'inviterName': inviterName,
        'inviteeEmail': inviteeEmail,
        'role': role,
        'permissionTier': permissionTier,
        'status': status.firestoreValue,
        'expiresAt': Timestamp.fromDate(expiresAt),
        'createdAt': Timestamp.fromDate(createdAt),
        if (respondedAt != null) 'respondedAt': Timestamp.fromDate(respondedAt!),
      };
}
