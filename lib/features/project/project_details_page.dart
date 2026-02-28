// lib/features/project/project_details_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/app_user.dart';
import '../../core/models/builder_contract.dart';
import '../../core/models/cost_entry.dart';
import '../../core/models/deletion_request.dart';
import '../../core/models/payment_record.dart';
import '../../core/models/phase.dart';
import '../../core/models/project.dart';
import '../../core/models/project_document.dart';
import '../../core/models/project_update.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/builder_profile_service.dart';
import '../../core/services/contract_service.dart';
import '../../core/services/deletion_request_service.dart';
import '../../core/services/payment_service.dart';
import '../../core/services/pdf_service.dart';
import '../../core/services/project_service.dart';
import '../estimate/estimate_view_page.dart';
import 'builder_marketplace_page.dart';
import 'contract_view_page.dart';
import 'cost_analytics_page.dart';
import 'create_contract_page.dart';

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
  bool _generatingReport = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 7, vsync: this)
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
              if (_generatingReport)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (project != null)
                PopupMenuButton<_MenuAction>(
                  onSelected: (action) =>
                      _handleMenu(context, action, project),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _MenuAction.viewAnalytics,
                      child: Text('View Analytics'),
                    ),
                    PopupMenuItem(
                      value: _MenuAction.generateReport,
                      child: Text('Generate Report'),
                    ),
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
                Tab(icon: Icon(Icons.payments_outlined), text: 'Payments'),
                Tab(icon: Icon(Icons.analytics_outlined), text: 'Estimates'),
              ],
            ),
          ),
          body: snap.connectionState == ConnectionState.waiting && project == null
              ? const Center(child: CircularProgressIndicator())
              : project == null
                  ? const Center(child: Text('Project not found.'))
                  : Builder(
                      builder: (context) {
                        final auth = context.read<AuthService>();
                        final currentUserUid = auth.currentUser?.uid ?? '';
                        final isOwner = project.ownerUid == currentUserUid;
                        final isBuilder = auth.role == UserRole.pm;
                        final deletionService =
                            context.read<DeletionRequestService>();
                        return TabBarView(
                          controller: _tabs,
                          children: [
                            _OverviewTab(
                              project: project,
                              projectId: widget.projectId,
                              projectService: projectService,
                              builderProfileService:
                                  context.read<BuilderProfileService>(),
                              contractService: context.read<ContractService>(),
                              currentUserUid: currentUserUid,
                              isOwner: isOwner,
                              deletionRequestService: deletionService,
                            ),
                            _PhasesTab(
                              projectId: widget.projectId,
                              projectService: projectService,
                            ),
                            _CostsTab(
                              projectId: widget.projectId,
                              currencySymbol: project.currencySymbol,
                              projectService: projectService,
                              isBuilder: isBuilder,
                              currentUserUid: currentUserUid,
                              currentUserName:
                                  auth.currentUser?.displayName ?? '',
                              deletionRequestService: deletionService,
                            ),
                            _UpdatesTab(
                              projectId: widget.projectId,
                              projectService: projectService,
                            ),
                            _DocsTab(
                              projectId: widget.projectId,
                              projectService: projectService,
                            ),
                            _PaymentsTab(
                              projectId: widget.projectId,
                              paymentService: context.read<PaymentService>(),
                              isBuilder: isBuilder,
                              currentUserUid: currentUserUid,
                              currentUserName:
                                  auth.currentUser?.displayName ?? '',
                              deletionRequestService: deletionService,
                            ),
                            _EstimatesTab(
                              projectId: widget.projectId,
                              projectService: projectService,
                            ),
                          ],
                        );
                      },
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
          onPressed: () => _showUploadDocSheet(
            context,
            projectService,
            auth.currentUser!.uid,
          ),
          child: const Icon(Icons.upload_file_outlined),
        ),
      5 => FloatingActionButton(
          tooltip: 'Record payment',
          onPressed: () => _showAddPayment(
            context,
            context.read<PaymentService>(),
            auth.currentUser!.uid,
            project,
          ),
          child: const Icon(Icons.add),
        ),
      6 => FloatingActionButton(
          tooltip: 'Attach estimate',
          onPressed: () => _showAttachEstimateSheet(
            context,
            projectService,
            auth.currentUser!.uid,
          ),
          child: const Icon(Icons.attach_file_outlined),
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

  // ── Payment sheet ────────────────────────────────────────────────────────────

  void _showAddPayment(
    BuildContext context,
    PaymentService paymentService,
    String authorUid,
    Project project,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _AddPaymentSheet(
        projectId: widget.projectId,
        authorUid: authorUid,
        paymentService: paymentService,
        projectService: context.read<ProjectService>(),
      ),
    );
  }

  // ── Attach estimate ──────────────────────────────────────────────────────────

  void _showAttachEstimateSheet(
    BuildContext context,
    ProjectService projectService,
    String uid,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AttachEstimateSheet(
        projectId: widget.projectId,
        uploaderUid: uid,
        projectService: projectService,
      ),
    );
  }

  // ── Doc upload ───────────────────────────────────────────────────────────────

  void _showUploadDocSheet(
    BuildContext context,
    ProjectService projectService,
    String uploaderUid,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _UploadDocSheet(
        projectId: widget.projectId,
        uploaderUid: uploaderUid,
        projectService: projectService,
      ),
    );
  }

  // ── Menu actions ─────────────────────────────────────────────────────────────

  Future<void> _handleMenu(
    BuildContext context,
    _MenuAction action,
    Project project,
  ) async {
    final projectService = context.read<ProjectService>();

    switch (action) {
      case _MenuAction.viewAnalytics:
        if (context.mounted) {
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => CostAnalyticsPage(project: project),
          ),);
        }
      case _MenuAction.generateReport:
        await _generateReport(context, project);
      case _MenuAction.editStatus:
        await _showStatusPicker(context, project, projectService);
      case _MenuAction.delete:
        await _confirmDelete(context, projectService);
    }
  }

  Future<void> _generateReport(BuildContext context, Project project) async {
    setState(() => _generatingReport = true);
    final projectService = context.read<ProjectService>();
    final paymentService = context.read<PaymentService>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final phases =
          await projectService.phasesStream(widget.projectId).first;
      final costs =
          await projectService.costEntriesStream(widget.projectId).first;
      final payments =
          await paymentService.paymentsStream(widget.projectId).first;

      final data = ProjectReportData(
        project: project,
        phases: phases,
        costs: costs,
        payments: payments,
      );
      final bytes = await PdfService().generateProjectReport(data);
      final safeName =
          project.title.replaceAll(RegExp(r'[^\w\s\-]'), '_').trim();
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${safeName}_report.pdf',
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Report failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _generatingReport = false);
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

enum _MenuAction { viewAnalytics, generateReport, editStatus, delete }

// ── Overview tab ───────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.project,
    required this.projectId,
    required this.projectService,
    required this.builderProfileService,
    required this.contractService,
    required this.currentUserUid,
    required this.isOwner,
    required this.deletionRequestService,
  });
  final Project project;
  final String projectId;
  final ProjectService projectService;
  final BuilderProfileService builderProfileService;
  final ContractService contractService;
  final String currentUserUid;
  final bool isOwner;
  final DeletionRequestService deletionRequestService;

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

        // Assigned builder card
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
                        Icons.engineering_outlined,
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

        const SizedBox(height: 16),

        // Deletion requests section (owner only)
        if (isOwner) ...[
          const SizedBox(height: 16),
          _DeletionRequestsSection(
            projectId: projectId,
            deletionRequestService: deletionRequestService,
          ),
        ],

        const SizedBox(height: 16),

        // Contract section
        StreamBuilder<BuilderContract?>(
          stream: contractService.activeContractStream(projectId, currentUserUid),
          builder: (ctx, snap) {
            final contract = snap.data;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.description_outlined,
                            size: 18, color: cs.outline,),
                        const SizedBox(width: 8),
                        Text(
                          'Contract',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (contract != null) ...[
                          const Spacer(),
                          _ContractStatusChip(status: contract.status),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (contract == null) ...[
                      Text(
                        'No active contract. Create a formal contract with a builder to protect both parties.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.outline,
                            ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.draw_outlined, size: 18),
                          label: const Text('Create Contract'),
                          onPressed: () => _openContractFlow(context),
                        ),
                      ),
                    ] else ...[
                      Text(
                        contract.builderName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'GHS ${NumberFormat('#,##0').format(contract.totalAmountGhs)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.outline,
                            ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          label: const Text('View Contract'),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ContractViewPage(
                                contract: contract,
                                currentUserUid: currentUserUid,
                                contractService: contractService,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
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

  void _openContractFlow(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BuilderMarketplacePage(
          initialRegion: project.region.isNotEmpty ? project.region : null,
          onSelect: (builder) {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CreateContractPage(
                  projectId: projectId,
                  projectTitle: project.title,
                  builder: builder,
                  ownerUid: currentUserUid,
                  contractService: contractService,
                ),
              ),
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
                      builder: (_) => _FullScreenPhoto(
                        url: phase.completionPhotoUrls[i],
                        title: 'Photo ${i + 1}',
                      ),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      phase.completionPhotoUrls[i],
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
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
                  isBuilder: isBuilder,
                  onDelete: () => projectService.deleteCostEntry(
                    projectId,
                    entries[i].id,
                    entries[i].amountGhs,
                  ),
                  onRequestDeletion: () => _requestDeletion(
                    context,
                    entries[i],
                  ),
                ),
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
      await deletionRequestService.request(
        DeletionRequest(
          itemId: entry.id,
          projectId: projectId,
          itemType: DeletionItemType.costEntry,
          itemDescription: entry.description,
          requestedByUid: currentUserUid,
          requestedByName: currentUserName,
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
          ? () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => _FullScreenPhoto(
                  url: entry.receiptUrl!,
                  title: entry.description,
                ),
              ),)
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
                  itemBuilder: (context, i) => GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _FullScreenPhoto(
                          url: update.photoUrls[i],
                          title: 'Photo ${i + 1}',
                        ),
                      ),
                    ),
                    child: ClipRRect(
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
            doc.category.label,
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
      await projectService.deleteDocument(
        projectId,
        doc.id,
        storagePath: doc.storagePath,
      );
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

// ── Upload document sheet ──────────────────────────────────────────────────────

class _UploadDocSheet extends StatefulWidget {
  const _UploadDocSheet({
    required this.projectId,
    required this.uploaderUid,
    required this.projectService,
  });

  final String projectId;
  final String uploaderUid;
  final ProjectService projectService;

  @override
  State<_UploadDocSheet> createState() => _UploadDocSheetState();
}

class _UploadDocSheetState extends State<_UploadDocSheet> {
  DocumentCategory _category = DocumentCategory.other;
  PlatformFile? _picked;
  final _nameCtrl = TextEditingController();
  bool _uploading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    setState(() {
      _picked = f;
      if (_nameCtrl.text.trim().isEmpty) {
        // Pre-fill name without extension
        final namePart = f.name.contains('.')
            ? f.name.substring(0, f.name.lastIndexOf('.'))
            : f.name;
        _nameCtrl.text = namePart;
      }
    });
  }

  Future<void> _upload() async {
    if (_picked == null || _picked!.path == null) return;
    final displayName = _nameCtrl.text.trim();
    setState(() => _uploading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.projectService.uploadDocument(
        projectId: widget.projectId,
        uploaderUid: widget.uploaderUid,
        file: File(_picked!.path!),
        fileName: _picked!.name,
        category: _category,
        displayName: displayName.isNotEmpty ? displayName : null,
        contentType: _picked!.extension != null
            ? _mimeFromExt(_picked!.extension!)
            : null,
      );
      if (mounted) {
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '"${displayName.isNotEmpty ? displayName : _picked!.name}" uploaded.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        messenger.showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24, 0, 24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload Document',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 20),
          Text('Category', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: DocumentCategory.values.map((cat) {
              return ChoiceChip(
                label: Text(cat.label),
                selected: _category == cat,
                onSelected: _uploading
                    ? null
                    : (_) => setState(() => _category = cat),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _uploading ? null : _pickFile,
            icon: const Icon(Icons.attach_file),
            label: Text(
              _picked == null ? 'Pick file' : _picked!.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_picked != null) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Document name',
                border: OutlineInputBorder(),
                helperText: 'Rename (optional)',
              ),
              enabled: !_uploading,
            ),
          ],
          if (_uploading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _picked == null || _uploading ? null : _upload,
              icon: const Icon(Icons.upload),
              label: const Text('Upload'),
            ),
          ),
        ],
      ),
    );
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
  final List<File> _completionPhotos = [];

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

  Future<void> _pickCompletionPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 80);
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
              {'completionPhotoUrls': [...existing, ...urls]},
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
          createdAt: DateTime.now(),
        );
        final phaseId =
            await widget.projectService.addPhase(widget.projectId, phase);
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
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
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
                    child: Image.network(
                      widget.editing!.completionPhotoUrls[i],
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
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
              _receipt == null ? 'Attach receipt photo' : 'Change receipt photo',
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
  final List<File> _photos = [];
  bool _saving = false;
  String? _error;

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
      }
    } else {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
      );
      if (picked != null && mounted) {
        setState(() => _photos.add(File(picked.path)));
      }
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

class _ContractStatusChip extends StatelessWidget {
  const _ContractStatusChip({required this.status});
  final ContractStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      ContractStatus.pendingBuilder => (cs.secondaryContainer, cs.onSecondaryContainer),
      ContractStatus.active => (Colors.green.withValues(alpha: 0.15), Colors.green[800]!),
      ContractStatus.declined => (cs.errorContainer, cs.onErrorContainer),
      ContractStatus.cancelled => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600),
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

// ── Estimates tab ─────────────────────────────────────────────────────────────

class _EstimatesTab extends StatelessWidget {
  const _EstimatesTab({
    required this.projectId,
    required this.projectService,
  });

  final String projectId;
  final ProjectService projectService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: projectService.estimatesStream(projectId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data ?? [];
        if (docs.isEmpty) {
          return _centeredHint(
            context,
            Icons.analytics_outlined,
            'No estimates yet',
            'Tap the attach button to link a saved estimate.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (_, i) => _EstimateTile(
            doc: docs[i],
            projectId: projectId,
            projectService: projectService,
          ),
        );
      },
    );
  }
}

class _EstimateTile extends StatelessWidget {
  const _EstimateTile({
    required this.doc,
    required this.projectId,
    required this.projectService,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String projectId;
  final ProjectService projectService;

  @override
  Widget build(BuildContext context) {
    final m = doc.data();
    final name = (m['projectName'] as String?) ??
        (m['projectNameInput'] as String?) ??
        'Estimate';
    final totalGhs = (m['grandTotalGhs'] as num?)?.toDouble();
    final createdTs = m['createdAt'];
    DateTime? created;
    if (createdTs is Timestamp) created = createdTs.toDate();
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Icon(
            Icons.analytics_outlined,
            color: cs.onPrimaryContainer,
            size: 20,
          ),
        ),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            if (totalGhs != null)
              '₵ ${NumberFormat('#,##0').format(totalGhs)}',
            if (created != null)
              DateFormat('d MMM yyyy').format(created),
          ].join(' · '),
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: cs.outline),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: cs.error),
          tooltip: 'Remove',
          onPressed: () => _confirmRemove(context),
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EstimateViewPage(docRef: doc.reference),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove estimate?'),
        content: const Text(
          'This will unlink the estimate from this project.',
        ),
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
    if (confirmed == true) {
      await projectService.deleteEstimate(projectId, doc.id);
    }
  }
}

// ── Attach estimate sheet ──────────────────────────────────────────────────────

class _AttachEstimateSheet extends StatefulWidget {
  const _AttachEstimateSheet({
    required this.projectId,
    required this.uploaderUid,
    required this.projectService,
  });

  final String projectId;
  final String uploaderUid;
  final ProjectService projectService;

  @override
  State<_AttachEstimateSheet> createState() => _AttachEstimateSheetState();
}

class _AttachEstimateSheetState extends State<_AttachEstimateSheet> {
  bool _attaching = false;

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      get _savedEstimates => FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uploaderUid)
          .collection('estimates')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (s) => s.docs
                .cast<QueryDocumentSnapshot<Map<String, dynamic>>>(),
          );

  Future<void> _attach(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    setState(() => _attaching = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.projectService.linkEstimate(
        widget.projectId,
        doc.data(),
      );
      if (mounted) {
        Navigator.of(context).pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('Estimate attached to project.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _attaching = false);
        messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(
            'Attach a Saved Estimate',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (_attaching) const LinearProgressIndicator(),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: StreamBuilder<
              List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
            stream: _savedEstimates,
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data!;
              if (docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No saved estimates found.\nGenerate an estimate first.',
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (_, i) {
                  final m = docs[i].data();
                  final name = (m['projectName'] as String?) ??
                      (m['projectNameInput'] as String?) ??
                      'Estimate';
                  final totalGhs =
                      (m['grandTotalGhs'] as num?)?.toDouble();
                  final createdTs = m['createdAt'];
                  DateTime? created;
                  if (createdTs is Timestamp) {
                    created = createdTs.toDate();
                  }
                  return ListTile(
                    title: Text(name, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      [
                        if (totalGhs != null)
                          '₵ ${NumberFormat('#,##0').format(totalGhs)}',
                        if (created != null)
                          DateFormat('d MMM yyyy').format(created),
                      ].join(' · '),
                    ),
                    onTap: _attaching ? null : () => _attach(docs[i]),
                  );
                },
              );
            },
          ),
        ),
      ],
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

// ── Payments tab ───────────────────────────────────────────────────────────────

class _PaymentsTab extends StatelessWidget {
  const _PaymentsTab({
    required this.projectId,
    required this.paymentService,
    required this.isBuilder,
    required this.currentUserUid,
    required this.currentUserName,
    required this.deletionRequestService,
  });
  final String projectId;
  final PaymentService paymentService;
  final bool isBuilder;
  final String currentUserUid;
  final String currentUserName;
  final DeletionRequestService deletionRequestService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PaymentRecord>>(
      stream: paymentService.paymentsStream(projectId),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final payments = snap.data ?? [];
        if (payments.isEmpty) {
          return _centeredHint(
            context,
            Icons.payments_outlined,
            'No payments recorded',
            'Tap + to record a payment in or out.',
          );
        }

        // Summary totals
        double totalOut = 0;
        double totalIn = 0;
        for (final p in payments) {
          if (p.direction == PaymentDirection.outbound) {
            totalOut += p.amountGhs;
          } else {
            totalIn += p.amountGhs;
          }
        }
        final net = totalIn - totalOut;
        final fmt = NumberFormat('#,##0.00');
        final cs = Theme.of(context).colorScheme;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Summary card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _SummaryColumn(
                        label: 'Paid Out',
                        value: 'GHS ${fmt.format(totalOut)}',
                        color: cs.error,
                      ),
                    ),
                    const VerticalDivider(width: 24),
                    Expanded(
                      child: _SummaryColumn(
                        label: 'Received',
                        value: 'GHS ${fmt.format(totalIn)}',
                        color: Colors.green,
                      ),
                    ),
                    const VerticalDivider(width: 24),
                    Expanded(
                      child: _SummaryColumn(
                        label: 'Net',
                        value: 'GHS ${fmt.format(net.abs())}',
                        color: net >= 0 ? Colors.green : cs.error,
                        prefix: net >= 0 ? '+' : '-',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...payments.map(
              (p) => _PaymentCard(
                payment: p,
                isBuilder: isBuilder,
                onDelete: () => paymentService.deletePayment(
                  projectId: projectId,
                  paymentId: p.id,
                ),
                onRequestDeletion: () => _requestPaymentDeletion(
                  context,
                  p,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _requestPaymentDeletion(
    BuildContext context,
    PaymentRecord payment,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Request deletion?'),
        content: Text(
          'Send a deletion request to the owner for:\n\n'
          '"${payment.description}" — GHS ${NumberFormat('#,##0.00').format(payment.amountGhs)}\n\n'
          'The record will only be deleted after the owner approves.',
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
      await deletionRequestService.request(
        DeletionRequest(
          itemId: payment.id,
          projectId: projectId,
          itemType: DeletionItemType.payment,
          itemDescription: payment.description,
          requestedByUid: currentUserUid,
          requestedByName: currentUserName,
          status: DeletionStatus.pending,
          createdAt: DateTime.now(),
          amountGhs: payment.amountGhs,
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

class _SummaryColumn extends StatelessWidget {
  const _SummaryColumn({
    required this.label,
    required this.value,
    required this.color,
    this.prefix = '',
  });
  final String label;
  final String value;
  final Color color;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          '$prefix$value',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.payment,
    required this.isBuilder,
    required this.onDelete,
    required this.onRequestDeletion,
  });
  final PaymentRecord payment;
  final bool isBuilder;
  final VoidCallback onDelete;
  final VoidCallback onRequestDeletion;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('d MMM yyyy');
    final isOut = payment.direction == PaymentDirection.outbound;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundColor:
              isOut ? cs.errorContainer : Colors.green.withValues(alpha: 0.15),
          child: Icon(
            isOut ? Icons.arrow_upward : Icons.arrow_downward,
            size: 18,
            color: isOut ? cs.error : Colors.green,
          ),
        ),
        title: Text(payment.description),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${payment.method.label} · ${dateFmt.format(payment.paymentDate)}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            if (payment.phaseTitle != null)
              Text(
                'Phase: ${payment.phaseTitle}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.outline,
                    ),
              ),
            if (payment.reference != null && payment.reference!.isNotEmpty)
              Text(
                'Ref: ${payment.reference}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.outline,
                    ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'GHS ${fmt.format(payment.amountGhs)}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isOut ? cs.error : Colors.green,
              ),
            ),
            if (isBuilder)
              GestureDetector(
                onTap: onRequestDeletion,
                child: Icon(
                  Icons.flag_outlined,
                  size: 16,
                  color: cs.error,
                ),
              )
            else
              GestureDetector(
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Delete payment?'),
                      content:
                          const Text('This record will be permanently removed.'),
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
                  if (confirmed == true) onDelete();
                },
                child: Icon(Icons.delete_outline, size: 16, color: cs.outline),
              ),
          ],
        ),
        isThreeLine: payment.phaseTitle != null || payment.reference != null,
      ),
    );
  }
}

// ── Add Payment Sheet ──────────────────────────────────────────────────────────

class _AddPaymentSheet extends StatefulWidget {
  const _AddPaymentSheet({
    required this.projectId,
    required this.authorUid,
    required this.paymentService,
    required this.projectService,
  });
  final String projectId;
  final String authorUid;
  final PaymentService paymentService;
  final ProjectService projectService;

  @override
  State<_AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends State<_AddPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();

  PaymentDirection _direction = PaymentDirection.outbound;
  PaymentMethod _method = PaymentMethod.cash;
  DateTime _paymentDate = DateTime.now();
  String? _selectedPhaseId;
  String? _selectedPhaseTitle;
  bool _saving = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _paymentDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final payment = PaymentRecord(
        id: '',
        authorUid: widget.authorUid,
        direction: _direction,
        amountGhs: double.parse(_amountCtrl.text.replaceAll(',', '')),
        description: _descCtrl.text.trim(),
        method: _method,
        paymentDate: _paymentDate,
        createdAt: DateTime.now(),
        reference: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
        phaseId: _selectedPhaseId,
        phaseTitle: _selectedPhaseTitle,
      );
      await widget.paymentService.addPayment(
        projectId: widget.projectId,
        payment: payment,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy');

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Record Payment',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),

              // Direction toggle
              SegmentedButton<PaymentDirection>(
                segments: PaymentDirection.values
                    .map(
                      (d) => ButtonSegment(
                        value: d,
                        label: Text(d.label),
                        icon: Icon(
                          d == PaymentDirection.outbound
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                        ),
                      ),
                    )
                    .toList(),
                selected: {_direction},
                onSelectionChanged: (s) =>
                    setState(() => _direction = s.first),
              ),
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // Amount
              TextFormField(
                controller: _amountCtrl,
                decoration: const InputDecoration(
                  labelText: 'Amount (GHS) *',
                  prefixText: 'GHS ',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = double.tryParse(v.replaceAll(',', ''));
                  if (n == null || n <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Payment method
              DropdownButtonFormField<PaymentMethod>(
                initialValue: _method,
                decoration: const InputDecoration(
                  labelText: 'Payment method',
                  border: OutlineInputBorder(),
                ),
                items: PaymentMethod.values
                    .map(
                      (m) => DropdownMenuItem(value: m, child: Text(m.label)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _method = v);
                },
              ),
              const SizedBox(height: 12),

              // Date picker
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Payment date'),
                subtitle: Text(dateFmt.format(_paymentDate)),
                onTap: _pickDate,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Reference (optional)
              TextFormField(
                controller: _refCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reference / receipt no. (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // Phase link (optional) — streams phases
              StreamBuilder<List<Phase>>(
                stream:
                    widget.projectService.phasesStream(widget.projectId),
                builder: (ctx, snap) {
                  final phases = snap.data ?? [];
                  if (phases.isEmpty) return const SizedBox.shrink();
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedPhaseId,
                    decoration: const InputDecoration(
                      labelText: 'Link to phase (optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        child: Text('None'),
                      ),
                      ...phases.map(
                        (ph) => DropdownMenuItem(
                          value: ph.id,
                          child: Text(ph.name),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _selectedPhaseId = v;
                        _selectedPhaseTitle = phases
                            .where((ph) => ph.id == v)
                            .map((ph) => ph.name)
                            .firstOrNull;
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 20),

              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Payment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Deletion requests section (owner view in Overview tab) ─────────────────────

class _DeletionRequestsSection extends StatelessWidget {
  const _DeletionRequestsSection({
    required this.projectId,
    required this.deletionRequestService,
  });

  final String projectId;
  final DeletionRequestService deletionRequestService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DeletionRequest>>(
      stream: deletionRequestService.pendingStream(projectId),
      builder: (context, snap) {
        final requests = snap.data ?? [];
        if (requests.isEmpty) return const SizedBox.shrink();

        final cs = Theme.of(context).colorScheme;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.flag_outlined, size: 18, color: cs.error),
                    const SizedBox(width: 8),
                    Text(
                      'Deletion Requests (${requests.length})',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: cs.error,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (int i = 0; i < requests.length; i++) ...[
                  _DeletionRequestTile(
                    request: requests[i],
                    onApprove: () => _handleApprove(context, requests[i]),
                    onDeny: () => _handleDeny(context, requests[i]),
                  ),
                  if (i < requests.length - 1) const Divider(height: 16),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleApprove(
    BuildContext context,
    DeletionRequest req,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Approve deletion?'),
        content: Text(
          'This will permanently delete:\n"${req.itemDescription}"\n\n'
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve & Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await deletionRequestService.approve(req);
      messenger.showSnackBar(
        const SnackBar(content: Text('Item deleted.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _handleDeny(
    BuildContext context,
    DeletionRequest req,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await deletionRequestService.deny(req);
      messenger.showSnackBar(
        const SnackBar(content: Text('Deletion request denied.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

class _DeletionRequestTile extends StatelessWidget {
  const _DeletionRequestTile({
    required this.request,
    required this.onApprove,
    required this.onDeny,
  });

  final DeletionRequest request;
  final VoidCallback onApprove;
  final VoidCallback onDeny;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0.00');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              request.itemDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              '${request.itemType.label}'
              '${request.amountGhs != null ? ' · GH₵${fmt.format(request.amountGhs)}' : ''}'
              ' · by ${request.requestedByName}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.outline,
                  ),
            ),
            Text(
              DateFormat('d MMM yyyy').format(request.createdAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.outline,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.error,
                side: BorderSide(color: cs.error),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
              ),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Approve'),
              onPressed: onApprove,
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
              ),
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Deny'),
              onPressed: onDeny,
            ),
          ],
        ),
      ],
    );
  }
}

// ── Full-screen receipt photo viewer ───────────────────────────────────────────

class _FullScreenPhoto extends StatelessWidget {
  const _FullScreenPhoto({required this.url, required this.title});
  final String url;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 5,
        child: Center(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
            errorBuilder: (context, _, __) => const Center(
              child: Icon(
                Icons.broken_image_outlined,
                size: 64,
                color: Colors.white54,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
