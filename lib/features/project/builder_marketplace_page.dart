import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/builder_profile.dart';
import '../../core/services/builder_profile_service.dart';
import 'builder_profile_detail_page.dart';

/// Browse active builder profiles.
/// Pass [onSelect] to use as a picker; omit for standalone browsing.
/// Pass [initialRegion] to pre-filter by the project's region.
class BuilderMarketplacePage extends StatefulWidget {
  const BuilderMarketplacePage({
    super.key,
    this.onSelect,
    this.initialRegion,
  });

  final void Function(BuilderProfile builder)? onSelect;
  final String? initialRegion;

  @override
  State<BuilderMarketplacePage> createState() => _BuilderMarketplacePageState();
}

class _BuilderMarketplacePageState extends State<BuilderMarketplacePage> {
  BuilderRole? _filterRole;
  String _search = '';
  late bool _sameRegionOnly;

  @override
  void initState() {
    super.initState();
    _sameRegionOnly = widget.initialRegion != null;
  }

  List<BuilderProfile> _applyFilters(List<BuilderProfile> all) {
    var list = all;
    if (_sameRegionOnly && widget.initialRegion != null) {
      list = list.where((b) => b.region == widget.initialRegion).toList();
    }
    if (_filterRole != null) {
      list = list.where((b) => b.role == _filterRole).toList();
    }
    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      list = list
          .where((b) =>
              b.displayName.toLowerCase().contains(q) ||
              b.bio.toLowerCase().contains(q) ||
              (b.location?.toLowerCase().contains(q) ?? false) ||
              b.region.toLowerCase().contains(q) ||
              b.specializations.any((s) => s.toLowerCase().contains(q)),)
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<BuilderProfileService>();
    final isPicker = widget.onSelect != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isPicker ? 'Select a Builder' : 'Find a Builder'),
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
          PopupMenuButton<BuilderRole?>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter by role',
            initialValue: _filterRole,
            onSelected: (v) => setState(() => _filterRole = v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('All roles')),
              for (final r in BuilderRole.values)
                PopupMenuItem(value: r, child: Text(r.label)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.initialRegion != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Project region: ${widget.initialRegion}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const Spacer(),
                  FilterChip(
                    label: const Text('Same region only'),
                    selected: _sameRegionOnly,
                    onSelected: (v) => setState(() => _sameRegionOnly = v),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<List<BuilderProfile>>(
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
                  return _EmptyState(
                    hasRegionFilter: _sameRegionOnly,
                    onClearRegion: widget.initialRegion != null
                        ? () => setState(() => _sameRegionOnly = false)
                        : null,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  itemCount: profiles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _BuilderCard(
                    builder: profiles[i],
                    onSelect: widget.onSelect,
                    projectRegion: widget.initialRegion,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Builder Card
// ─────────────────────────────────────────────

class _BuilderCard extends StatelessWidget {
  const _BuilderCard({
    required this.builder,
    this.onSelect,
    this.projectRegion,
  });
  final BuilderProfile builder;
  final void Function(BuilderProfile)? onSelect;
  final String? projectRegion;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sameRegion =
        projectRegion != null && builder.region == projectRegion;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BuilderProfileDetailPage(
              builder: builder,
              onSelect: onSelect,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: avatar + name + role chip + verified + rating
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: cs.primaryContainer,
                        backgroundImage: builder.photoUrl != null
                            ? NetworkImage(builder.photoUrl!)
                            : null,
                        child: builder.photoUrl == null
                            ? Text(
                                _initials(builder.displayName),
                                style: TextStyle(
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
                            size: 16,
                            color: cs.primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
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
                                style:
                                    Theme.of(context).textTheme.titleMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!builder.availableForHire)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2,),
                                decoration: BoxDecoration(
                                  color: cs.errorContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Unavailable',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: cs.onErrorContainer,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Chip(
                          label: Text(builder.role.label),
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
                          Icon(Icons.star_rounded, size: 16, color: cs.primary),
                          const SizedBox(width: 2),
                          Text(
                            builder.averageRating.toStringAsFixed(1),
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ],
                      ),
                      Text(
                        '${builder.reviewCount} review${builder.reviewCount == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: cs.outline,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Bio
              if (builder.bio.isNotEmpty)
                Text(
                  builder.bio,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),

              // Meta: location, region badge, years, projects
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  if (builder.location != null)
                    _MetaChip(
                      icon: Icons.place_outlined,
                      label: builder.location!,
                    ),
                  if (builder.region.isNotEmpty)
                    _MetaChip(
                      icon: Icons.map_outlined,
                      label: builder.region,
                      highlight: sameRegion,
                    ),
                  if (builder.yearsExperience != null)
                    _MetaChip(
                      icon: Icons.work_history_outlined,
                      label: '${builder.yearsExperience} yrs',
                    ),
                  if (builder.projectsCompleted > 0)
                    _MetaChip(
                      icon: Icons.check_circle_outline,
                      label: '${builder.projectsCompleted} projects',
                    ),
                ],
              ),

              if (builder.specializations.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
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

              if (onSelect != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => onSelect!(builder),
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
  const _MetaChip({
    required this.icon,
    required this.label,
    this.highlight = false,
  });
  final IconData icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: highlight ? cs.primary : cs.outline,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: highlight ? cs.primary : null,
                fontWeight:
                    highlight ? FontWeight.w600 : null,
              ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.hasRegionFilter = false, this.onClearRegion});
  final bool hasRegionFilter;
  final VoidCallback? onClearRegion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.engineering_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              hasRegionFilter
                  ? 'No builders in this region'
                  : 'No builders found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              hasRegionFilter
                  ? 'Try expanding your search to all regions.'
                  : 'Try adjusting your search or filters.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (hasRegionFilter && onClearRegion != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onClearRegion,
                child: const Text('Show all regions'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
