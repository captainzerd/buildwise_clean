import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/builder_profile.dart';

class BuilderProfileDetailPage extends StatelessWidget {
  const BuilderProfileDetailPage({
    super.key,
    required this.builder,
    this.onSelect,
  });

  final BuilderProfile builder;
  final void Function(BuilderProfile)? onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reviewsStream = FirebaseFirestore.instance
        .collection('pm_profiles')
        .doc(builder.uid)
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          builder.displayName.isNotEmpty ? builder.displayName : 'Builder',
        ),
        actions: [
          if (onSelect != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onSelect!(builder);
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
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: cs.primaryContainer,
                    backgroundImage: builder.photoUrl != null
                        ? NetworkImage(builder.photoUrl!)
                        : null,
                    child: builder.photoUrl == null
                        ? Text(
                            _initials(builder.displayName),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: cs.onPrimaryContainer,
                            ),
                          )
                        : null,
                  ),
                  if (builder.isVerified)
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Icon(
                        Icons.verified_rounded,
                        size: 20,
                        color: cs.primary,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            builder.displayName.isNotEmpty
                                ? builder.displayName
                                : 'Unnamed',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        if (builder.isVerified)
                          Chip(
                            avatar: Icon(Icons.verified_rounded,
                                size: 14, color: cs.primary,),
                            label: const Text('Verified'),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Chip(
                      label: Text(builder.role.label),
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
                          '${builder.averageRating.toStringAsFixed(1)}  '
                          '(${builder.reviewCount} review${builder.reviewCount == 1 ? '' : 's'})',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          builder.availableForHire
                              ? Icons.check_circle_outline
                              : Icons.cancel_outlined,
                          size: 14,
                          color: builder.availableForHire
                              ? Colors.green
                              : cs.error,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          builder.availableForHire
                              ? 'Available for hire'
                              : 'Currently unavailable',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: builder.availableForHire
                                    ? Colors.green
                                    : cs.error,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Contact buttons ──────────────────────────
          if (builder.phone != null || builder.whatsappNumber != null)
            Row(
              children: [
                if (builder.phone != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.phone_outlined, size: 18),
                      label: const Text('Call'),
                      onPressed: () => _launch('tel:${builder.phone}'),
                    ),
                  ),
                if (builder.phone != null && builder.whatsappNumber != null)
                  const SizedBox(width: 8),
                if (builder.whatsappNumber != null)
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => _launchWhatsApp(
                        builder.whatsappNumber!,
                        'Hi ${builder.displayName}, I found your profile on BuildWise.',
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_outlined, size: 18),
                          SizedBox(width: 6),
                          Text('WhatsApp'),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

          const SizedBox(height: 16),

          // ── Bio ─────────────────────────────────────
          if (builder.bio.isNotEmpty) ...[
            Text('About', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(builder.bio, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
          ],

          // ── Info card ───────────────────────────────
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  if (builder.location != null)
                    _InfoRow(
                      icon: Icons.place_outlined,
                      label: 'Location',
                      value: builder.location!,
                    ),
                  if (builder.region.isNotEmpty)
                    _InfoRow(
                      icon: Icons.map_outlined,
                      label: 'Region',
                      value: builder.region,
                    ),
                  if (builder.yearsExperience != null)
                    _InfoRow(
                      icon: Icons.work_history_outlined,
                      label: 'Experience',
                      value:
                          '${builder.yearsExperience} year${builder.yearsExperience == 1 ? "" : "s"}',
                    ),
                  if (builder.projectsCompleted > 0)
                    _InfoRow(
                      icon: Icons.check_circle_outline,
                      label: 'Projects',
                      value: '${builder.projectsCompleted} completed',
                    ),
                  if (builder.minimumBudgetGhs != null)
                    _InfoRow(
                      icon: Icons.payments_outlined,
                      label: 'Min. Budget',
                      value: 'GHS ${NumberFormat('#,##0').format(builder.minimumBudgetGhs)}',
                    ),
                  if (builder.email != null)
                    _InfoRow(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: builder.email!,
                    ),
                ],
              ),
            ),
          ),

          // ── Specializations ─────────────────────────
          if (builder.specializations.isNotEmpty) ...[
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
                for (final s in builder.specializations)
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
                children: [for (final doc in docs) _ReviewTile(doc: doc)],
              );
            },
          ),

          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchWhatsApp(String number, String message) async {
    final clean = number.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse(
      'https://wa.me/$clean?text=${Uri.encodeComponent(message)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
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
            width: 88,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.outline),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

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
