// lib/features/project/project_details_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/cost_entry.dart';
import '../../core/models/phase.dart';
import '../../core/models/project.dart';
import '../../core/models/project_document.dart';
import '../../core/models/project_update.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/builder_profile_service.dart';
import '../../core/services/project_service.dart';
import 'builder_marketplace_page.dart';

class ProjectDetailsPage extends StatefulWidget {
  const ProjectDetailsPage({
    super.key,
    required this.projectId,
    this.projectTitle = '',
  });

  final String projectId;
  final String projectTitle;

  @override
  State<ProjectDetailsPage> createState() => _ProjectDetailsPageState();
}

class _ProjectDetailsPageState extends State<ProjectDetailsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this)
      ..addListener(() {
        if (!_tabs.indexIsChanging) {
          setState(() => _tabIndex = _tabs.index);
        }
      });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectService = context.read<ProjectService>();

    return StreamBuilder<Project?>(
      stream: projectService.projectStream(widget.projectId),
      builder: (context, snap) {
        final project = snap.data;
        final title = project?.title ?? widget.projectTitle;

        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: [
              if (project != null)
                PopupMenuButton<_MenuAction>(
                  onSelected: (action) =>
                      _handleMenu(context, action, project),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _MenuAction.editStatus,
                      child: Text('Change status'),
                    ),
                    PopupMenuItem(
                      value: _MenuAction.delete,
                      child: Text('Delete project'),
                    ),
                  ],
                ),
            ],
            bottom: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(icon: Icon(Icons.info_outline), text: 'Overview'),
                Tab(icon: Icon(Icons.layers_outlined), text: 'Phases'),
                Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Costs'),
                Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Updates'),
                Tab(icon: Icon(Icons.folder_outlined), text: 'Docs'),
              ],
            ),
          ),
          body: snap.connectionState == ConnectionState.waiting && project == null
              ? const Center(child: CircularProgressIndicator())
              : project == null
                  ? const Center(child: Text('Project not found.'))
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        _OverviewTab(
                          project: project,
                          projectId: widget.projectId,
                          projectService: projectService,
                          builderProfileService:
                              context.read<BuilderProfileService>(),
                          currentUserUid:
                              context.read<AuthService>().currentUser?.uid ?? '',
                        ),
                        _PhasesTab(
                          projectId: widget.projectId,
                          projectService: projectService,
                        ),
                        _CostsTab(
                          projectId: widget.projectId,
                          currencySymbol: project.currencySymbol,
                          projectService: projectService,
                        ),
                        _UpdatesTab(
                          projectId: widget.projectId,
                          projectService: projectService,
                        ),
                        _DocsTab(
                          projectId: widget.projectId,
                          projectService: projectService,
                        ),
                      ],
                    ),
          floatingActionButton: project != null
              ? _buildFab(context, project)
              : null,
        );
      },
    );
  }

  Widget? _buildFab(BuildContext context, Project project) {
    final projectService = context.read<ProjectService>();
    final auth = context.read<AuthService>();

    return switch (_tabIndex) {
      1 => FloatingActionButton(
          tooltip: 'Add phase',
          onPressed: () => _showAddPhase(context, projectService),
          child: const Icon(Icons.add),
        ),
      2 => FloatingActionButton(
          tooltip: 'Add cost entry',
          onPressed: () => _showAddCost(
            context,
            projectService,
            auth.currentUser!.uid,
          ),
          child: const Icon(Icons.add),
        ),
      3 => FloatingActionButton(
          tooltip: 'Add update',
          onPressed: () => _showAddUpdate(
            context,
            projectService,
            auth.currentUser!.uid,
          ),
          child: const Icon(Icons.add),
        ),
      4 => FloatingActionButton(
          tooltip: 'Upload document',
          onPressed: () => _uploadDoc(
            context,
            projectService,
            auth.currentUser!.uid,
          ),
          child: const Icon(Icons.upload_file_outlined),
        ),
      _ => null,
    };
  }

  // ── Phase sheet ──────────────────────────────────────────────────────────────

  void _showAddPhase(BuildContext context, ProjectService projectService) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _AddPhaseSheet(
        projectId: widget.projectId,
        existingCount: 0,
        projectService: projectService,
      ),
    );
  }

  // ── Cost sheet ───────────────────────────────────────────────────────────────

  void _showAddCost(
    BuildContext context,
    ProjectService projectService,
    String authorUid,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _AddCostSheet(
        projectId: widget.projectId,
        authorUid: authorUid,
        projectService: projectService,
      ),
    );
  }

  // ── Update sheet ─────────────────────────────────────────────────────────────

  void _showAddUpdate(
    BuildContext context,
    ProjectService projectService,
    String authorUid,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _AddUpdateSheet(
        projectId: widget.projectId,
        authorUid: authorUid,
        projectService: projectService,
      ),
    );
  }

  // ── Doc upload ───────────────────────────────────────────────────────────────

  Future<void> _uploadDoc(
    BuildContext context,
    ProjectService projectService,
    String uploaderUid,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    if (picked.path == null) return;

    final file = File(picked.path!);
    final fileName = picked.name;

    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await projectService.uploadDocument(
        projectId: widget.projectId,
        uploaderUid: uploaderUid,
        file: file,
        fileName: fileName,
        contentType: picked.extension != null
            ? _mimeFromExt(picked.extension!)
            : null,
      );
      messenger.showSnackBar(
        SnackBar(content: Text('"$fileName" uploaded.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  String? _mimeFromExt(String ext) => switch (ext.toLowerCase()) {
        'pdf' => 'application/pdf',
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'doc' => 'application/msword',
        'docx' =>
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'xls' => 'application/vnd.ms-excel',
        'xlsx' =>
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        _ => null,
      };

  // ── Menu actions ─────────────────────────────────────────────────────────────

  Future<void> _handleMenu(
    BuildContext context,
    _MenuAction action,
    Project project,
  ) async {
    final projectService = context.read<ProjectService>();

    switch (action) {
      case _MenuAction.editStatus:
        await _showStatusPicker(context, project, projectService);
      case _MenuAction.delete:
        await _confirmDelete(context, projectService);
    }
  }

  Future<void> _showStatusPicker(
    BuildContext context,
    Project project,
    ProjectService projectService,
  ) async {
    final picked = await showDialog<ProjectStatus>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Change status'),
        children: [
          for (final s in ProjectStatus.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, s),
              child: Row(
                children: [
                  if (s == project.status)
                    const Icon(Icons.check, size: 18)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Text(s.label),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked != null && picked != project.status) {
      await projectService.updateProject(
        widget.projectId,
        {'status': picked.firestoreValue},
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ProjectService projectService,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete project?'),
        content: const Text(
          'This will permanently delete the project. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await projectService.deleteProject(widget.projectId);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

enum _MenuAction { editStatus, delete }

// ── Overview tab ───────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.project,
    required this.projectId,
    required this.projectService,
    required this.builderProfileService,
    required this.currentUserUid,
  });
  final Project project;
  final String projectId;
  final ProjectService projectService;
  final BuilderProfileService builderProfileService;
  final String currentUserUid;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final budget = project.budget;
    final spent = project.amountSpent;
    final progress = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    final overBudget = budget > 0 && spent > budget;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status + header
        Row(
          children: [
            Expanded(
              child: Text(
                project.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            _StatusBadge(status: project.status),
          ],
        ),

        if (project.description != null) ...[
          const SizedBox(height: 8),
          Text(
            project.description!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],

        const SizedBox(height: 16),

        // Info rows
        _InfoCard(children: [
          if ((project.location ?? '').isNotEmpty)
            _kv(
              context,
              Icons.place_outlined,
              'Location',
              project.location!,
            ),
          if (project.region.isNotEmpty)
            _kv(
              context,
              Icons.map_outlined,
              'Region',
              project.region,
            ),
          _kv(
            context,
            Icons.calendar_today_outlined,
            'Created',
            DateFormat('d MMM yyyy').format(project.createdAt),
          ),
          _kv(
            context,
            Icons.update,
            'Updated',
            DateFormat('d MMM yyyy').format(project.updatedAt),
          ),
        ],),

        const SizedBox(height: 16),

        // Budget card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Budget',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                if (budget > 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Spent',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          Text(
                            '${project.currencySymbol}${_fmt(spent)}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: overBudget ? cs.error : cs.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Budget',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          Text(
                            '${project.currencySymbol}${_fmt(budget)}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: cs.surfaceContainerHighest,
                    color: overBudget ? cs.error : cs.primary,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    overBudget
                        ? 'Over budget by ${project.currencySymbol}${_fmt(spent - budget)}'
                        : 'Remaining: ${project.currencySymbol}${_fmt(budget - spent)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: overBudget ? cs.error : cs.outline,
                        ),
                  ),
                ] else
                  Text(
                    'No budget set',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.outline,
                        ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Assigned PM card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: cs.secondaryContainer,
                      child: Icon(
                        Icons.person_outline,
                        color: cs.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Builder',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          Text(
                            project.assignedPmName ?? 'Not assigned',
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: project.assignedPmName == null
                                          ? cs.outline
                                          : null,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.person_search_outlined, size: 18),
                        label: Text(project.assignedPmUid == null
                            ? 'Assign Builder'
                            : 'Change Builder',),
                        onPressed: () => _openPmPicker(context),
                      ),
                    ),
                    if (project.assignedPmUid != null) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.error,
                          side: BorderSide(color: cs.error),
                        ),
                        icon: const Icon(Icons.person_remove_outlined, size: 18),
                        label: const Text('Remove'),
                        onPressed: () => _removePm(context),
                      ),
                    ],
                  ],
                ),
                if (project.assignedPmUid != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.star_outline, size: 18),
                      label: const Text('Rate Builder'),
                      onPressed: () => _ratePm(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _kv(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.outline),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.outline,
                  ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) =>
      v >= 1000 ? NumberFormat('#,##0').format(v) : v.toStringAsFixed(0);

  void _openPmPicker(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BuilderMarketplacePage(
          initialRegion: project.region.isNotEmpty ? project.region : null,
          onSelect: (builder) async {
            Navigator.of(context).pop();
            await projectService.assignPm(
              projectId,
              pmUid: builder.uid,
              pmName: builder.displayName,
            );
          },
        ),
      ),
    );
  }

  Future<void> _removePm(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Builder?'),
        content: const Text('This will unassign the current builder.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await projectService.removePm(projectId);
    }
  }

  Future<void> _ratePm(BuildContext context) async {
    int selectedRating = 5;
    final commentCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Rate Builder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 1; i <= 5; i++)
                    IconButton(
                      icon: Icon(
                        i <= selectedRating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                      ),
                      onPressed: () =>
                          setDlgState(() => selectedRating = i),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: commentCtrl,
                decoration: const InputDecoration(
                  hintText: 'Optional comment',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && project.assignedPmUid != null &&
        context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await builderProfileService.addReview(
          builderUid: project.assignedPmUid!,
          reviewerUid: currentUserUid,
          rating: selectedRating.toDouble(),
          comment: commentCtrl.text.trim(),
        );
        messenger.showSnackBar(
          const SnackBar(content: Text('Rating submitted')),
        );
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    commentCtrl.dispose();
  }
}

// ── Phases tab ─────────────────────────────────────────────────────────────────

class _PhasesTab extends StatelessWidget {
  const _PhasesTab({
    required this.projectId,
    required this.projectService,
  });

  final String projectId;
  final ProjectService projectService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Phase>>(
      stream: projectService.phasesStream(projectId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final phases = snap.data ?? [];
        if (phases.isEmpty) {
          return _centeredHint(
            context,
            Icons.layers_outlined,
            'No phases yet',
            'Tap + to add your first phase.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: phases.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _PhaseCard(
            phase: phases[i],
            onTap: () => _showEditPhase(context, phases[i]),
            onDelete: () => projectService.deletePhase(
              projectId,
              phases[i].id,
            ),
          ),
        );
      },
    );
  }

  void _showEditPhase(BuildContext context, Phase phase) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _AddPhaseSheet(
        projectId: projectId,
        existingCount: phase.order,
        projectService: projectService,
        editing: phase,
      ),
    );
  }
}

class _PhaseCard extends StatelessWidget {
  const _PhaseCard({
    required this.phase,
    required this.onTap,
    required this.onDelete,
  });

  final Phase phase;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: _statusColor(context, phase.status),
          radius: 18,
          child: Text(
            '${phase.order + 1}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        title: Text(phase.name),
        subtitle: phase.estimatedCostGhs != null
            ? Text(
                'Est. GH₵${NumberFormat('#,##0').format(phase.estimatedCostGhs)}',
                style: Theme.of(context).textTheme.bodySmall,
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PhaseStatusChip(status: phase.status),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: 'Delete phase',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(BuildContext context, PhaseStatus status) {
    final cs = Theme.of(context).colorScheme;
    return switch (status) {
      PhaseStatus.pending => cs.outline,
      PhaseStatus.inProgress => cs.primary,
      PhaseStatus.completed => Colors.green,
    };
  }
}

class _PhaseStatusChip extends StatelessWidget {
  const _PhaseStatusChip({required this.status});
  final PhaseStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      PhaseStatus.pending => (
          Theme.of(context).colorScheme.surfaceContainerHighest,
          Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      PhaseStatus.inProgress => (
          Theme.of(context).colorScheme.primaryContainer,
          Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      PhaseStatus.completed => (
          Colors.green.shade100,
          Colors.green.shade900,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 11, color: fg),
      ),
    );
  }
}

// ── Costs tab ──────────────────────────────────────────────────────────────────

class _CostsTab extends StatelessWidget {
  const _CostsTab({
    required this.projectId,
    required this.currencySymbol,
    required this.projectService,
  });

  final String projectId;
  final String currencySymbol;
  final ProjectService projectService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CostEntry>>(
      stream: projectService.costEntriesStream(projectId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final entries = snap.data ?? [];
        final total = entries.fold<double>(0, (s, e) => s + e.amountGhs);

        if (entries.isEmpty) {
          return _centeredHint(
            context,
            Icons.receipt_long_outlined,
            'No costs recorded',
            'Tap + to add your first cost entry.',
          );
        }

        return Column(
          children: [
            // Total bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total spent',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(
                    '$currencySymbol${NumberFormat('#,##0.00').format(total)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => _CostEntryTile(
                  entry: entries[i],
                  currencySymbol: currencySymbol,
                  onDelete: () => projectService.deleteCostEntry(
                    projectId,
                    entries[i].id,
                    entries[i].amountGhs,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CostEntryTile extends StatelessWidget {
  const _CostEntryTile({
    required this.entry,
    required this.currencySymbol,
    required this.onDelete,
  });

  final CostEntry entry;
  final String currencySymbol;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      title: Text(entry.description),
      subtitle: Text(
        '${entry.category}  •  ${DateFormat('d MMM yyyy').format(entry.createdAt)}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$currencySymbol${NumberFormat('#,##0.00').format(entry.amountGhs)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            tooltip: 'Delete',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ── Updates tab ────────────────────────────────────────────────────────────────

class _UpdatesTab extends StatelessWidget {
  const _UpdatesTab({
    required this.projectId,
    required this.projectService,
  });

  final String projectId;
  final ProjectService projectService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProjectUpdate>>(
      stream: projectService.updatesStream(projectId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final updates = snap.data ?? [];
        if (updates.isEmpty) {
          return _centeredHint(
            context,
            Icons.chat_bubble_outline,
            'No updates yet',
            'Tap + to post the first update.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: updates.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _UpdateCard(update: updates[i]),
        );
      },
    );
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({required this.update});
  final ProjectUpdate update;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.update, size: 16, color: cs.outline),
                const SizedBox(width: 6),
                Text(
                  DateFormat('d MMM yyyy, HH:mm').format(update.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.outline,
                      ),
                ),
                if (update.costDelta != null) ...[
                  const Spacer(),
                  Text(
                    '+ GH₵${NumberFormat('#,##0').format(update.costDelta)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.error,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(update.text),
            if (update.photoUrls.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: update.photoUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      update.photoUrls[i],
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Docs tab ───────────────────────────────────────────────────────────────────

class _DocsTab extends StatelessWidget {
  const _DocsTab({
    required this.projectId,
    required this.projectService,
  });

  final String projectId;
  final ProjectService projectService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProjectDocument>>(
      stream: projectService.documentsStream(projectId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data ?? [];
        if (docs.isEmpty) {
          return _centeredHint(
            context,
            Icons.folder_outlined,
            'No documents yet',
            'Tap the upload button to add files.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (_, i) => _DocTile(
            doc: docs[i],
            projectId: projectId,
            projectService: projectService,
          ),
        );
      },
    );
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({
    required this.doc,
    required this.projectId,
    required this.projectService,
  });

  final ProjectDocument doc;
  final String projectId;
  final ProjectService projectService;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sizeLabel = doc.sizeBytes != null
        ? _formatBytes(doc.sizeBytes!)
        : null;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Icon(
            _iconForType(doc.contentType),
            color: cs.onPrimaryContainer,
            size: 20,
          ),
        ),
        title: Text(doc.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            DateFormat('d MMM yyyy').format(doc.createdAt),
            if (sizeLabel != null) sizeLabel,
          ].join(' · '),
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: cs.outline),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.open_in_new_outlined),
              tooltip: 'Open',
              onPressed: () => _open(context),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: cs.error),
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(doc.url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open file.')),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text('Remove "${doc.name}" from this project?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await projectService.deleteDocument(projectId, doc.id);
    }
  }

  IconData _iconForType(String? type) {
    if (type == null) return Icons.insert_drive_file_outlined;
    if (type.startsWith('image/')) return Icons.image_outlined;
    if (type == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (type.contains('word')) return Icons.description_outlined;
    if (type.contains('sheet') || type.contains('excel')) {
      return Icons.table_chart_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

// ── Add phase sheet ────────────────────────────────────────────────────────────

class _AddPhaseSheet extends StatefulWidget {
  const _AddPhaseSheet({
    required this.projectId,
    required this.existingCount,
    required this.projectService,
    this.editing,
  });

  final String projectId;
  final int existingCount;
  final ProjectService projectService;
  final Phase? editing;

  @override
  State<_AddPhaseSheet> createState() => _AddPhaseSheetState();
}

class _AddPhaseSheetState extends State<_AddPhaseSheet> {
  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _estCostCtrl = TextEditingController();
  PhaseStatus _status = PhaseStatus.pending;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.editing != null) {
      final e = widget.editing!;
      _nameCtrl.text = e.name;
      _notesCtrl.text = e.notes ?? '';
      _estCostCtrl.text = e.estimatedCostGhs?.toStringAsFixed(0) ?? '';
      _status = e.status;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    _estCostCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      if (widget.editing != null) {
        await widget.projectService.updatePhase(
          widget.projectId,
          widget.editing!.id,
          {
            'name': _nameCtrl.text.trim(),
            'status': _status.firestoreValue,
            if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
            if (_estCostCtrl.text.isNotEmpty)
              'estimatedCostGhs': double.tryParse(_estCostCtrl.text),
          },
        );
      } else {
        final phase = Phase(
          id: '',
          name: _nameCtrl.text.trim(),
          order: widget.existingCount,
          status: _status,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          estimatedCostGhs: double.tryParse(_estCostCtrl.text),
          createdAt: DateTime.now(),
        );
        await widget.projectService.addPhase(widget.projectId, phase);
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            editing ? 'Edit Phase' : 'Add Phase',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Phase name *',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<PhaseStatus>(
            initialValue: _status,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final s in PhaseStatus.values)
                DropdownMenuItem(value: s, child: Text(s.label)),
            ],
            onChanged: (v) => setState(() => _status = v ?? _status),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _estCostCtrl,
            decoration: const InputDecoration(
              labelText: 'Estimated cost (GHS, optional)',
              prefixText: 'GH₵ ',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : (editing ? 'Update' : 'Add phase')),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add cost sheet ─────────────────────────────────────────────────────────────

class _AddCostSheet extends StatefulWidget {
  const _AddCostSheet({
    required this.projectId,
    required this.authorUid,
    required this.projectService,
  });

  final String projectId;
  final String authorUid;
  final ProjectService projectService;

  @override
  State<_AddCostSheet> createState() => _AddCostSheetState();
}

class _AddCostSheetState extends State<_AddCostSheet> {
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _category = CostEntry.categories.first;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final desc = _descCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text);
    if (desc.isEmpty || amount == null || amount <= 0) {
      setState(() => _error = 'Enter a description and a valid amount.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final entry = CostEntry(
        id: '',
        authorUid: widget.authorUid,
        description: desc,
        category: _category,
        amountGhs: amount,
        createdAt: DateTime.now(),
      );
      await widget.projectService.addCostEntry(widget.projectId, entry);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add Cost Entry',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Description *',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final c in CostEntry.categories)
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            decoration: const InputDecoration(
              labelText: 'Amount (GHS) *',
              prefixText: 'GH₵ ',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Add cost entry'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add update sheet ───────────────────────────────────────────────────────────

class _AddUpdateSheet extends StatefulWidget {
  const _AddUpdateSheet({
    required this.projectId,
    required this.authorUid,
    required this.projectService,
  });

  final String projectId;
  final String authorUid;
  final ProjectService projectService;

  @override
  State<_AddUpdateSheet> createState() => _AddUpdateSheetState();
}

class _AddUpdateSheetState extends State<_AddUpdateSheet> {
  final _textCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _textCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Enter a note or update.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.projectService.addUpdate(
        projectId: widget.projectId,
        authorUid: widget.authorUid,
        text: text,
        costDelta: double.tryParse(_costCtrl.text),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add Update',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _textCtrl,
            decoration: const InputDecoration(
              labelText: 'Note / update *',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _costCtrl,
            decoration: const InputDecoration(
              labelText: 'Cost incurred (GHS, optional)',
              prefixText: 'GH₵ ',
              hintText: 'Leave blank if none',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Post update'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final ProjectStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w500),
      ),
    );
  }
}

Widget _centeredHint(
  BuildContext context,
  IconData icon,
  String title,
  String subtitle,
) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
