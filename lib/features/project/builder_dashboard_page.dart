// lib/features/project/builder_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/config/service_locator.dart';
import '../../core/models/phase.dart';
import '../../core/models/project.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/project_service.dart';
import '../../core/widgets/empty_state.dart';

class BuilderDashboardPage extends StatefulWidget {
  const BuilderDashboardPage({super.key});

  @override
  State<BuilderDashboardPage> createState() => _BuilderDashboardPageState();
}

class _BuilderDashboardPageState extends State<BuilderDashboardPage> {
  List<Project> _projects = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProjects());
  }

  Future<void> _loadProjects() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final uid = context.read<AuthService>().currentUser!.uid;
    try {
      final (page, _) = await sl<ProjectService>().fetchBuilderProjectsPage(
        uid,
        limit: 50,
      );
      if (mounted) {
        setState(() {
          _projects = page;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _projects.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && _projects.isEmpty) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Error loading projects',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _loadProjects,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_projects.isEmpty) {
      return Scaffold(
        body: EmptyState(
          icon: Icons.engineering_outlined,
          title: 'No active projects',
          message:
              'No active projects. Contact your client to be added to a project.',
          actionLabel: 'Complete your profile',
          onAction: () => context.push('/account/profile/builder'),
        ),
      );
    }

    // Find most recent active project for action items
    final activeProjects = _projects
        .where((p) => p.status == ProjectStatus.active)
        .toList();
    final Project? focusProject =
        activeProjects.isNotEmpty ? activeProjects.first : null;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadProjects,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            // Action section header
            Text(
              'What needs your attention',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),

            if (focusProject != null)
              _PhaseActionsSection(project: focusProject)
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'No active projects right now. Check back once your client activates a project.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // All projects section
            Text(
              'All my projects',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),

            for (final project in _projects) ...[
              _CondensedProjectCard(project: project),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Phase actions for the focused active project ────────────────────────────

class _PhaseActionsSection extends StatelessWidget {
  const _PhaseActionsSection({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Phase>>(
      stream: sl<ProjectService>().phasesStream(project.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error loading phases: ${snapshot.error}'),
            ),
          );
        }

        final phases = snapshot.data ?? [];

        // 1. Rejected phases (pendingApproval + rejectionComment)
        final rejected = phases
            .where(
              (p) =>
                  p.status == PhaseStatus.pendingApproval &&
                  p.rejectionComment != null &&
                  p.rejectionComment!.isNotEmpty,
            )
            .toList();

        // 2. Ready to submit (inProgress + >= 2 photos)
        final readyToSubmit = phases
            .where(
              (p) =>
                  p.status == PhaseStatus.inProgress &&
                  p.completionPhotoUrls.length >= 2,
            )
            .toList();

        // 3. Needs more photos (inProgress + < 2 photos)
        final needsPhotos = phases
            .where(
              (p) =>
                  p.status == PhaseStatus.inProgress &&
                  p.completionPhotoUrls.length < 2,
            )
            .toList();

        final hasActions =
            rejected.isNotEmpty ||
            readyToSubmit.isNotEmpty ||
            needsPhotos.isNotEmpty;

        if (!hasActions) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'All caught up on "${project.title}". Keep up the great work!',
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Project label
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                project.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ),

            // Rejected phases (red)
            for (final phase in rejected)
              _ActionCard(
                key: ValueKey('rejected-${phase.id}'),
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor:
                    Theme.of(context).colorScheme.onErrorContainer,
                icon: Icons.cancel_outlined,
                title: 'Rejected: ${phase.name}',
                subtitle: phase.rejectionComment!,
                actionLabel: 'View rejection',
                onTap: () =>
                    context.push('/projects/${project.id}', extra: project.title),
              ),

            // Ready to submit (green)
            for (final phase in readyToSubmit)
              _ActionCard(
                key: ValueKey('submit-${phase.id}'),
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                foregroundColor:
                    Theme.of(context).colorScheme.onPrimaryContainer,
                icon: Icons.upload_outlined,
                title: '${phase.name} — Ready to submit',
                subtitle:
                    '${phase.completionPhotoUrls.length} photos uploaded. Submit for owner approval.',
                actionLabel: 'Submit for approval',
                onTap: () =>
                    context.push('/projects/${project.id}', extra: project.title),
              ),

            // Needs photos (amber)
            for (final phase in needsPhotos)
              _ActionCard(
                key: ValueKey('photos-${phase.id}'),
                backgroundColor: Colors.amber.shade100,
                foregroundColor: Colors.brown.shade800,
                icon: Icons.add_a_photo_outlined,
                title: '${phase.name} needs photos',
                subtitle:
                    '${phase.completionPhotoUrls.length}/2 photos uploaded. Add at least 2 to submit.',
                actionLabel: 'Add photos',
                onTap: () =>
                    context.push('/projects/${project.id}', extra: project.title),
              ),
          ],
        );
      },
    );
  }
}

// ── Action card ─────────────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    super.key,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: foregroundColor, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: foregroundColor,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: foregroundColor,
                            ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: foregroundColor,
                          foregroundColor: backgroundColor,
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        onPressed: onTap,
                        child: Text(actionLabel),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Condensed project card ──────────────────────────────────────────────────

class _CondensedProjectCard extends StatelessWidget {
  const _CondensedProjectCard({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            context.push('/projects/${project.id}', extra: project.title),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.title,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((project.ownerName ?? '').isNotEmpty)
                      Text(
                        project.ownerName!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.outline,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusChip(status: project.status),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: cs.outline),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Status chip (local copy so this file is self-contained) ─────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final ProjectStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (color, textColor) = switch (status) {
      ProjectStatus.planning => (
          cs.secondaryContainer,
          cs.onSecondaryContainer,
        ),
      ProjectStatus.active => (
          cs.primaryContainer,
          cs.onPrimaryContainer,
        ),
      ProjectStatus.paused => (
          cs.tertiaryContainer,
          cs.onTertiaryContainer,
        ),
      ProjectStatus.completed => (
          cs.surfaceContainerHighest,
          cs.onSurfaceVariant,
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
