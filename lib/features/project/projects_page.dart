// lib/features/project/projects_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/config/service_locator.dart';
import '../../core/models/app_user.dart';
import '../../core/models/project.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/project_service.dart';
import '../../core/widgets/app_page_route.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/tip_banner.dart';
import '../../core/state/builder_project_state.dart';
import 'builder_marketplace_page.dart';
import 'export_sheet.dart';

class ProjectsPage extends StatelessWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final role = auth.role;

    if (role == UserRole.pm) {
      return const _BuilderProjectsView();
    }
    return const _OwnerProjectsView();
  }
}

// ── Owner view ─────────────────────────────────────────────────────────────────

class _OwnerProjectsView extends StatefulWidget {
  const _OwnerProjectsView();

  @override
  State<_OwnerProjectsView> createState() => _OwnerProjectsViewState();
}

class _OwnerProjectsViewState extends State<_OwnerProjectsView> {
  String _search = '';
  ProjectStatus? _statusFilter;

  List<Project> _projects = [];
  DocumentSnapshot? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;

  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFirst());
  }

  Future<void> _loadFirst() async {
    setState(() {
      _projects = [];
      _cursor = null;
      _hasMore = true;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    final projectService = sl<ProjectService>();
    final uid = context.read<AuthService>().currentUser!.uid;
    try {
      final (page, lastDoc) = await projectService.fetchOwnerProjectsPage(
        uid,
        limit: _pageSize,
        startAfter: _cursor,
      );
      setState(() {
        _projects.addAll(page);
        _cursor = lastDoc;
        _hasMore = page.length >= _pageSize;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Project> get _filtered {
    var list = _projects;
    if (_statusFilter != null) {
      list = list.where((p) => p.status == _statusFilter).toList();
    }
    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      list = list
          .where(
            (p) =>
                p.title.toLowerCase().contains(q) ||
                (p.location?.toLowerCase().contains(q) ?? false) ||
                p.region.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search projects…',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          _StatusFilterBar(
            selected: _statusFilter,
            onSelected: (s) => setState(() => _statusFilter = s),
          ),
          const TipBanner(
            tipKey: 'tip_projects_assign_pm',
            message:
                'After creating a project, open it and assign a builder/PM from the Overview tab to give them access.',
          ),
          Expanded(
            child: _buildBody(context),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'export_portfolio',
            tooltip: 'Export Portfolio',
            onPressed: () {
              final auth = context.read<AuthService>();
              showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                builder: (_) => ExportSheet(
                  projectId: '',
                  ownerUid: auth.currentUser?.uid ?? '',
                ),
              );
            },
            child: const Icon(Icons.download_outlined),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'new_project',
            onPressed: () => _openCreate(context),
            icon: const Icon(Icons.add),
            label: const Text('New Project'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _projects.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _projects.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Error loading projects: $_error', textAlign: TextAlign.center),
        ),
      );
    }
    if (_projects.isEmpty) {
      return EmptyState(
        icon: Icons.work_outline,
        title: 'No projects yet',
        message:
            'Create your first project to start tracking costs and progress.',
        actionLabel: 'New project',
        onAction: () => _openCreate(context),
      );
    }

    final projects = _filtered;
    if (projects.isEmpty) {
      return const Center(child: Text('No projects match your search.'));
    }

    Widget buildItem(int i) {
      if (i == projects.length) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: _loading
                ? const CircularProgressIndicator()
                : TextButton.icon(
                    icon: const Icon(Icons.expand_more),
                    label: const Text('Load more'),
                    onPressed: _loadMore,
                  ),
          ),
        );
      }
      return _ProjectCard(
        project: projects[i],
        onTap: () => _openDetails(context, projects[i]),
      );
    }

    final itemCount = projects.length + (_hasMore || _loading ? 1 : 0);
    const padding = EdgeInsets.fromLTRB(16, 12, 16, 96);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 600;
        return RefreshIndicator(
          onRefresh: _loadFirst,
          child: isTablet
              ? GridView.builder(
                  padding: padding,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.1,
                  ),
                  itemCount: itemCount,
                  itemBuilder: (_, i) => buildItem(i),
                )
              : ListView.separated(
                  padding: padding,
                  itemCount: itemCount,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => buildItem(i),
                ),
        );
      },
    );
  }

  void _openCreate(BuildContext context) {
    final auth = context.read<AuthService>();
    final tier = auth.currentUser?.subscriptionTier ?? SubscriptionTier.free;
    final maxProjects = tier.maxProjects;

    // Free / Project Pass users are capped at 1 project.
    if (_projects.length >= maxProjects) {
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Project limit reached'),
          content: Text(
            tier == SubscriptionTier.free
                ? 'The free plan supports 1 project.\n\n'
                    'Upgrade to Project Pass (one-time GH₵349) for your full build, '
                    'or to Pro for unlimited projects.'
                : 'Project Pass supports 1 project.\n\n'
                    'Upgrade to Pro for unlimited projects.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/account/upgrade');
              },
              child: const Text('See plans'),
            ),
          ],
        ),
      );
      return;
    }
    context.push('/projects/create');
  }

  void _openDetails(BuildContext context, Project project) {
    context.push('/projects/${project.id}', extra: project.title);
  }
}

// ── Builder view ───────────────────────────────────────────────────────────────

class _BuilderProjectsView extends StatefulWidget {
  const _BuilderProjectsView();

  @override
  State<_BuilderProjectsView> createState() => _BuilderProjectsViewState();
}

class _BuilderProjectsViewState extends State<_BuilderProjectsView> {
  String _search = '';
  ProjectStatus? _statusFilter;

  List<Project> _projects = [];
  bool _hasMore = true;
  bool _loading = false;
  String? _error;

  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFirst());
  }

  Future<void> _loadFirst() async {
    setState(() {
      _projects = [];
      _hasMore = true;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    final uid = context.read<AuthService>().currentUser!.uid;
    try {
      final (page, _) = await sl<ProjectService>().fetchBuilderProjectsPage(
        uid,
        limit: _pageSize,
      );
      setState(() {
        _projects = page; // full fetch, already deduped and sorted in service
        _hasMore = false; // builder list is fully loaded in one call
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Project> get _filtered {
    var list = _projects;
    if (_statusFilter != null) {
      list = list.where((p) => p.status == _statusFilter).toList();
    }
    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      list = list
          .where(
            (p) =>
                p.title.toLowerCase().contains(q) ||
                (p.location?.toLowerCase().contains(q) ?? false) ||
                p.region.toLowerCase().contains(q) ||
                (p.ownerName?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search projects or owners…',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          _StatusFilterBar(
            selected: _statusFilter,
            onSelected: (s) => setState(() => _statusFilter = s),
          ),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _projects.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _projects.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Error loading projects: $_error', textAlign: TextAlign.center),
        ),
      );
    }
    if (_projects.isEmpty) {
      return EmptyState(
        icon: Icons.engineering_outlined,
        title: 'No assigned projects',
        message: 'Projects assigned to you will appear here.',
        actionLabel: 'Complete your profile',
        onAction: () => context.push('/account/profile/builder'),
      );
    }

    final projects = _filtered;
    if (projects.isEmpty) {
      return const Center(child: Text('No projects match your search.'));
    }

    // Group by ownerName
    final groups = <String, List<Project>>{};
    for (final p in projects) {
      final owner = p.ownerName ?? 'Unknown Owner';
      groups.putIfAbsent(owner, () => []).add(p);
    }
    final ownerNames = groups.keys.toList()..sort();

    return RefreshIndicator(
      onRefresh: _loadFirst,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: ownerNames.length + (_hasMore || _loading ? 1 : 0),
        itemBuilder: (context, gi) {
          if (gi == ownerNames.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: _loading
                    ? const CircularProgressIndicator()
                    : TextButton.icon(
                        icon: const Icon(Icons.expand_more),
                        label: const Text('Load more'),
                        onPressed: _loadMore,
                      ),
              ),
            );
          }
          final ownerName = ownerNames[gi];
          final ownerProjects = groups[ownerName]!;
          return _BuilderOwnerGroup(
            ownerName: ownerName,
            projects: ownerProjects,
          );
        },
      ),
    );
  }
}

/// Group card showing all projects under one owner for a builder.
class _BuilderOwnerGroup extends StatelessWidget {
  const _BuilderOwnerGroup({
    required this.ownerName,
    required this.projects,
  });

  final String ownerName;
  final List<Project> projects;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Row(
            children: [
              Icon(Icons.person_outline, size: 16, color: cs.outline),
              const SizedBox(width: 6),
              Text(
                ownerName,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: cs.outline,
                    ),
              ),
            ],
          ),
        ),
        for (final p in projects) ...[
          _BuilderProjectCard(project: p),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _BuilderProjectCard extends StatelessWidget {
  const _BuilderProjectCard({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final builderState = context.watch<BuilderProjectState>();
    final isActive = builderState.isSameProject(project.id);

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: isActive
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: cs.primary, width: 2),
            )
          : null,
      child: InkWell(
        onTap: () => _handleTap(context, builderState),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isActive) ...[
                    Icon(Icons.check_circle, size: 16, color: cs.primary),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      project.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(status: project.status),
                ],
              ),
              if ((project.location ?? project.region).isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.place_outlined, size: 14, color: cs.outline),
                    const SizedBox(width: 4),
                    Text(
                      project.location?.isNotEmpty == true
                          ? project.location!
                          : project.region,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.outline,
                          ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Text(
                DateFormat('d MMM yyyy').format(project.createdAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.outline,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleTap(
    BuildContext context,
    BuilderProjectState builderState,
  ) async {
    // If there's already a different active project, confirm before switching.
    if (builderState.hasActive && !builderState.isSameProject(project.id)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.swap_horiz_outlined),
          title: const Text('Switch project?'),
          content: Text(
            'You are currently working on "${builderState.activeProjectTitle}".\n\n'
            'Switch to "${project.title}"?\n\n'
            'Make sure you have finished adding details to your current project before switching.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Stay'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Switch'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    builderState.activate(project.id, project.title);

    if (context.mounted) {
      context.push('/projects/${project.id}', extra: project.title);
    }
  }
}

// ── Status filter bar ──────────────────────────────────────────────────────────

class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({required this.selected, required this.onSelected});
  final ProjectStatus? selected;
  final void Function(ProjectStatus?) onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            label: const Text('All'),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
          const SizedBox(width: 6),
          for (final s in ProjectStatus.values) ...[
            FilterChip(
              label: Text(s.label),
              selected: selected == s,
              onSelected: (_) => onSelected(selected == s ? null : s),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

// ── Project card (owner view) ───────────────────────────────────────────────────

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project, required this.onTap});

  final Project project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final budget = project.budget;
    final spent = project.amountSpent;
    final progress = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    final overBudget = budget > 0 && spent > budget;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      project.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(status: project.status),
                ],
              ),

              if ((project.location ?? project.region).isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.place_outlined, size: 14, color: cs.outline),
                    const SizedBox(width: 4),
                    Text(
                      project.location?.isNotEmpty == true
                          ? project.location!
                          : project.region,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.outline,
                          ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),

              if (budget > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Spent  ${project.currencySymbol}${_fmt(spent)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: overBudget ? cs.error : null,
                          ),
                    ),
                    Text(
                      'Budget  ${project.currencySymbol}${_fmt(budget)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: cs.surfaceContainerHighest,
                  color: overBudget ? cs.error : cs.primary,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(4),
                ),
              ] else
                Text(
                  'No budget set',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.outline,
                      ),
                ),

              const SizedBox(height: 8),

              Row(
                children: [
                  if (project.assignedPmName != null) ...[
                    Icon(Icons.engineering_outlined, size: 14, color: cs.outline),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        project.assignedPmName!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.outline,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else
                    Expanded(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: Icon(Icons.person_search_outlined,
                            size: 14, color: cs.primary,),
                        label: Text(
                          'Find a Builder',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cs.primary,
                              ),
                        ),
                        onPressed: () => Navigator.of(context).push(
                          AppPageRoute<void>(
                            builder: (_) => BuilderMarketplacePage(
                              initialRegion: project.region.isNotEmpty
                                  ? project.region
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Text(
                    DateFormat('d MMM yyyy').format(project.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.outline,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(double v) => v >= 1000
      ? NumberFormat('#,##0').format(v)
      : v.toStringAsFixed(0);
}

// ── Status chip ────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final ProjectStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, textColor) = switch (status) {
      ProjectStatus.planning => (
          Theme.of(context).colorScheme.secondaryContainer,
          Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ProjectStatus.active => (
          Theme.of(context).colorScheme.primaryContainer,
          Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ProjectStatus.paused => (
          Theme.of(context).colorScheme.tertiaryContainer,
          Theme.of(context).colorScheme.onTertiaryContainer,
        ),
      ProjectStatus.completed => (
          Theme.of(context).colorScheme.surfaceContainerHighest,
          Theme.of(context).colorScheme.onSurfaceVariant,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 11, color: textColor),
      ),
    );
  }
}

