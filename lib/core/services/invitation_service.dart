// lib/core/services/invitation_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/invitation.dart';
import '../models/team_member.dart';
import 'project_service.dart';

class InvitationService {
  InvitationService({
    FirebaseFirestore? db,
    FirebaseFunctions? functions,
    ProjectService? projectService,
  })  : _db = db ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1'),
        _projectService = projectService ?? ProjectService();

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final ProjectService _projectService;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('invitations');

  /// Search for existing WyseBrix users by email prefix.
  /// Returns a list of user maps with id, displayName, email, professionalType.
  Future<List<Map<String, dynamic>>> searchUsers(String emailQuery) async {
    if (emailQuery.trim().length < 3) return [];
    final snap = await _db
        .collection('users')
        .where('email', isGreaterThanOrEqualTo: emailQuery.trim())
        .where(
          'email',
          isLessThan: '${emailQuery.trim()}\uf8ff',
        )
        .limit(10)
        .get();
    return snap.docs.map((d) {
      final data = d.data();
      return {
        'id': d.id,
        'displayName': data['displayName'] as String? ?? '',
        'email': data['email'] as String? ?? '',
        'professionalType': data['professionalType'] as String? ?? '',
        'avatarUrl': data['avatarUrl'] as String?,
      };
    }).toList();
  }

  /// Creates a project invitation via Cloud Function callable.
  /// Returns the invitation token.
  Future<String> createInvitation({
    required String projectId,
    required String projectTitle,
    required String inviterUid,
    required String inviterName,
    required String inviteeEmail,
    required String role,
    required String permissionTier,
  }) async {
    final callable = _functions.httpsCallable('createInvitation');
    final result = await callable.call<Map<String, dynamic>>({
      'projectId': projectId,
      'projectTitle': projectTitle,
      'inviterUid': inviterUid,
      'inviterName': inviterName,
      'inviteeEmail': inviteeEmail,
      'role': role,
      'permissionTier': permissionTier,
    });
    return result.data['token'] as String;
  }

  /// Fetch a single invitation by token.
  Future<Invitation?> fetchInvitation(String token) async {
    final doc = await _col.doc(token).get();
    if (!doc.exists) return null;
    return Invitation.fromDoc(doc);
  }

  /// Accept an invitation — adds the user to the project team and marks
  /// the invitation as accepted.
  Future<void> acceptInvitation(
    String token,
    String uid,
    String displayName, {
    String? avatarUrl,
  }) async {
    final doc = await _col.doc(token).get();
    if (!doc.exists) throw Exception('Invitation not found');
    final invitation = Invitation.fromDoc(doc);
    if (invitation.status != InvitationStatus.pending) {
      throw Exception('Invitation is no longer valid');
    }
    if (invitation.isExpired) throw Exception('Invitation has expired');

    final member = TeamMember(
      uid: uid,
      displayName: displayName,
      role: invitation.role,
      joinedAt: DateTime.now(),
      avatarUrl: avatarUrl,
      permissionTier: invitation.permissionTier,
    );

    await _projectService.addTeamMember(invitation.projectId, member);
    await _col.doc(token).update({
      'status': InvitationStatus.accepted.firestoreValue,
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Decline an invitation.
  Future<void> declineInvitation(String token) async {
    await _col.doc(token).update({
      'status': InvitationStatus.declined.firestoreValue,
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Cancel a pending invitation (by inviter/owner).
  Future<void> cancelInvitation(String token) async {
    await _col.doc(token).update({
      'status': InvitationStatus.cancelled.firestoreValue,
    });
  }

  /// Stream of all invitations for a project (for owner to manage).
  Stream<List<Invitation>> projectInvitationsStream(String projectId) {
    return _col
        .where('projectId', isEqualTo: projectId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map(Invitation.fromDoc)
              .toList(),
        );
  }
}
