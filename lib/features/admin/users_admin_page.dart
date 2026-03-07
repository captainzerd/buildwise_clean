// lib/features/admin/users_admin_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/models/app_user.dart';

class UsersAdminPage extends StatelessWidget {
  const UsersAdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => AppUser.fromDoc(
                    d as DocumentSnapshot<Map<String, dynamic>>,
                  ),)
              .toList(),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('All Users')),
      body: StreamBuilder<List<AppUser>>(
        stream: stream,
        builder: (ctx, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final users = snap.data!;
          if (users.isEmpty) {
            return const Center(child: Text('No users found.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _UserCard(user: users[i]),
          );
        },
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          backgroundImage:
              user.photoUrl != null ? CachedNetworkImageProvider(user.photoUrl!) : null,
          child: user.photoUrl == null
              ? Text(
                  _initials(user.displayName),
                  style: TextStyle(color: cs.onPrimaryContainer),
                )
              : null,
        ),
        title: Text(
          user.displayName.isNotEmpty ? user.displayName : '(no name)',
        ),
        subtitle: Text(user.email),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!user.emailVerified)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.warning_amber_outlined,
                  size: 16,
                  color: cs.error,
                ),
              ),
            _RoleBadge(role: user.role),
          ],
        ),
        onTap: () => _showRoleDialog(context, user),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Future<void> _showRoleDialog(BuildContext context, AppUser user) async {
    final picked = await showDialog<ProfessionalType>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text('Change role for\n${user.email}'),
        children: [
          for (final r in ProfessionalType.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, r),
              child: Row(
                children: [
                  if (r == user.role)
                    const Icon(Icons.check, size: 18)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Text(r.label),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked != null && picked != user.role) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'role': picked.name});
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Role updated to ${picked.label}.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), duration: const Duration(seconds: 10)),
          );
        }
      }
    }
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final ProfessionalType role;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (Color bg, Color fg) = switch (role) {
      _ when role.isAdmin => (cs.errorContainer, cs.onErrorContainer),
      _ when role.isProfessional => (cs.secondaryContainer, cs.onSecondaryContainer),
      _ => (cs.primaryContainer, cs.onPrimaryContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        role.label,
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w500),
      ),
    );
  }
}
