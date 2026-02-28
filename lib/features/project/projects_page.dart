// lib/features/project/projects_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/app_user.dart';
import '../../core/models/project.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/project_service.dart';
import '../../core/state/builder_project_state.dart';
import 'builder_marketplace_page.dart';
import 'create_project_page.dart';
import 'project_details_page.dart';

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

  List<Project> _applyFilters(List<Project> all) {
    var list = all;
    if (_statusFilter != null) {
      list = list.where((p) => p.status == _statusFilter).toList();
    }
    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      list = list
          .where((p) =>
              p.title.toLowerCase().contains(q) ||
              (p.location?.toLowerCase().contains(q) ?? false) ||
              p.region.toLowerCase().contains(q),)
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final projectService = context.read<ProjectService>();
    final uid = auth.currentUser!.uid;

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
          Expanded(
            child: StreamBuilder<List<Project>>(
              stream: projectService.projectsForOwner(uid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Error loading projects: ${snap.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final all = snap.data ?? [];
                final projects = _applyFilters(all);

                if (all.isEmpty) {
                  return _EmptyState(
                    onCreateTap: () => _openCreate(context),
                  );
                }

                if (projects.isEmpty) {
                  return const Center(
                    child: Text('No projects match your search.'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  itemCount: projects.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _ProjectCard(
                    project: projects[i],
                    onTap: () => _openDetails(context, projects[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreate(context),
        icon: const Icon(Icons.add),
        label: const Text('New Project'),
      ),
    );
  }

  void _openCreate(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CreateProjectPage(),
      ),
    );
  }

  void _openDetails(BuildContext context, Project project) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProjectDetailsPage(
          projectId: project.id,
          projectTitle: project.title,
        ),
      ),
    );
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

  List<Project> _applyFilters(List<Project> all) {
    var list = all;
    if (_statusFilter != null) {
      list = list.where((p) => p.status == _statusFilter).toList();
    }
    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      list = list
          .where((p) =>
              p.title.toLowerCase().contains(q) ||
              (p.location?.toLowerCase().contains(q) ?? false) ||
              p.region.toLowerCase().contains(q) ||
              (p.ownerName?.toLowerCase().contains(q) ?? false),)
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final projectService = context.read<ProjectService>();
    final uid = auth.currentUser!.uid;

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
          Expanded(
            child: StreamBuilder<List<Project>>(
              stream: projectService.projectsForBuilder(uid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Error loading projects: ${snap.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final all = snap.data ?? [];
                final projects = _applyFilters(all);

                if (all.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.engineering_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No assigned projects',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Projects assigned to you will appear here.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (projects.isEmpty) {
                  return const Center(
                    child: Text('No projects match your search.'),
                  );
                }

                // Group filtered projects by ownerName
                final groups = <String, List<Project>>{};
                for (final p in projects) {
                  final owner = p.ownerName ?? 'Unknown Owner';
                  groups.putIfAbsent(owner, () => []).add(p);
                }
                final ownerNames = groups.keys.toList()..sort();

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  itemCount: ownerNames.length,
                  itemBuilder: (context, gi) {
                    final ownerName = ownerNames[gi];
                    final ownerProjects = groups[ownerName]!;
                    return _BuilderOwnerGroup(
                      ownerName: ownerName,
                      projects: ownerProjects,
                    );
                  },
                );
              },
            ),
          ),
        ],
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
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProjectDetailsPage(
            projectId: project.id,
            projectTitle: project.title,
          ),
        ),
      );
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
                          MaterialPageRoute<void>(
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

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreateTap});
  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.work_outline,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No projects yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first project to start tracking costs and progress.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(Icons.add),
              label: const Text('Create project'),
            ),
          ],
        ),
      ),
    );
  }
}
