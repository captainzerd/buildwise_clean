import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/builder_profile.dart';
import '../../core/services/builder_profile_service.dart';
import '../../core/widgets/verification_badge.dart';
import 'builder_profile_detail_page.dart';

enum _SortOption { trustScore, rating, reviews, newest }

/// Browse active builder profiles with search, filters, and sorting.
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
  bool _ncaVerifiedOnly = false;
  bool _insuredOnly = false;
  bool _availableOnly = false;
  double _minRating = 0;
  _SortOption _sort = _SortOption.trustScore;

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
    if (_ncaVerifiedOnly) {
      list = list.where((b) => b.isNcaVerified).toList();
    }
    if (_insuredOnly) {
      list = list.where((b) => b.isInsuranceValid).toList();
    }
    if (_availableOnly) {
      list = list.where((b) => b.availableForHire).toList();
    }
    if (_minRating > 0) {
      list = list.where((b) => b.averageRating >= _minRating).toList();
    }
    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      list = list
          .where(
            (b) =>
                b.displayName.toLowerCase().contains(q) ||
                b.bio.toLowerCase().contains(q) ||
                (b.location?.toLowerCase().contains(q) ?? false) ||
                b.region.toLowerCase().contains(q) ||
                b.specializations.any((s) => s.toLowerCase().contains(q)) ||
                (b.ncaClass?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }

    // Sort
    switch (_sort) {
      case _SortOption.trustScore:
        list.sort((a, b) => b.trustScore.compareTo(a.trustScore));
      case _SortOption.rating:
        list.sort((a, b) => b.averageRating.compareTo(a.averageRating));
      case _SortOption.reviews:
        list.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
      case _SortOption.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return list;
  }

  bool get _hasActiveFilters =>
      _filterRole != null ||
      _ncaVerifiedOnly ||
      _insuredOnly ||
      _availableOnly ||
      _minRating > 0 ||
      _sameRegionOnly;

  @override
  Widget build(BuildContext context) {
    final service = context.read<BuilderProfileService>();
    final isPicker = widget.onSelect != null;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(isPicker ? 'Select a Builder' : 'Find a Builder'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search name, skill, NCA class, location…',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                filled: true,
                fillColor: cs.surface,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
        ),
        actions: [
          // Sort button
          PopupMenuButton<_SortOption>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            initialValue: _sort,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _SortOption.trustScore,
                child: Text('Sort: Trust Score'),
              ),
              PopupMenuItem(
                value: _SortOption.rating,
                child: Text('Sort: Rating'),
              ),
              PopupMenuItem(
                value: _SortOption.reviews,
                child: Text('Sort: Most Reviewed'),
              ),
              PopupMenuItem(
                value: _SortOption.newest,
                child: Text('Sort: Newest'),
              ),
            ],
          ),
          // Filter button with active indicator
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                tooltip: 'Filter',
                onPressed: () => _showFilterSheet(context),
              ),
              if (_hasActiveFilters)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: cs.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Region + active filter chips bar
          if (widget.initialRegion != null || _hasActiveFilters)
            _FilterChipBar(
              initialRegion: widget.initialRegion,
              sameRegionOnly: _sameRegionOnly,
              ncaVerifiedOnly: _ncaVerifiedOnly,
              insuredOnly: _insuredOnly,
              availableOnly: _availableOnly,
              minRating: _minRating,
              filterRole: _filterRole,
              onToggleRegion: (v) => setState(() => _sameRegionOnly = v),
              onClearRole: () => setState(() => _filterRole = null),
              onClearRating: () => setState(() => _minRating = 0),
              onClearNca: () => setState(() => _ncaVerifiedOnly = false),
              onClearInsured: () => setState(() => _insuredOnly = false),
              onClearAvailable: () => setState(() => _availableOnly = false),
            ),

          Expanded(
            child: StreamBuilder<List<BuilderProfile>>(
              stream: service.verifiedBuildersStream(),
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
                    hasFilters: _hasActiveFilters,
                    onClearFilters: () => setState(() {
                      _filterRole = null;
                      _ncaVerifiedOnly = false;
                      _insuredOnly = false;
                      _availableOnly = false;
                      _minRating = 0;
                      _sameRegionOnly = false;
                    }),
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

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(
        filterRole: _filterRole,
        ncaVerifiedOnly: _ncaVerifiedOnly,
        insuredOnly: _insuredOnly,
        availableOnly: _availableOnly,
        minRating: _minRating,
        onApply: (role, nca, insured, available, rating) {
          setState(() {
            _filterRole = role;
            _ncaVerifiedOnly = nca;
            _insuredOnly = insured;
            _availableOnly = available;
            _minRating = rating;
          });
        },
      ),
    );
  }
}

// ── Filter chip bar ───────────────────────────────────────────────────────────

class _FilterChipBar extends StatelessWidget {
  const _FilterChipBar({
    required this.initialRegion,
    required this.sameRegionOnly,
    required this.ncaVerifiedOnly,
    required this.insuredOnly,
    required this.availableOnly,
    required this.minRating,
    required this.filterRole,
    required this.onToggleRegion,
    required this.onClearRole,
    required this.onClearRating,
    required this.onClearNca,
    required this.onClearInsured,
    required this.onClearAvailable,
  });

  final String? initialRegion;
  final bool sameRegionOnly;
  final bool ncaVerifiedOnly;
  final bool insuredOnly;
  final bool availableOnly;
  final double minRating;
  final BuilderRole? filterRole;
  final void Function(bool) onToggleRegion;
  final VoidCallback onClearRole;
  final VoidCallback onClearRating;
  final VoidCallback onClearNca;
  final VoidCallback onClearInsured;
  final VoidCallback onClearAvailable;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          if (initialRegion != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text('${initialRegion!} only'),
                selected: sameRegionOnly,
                onSelected: onToggleRegion,
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (filterRole != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text(filterRole!.label),
                onDeleted: onClearRole,
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (ncaVerifiedOnly)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: const Text('NCA Licensed'),
                avatar: const Icon(Icons.badge_outlined, size: 14),
                onDeleted: onClearNca,
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (insuredOnly)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: const Text('Insured'),
                avatar: const Icon(Icons.shield_outlined, size: 14),
                onDeleted: onClearInsured,
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (availableOnly)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: const Text('Available now'),
                onDeleted: onClearAvailable,
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (minRating > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text('${minRating.toStringAsFixed(1)}★+'),
                onDeleted: onClearRating,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Filter bottom sheet ───────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.filterRole,
    required this.ncaVerifiedOnly,
    required this.insuredOnly,
    required this.availableOnly,
    required this.minRating,
    required this.onApply,
  });

  final BuilderRole? filterRole;
  final bool ncaVerifiedOnly;
  final bool insuredOnly;
  final bool availableOnly;
  final double minRating;
  final void Function(
    BuilderRole? role,
    bool nca,
    bool insured,
    bool available,
    double rating,
  ) onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late BuilderRole? _role;
  late bool _nca;
  late bool _insured;
  late bool _available;
  late double _rating;

  @override
  void initState() {
    super.initState();
    _role = widget.filterRole;
    _nca = widget.ncaVerifiedOnly;
    _insured = widget.insuredOnly;
    _available = widget.availableOnly;
    _rating = widget.minRating;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Filter Contractors',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _role = null;
                  _nca = false;
                  _insured = false;
                  _available = false;
                  _rating = 0;
                }),
                child: const Text('Clear all'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Role
          Text(
            'Profession',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: _role == null,
                onSelected: (_) => setState(() => _role = null),
              ),
              for (final r in BuilderRole.values)
                ChoiceChip(
                  label: Text(r.label),
                  selected: _role == r,
                  onSelected: (_) => setState(() => _role = r),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Verification
          Text(
            'Verification',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('NCA Licensed'),
            subtitle: const Text(
              'National Construction Authority certified',
            ),
            value: _nca,
            onChanged: (v) => setState(() => _nca = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Insured'),
            subtitle: const Text('Valid PLI/PII insurance on file'),
            value: _insured,
            onChanged: (v) => setState(() => _insured = v),
          ),
          const SizedBox(height: 8),

          // Availability
          Text(
            'Availability',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Available now'),
            value: _available,
            onChanged: (v) => setState(() => _available = v),
          ),
          const SizedBox(height: 8),

          // Minimum rating
          Text(
            'Minimum rating',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final r in [0.0, 3.0, 3.5, 4.0, 4.5])
                ChoiceChip(
                  label: Text(r == 0 ? 'Any' : '${r.toStringAsFixed(1)}★+'),
                  selected: _rating == r,
                  onSelected: (_) => setState(() => _rating = r),
                ),
            ],
          ),
          const SizedBox(height: 20),

          FilledButton(
            onPressed: () {
              widget.onApply(_role, _nca, _insured, _available, _rating);
              Navigator.of(context).pop();
            },
            child: const Text('Apply filters'),
          ),
        ],
      ),
    );
  }
}

// ── Builder card ──────────────────────────────────────────────────────────────

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
    final sameRegion = projectRegion != null && builder.region == projectRegion;

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
              // Header: avatar + name + role + rating + trust score
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: cs.primaryContainer,
                        backgroundImage: builder.photoUrl != null
                            ? CachedNetworkImageProvider(builder.photoUrl!)
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
                      if (builder.trustScore >= 70)
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: Tooltip(
                            message: 'Trust Score ${builder.trustScore}/100',
                            child: Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: cs.primary,
                            ),
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
                                style: Theme.of(context).textTheme.titleMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!builder.availableForHire)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
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
                  // Rating + trust score
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: cs.primary,
                          ),
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _trustColor(builder.trustScore)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${builder.trustScore}pts',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _trustColor(builder.trustScore),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Verification badges
              VerificationBadgeRow(profile: builder, compact: true),

              const SizedBox(height: 8),

              // Bio
              if (builder.bio.isNotEmpty)
                Text(
                  builder.bio,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),

              // Meta chips
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
                  if (builder.ncaClass != null)
                    _MetaChip(
                      icon: Icons.badge_outlined,
                      label: 'NCA ${builder.ncaClass}',
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

  Color _trustColor(int score) {
    if (score >= 70) return Colors.green;
    if (score >= 40) return Colors.orange;
    return Colors.grey;
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

// ── Meta chip ─────────────────────────────────────────────────────────────────

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
                fontWeight: highlight ? FontWeight.w600 : null,
              ),
        ),
      ],
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    this.hasFilters = false,
    this.onClearFilters,
  });
  final bool hasFilters;
  final VoidCallback? onClearFilters;

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
              hasFilters
                  ? 'No contractors match your filters'
                  : 'No contractors found',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'Try relaxing your filters to see more results.'
                  : 'Check back later as new contractors join.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (hasFilters && onClearFilters != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onClearFilters,
                child: const Text('Clear all filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
