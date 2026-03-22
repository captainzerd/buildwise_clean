// lib/features/project/project_details_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
// ignore: unnecessary_import
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/config/service_locator.dart';
import '../../core/models/app_user.dart';
import '../../core/models/audit_event.dart';
import '../../core/models/project.dart';
import '../../core/services/audit_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/builder_profile_service.dart';
import '../../core/services/contract_service.dart';
import '../../core/services/deletion_request_service.dart';
import '../../core/services/payment_service.dart';
import '../../core/services/paystack_service.dart';
import '../../core/services/project_service.dart';
import 'export_sheet.dart';
import 'tabs/changes_tab.dart';
import 'tabs/finance_tab.dart';
import 'tabs/overview_tab.dart';
import 'widgets/project_shared_widgets.dart';

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

  // Sub-section index for finance tab (communicated back from child widget).
  int _financeSection = 0; // 0 = Costs, 1 = Payments, 2 = Estimates

  // Tab index constants
  static const _kFinance = 1;
  static const _kChanges = 2;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this)
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
    final projectService = sl<ProjectService>();

    return StreamBuilder<Project?>(
      stream: projectService.projectStream(widget.projectId),
      builder: (context, snap) {
        final project = snap.data;
        final title = project?.title ?? widget.projectTitle;

        return Scaffold(
          key: const Key('project_details_screen'),
          appBar: AppBar(
            title: Text(title),
            actions: [
              IconButton(
                tooltip: 'Help',
                icon: const Icon(Icons.help_outline),
                onPressed: () => _showHelp(context),
              ),
              if (project != null)
                PopupMenuButton<_MenuAction>(
                  onSelected: (action) => _handleMenu(context, action, project),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: _MenuAction.editProject,
                      child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit Project')),
                    ),
                    const PopupMenuItem(
                      value: _MenuAction.editStatus,
                      child: ListTile(leading: Icon(Icons.flag_outlined), title: Text('Change Status')),
                    ),
                    const PopupMenuItem(
                      value: _MenuAction.export,
                      child: ListTile(leading: Icon(Icons.upload_outlined), title: Text('Export')),
                    ),
                  ],
                ),
            ],
            bottom: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(key: Key('overview_tab'), icon: Icon(Icons.info_outline), text: 'Overview'),
                Tab(key: Key('finance_tab'), icon: Icon(Icons.attach_money_outlined), text: 'Finance'),
                Tab(icon: Icon(Icons.compare_arrows_outlined), text: 'Changes'),
              ],
            ),
          ),
          body: snap.connectionState == ConnectionState.waiting &&
                  project == null
              ? const Center(child: CircularProgressIndicator())
              : project == null
                  ? const Center(child: Text('Project not found.'))
                  : Builder(
                      builder: (context) {
                        final auth = context.read<AuthService>();
                        final currentUserUid = auth.currentUser?.uid ?? '';
                        final isOwner = project.ownerUid == currentUserUid;
                        final isBuilder = auth.role.isProfessional;
                        final deletionService = sl<DeletionRequestService>();
                        return TabBarView(
                          controller: _tabs,
                          children: [
                            OverviewTab(
                              project: project,
                              projectId: widget.projectId,
                              projectService: projectService,
                              builderProfileService:
                                  context.read<BuilderProfileService>(),
                              contractService: sl<ContractService>(),
                              currentUserUid: currentUserUid,
                              isOwner: isOwner,
                              deletionRequestService: deletionService,
                            ),
                            FinanceTab(
                              projectId: widget.projectId,
                              project: project,
                              projectService: projectService,
                              paymentService: sl<PaymentService>(),
                              paystackService: sl<PaystackService>(),
                              deletionRequestService: deletionService,
                              isOwner: isOwner,
                              isBuilder: isBuilder,
                              currentUserUid: currentUserUid,
                              currentUserName:
                                  auth.currentUser?.displayName ?? '',
                              currentUserEmail: auth.currentUser?.email ?? '',
                              onSectionChanged: (i) =>
                                  setState(() => _financeSection = i),
                            ),
                            ChangesTab(projectId: widget.projectId),
                          ],
                        );
                      },
                    ),
          floatingActionButton:
              project != null ? _buildFab(context, project) : null,
        );
      },
    );
  }

  Widget? _buildFab(BuildContext context, Project project) {
    final projectService = sl<ProjectService>();
    final auth = context.read<AuthService>();
    final uid = auth.currentUser!.uid;

    return switch (_tabIndex) {
      _kFinance => switch (_financeSection) {
          0 => FloatingActionButton(
              tooltip: 'Add cost entry',
              onPressed: () => _showAddCost(context, projectService, uid),
              child: const Icon(Icons.add),
            ),
          1 => FloatingActionButton(
              tooltip: 'Record payment',
              onPressed: () => _showAddPayment(
                context,
                sl<PaymentService>(),
                uid,
                project,
              ),
              child: const Icon(Icons.add),
            ),
          2 => FloatingActionButton(
              tooltip: 'Attach estimate',
              onPressed: () =>
                  _showAttachEstimateSheet(context, projectService, uid),
              child: const Icon(Icons.attach_file_outlined),
            ),
          _ => null,
        },
      _kChanges => FloatingActionButton.extended(
          onPressed: () => context.push(
            '/projects/${widget.projectId}/variation-orders',
            extra: {
              'projectTitle': project.title,
              'projectBudgetGhs': project.budget,
            },
          ),
          icon: const Icon(Icons.add),
          label: const Text('Add change'),
        ),
      _ => null,
    };
  }

  // ── Help sheet ───────────────────────────────────────────────────────────────

  static const _helpContent = {
    0: (
      title: 'Overview',
      tips: [
        'See your budget at a glance — total spent, remaining, and phase-by-phase progress.',
        'Photos of your build are shown here too.',
      ],
    ),
    _kFinance: (
      title: 'Finance',
      tips: [
        'Add every payment you make — materials, labour, permits.',
        'Entries are grouped by build phase so you can see where money is going.',
      ],
    ),
    _kChanges: (
      title: 'Changes',
      tips: [
        'When your contractor asks for extra money beyond the original quote, log it here as a change.',
        'Tap "Add change" to record the amount and reason.',
      ],
    ),
  };

  void _showHelp(BuildContext context) {
    final entry = _helpContent[_tabIndex] ?? _helpContent[0]!;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.help_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  entry.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...entry.tips.map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontSize: 16)),
                    Expanded(child: Text(tip)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Cost sheet ───────────────────────────────────────────────────────────────

  void _showAddCost(
    BuildContext context,
    ProjectService projectService,
    String authorUid, {
    int currentCostCount = 0,
  }) {
    final auth = context.read<AuthService>();
    final tier = auth.currentUser?.subscriptionTier ?? SubscriptionTier.free;
    final maxEntries = tier.maxCostEntriesPerProject;

    if (currentCostCount >= maxEntries) {
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Cost entry limit reached'),
          content: Text(
            'The free plan allows up to $maxEntries cost entries per project.\n\n'
            'Upgrade to Project Pass or Pro to record unlimited costs.',
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

    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => ProjectAddCostSheet(
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
      builder: (ctx) => ProjectAddPaymentSheet(
        projectId: widget.projectId,
        authorUid: authorUid,
        paymentService: paymentService,
        projectService: sl<ProjectService>(),
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
      builder: (_) => ProjectAttachEstimateSheet(
        projectId: widget.projectId,
        uploaderUid: uid,
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
    final projectService = sl<ProjectService>();

    switch (action) {
      case _MenuAction.editProject:
        if (context.mounted) {
          context.push('/projects/${widget.projectId}/edit', extra: project);
        }
      case _MenuAction.editStatus:
        await _showStatusPicker(context, project, projectService);
      case _MenuAction.export:
        if (context.mounted) {
          showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (_) => ExportSheet(
              projectId: widget.projectId,
              ownerUid: project.ownerUid,
            ),
          );
        }
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
      if (context.mounted) {
        final auth = context.read<AuthService>();
        unawaited(
          sl<AuditService>().logEvent(
            projectId: widget.projectId,
            type: AuditEventType.projectStatusChanged,
            actorUid: auth.currentUser?.uid ?? '',
            actorName: auth.currentUser?.displayName ?? '',
            description: 'Project status changed to ${picked.label}',
            metadata: {'newStatus': picked.firestoreValue},
          ),
        );
      }
    }
  }

}

enum _MenuAction {
  editProject,
  editStatus,
  export,
}
