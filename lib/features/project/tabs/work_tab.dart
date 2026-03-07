// lib/features/project/tabs/work_tab.dart
import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/config/service_locator.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/audit_event.dart';
import '../../../core/models/boq_item.dart';
import '../../../core/models/cost_entry.dart';
import '../../../core/models/deletion_request.dart';
import '../../../core/models/phase.dart';
import '../../../core/models/project_update.dart';
import '../../../core/models/snag_item.dart';
import '../../../core/services/audit_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/boq_service.dart';
import '../../../core/services/deletion_request_service.dart';
import '../../../core/services/project_service.dart';
import '../../../core/services/snag_service.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/shimmer_box.dart';
import '../../estimate/boq_page.dart';
import '../widgets/phases_timeline.dart';
import '../widgets/project_shared_widgets.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

enum _WorkSection { phases, monitor, issues, siteLog }

class WorkTab extends StatefulWidget {
  const WorkTab({
    super.key,
    required this.projectId,
    required this.projectService,
    required this.isOwner,
    required this.isBuilder,
    required this.currentUserUid,
    required this.currentUserName,
    required this.onSectionChanged,
  });

  final String projectId;
  final ProjectService projectService;
  final bool isOwner;
  final bool isBuilder;
  final String currentUserUid;
  final String currentUserName;
  final ValueChanged<int> onSectionChanged;

  @override
  State<WorkTab> createState() => WorkTabState();
}

class WorkTabState extends State<WorkTab> {
  _WorkSection _section = _WorkSection.phases;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SegmentedButton<_WorkSection>(
            expandedInsets: EdgeInsets.zero,
            segments: const [
              ButtonSegment(
                value: _WorkSection.phases,
                icon: Icon(Icons.foundation),
                label: Text('Phases'),
              ),
              ButtonSegment(
                value: _WorkSection.monitor,
                icon: Icon(Icons.monitor_outlined),
                label: Text('Monitor'),
              ),
              ButtonSegment(
                value: _WorkSection.issues,
                icon: Icon(Icons.report_problem_outlined),
                label: Text('Issues'),
              ),
              ButtonSegment(
                value: _WorkSection.siteLog,
                icon: Icon(Icons.photo_library_outlined),
                label: Text('Site Log'),
              ),
            ],
            selected: {_section},
            onSelectionChanged: (s) {
              setState(() => _section = s.first);
              widget.onSectionChanged(s.first.index);
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: IndexedStack(
            index: _section.index,
            children: [
              _PhasesTab(
                projectId: widget.projectId,
                projectService: widget.projectService,
                isOwner: widget.isOwner,
                isBuilder: widget.isBuilder,
              ),
              _MonitorTab(
                projectId: widget.projectId,
                projectService: widget.projectService,
              ),
              _IssuesTab(
                projectId: widget.projectId,
                isOwner: widget.isOwner,
                isBuilder: widget.isBuilder,
                currentUserUid: widget.currentUserUid,
                currentUserName: widget.currentUserName,
              ),
              _SiteLogTab(
                projectId: widget.projectId,
                projectService: widget.projectService,
              ),
            ],
          ),
        ),
      ],
    );
  }
}


enum _PhaseView { list, timeline }


class _PhasesTab extends StatefulWidget {
  const _PhasesTab({
    required this.projectId,
    required this.projectService,
    required this.isOwner,
    required this.isBuilder,
  });

  final String projectId;
  final ProjectService projectService;
  final bool isOwner;
  final bool isBuilder;

  @override
  State<_PhasesTab> createState() => _PhasesTabState();
}

class _PhasesTabState extends State<_PhasesTab> {
  _PhaseView _activeView = _PhaseView.list;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Phase>>(
      stream: widget.projectService.phasesStream(widget.projectId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final phases = snap.data ?? [];

        return Column(
          children: [
            // ── View toggle ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SegmentedButton<_PhaseView>(
                segments: const [
                  ButtonSegment(
                    value: _PhaseView.list,
                    icon: Icon(Icons.list),
                    label: Text('List'),
                  ),
                  ButtonSegment(
                    value: _PhaseView.timeline,
                    icon: Icon(Icons.bar_chart),
                    label: Text('Timeline'),
                  ),
                ],
                selected: {_activeView},
                onSelectionChanged: (s) =>
                    setState(() => _activeView = s.first),
              ),
            ),
            const SizedBox(height: 8),
            // ── EV summary ──
            if (phases.isNotEmpty) _EvSummaryCard(phases: phases),
            // ── Content ──
            Expanded(
              child: phases.isEmpty
                  ? EmptyState(
                      icon: Icons.layers_outlined,
                      title: 'No phases yet',
                      message: 'Add a phase to track your project timeline.',
                      actionLabel: widget.isOwner ? 'Add first phase' : null,
                      onAction: widget.isOwner
                          ? () => showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                showDragHandle: true,
                                builder: (_) => ProjectAddPhaseSheet(
                                  projectId: widget.projectId,
                                  existingCount: 0,
                                  projectService: widget.projectService,
                                ),
                              )
                          : null,
                    )
                  : _activeView == _PhaseView.timeline
                      ? PhasesTimeline(phases: phases)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          itemCount: phases.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final phase = phases[i];
                            return Dismissible(
                              key: ValueKey(phase.id),
                              direction: widget.isOwner
                                  ? DismissDirection.endToStart
                                  : DismissDirection.none,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .errorContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.delete_outline,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer,
                                ),
                              ),
                              confirmDismiss: (_) async {
                                HapticFeedback.mediumImpact();
                                return true;
                              },
                              onDismissed: (_) {
                                widget.projectService.deletePhase(
                                  widget.projectId,
                                  phase.id,
                                );
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '"${phase.name}" deleted',
                                      ),
                                      action: SnackBarAction(
                                        label: 'Undo',
                                        onPressed: () {
                                          widget.projectService.addPhase(
                                            widget.projectId,
                                            phase,
                                          );
                                        },
                                      ),
                                    ),
                                  );
                              },
                              child: _PhaseCard(
                                phase: phase,
                                isOwner: widget.isOwner,
                                isBuilder: widget.isBuilder,
                                onTap: () => _showEditPhase(context, phase),
                                onDelete: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (dlgCtx) => AlertDialog(
                                      title: const Text('Delete phase?'),
                                      content: Text(
                                        'Delete "${phase.name}"?\n\nThis action cannot be undone.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dlgCtx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        FilledButton(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: Theme.of(context)
                                                .colorScheme
                                                .error,
                                            foregroundColor: Theme.of(context)
                                                .colorScheme
                                                .onError,
                                          ),
                                          onPressed: () =>
                                              Navigator.pop(dlgCtx, true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true && context.mounted) {
                                    await widget.projectService.deletePhase(
                                      widget.projectId,
                                      phase.id,
                                    );
                                  }
                                },
                                onSubmitForApproval: () => widget.projectService
                                    .submitPhaseForApproval(
                                  widget.projectId,
                                  phase.id,
                                ),
                                onApprove: () =>
                                    widget.projectService.approvePhase(
                                  widget.projectId,
                                  phase.id,
                                ),
                                onReject: (comment) =>
                                    widget.projectService.rejectPhase(
                                  widget.projectId,
                                  phase.id,
                                  comment: comment,
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }

  void _showEditPhase(BuildContext context, Phase phase) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => ProjectAddPhaseSheet(
        projectId: widget.projectId,
        existingCount: phase.order,
        projectService: widget.projectService,
        editing: phase,
      ),
    );
  }
}

// ── Earned Value summary card ──────────────────────────────────────────────────


class _EvSummaryCard extends StatelessWidget {
  const _EvSummaryCard({required this.phases});
  final List<Phase> phases;

  @override
  Widget build(BuildContext context) {
    // Only meaningful when at least one phase has an estimated cost
    final phasesWithEst = phases.where((p) => (p.estimatedCostGhs ?? 0) > 0);
    if (phasesWithEst.isEmpty) return const SizedBox.shrink();

    final bac =
        phasesWithEst.fold<double>(0, (s, p) => s + p.estimatedCostGhs!);
    final ev = phasesWithEst.fold<double>(
      0,
      (s, p) => s + p.estimatedCostGhs! * (p.percentComplete / 100.0),
    );
    final ac =
        phasesWithEst.fold<double>(0, (s, p) => s + (p.actualCostGhs ?? 0));

    final cpi = ac > 0 ? ev / ac : null;
    final spi = bac > 0 ? ev / bac : null;

    final cs = Theme.of(context).colorScheme;

    Color kpiColor(double? v) {
      if (v == null) return cs.onSurfaceVariant;
      if (v >= 1.0) return Colors.green[700]!;
      if (v >= 0.8) return Colors.orange[700]!;
      return cs.error;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Earned Value Analysis',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _EvKpi(
                    label: 'CPI',
                    tooltip:
                        'Cost Performance Index: EV ÷ AC. >1 = under budget.',
                    value: cpi != null ? cpi.toStringAsFixed(2) : 'N/A',
                    color: kpiColor(cpi),
                  ),
                  const SizedBox(width: 12),
                  _EvKpi(
                    label: 'SPI',
                    tooltip:
                        'Schedule Performance: % of budget earned. >80% = on track.',
                    value: spi != null
                        ? '${(spi * 100).toStringAsFixed(1)}%'
                        : 'N/A',
                    color: kpiColor(spi),
                  ),
                  const SizedBox(width: 12),
                  _EvKpi(
                    label: 'EV',
                    tooltip: 'Earned Value: budget for work physically done.',
                    value: NumberFormat.compactCurrency(
                            symbol: 'GHS ', decimalDigits: 0,)
                        .format(ev),
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EvKpi extends StatelessWidget {
  const _EvKpi({
    required this.label,
    required this.tooltip,
    required this.value,
    required this.color,
  });
  final String label;
  final String tooltip;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,),
            ),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhaseCard extends StatelessWidget {
  const _PhaseCard({
    required this.phase,
    required this.isOwner,
    required this.isBuilder,
    required this.onTap,
    required this.onDelete,
    required this.onSubmitForApproval,
    required this.onApprove,
    required this.onReject,
  });

  final Phase phase;
  final bool isOwner;
  final bool isBuilder;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onSubmitForApproval;
  final VoidCallback onApprove;
  final void Function(String? comment) onReject;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
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
            title: Row(
              children: [
                if (phase.isMilestone) ...[
                  const Icon(Icons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                ],
                Expanded(child: Text(phase.name)),
              ],
            ),
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
                if (isOwner)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    tooltip: 'Delete phase',
                    onPressed: onDelete,
                  ),
              ],
            ),
          ),
          // Percent complete progress bar (always shown when > 0 or in progress)
          if (phase.percentComplete > 0 ||
              phase.status == PhaseStatus.inProgress)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: phase.percentComplete / 100.0,
                        minHeight: 6,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${phase.percentComplete}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          // Delay chip
          if (phase.isDelayed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${phase.delayDays}d late',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(
                        context,
                      ).colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          // Planned vs actual dates
          if (phase.actualStartDate != null || phase.actualEndDate != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (phase.startDate != null && phase.actualStartDate != null)
                    Text(
                      'Started: planned ${DateFormat('d MMM').format(phase.startDate!)} '
                      '→ actual ${DateFormat('d MMM').format(phase.actualStartDate!)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  if (phase.endDate != null && phase.actualEndDate != null)
                    Text(
                      'Ended: planned ${DateFormat('d MMM').format(phase.endDate!)} '
                      '→ actual ${DateFormat('d MMM').format(phase.actualEndDate!)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: phase.isDelayed
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ),
          // Rejection comment banner
          if (phase.rejectionComment != null &&
              phase.rejectionComment!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.errorContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Rejected: ${phase.rejectionComment}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          // Approval action buttons
          if (isBuilder && phase.status == PhaseStatus.inProgress)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Submit for Approval'),
                  onPressed: onSubmitForApproval,
                ),
              ),
            ),
          if (isOwner && phase.status == PhaseStatus.pendingApproval) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.thumb_up_outlined, size: 16),
                      label: const Text('Approve'),
                      onPressed: onApprove,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.thumb_down_outlined, size: 16),
                      label: const Text('Reject'),
                      onPressed: () => _showRejectDialog(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (phase.completionPhotoUrls.isNotEmpty)
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                itemCount: phase.completionPhotoUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ProjectPhotoGallery(
                        urls: phase.completionPhotoUrls,
                        initialIndex: i,
                      ),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: phase.completionPhotoUrls[i],
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          const ShimmerBox(width: 60, height: 60),
                      errorWidget: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showRejectDialog(BuildContext context) async {
    final controller = TextEditingController();
    final comment = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Phase'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (comment != null) {
      onReject(comment.isEmpty ? null : comment);
    }
  }

  Color _statusColor(BuildContext context, PhaseStatus status) {
    final cs = Theme.of(context).colorScheme;
    return switch (status) {
      PhaseStatus.pending => cs.outline,
      PhaseStatus.inProgress => cs.primary,
      PhaseStatus.pendingApproval => Colors.orange,
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
      PhaseStatus.pendingApproval => (
          Colors.orange.shade100,
          Colors.orange.shade900,
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

class BoqTab extends StatelessWidget {
  const BoqTab({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('boq')
          .doc('default')
          .get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final doc = snap.data;
        if (doc == null || !doc.exists) {
          return const EmptyState(
            icon: Icons.table_chart_outlined,
            title: 'No BOQ saved',
            message:
                'Create a project from an estimate to attach a Bill of Quantities.',
          );
        }
        final data = doc.data()!;
        final rawItems = data['items'] as List? ?? [];
        final items = rawItems
            .map((e) => BoqItem.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
        final floorArea = (data['floorAreaSqm'] as num?)?.toDouble() ?? 0.0;
        final grandTotal = items.fold<double>(0, (s, e) => s + e.totalGhs);
        final savedAt = (data['savedAt'] as Timestamp?)?.toDate();
        final fmt = NumberFormat('#,##0');

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bill of Quantities',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Grand Total',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            Text(
                              'GH₵ ${fmt.format(grandTotal)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Floor area',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            Text(
                              '${floorArea.toStringAsFixed(0)} m²',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (savedAt != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Saved ${DateFormat('d MMM y').format(savedAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => BoqPage(
                              precomputedItems: items,
                              floorAreaSqm: floorArea,
                              boqService: sl<BoqService>(),
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.table_chart_outlined),
                        label: const Text('View full BOQ'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Costs tab ──────────────────────────────────────────────────────────────────


class CostsTab extends StatefulWidget {
  const CostsTab({
    super.key,
    required this.projectId,
    required this.currencySymbol,
    required this.projectService,
    required this.isBuilder,
    required this.currentUserUid,
    required this.currentUserName,
    required this.deletionRequestService,
  });

  final String projectId;
  final String currencySymbol;
  final ProjectService projectService;
  final bool isBuilder;
  final String currentUserUid;
  final String currentUserName;
  final DeletionRequestService deletionRequestService;

  @override
  State<CostsTab> createState() => CostsTabState();
}

class CostsTabState extends State<CostsTab> {
  String _costQuery = '';
  final _searchCtrl = TextEditingController();
  int _costsLimit = 50;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CostEntry>>(
      stream: widget.projectService.costEntriesStream(widget.projectId, limit: _costsLimit),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final allEntries = snap.data ?? [];
        final entries = _costQuery.isEmpty
            ? allEntries
            : allEntries.where((e) {
                final q = _costQuery.toLowerCase();
                return e.category.toLowerCase().contains(q) ||
                    e.description.toLowerCase().contains(q);
              }).toList();
        final total = allEntries.fold<double>(0, (s, e) => s + e.amountGhs);

        if (allEntries.isEmpty) {
          return EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No costs recorded',
            message: 'Record your first cost to track spending.',
            actionLabel: 'Add first cost',
            onAction: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => ProjectAddCostSheet(
                projectId: widget.projectId,
                authorUid: widget.currentUserUid,
                projectService: widget.projectService,
              ),
            ),
          );
        }

        return Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search costs…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _costQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _costQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: (v) => setState(() => _costQuery = v),
              ),
            ),
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
                    '${widget.currencySymbol}${NumberFormat('#,##0.00').format(total)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: entries.isEmpty
                  ? const Center(child: Text('No matching costs'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      itemCount: entries.length +
                          (allEntries.length >= _costsLimit ? 1 : 0),
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        if (i == entries.length) {
                          // "Load more" footer
                          return Center(
                            child: TextButton(
                              onPressed: () =>
                                  setState(() => _costsLimit += 50),
                              child: const Text('Load more'),
                            ),
                          );
                        }
                        return _CostEntryTile(
                          entry: entries[i],
                          currencySymbol: widget.currencySymbol,
                          isBuilder: widget.isBuilder,
                          onDelete: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (dlgCtx) => AlertDialog(
                                title: const Text('Delete cost entry?'),
                                content: Text(
                                  'Delete "${entries[i].category}" — '
                                  'GH₵${NumberFormat('#,##0.00').format(entries[i].amountGhs)}?\n\n'
                                  'This action cannot be undone.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dlgCtx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor:
                                          Theme.of(context).colorScheme.error,
                                      foregroundColor:
                                          Theme.of(context).colorScheme.onError,
                                    ),
                                    onPressed: () =>
                                        Navigator.pop(dlgCtx, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true && context.mounted) {
                              await widget.projectService.deleteCostEntry(
                                widget.projectId,
                                entries[i].id,
                                entries[i].amountGhs,
                                phaseId: entries[i].phaseId,
                              );
                            }
                          },
                          onRequestDeletion: () => _requestDeletion(
                            context,
                            entries[i],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _requestDeletion(BuildContext context, CostEntry entry) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Request deletion?'),
        content: Text(
          'Send a deletion request to the owner for:\n\n'
          '"${entry.description}" — GH₵${NumberFormat('#,##0.00').format(entry.amountGhs)}\n\n'
          'The item will only be deleted after the owner approves.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.deletionRequestService.request(
        DeletionRequest(
          itemId: entry.id,
          projectId: widget.projectId,
          itemType: DeletionItemType.costEntry,
          itemDescription: entry.description,
          requestedByUid: widget.currentUserUid,
          requestedByName: widget.currentUserName,
          status: DeletionStatus.pending,
          createdAt: DateTime.now(),
          amountGhs: entry.amountGhs,
        ),
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Deletion request sent to owner.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

class _CostEntryTile extends StatelessWidget {
  const _CostEntryTile({
    required this.entry,
    required this.currencySymbol,
    required this.isBuilder,
    required this.onDelete,
    required this.onRequestDeletion,
  });

  final CostEntry entry;
  final String currencySymbol;
  final bool isBuilder;
  final VoidCallback onDelete;
  final VoidCallback onRequestDeletion;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      title: Text(entry.description),
      subtitle: Text(
        '${entry.category}  •  ${DateFormat('d MMM yyyy').format(entry.createdAt)}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: entry.receiptUrl != null
          ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProjectFullScreenPhoto(
                    url: entry.receiptUrl!,
                    title: entry.description,
                  ),
                ),
              )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (entry.receiptUrl != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                Icons.receipt_outlined,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          Text(
            '$currencySymbol${NumberFormat('#,##0.00').format(entry.amountGhs)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(width: 4),
          if (isBuilder)
            IconButton(
              icon: Icon(
                Icons.flag_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.error,
              ),
              tooltip: 'Request deletion',
              onPressed: onRequestDeletion,
            )
          else
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


class _MonitorTab extends StatelessWidget {
  const _MonitorTab({
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
          return const EmptyState(
            icon: Icons.monitor_outlined,
            title: 'No phases yet',
            message: 'Add phases to track construction progress.',
          );
        }

        final progressPercent = ProjectService.overallProgressPercent(phases);
        final completedCount =
            phases.where((p) => p.status == PhaseStatus.completed).length;
        final inProgressCount =
            phases.where((p) => p.status == PhaseStatus.inProgress).length;
        final delayedPhases = phases.where((p) => p.isDelayed).toList();
        final milestones = phases.where((p) => p.isMilestone).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            // Progress gauge
            _ProgressGauge(progressPercent: progressPercent),
            const SizedBox(height: 16),
            // Schedule health KPI row
            Row(
              children: [
                _MonitorKpiCard(
                  label: 'On Track',
                  value: inProgressCount.toString(),
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                _MonitorKpiCard(
                  label: 'Delayed',
                  value: delayedPhases.length.toString(),
                  color: delayedPhases.isEmpty ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                _MonitorKpiCard(
                  label: 'Completed',
                  value: completedCount.toString(),
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Milestone tracker
            if (milestones.isNotEmpty) ...[
              Text(
                'Milestones',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _MilestoneTracker(milestones: milestones),
              const SizedBox(height: 16),
            ],
            // Delayed phases warning card
            if (delayedPhases.isNotEmpty) ...[
              _DelayedPhasesCard(phases: delayedPhases),
              const SizedBox(height: 16),
            ],
            // Earned Value Analysis (reused)
            _EvSummaryCard(phases: phases),
          ],
        );
      },
    );
  }
}

class _ProgressGauge extends StatelessWidget {
  const _ProgressGauge({required this.progressPercent});
  final double progressPercent;

  @override
  Widget build(BuildContext context) {
    final pct = progressPercent.clamp(0.0, 100.0);
    final color = pct >= 70
        ? Colors.green
        : pct >= 40
            ? Colors.orange
            : Colors.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Overall Progress',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: pct / 100,
                    strokeWidth: 12,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                Text(
                  '${pct.toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MonitorKpiCard extends StatelessWidget {
  const _MonitorKpiCard({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MilestoneTracker extends StatelessWidget {
  const _MilestoneTracker({required this.milestones});
  final List<Phase> milestones;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < milestones.length; i++) ...[
            if (i > 0) const Divider(height: 0, indent: 56),
            ListTile(
              leading: Icon(
                milestones[i].isWorkDone ? Icons.circle : Icons.circle_outlined,
                color: milestones[i].isWorkDone ? Colors.green : cs.outline,
                size: 20,
              ),
              title: Text(milestones[i].name),
              subtitle: milestones[i].endDate != null
                  ? Text(
                      'Due: ${DateFormat('d MMM yyyy').format(milestones[i].endDate!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: !milestones[i].isWorkDone &&
                                milestones[i].endDate!.isBefore(now)
                            ? cs.error
                            : cs.onSurfaceVariant,
                      ),
                    )
                  : null,
              trailing: Icon(
                Icons.diamond_outlined,
                color: Colors.amber,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DelayedPhasesCard extends StatelessWidget {
  const _DelayedPhasesCard({required this.phases});
  final List<Phase> phases;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:
            Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_outlined,
                  color: Theme.of(context).colorScheme.error,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '${phases.length} Delayed Phase${phases.length > 1 ? 's' : ''}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          for (final phase in phases)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                children: [
                  Expanded(child: Text(phase.name)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${phase.delayDays}d late',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _IssuesTab extends StatefulWidget {
  const _IssuesTab({
    required this.projectId,
    required this.isOwner,
    required this.isBuilder,
    required this.currentUserUid,
    required this.currentUserName,
  });

  final String projectId;
  final bool isOwner;
  final bool isBuilder;
  final String currentUserUid;
  final String currentUserName;

  @override
  State<_IssuesTab> createState() => _IssuesTabState();
}

class _IssuesTabState extends State<_IssuesTab> {
  IssueType? _typeFilter;
  IssueSeverity? _severityFilter;

  @override
  Widget build(BuildContext context) {
    final snagService = sl<SnagService>();
    return StreamBuilder<List<SnagItem>>(
      stream: snagService.itemsStream(widget.projectId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final allItems = snap.data ?? [];

        // Apply filters
        final items = allItems.where((item) {
          if (_typeFilter != null && item.issueType != _typeFilter) {
            return false;
          }
          if (_severityFilter != null && item.severity != _severityFilter) {
            return false;
          }
          return true;
        }).toList();

        // Stats by type
        final defectCount =
            allItems.where((i) => i.issueType == IssueType.defect).length;
        final safetyCount = allItems
            .where((i) => i.issueType == IssueType.safetyIncident)
            .length;
        final qualityCount =
            allItems.where((i) => i.issueType == IssueType.qualityIssue).length;

        // Contractor accountability data (owner only)
        final contractorGroups = <String, (int open, int resolved)>{};
        if (widget.isOwner) {
          for (final item in allItems) {
            if (item.contractorName == null) continue;
            final name = item.contractorName!;
            final current = contractorGroups[name] ?? (0, 0);
            if (item.status == SnagStatus.open) {
              contractorGroups[name] = (current.$1 + 1, current.$2);
            } else {
              contractorGroups[name] = (current.$1, current.$2 + 1);
            }
          }
        }

        return Column(
          children: [
            // Stats bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _IssueStatChip(
                      label: 'Defects',
                      count: defectCount,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    _IssueStatChip(
                      label: 'Safety',
                      count: safetyCount,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    _IssueStatChip(
                      label: 'Quality',
                      count: qualityCount,
                      color: Colors.purple,
                    ),
                  ],
                ),
              ),
            ),
            // Type filter chips
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _typeFilter == null,
                      onSelected: (_) => setState(() => _typeFilter = null),
                    ),
                    const SizedBox(width: 8),
                    for (final type in IssueType.values) ...[
                      FilterChip(
                        avatar: Icon(type.icon, size: 14),
                        label: Text(type.label),
                        selected: _typeFilter == type,
                        onSelected: (_) => setState(
                          () => _typeFilter = _typeFilter == type ? null : type,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
            // Severity filter chips
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Any severity'),
                      selected: _severityFilter == null,
                      onSelected: (_) => setState(() => _severityFilter = null),
                    ),
                    const SizedBox(width: 8),
                    for (final sev in IssueSeverity.values) ...[
                      FilterChip(
                        label: Text(sev.label),
                        selected: _severityFilter == sev,
                        selectedColor: sev.color.withValues(alpha: 0.2),
                        onSelected: (_) => setState(
                          () => _severityFilter =
                              _severityFilter == sev ? null : sev,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            // Issue list
            Expanded(
              child: items.isEmpty
                  ? const EmptyState(
                      icon: Icons.check_circle_outline,
                      title: 'No issues found',
                      message:
                          'Great work! No issues matching the current filters.',
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        0,
                        8,
                        0,
                        widget.isOwner && contractorGroups.isNotEmpty
                            ? 260.0
                            : 96.0,
                      ),
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 0, indent: 16),
                      itemBuilder: (_, i) => _IssueCard(
                        item: items[i],
                        projectId: widget.projectId,
                        isOwner: widget.isOwner,
                        isBuilder: widget.isBuilder,
                        snagService: snagService,
                      ),
                    ),
            ),
            // Contractor accountability card (owner only)
            if (widget.isOwner && contractorGroups.isNotEmpty)
              _ContractorAccountabilityCard(groups: contractorGroups),
          ],
        );
      },
    );
  }
}

class _IssueStatChip extends StatelessWidget {
  const _IssueStatChip({
    required this.label,
    required this.count,
    required this.color,
  });
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color,
        radius: 10,
        child: Text(
          '$count',
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({
    required this.item,
    required this.projectId,
    required this.isOwner,
    required this.isBuilder,
    required this.snagService,
  });

  final SnagItem item;
  final String projectId;
  final bool isOwner;
  final bool isBuilder;
  final SnagService snagService;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSafety = item.issueType == IssueType.safetyIncident;

    final (statusIcon, statusColor) = switch (item.status) {
      SnagStatus.confirmed => (Icons.check_circle, Colors.green),
      SnagStatus.resolved => (Icons.check_circle_outline, Colors.orange),
      _ => (Icons.error_outline, cs.error),
    };

    return Card(
      color: isSafety ? cs.errorContainer.withValues(alpha: 0.25) : null,
      child: ListTile(
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.issueType.icon, size: 18, color: cs.primary),
            Icon(statusIcon, size: 14, color: statusColor),
          ],
        ),
        title: Text(item.description),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.contractorName != null)
              Text(
                'Contractor: ${item.contractorName}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (item.assignedToName != null)
              Text(
                'Assigned to: ${item.assignedToName}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (item.dueDate != null)
              Text(
                'Due: ${DateFormat('d MMM yyyy').format(item.dueDate!)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: item.dueDate!.isBefore(DateTime.now()) &&
                              item.status == SnagStatus.open
                          ? cs.error
                          : null,
                    ),
              ),
            if (item.photoUrls.isNotEmpty) ...[
              const SizedBox(height: 4),
              SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: item.photoUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 4),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(
                      imageUrl: item.photoUrls[i],
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Severity badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: item.severity.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: item.severity.color.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                item.severity.label,
                style: TextStyle(
                  fontSize: 10,
                  color: item.severity.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Action button
            if (item.status == SnagStatus.open && isBuilder)
              TextButton(
                onPressed: () => _resolveDialog(context),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(60, 24),
                ),
                child: const Text('Resolve'),
              )
            else if (item.status == SnagStatus.resolved && isOwner)
              FilledButton.tonal(
                onPressed: () => snagService.confirmItem(projectId, item.id),
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(60, 24),
                ),
                child: const Text('Confirm'),
              )
            else if (isOwner && item.status != SnagStatus.confirmed)
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline, size: 18),
                color: cs.error,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => snagService.deleteItem(projectId, item.id),
              ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Future<void> _resolveDialog(BuildContext context) async {
    final notesCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as resolved'),
        content: TextField(
          controller: notesCtrl,
          decoration: const InputDecoration(
            labelText: 'Resolution notes (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    notesCtrl.dispose();
    if (confirmed == true && context.mounted) {
      await snagService.resolveItem(
        projectId,
        item.id,
        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      );
    }
  }
}

class _ContractorAccountabilityCard extends StatelessWidget {
  const _ContractorAccountabilityCard({required this.groups});
  final Map<String, (int open, int resolved)> groups;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contractor Accountability',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          for (final entry in groups.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(child: Text(entry.key)),
                  Text(
                    '${entry.value.$1} open / ${entry.value.$2} resolved',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: entry.value.$1 > 0 ? cs.error : Colors.green,
                        ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Add issue sheet ───────────────────────────────────────────────────────────

class ProjectAddIssueSheet extends StatefulWidget {
  const ProjectAddIssueSheet({
    super.key,
    required this.projectId,
    required this.snagService,
    required this.auth,
  });

  final String projectId;
  final SnagService snagService;
  final AuthService auth;

  @override
  State<ProjectAddIssueSheet> createState() => ProjectAddIssueSheetState();
}

class ProjectAddIssueSheetState extends State<ProjectAddIssueSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _contractorCtrl = TextEditingController();
  IssueType _issueType = IssueType.defect;
  IssueSeverity _severity = IssueSeverity.medium;
  bool _saving = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    _contractorCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final user = widget.auth.currentUser;
      final now = DateTime.now();
      final contractorName = _contractorCtrl.text.trim();
      final item = SnagItem(
        id: '',
        description: _descCtrl.text.trim(),
        createdAt: now,
        createdByUid: user?.uid ?? '',
        createdByName: user?.displayName ?? '',
        issueType: _issueType,
        severity: _severity,
        contractorName: contractorName.isEmpty ? null : contractorName,
      );
      await widget.snagService.addItem(widget.projectId, item);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Report Issue',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            // Issue type chips
            Text(
              'Type',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final type in IssueType.values)
                  ChoiceChip(
                    avatar: Icon(type.icon, size: 14),
                    label: Text(type.label),
                    selected: _issueType == type,
                    onSelected: (_) => setState(() => _issueType = type),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Severity chips
            Text(
              'Severity',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final sev in IssueSeverity.values)
                  ChoiceChip(
                    label: Text(sev.label),
                    selected: _severity == sev,
                    selectedColor: sev.color.withValues(alpha: 0.2),
                    onSelected: (_) => setState(() => _severity = sev),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Description
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description *',
                hintText: 'e.g. Cracked beam on second floor',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            // Contractor name
            TextFormField(
              controller: _contractorCtrl,
              decoration: const InputDecoration(
                labelText: 'Responsible contractor (optional)',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Report issue'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Site Log tab (renamed from _UpdatesTab, with month grouping + AI badge) ────


class _SiteLogTab extends StatelessWidget {
  const _SiteLogTab({
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
          return const EmptyState(
            icon: Icons.photo_library_outlined,
            title: 'No site log entries yet',
            message: 'Tap + to post the first site update.',
          );
        }

        // Group updates by month/year
        final grouped = <String, List<ProjectUpdate>>{};
        for (final u in updates) {
          final key = DateFormat('MMMM yyyy').format(u.createdAt);
          grouped.putIfAbsent(key, () => []).add(u);
        }

        final sections = grouped.entries.toList();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: sections.fold<int>(
            0,
            (total, e) => total + 1 + e.value.length,
          ),
          itemBuilder: (_, idx) {
            var offset = 0;
            for (final section in sections) {
              if (idx == offset) {
                return _MonthHeader(month: section.key);
              }
              offset++;
              final localIdx = idx - offset;
              if (localIdx < section.value.length) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _UpdateCard(update: section.value[localIdx]),
                );
              }
              offset += section.value.length;
            }
            return const SizedBox.shrink();
          },
        );
      },
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.month});
  final String month;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
      child: Row(
        children: [
          Text(
            month,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ],
      ),
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
                if (update.updateType != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      switch (update.updateType) {
                        'milestone' => 'Milestone',
                        'incident' => 'Incident',
                        _ => 'Daily',
                      },
                      style: TextStyle(
                        fontSize: 10,
                        color: cs.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
                if (update.aiVerificationStatus != null) ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'AI Analysis: ${update.aiVerificationStatus}',
                    child: Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: switch (update.aiVerificationStatus) {
                        'verified' => Colors.green,
                        'flagged' => cs.error,
                        _ => cs.outline,
                      },
                    ),
                  ),
                ],
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
                  itemBuilder: (context, i) => GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProjectPhotoGallery(
                          urls: update.photoUrls,
                          initialIndex: i,
                        ),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CachedNetworkImage(
                        imageUrl: update.photoUrls[i],
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            const ShimmerBox(width: 80, height: 80),
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                ),
              ),
              if (update.hasGps) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 12,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${update.photoLat!.toStringAsFixed(5)}, ${update.photoLng!.toStringAsFixed(5)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.green.shade700,
                          ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class ProjectAddPhaseSheet extends StatefulWidget {
  const ProjectAddPhaseSheet({
    super.key,
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
  State<ProjectAddPhaseSheet> createState() => ProjectAddPhaseSheetState();
}

class ProjectAddPhaseSheetState extends State<ProjectAddPhaseSheet> {
  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _estCostCtrl = TextEditingController();
  PhaseStatus _status = PhaseStatus.pending;
  bool _saving = false;
  final List<File> _completionPhotos = [];
  DateTime? _startDate;
  DateTime? _endDate;
  int _percentComplete = 0;
  bool _isMilestone = false;

  @override
  void initState() {
    super.initState();
    if (widget.editing != null) {
      final e = widget.editing!;
      _nameCtrl.text = e.name;
      _notesCtrl.text = e.notes ?? '';
      _estCostCtrl.text = e.estimatedCostGhs?.toStringAsFixed(0) ?? '';
      _status = e.status;
      _startDate = e.startDate;
      _endDate = e.endDate;
      _percentComplete = e.percentComplete;
      _isMilestone = e.isMilestone;
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_startDate ?? now)
        : (_endDate ?? _startDate?.add(const Duration(days: 30)) ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    _estCostCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCompletionPhoto(ImageSource source) async {
    final picked =
        await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (picked != null && mounted) {
      setState(() => _completionPhotos.add(File(picked.path)));
    }
  }

  Future<void> _showPhotoSourcePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickCompletionPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickCompletionPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    // Capture context-dependent services before any await (async gap safety).
    final auditService = sl<AuditService>();
    final actorUid = context.read<AuthService>().currentUser?.uid ?? '';
    final actorName =
        context.read<AuthService>().currentUser?.displayName ?? '';
    try {
      if (widget.editing != null) {
        await widget.projectService.updatePhase(
          widget.projectId,
          widget.editing!.id,
          {
            'name': _nameCtrl.text.trim(),
            'status': _status.firestoreValue,
            'percentComplete': _percentComplete,
            'isMilestone': _isMilestone,
            if (_notesCtrl.text.trim().isNotEmpty)
              'notes': _notesCtrl.text.trim(),
            if (_estCostCtrl.text.isNotEmpty)
              'estimatedCostGhs': double.tryParse(_estCostCtrl.text),
            if (_startDate != null)
              'startDate': Timestamp.fromDate(_startDate!),
            if (_endDate != null) 'endDate': Timestamp.fromDate(_endDate!),
          },
        );
        if (_completionPhotos.isNotEmpty) {
          final urls = await widget.projectService.uploadPhaseCompletionPhotos(
            projectId: widget.projectId,
            phaseId: widget.editing!.id,
            files: _completionPhotos,
          );
          if (urls.isNotEmpty) {
            final existing = widget.editing!.completionPhotoUrls;
            await widget.projectService.updatePhase(
              widget.projectId,
              widget.editing!.id,
              {
                'completionPhotoUrls': [...existing, ...urls],
              },
            );
          }
        }
      } else {
        final phase = Phase(
          id: '',
          name: _nameCtrl.text.trim(),
          order: widget.existingCount,
          status: _status,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          estimatedCostGhs: double.tryParse(_estCostCtrl.text),
          startDate: _startDate,
          endDate: _endDate,
          createdAt: DateTime.now(),
          isMilestone: _isMilestone,
        );
        final phaseId =
            await widget.projectService.addPhase(widget.projectId, phase);
        unawaited(
          auditService.logEvent(
            projectId: widget.projectId,
            type: AuditEventType.phaseAdded,
            actorUid: actorUid,
            actorName: actorName,
            description: 'Added phase: ${phase.name}',
            metadata: {'phaseId': phaseId, 'phaseName': phase.name},
          ),
        );
        if (_status == PhaseStatus.completed && _completionPhotos.isNotEmpty) {
          final urls = await widget.projectService.uploadPhaseCompletionPhotos(
            projectId: widget.projectId,
            phaseId: phaseId,
            files: _completionPhotos,
          );
          if (urls.isNotEmpty) {
            await widget.projectService.updatePhase(
              widget.projectId,
              phaseId,
              {'completionPhotoUrls': urls},
            );
          }
        }
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
          // Start / End date pickers
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(isStart: true),
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Start date',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: Text(
                      _startDate != null
                          ? DateFormat('d MMM yy').format(_startDate!)
                          : 'Tap to set',
                      style: TextStyle(
                        fontSize: 13,
                        color: _startDate != null ? null : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(isStart: false),
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'End date',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: Text(
                      _endDate != null
                          ? DateFormat('d MMM yy').format(_endDate!)
                          : 'Tap to set',
                      style: TextStyle(
                        fontSize: 13,
                        color: _endDate != null ? null : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
          const SizedBox(height: 12),
          // Physical completion % for Earned Value analysis
          Row(
            children: [
              Text(
                'Completion: $_percentComplete%',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          Slider(
            value: _percentComplete.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            label: '$_percentComplete%',
            onChanged: (v) => setState(() => _percentComplete = v.round()),
          ),
          // Milestone toggle
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mark as milestone'),
            subtitle: const Text(
              'Milestone phases are highlighted with a star and diamond on the Gantt chart.',
            ),
            secondary: const Icon(Icons.star_outline),
            value: _isMilestone,
            onChanged: (v) => setState(() => _isMilestone = v),
          ),
          // Completion photos — available when status is completed
          if (_status == PhaseStatus.completed) ...[
            const SizedBox(height: 12),
            Text(
              'Completion photos (optional)',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            // Existing photos (edit mode)
            if (widget.editing != null &&
                widget.editing!.completionPhotoUrls.isNotEmpty) ...[
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.editing!.completionPhotoUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: widget.editing!.completionPhotoUrls[i],
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          const ShimmerBox(width: 60, height: 60),
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            // Newly picked photos
            if (_completionPhotos.isNotEmpty) ...[
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _completionPhotos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _completionPhotos[i],
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _completionPhotos.removeAt(i)),
                          child: const CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.black54,
                            child: Icon(
                              Icons.close,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              onPressed: _showPhotoSourcePicker,
              icon: const Icon(Icons.add_a_photo_outlined, size: 18),
              label: const Text('Add photo'),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(
                  _saving ? 'Saving…' : (editing ? 'Update' : 'Add phase'),),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add cost sheet ─────────────────────────────────────────────────────────────


class ProjectAddCostSheet extends StatefulWidget {
  const ProjectAddCostSheet({
    super.key,
    required this.projectId,
    required this.authorUid,
    required this.projectService,
  });

  final String projectId;
  final String authorUid;
  final ProjectService projectService;

  @override
  State<ProjectAddCostSheet> createState() => ProjectAddCostSheetState();
}

class ProjectAddCostSheetState extends State<ProjectAddCostSheet> {
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _category = CostEntry.categories.first;
  File? _receipt;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1920,
    );
    if (picked != null && mounted) {
      setState(() => _receipt = File(picked.path));
    }
  }

  void _showReceiptPicker() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(context);
                _pickReceipt(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickReceipt(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final desc = _descCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text);
    if (desc.isEmpty || amount == null || amount <= 0) {
      setState(() => _error = 'Enter a description and a valid amount.');
      return;
    }

    // Enforce free-tier cost-entry limit.
    final auth = context.read<AuthService>();
    final tier = auth.currentUser?.subscriptionTier ?? SubscriptionTier.free;
    if (tier.maxCostEntriesPerProject < 999999) {
      final currentCount =
          await widget.projectService.costEntryCount(widget.projectId);
      if (currentCount >= tier.maxCostEntriesPerProject) {
        if (mounted) {
          setState(
            () => _error =
                'Free plan limit reached (${tier.maxCostEntriesPerProject} entries). '
                    'Upgrade to add more costs.',
          );
        }
        return;
      }
    }

    // Capture before async gap.
    final auditService = sl<AuditService>();
    final actorName = auth.currentUser?.displayName ?? '';
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      String? receiptUrl;
      if (_receipt != null) {
        final receiptId = const Uuid().v4();
        receiptUrl = await widget.projectService.uploadReceiptPhoto(
          projectId: widget.projectId,
          receiptId: receiptId,
          file: _receipt!,
        );
      }
      final entry = CostEntry(
        id: '',
        authorUid: widget.authorUid,
        description: desc,
        category: _category,
        amountGhs: amount,
        receiptUrl: receiptUrl,
        createdAt: DateTime.now(),
      );
      await widget.projectService.addCostEntry(widget.projectId, entry);
      unawaited(
        auditService.logEvent(
          projectId: widget.projectId,
          type: AuditEventType.costEntryAdded,
          actorUid: widget.authorUid,
          actorName: actorName,
          description:
              'Added cost entry: $_category \u2014 GHS ${amount.toStringAsFixed(2)}',
          metadata: {'category': _category, 'amountGhs': amount},
        ),
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
          const SizedBox(height: 12),
          // Receipt photo picker
          OutlinedButton.icon(
            onPressed: _saving ? null : _showReceiptPicker,
            icon: const Icon(Icons.receipt_outlined, size: 18),
            label: Text(
              _receipt == null
                  ? 'Attach receipt photo'
                  : 'Change receipt photo',
            ),
          ),
          if (_receipt != null) ...[
            const SizedBox(height: 8),
            Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _receipt!,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                IconButton(
                  tooltip: 'Remove photo',
                  icon: const Icon(Icons.close, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => setState(() => _receipt = null),
                ),
              ],
            ),
          ],
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


class ProjectAddUpdateSheet extends StatefulWidget {
  const ProjectAddUpdateSheet({
    super.key,
    required this.projectId,
    required this.authorUid,
    required this.projectService,
  });

  final String projectId;
  final String authorUid;
  final ProjectService projectService;

  @override
  State<ProjectAddUpdateSheet> createState() => ProjectAddUpdateSheetState();
}

class ProjectAddUpdateSheetState extends State<ProjectAddUpdateSheet> {
  final _textCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final List<File> _photos = [];
  bool _saving = false;
  String? _error;
  double? _photoLat;
  double? _photoLng;
  bool _capturingGps = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos(ImageSource source) async {
    if (source == ImageSource.gallery) {
      final picked = await ImagePicker().pickMultiImage(
        imageQuality: 80,
        maxWidth: 1920,
      );
      if (picked.isNotEmpty && mounted) {
        setState(() => _photos.addAll(picked.map((x) => File(x.path))));
        _captureGps();
      }
    } else {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
      );
      if (picked != null && mounted) {
        setState(() => _photos.add(File(picked.path)));
        _captureGps();
      }
    }
  }

  /// Silently captures GPS coordinates. Non-blocking; updates UI when done.
  Future<void> _captureGps() async {
    if (!mounted) return;
    setState(() => _capturingGps = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (mounted) {
        setState(() {
          _photoLat = pos.latitude;
          _photoLng = pos.longitude;
        });
      }
    } catch (_) {
      // GPS unavailable — proceed without coordinates.
    } finally {
      if (mounted) setState(() => _capturingGps = false);
    }
  }

  void _showPhotoPicker() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(context);
                _pickPhotos(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickPhotos(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
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
      List<String> photoUrls = [];
      if (_photos.isNotEmpty) {
        final uploadId = const Uuid().v4();
        photoUrls = await widget.projectService.uploadUpdatePhotos(
          projectId: widget.projectId,
          updateId: uploadId,
          files: _photos,
        );
      }
      await widget.projectService.addUpdate(
        projectId: widget.projectId,
        authorUid: widget.authorUid,
        text: text,
        photoUrls: photoUrls,
        costDelta: double.tryParse(_costCtrl.text),
        photoLat: _photoLat,
        photoLng: _photoLng,
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
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _saving ? null : _showPhotoPicker,
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
            label: Text(
              _photos.isEmpty
                  ? 'Add site photos'
                  : 'Add more photos (${_photos.length} selected)',
            ),
          ),
          if (_photos.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        _photos[i],
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => setState(() => _photos.removeAt(i)),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(2),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          // GPS tag indicator
          if (_photos.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (_capturingGps) ...[
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Getting GPS…',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ] else if (_photoLat != null) ...[
                  Icon(
                    Icons.location_on,
                    size: 14,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'GPS tagged — ${_photoLat!.toStringAsFixed(5)}, ${_photoLng!.toStringAsFixed(5)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.green.shade700,
                        ),
                  ),
                ] else ...[
                  Icon(
                    Icons.location_off_outlined,
                    size: 14,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'No GPS tag',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ],
            ),
          ],
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

// ── Contract status chip ────────────────────────────────────────────────────────

