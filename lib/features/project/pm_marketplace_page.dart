// lib/features/project/pm_marketplace_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/pm_profile.dart';
import '../../core/services/pm_profile_service.dart';
import 'pm_profile_detail_page.dart';

/// Browse active PM profiles. Pass [onSelect] to use as a picker;
/// omit to use as a standalone browsing page.
class PmMarketplacePage extends StatefulWidget {
  const PmMarketplacePage({super.key, this.onSelect});

  /// Called when user taps "Select" on a profile card.
  final void Function(PmProfile pm)? onSelect;

  @override
  State<PmMarketplacePage> createState() => _PmMarketplacePageState();
}

class _PmMarketplacePageState extends State<PmMarketplacePage> {
  PmRole? _filterRole;
  String _search = '';

  List<PmProfile> _applyFilters(List<PmProfile> all) {
    var list = all;
    if (_filterRole != null) {
      list = list.where((p) => p.role == _filterRole).toList();
    }
    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      list = list
          .where((p) =>
              p.displayName.toLowerCase().contains(q) ||
              p.bio.toLowerCase().contains(q) ||
              (p.location?.toLowerCase().contains(q) ?? false) ||
              p.specializations.any((s) => s.toLowerCase().contains(q)),)
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<PmProfileService>();
    final isPicker = widget.onSelect != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isPicker ? 'Select a PM' : 'PM Marketplace'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search name, skill, location…',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
        ),
        actions: [
          PopupMenuButton<PmRole?>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter by role',
            initialValue: _filterRole,
            onSelected: (v) => setState(() => _filterRole = v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('All roles')),
              for (final r in PmRole.values)
                PopupMenuItem(value: r, child: Text(r.label)),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<PmProfile>>(
        stream: service.listActive(),
        builder: (ctx, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final profiles = _applyFilters(snap.data!);
          if (profiles.isEmpty) {
            return const _EmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: profiles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _PmCard(
              pm: profiles[i],
              onSelect: widget.onSelect,
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PM Card
// ─────────────────────────────────────────────

class _PmCard extends StatelessWidget {
  const _PmCard({required this.pm, this.onSelect});
  final PmProfile pm;
  final void Function(PmProfile)? onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PmProfileDetailPage(
              pm: pm,
              onSelect: onSelect,
            ),
          ),
        ),
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: avatar + name + role chip
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: cs.primaryContainer,
                  backgroundImage: pm.photoUrl != null
                      ? NetworkImage(pm.photoUrl!)
                      : null,
                  child: pm.photoUrl == null
                      ? Text(
                          _initials(pm.displayName),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: cs.onPrimaryContainer,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pm.displayName.isNotEmpty ? pm.displayName : 'Unnamed',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Chip(
                        label: Text(pm.role.label),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                // Rating
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded,
                            size: 16, color: cs.primary,),
                        const SizedBox(width: 2),
                        Text(
                          pm.averageRating.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                    Text(
                      '${pm.reviewCount} review${pm.reviewCount == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: cs.outline,
                          ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Bio
            Text(
              pm.bio,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),

            // Meta: location, years, specializations
            if (pm.location != null || pm.yearsExperience != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                children: [
                  if (pm.location != null)
                    _MetaChip(
                      icon: Icons.location_on_outlined,
                      label: pm.location!,
                    ),
                  if (pm.yearsExperience != null)
                    _MetaChip(
                      icon: Icons.work_history_outlined,
                      label: '${pm.yearsExperience} yrs exp',
                    ),
                ],
              ),
            ],

            if (pm.specializations.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
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

            if (onSelect != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => onSelect!(pm),
                  child: const Text('Select'),
                ),
              ),
            ],
          ],
        ),
        ),
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No PMs found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
