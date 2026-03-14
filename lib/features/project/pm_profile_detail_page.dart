// lib/features/project/pm_profile_detail_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/pm_profile.dart';

class PmProfileDetailPage extends StatelessWidget {
  const PmProfileDetailPage({
    super.key,
    required this.pm,
    this.onSelect,
  });

  final PmProfile pm;
  final void Function(PmProfile)? onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reviewsStream = FirebaseFirestore.instance
        .collection('pm_profiles')
        .doc(pm.uid)
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(pm.displayName.isNotEmpty ? pm.displayName : 'PM Profile'),
        actions: [
          if (onSelect != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onSelect!(pm);
              },
              child: const Text('Select'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Header ──────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: cs.primaryContainer,
                backgroundImage:
                    pm.photoUrl != null ? CachedNetworkImageProvider(pm.photoUrl!) : null,
                child: pm.photoUrl == null
                    ? Text(
                        _initials(pm.displayName),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pm.displayName.isNotEmpty ? pm.displayName : 'Unnamed',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Chip(
                      label: Text(pm.role.label),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star_rounded,
                            size: 18, color: Colors.amber[700],),
                        const SizedBox(width: 4),
                        Text(
                          '${pm.averageRating.toStringAsFixed(1)}  (${pm.reviewCount} review${pm.reviewCount == 1 ? '' : 's'})',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Bio ─────────────────────────────────────
          if (pm.bio.isNotEmpty) ...[
            Text('About', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(pm.bio, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
          ],

          // ── Info card ───────────────────────────────
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  if (pm.location != null)
                    _InfoRow(
                      icon: Icons.place_outlined,
                      label: 'Location',
                      value: pm.location!,
                    ),
                  if (pm.region.isNotEmpty)
                    _InfoRow(
                      icon: Icons.map_outlined,
                      label: 'Region',
                      value: pm.region,
                    ),
                  if (pm.yearsExperience != null)
                    _InfoRow(
                      icon: Icons.work_history_outlined,
                      label: 'Experience',
                      value: '${pm.yearsExperience} year${pm.yearsExperience == 1 ? "" : "s"}',
                    ),
                  if (pm.phone != null)
                    _InfoRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: pm.phone!,
                    ),
                  if (pm.email != null)
                    _InfoRow(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: pm.email!,
                    ),
                ],
              ),
            ),
          ),

          // ── Specializations ─────────────────────────
          if (pm.specializations.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Specializations',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final s in pm.specializations)
                  Chip(
                    label: Text(s),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
          ],

          const SizedBox(height: 20),

          // ── Reviews ─────────────────────────────────
          Text('Reviews', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),

          StreamBuilder<QuerySnapshot>(
            stream: reviewsStream,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? const [];
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No reviews yet.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.outline),
                  ),
                );
              }
              return Column(
                children: [
                  for (final doc in docs) _ReviewTile(doc: doc),
                ],
              );
            },
          ),

          const SizedBox(height: 48),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

// ── Info row ───────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.outline),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.outline),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Review tile ────────────────────────────────────────────────────────────────

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.doc});
  final DocumentSnapshot doc;

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rating = (data['rating'] as num?)?.toDouble() ?? 0;
    final comment = (data['comment'] as String?)?.trim() ?? '';
    final ts = data['createdAt'];
    DateTime? date;
    if (ts is Timestamp) date = ts.toDate();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Stars
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 1; i <= 5; i++)
                      Icon(
                        i <= rating ? Icons.star_rounded : Icons.star_outline,
                        size: 16,
                        color: Colors.amber[700],
                      ),
                  ],
                ),
                const Spacer(),
                if (date != null)
                  Text(
                    DateFormat('d MMM yyyy').format(date),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
              ],
            ),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(comment, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
