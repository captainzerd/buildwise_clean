// lib/features/project/project_details_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
// ignore: unnecessary_import
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../core/config/service_locator.dart';
import '../../core/models/app_user.dart';
import '../../core/models/audit_event.dart';
import '../../core/models/project.dart';
import '../../core/models/project_template.dart';
import '../../core/services/audit_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/builder_profile_service.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/contract_service.dart';
import '../../core/services/deletion_request_service.dart';
import '../../core/services/payment_service.dart';
import '../../core/services/paystack_service.dart';
import '../../core/services/pdf_service.dart';
import '../../core/services/project_service.dart';
import '../../core/services/project_template_service.dart';
import '../../core/services/snag_service.dart';
import 'cost_analytics_page.dart';
import 'export_sheet.dart';
import 'tabs/chat_tab.dart';
import 'tabs/documents_tab.dart';
import 'tabs/finance_tab.dart';
import 'tabs/overview_tab.dart';
import 'tabs/risk_tab.dart';
import 'tabs/work_tab.dart';
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
  bool _generatingReport = false;

  // Sub-section indices for merged tabs (communicated back from child widgets).
  int _workSection = 0; // 0 = Phases, 1 = Monitor, 2 = Issues, 3 = Site Log
  int _financeSection = 0; // 0 = Costs, 1 = Payments, 2 = Estimates

  // Tab index constants
  static const _kWork = 1;
  static const _kFinance = 2;
  static const _kDocuments = 3;
  static const _kRisk = 4;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this)
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
          appBar: AppBar(
            title: Text(title),
            actions: [
              IconButton(
                tooltip: 'Help',
                icon: const Icon(Icons.help_outline),
                onPressed: () => _showHelp(context),
              ),
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
                  onSelected: (action) => _handleMenu(context, action, project),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _MenuAction.editProject,
                      child: Text('Edit Project'),
                    ),
                    PopupMenuItem(
                      value: _MenuAction.viewAnalytics,
                      child: Text('View Analytics'),
                    ),
                    PopupMenuItem(
                      value: _MenuAction.generateReport,
                      child: Text('Generate Report'),
                    ),
                    PopupMenuItem(
                      value: _MenuAction.export,
                      child: Text('Export'),
                    ),
                    PopupMenuItem(
                      value: _MenuAction.viewAuditLog,
                      child: Text('View Audit Log'),
                    ),
                    PopupMenuItem(
                      value: _MenuAction.viewQuotes,
                      child: Text('View Quotes'),
                    ),
                    PopupMenuItem(
                      value: _MenuAction.dueDiligence,
                      child: Text('Due Diligence'),
                    ),
                    PopupMenuItem(
                      value: _MenuAction.snagList,
                      child: Text('Snag List'),
                    ),
                    PopupMenuItem(
                      value: _MenuAction.laborTracking,
                      child: Text('Labour Tracking'),
                    ),
                    PopupMenuItem(
                      value: _MenuAction.changeOrders,
                      child: Text('Change Orders'),
                    ),
                    PopupMenuItem(
                      value: _MenuAction.siteVisits,
                      child: Text('Site Inspections'),
                    ),
                    PopupMenuItem(
                      value: _MenuAction.manageTasks,
                      child: Text('Manage Tasks'),
                    ),
                    PopupMenuItem(
                      value: _MenuAction.generateInvoice,
                      child: Text('Generate Invoice'),
                    ),
                    PopupMenuItem(
                      value: _MenuAction.saveAsTemplate,
                      child: Text('Save as Template'),
                    ),
                    PopupMenuItem(
                      value: _MenuAction.viewTemplates,
                      child: Text('My Templates'),
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
                Tab(icon: Icon(Icons.build_outlined), text: 'Progress'),
                Tab(
                    icon: Icon(Icons.account_balance_wallet_outlined),
                    text: 'Finance'),
                Tab(icon: Icon(Icons.folder_outlined), text: 'Documents'),
                Tab(icon: Icon(Icons.warning_amber_outlined), text: 'Risks'),
                Tab(icon: Icon(Icons.forum_outlined), text: 'Chat'),
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
                        final isBuilder = auth.role == UserRole.pm;
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
                            WorkTab(
                              projectId: widget.projectId,
                              projectService: projectService,
                              isOwner: isOwner,
                              isBuilder: isBuilder,
                              currentUserUid: currentUserUid,
                              currentUserName:
                                  auth.currentUser?.displayName ?? '',
                              onSectionChanged: (i) =>
                                  setState(() => _workSection = i),
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
                            DocsTab(
                              projectId: widget.projectId,
                              projectService: projectService,
                              currentUserUid: currentUserUid,
                              ownerUid: project.ownerUid,
                              observerUids: project.observerUids,
                            ),
                            RisksTab(projectId: widget.projectId),
                            ChatTab(
                              projectId: widget.projectId,
                              currentUserUid: currentUserUid,
                              currentUserName:
                                  auth.currentUser?.displayName ?? 'You',
                              chatService: sl<ChatService>(),
                            ),
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
      _kWork => switch (_workSection) {
          0 => FloatingActionButton(
              tooltip: 'Add phase',
              onPressed: () => _showAddPhase(context, projectService),
              child: const Icon(Icons.add),
            ),
          1 => null, // Monitor tab — no FAB
          2 => project.ownerUid == uid
              ? FloatingActionButton.extended(
                  tooltip: 'Add issue',
                  onPressed: () => _showAddIssue(context, uid),
                  icon: const Icon(Icons.add),
                  label: const Text('Add issue'),
                )
              : null,
          3 => FloatingActionButton(
              tooltip: 'Add log entry',
              onPressed: () => _showAddUpdate(context, projectService, uid),
              child: const Icon(Icons.add),
            ),
          _ => null,
        },
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
      _kDocuments => FloatingActionButton(
          tooltip: 'Upload document',
          onPressed: () => _showUploadDocSheet(context, projectService, uid),
          child: const Icon(Icons.upload_file_outlined),
        ),
      _kRisk => FloatingActionButton(
          tooltip: 'Add risk',
          onPressed: () => _showAddRisk(context, widget.projectId),
          child: const Icon(Icons.add),
        ),
      _ => null,
    };
  }

  void _showAddRisk(BuildContext context, String projectId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ProjectAddRiskSheet(projectId: projectId),
    );
  }

  // ── Help sheet ───────────────────────────────────────────────────────────────

  static const _helpContent = {
    0: (
      // Overview
      title: 'Overview Tab',
      tips: [
        'See your project budget vs. actual spend at a glance.',
        'Tap the chart to open a detailed cost analytics breakdown.',
        'Assign a Project Manager or Builder from the Overview tab.',
        'Use the ⋮ menu → Edit Project to update title, budget, or region.',
      ],
    ),
    1: (
      // Progress
      title: 'Progress Tab — Phases & Updates',
      tips: [
        'Add phases to track each stage of construction (Foundation, Structure, etc.).',
        'Set Estimated Cost and % Complete on each phase to power the EV analysis.',
        'Switch to Updates (top toggle) to log daily site progress with photos.',
        'Photos are GPS-tagged automatically — keep location permissions enabled.',
      ],
    ),
    2: (
      // Finance
      title: 'Finance Tab — Costs, Payments & Estimates',
      tips: [
        'Record every site cost entry to track actual spend against budget.',
        'Attach a receipt photo to any cost entry for accountability.',
        'Record payments made to contractors and suppliers.',
        'Switch to Estimates to attach a saved WyseBrix estimate to this project.',
      ],
    ),
    3: (
      // Documents
      title: 'Documents Tab',
      tips: [
        'Upload permits, plans, warranties, and contracts here.',
        'Set an expiry date on documents — you\'ll get an alert 30 days before.',
        'Tap any document to open or share it.',
      ],
    ),
    4: (
      // Chat
      title: 'Chat Tab',
      tips: [
        'Message your project team (PM, builder) in real time.',
        'All chat messages are stored securely in Firestore.',
        'Tap the bell icon to manage notification preferences for this project.',
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

  // ── Phase sheet ──────────────────────────────────────────────────────────────

  void _showAddPhase(BuildContext context, ProjectService projectService) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => ProjectAddPhaseSheet(
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

  // ── Add issue sheet ───────────────────────────────────────────────────────────

  void _showAddIssue(BuildContext context, String authorUid) {
    HapticFeedback.mediumImpact();
    final auth = context.read<AuthService>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ProjectAddIssueSheet(
        projectId: widget.projectId,
        snagService: sl<SnagService>(),
        auth: auth,
      ),
    );
  }

  // ── Update sheet ─────────────────────────────────────────────────────────────

  void _showAddUpdate(
    BuildContext context,
    ProjectService projectService,
    String authorUid,
  ) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => ProjectAddUpdateSheet(
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
      builder: (ctx) => ProjectUploadDocSheet(
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
    final projectService = sl<ProjectService>();

    switch (action) {
      case _MenuAction.editProject:
        if (context.mounted) {
          context.push('/projects/${widget.projectId}/edit', extra: project);
        }
      case _MenuAction.viewAnalytics:
        if (context.mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CostAnalyticsPage(project: project),
            ),
          );
        }
      case _MenuAction.generateReport:
        await _generateReport(context, project);
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
      case _MenuAction.viewAuditLog:
        if (context.mounted) {
          context.push(
            '/projects/${widget.projectId}/audit',
            extra: {'projectTitle': project.title},
          );
        }
      case _MenuAction.viewQuotes:
        if (context.mounted) {
          context.push(
            '/projects/${widget.projectId}/quotes',
            extra: {'projectTitle': project.title},
          );
        }
      case _MenuAction.editStatus:
        await _showStatusPicker(context, project, projectService);
      case _MenuAction.dueDiligence:
        if (context.mounted) {
          final auth = context.read<AuthService>();
          final isOwner = project.ownerUid == auth.currentUser?.uid;
          context.push(
            '/projects/${widget.projectId}/due-diligence',
            extra: {
              'projectTitle': project.title,
              'isOwner': isOwner,
            },
          );
        }
      case _MenuAction.snagList:
        if (context.mounted) {
          final auth = context.read<AuthService>();
          final isOwner = project.ownerUid == auth.currentUser?.uid;
          final isBuilder = auth.role == UserRole.pm;
          context.push(
            '/projects/${widget.projectId}/snag',
            extra: {
              'projectTitle': project.title,
              'isOwner': isOwner,
              'isBuilder': isBuilder,
              'assignedBuilderUid': project.assignedPmUid,
              'assignedBuilderName': project.assignedPmName,
            },
          );
        }
      case _MenuAction.laborTracking:
        if (context.mounted) {
          final auth = context.read<AuthService>();
          final isOwner = project.ownerUid == auth.currentUser?.uid;
          context.push(
            '/projects/${widget.projectId}/labor',
            extra: {
              'projectTitle': project.title,
              'isOwner': isOwner,
            },
          );
        }
      case _MenuAction.changeOrders:
        if (context.mounted) {
          context.push(
            '/projects/${widget.projectId}/variation-orders',
            extra: {
              'projectTitle': project.title,
              'projectBudgetGhs': project.budget,
            },
          );
        }
      case _MenuAction.siteVisits:
        if (context.mounted) {
          context.push(
            '/projects/${widget.projectId}/site-visits',
            extra: {'projectTitle': project.title},
          );
        }
      case _MenuAction.manageTasks:
        if (context.mounted) {
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (_) => ProjectTasksSheet(projectId: widget.projectId),
          );
        }
      case _MenuAction.generateInvoice:
        if (context.mounted) {
          context.push(
            '/projects/${widget.projectId}/invoice',
            extra: project,
          );
        }
      case _MenuAction.saveAsTemplate:
        await _saveAsTemplate(context, project);
      case _MenuAction.viewTemplates:
        if (context.mounted) {
          context.push('/projects/${widget.projectId}/templates');
        }
      case _MenuAction.delete:
        await _confirmDelete(context, projectService);
    }
  }

  Future<void> _saveAsTemplate(BuildContext context, Project project) async {
    final nameCtrl = TextEditingController(text: project.title);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save as Template'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Creates a reusable template with this project\'s '
              'name, region, budget and phases.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Template name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final projectService = sl<ProjectService>();
      final templateService = sl<ProjectTemplateService>();
      final auth = context.read<AuthService>();

      final phases = await projectService.phasesStream(widget.projectId).first;
      final templatePhases = phases
          .map(
            (p) => TemplatePhase(
              name: p.name,
              estimatedCostGhs: p.estimatedCostGhs ?? 0,
            ),
          )
          .toList();

      await templateService.saveTemplate(
        ProjectTemplate(
          id: '',
          ownerUid: auth.currentUser?.uid ?? '',
          name: nameCtrl.text.trim().isEmpty
              ? project.title
              : nameCtrl.text.trim(),
          description: project.description ?? '',
          region: project.region,
          budget: project.budget,
          phases: templatePhases,
          createdAt: DateTime.now(),
        ),
      );

      messenger.showSnackBar(
        const SnackBar(content: Text('Template saved')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error saving template: $e')),
      );
    }
  }

  Future<void> _generateReport(BuildContext context, Project project) async {
    // Gate behind Pro subscription
    final auth = context.read<AuthService>();
    final tier = auth.currentUser?.subscriptionTier ?? SubscriptionTier.free;
    if (!tier.canExportPdf) {
      context.push(
        '/account/upgrade',
        extra: {'tier': SubscriptionTier.pro.name, 'feature': 'PDF Reports'},
      );
      return;
    }
    setState(() => _generatingReport = true);
    final projectService = sl<ProjectService>();
    final paymentService = sl<PaymentService>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final phases = await projectService.phasesStream(widget.projectId).first;
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

enum _MenuAction {
  editProject,
  viewAnalytics,
  generateReport,
  export,
  viewAuditLog,
  editStatus,
  viewQuotes,
  dueDiligence,
  snagList,
  laborTracking,
  changeOrders,
  siteVisits,
  manageTasks,
  generateInvoice,
  saveAsTemplate,
  viewTemplates,
  delete,
}
