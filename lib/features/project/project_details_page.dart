import '../../core/config/service_locator.dart';
// lib/features/project/project_details_page.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
// ignore: unnecessary_import
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/app_user.dart';
import '../../core/models/boq_item.dart';
import '../../core/services/boq_service.dart';
import '../estimate/boq_page.dart';
import '../../core/models/builder_contract.dart';
import '../../core/models/cost_entry.dart';
import '../../core/models/deletion_request.dart';
import '../../core/models/payment_record.dart';
import '../../core/models/phase.dart';
import '../../core/models/project.dart';
import '../../core/models/project_document.dart';
import '../../core/models/project_update.dart';
import '../../core/models/audit_event.dart';
import '../../core/services/audit_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/builder_profile_service.dart';
import '../../core/services/contract_service.dart';
import '../../core/services/deletion_request_service.dart';
import '../../core/services/payment_service.dart';
import '../../core/services/pdf_service.dart';
import '../../core/models/chat_message.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/paystack_service.dart';
import '../../core/services/project_service.dart';
import 'export_sheet.dart';
import '../payment/paystack_checkout_page.dart';
import '../estimate/estimate_view_page.dart';
import 'builder_marketplace_page.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_box.dart';
import 'cost_analytics_page.dart';
import '../../core/models/project_template.dart';
import '../../core/services/project_template_service.dart';
import 'widgets/phases_timeline.dart';

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
  int _workSection = 0;    // 0 = Phases, 1 = Updates
  int _financeSection = 0; // 0 = Costs, 1 = Payments, 2 = Estimates

  // Tab index constants
  static const _kWork      = 1;
  static const _kFinance   = 2;
  static const _kDocuments = 3;

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
                  onSelected: (action) =>
                      _handleMenu(context, action, project),
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
                Tab(icon: Icon(Icons.build_outlined), text: 'Work'),
                Tab(icon: Icon(Icons.account_balance_wallet_outlined), text: 'Finance'),
                Tab(icon: Icon(Icons.folder_outlined), text: 'Documents'),
                Tab(icon: Icon(Icons.forum_outlined), text: 'Chat'),
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
                            sl<DeletionRequestService>();
                        return TabBarView(
                          controller: _tabs,
                          children: [
                            _OverviewTab(
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
                            _WorkTab(
                              projectId: widget.projectId,
                              projectService: projectService,
                              isOwner: isOwner,
                              isBuilder: isBuilder,
                              onSectionChanged: (i) =>
                                  setState(() => _workSection = i),
                            ),
                            _FinanceTab(
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
                              currentUserEmail:
                                  auth.currentUser?.email ?? '',
                              onSectionChanged: (i) =>
                                  setState(() => _financeSection = i),
                            ),
                            _DocsTab(
                              projectId: widget.projectId,
                              projectService: projectService,
                            ),
                            _ChatTab(
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
          floatingActionButton: project != null
              ? _buildFab(context, project)
              : null,
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
          1 => FloatingActionButton(
              tooltip: 'Add update',
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
      _ => null,
    };
  }

  // ── Help sheet ───────────────────────────────────────────────────────────────

  static const _helpContent = {
    0: ( // Overview
      title: 'Overview Tab',
      tips: [
        'See your project budget vs. actual spend at a glance.',
        'Tap the chart to open a detailed cost analytics breakdown.',
        'Assign a Project Manager or Builder from the Overview tab.',
        'Use the ⋮ menu → Edit Project to update title, budget, or region.',
      ],
    ),
    1: ( // Work
      title: 'Work Tab — Phases & Updates',
      tips: [
        'Add phases to track each stage of construction (Foundation, Structure, etc.).',
        'Set Estimated Cost and % Complete on each phase to power the EV analysis.',
        'Switch to Updates (top toggle) to log daily site progress with photos.',
        'Photos are GPS-tagged automatically — keep location permissions enabled.',
      ],
    ),
    2: ( // Finance
      title: 'Finance Tab — Costs, Payments & Estimates',
      tips: [
        'Record every site cost entry to track actual spend against budget.',
        'Attach a receipt photo to any cost entry for accountability.',
        'Record payments made to contractors and suppliers.',
        'Switch to Estimates to attach a saved BuildWise estimate to this project.',
      ],
    ),
    3: ( // Documents
      title: 'Documents Tab',
      tips: [
        'Upload permits, plans, warranties, and contracts here.',
        'Set an expiry date on documents — you\'ll get an alert 30 days before.',
        'Tap any document to open or share it.',
      ],
    ),
    4: ( // Chat
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
    HapticFeedback.mediumImpact();
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
    final projectService = sl<ProjectService>();

    switch (action) {
      case _MenuAction.editProject:
        if (context.mounted) {
          context.push('/projects/${widget.projectId}/edit', extra: project);
        }
      case _MenuAction.viewAnalytics:
        if (context.mounted) {
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => CostAnalyticsPage(project: project),
          ),);
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
            extra: {'projectTitle': project.title},
          );
        }
      case _MenuAction.siteVisits:
        if (context.mounted) {
          context.push(
            '/projects/${widget.projectId}/site-visits',
            extra: {'projectTitle': project.title},
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
          name: nameCtrl.text.trim().isEmpty ? project.title : nameCtrl.text.trim(),
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
      if (context.mounted) {
        final auth = context.read<AuthService>();
        unawaited(
          sl<AuditService>().logEvent(
            projectId: widget.projectId,
            type: AuditEventType.projectStatusChanged,
            actorUid: auth.currentUser?.uid ?? '',
            actorName: auth.currentUser?.displayName ?? '',
            description:
                'Project status changed to ${picked.label}',
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
  generateInvoice,
  saveAsTemplate,
  viewTemplates,
  delete,
}

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
        // Budget alert banner
        if (project.budget > 0 &&
            project.amountSpent >=
                project.budget * project.budgetAlertThreshold)
          _BudgetAlertBanner(project: project),
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

        // ── KPI row ──────────────────────────────────────────────────────────
        StreamBuilder<List<Phase>>(
          stream: projectService.phasesStream(projectId),
          builder: (ctx, phaseSnap) {
            final phases = phaseSnap.data ?? [];
            final done = phases.where(
              (p) => p.status == PhaseStatus.completed,
            ).length;
            final total = phases.length;
            final spentPct = budget > 0
                ? '${(spent / budget * 100).clamp(0, 999).toStringAsFixed(0)}%'
                : '—';

            return Row(
              children: [
                Expanded(
                  child: _KpiCard(
                    label: 'Budget used',
                    value: spentPct,
                    icon: Icons.account_balance_wallet_outlined,
                    accent: overBudget ? cs.error : cs.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _KpiCard(
                    label: 'Phases done',
                    value: total == 0 ? '—' : '$done\u2009/\u2009$total',
                    icon: Icons.layers_outlined,
                    accent: cs.secondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _KpiCard(
                    label: 'Status',
                    value: project.status.name[0].toUpperCase() +
                        project.status.name.substring(1),
                    icon: Icons.flag_outlined,
                    accent: cs.tertiary,
                  ),
                ),
              ],
            );
          },
        ),

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
                      // Overdue milestone badge
                      Builder(
                        builder: (_) {
                          final overdueCount = contract.milestones
                              .where(
                                (m) =>
                                    !m.isPaid &&
                                    m.dueDate != null &&
                                    m.dueDate!.isBefore(DateTime.now()),
                              )
                              .length;
                          if (overdueCount == 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Chip(
                              avatar: Icon(
                                Icons.warning_amber,
                                size: 16,
                                color: cs.onErrorContainer,
                              ),
                              label: Text(
                                '$overdueCount milestone${overdueCount > 1 ? 's' : ''} overdue',
                              ),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                color: cs.onErrorContainer,
                              ),
                              backgroundColor: cs.errorContainer,
                              side: BorderSide.none,
                              visualDensity: VisualDensity.compact,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          label: const Text('View Contract'),
                          onPressed: () => context.push(
                            '/projects/$projectId/contract/view',
                            extra: {
                              'contract': contract,
                              'currentUserUid': currentUserUid,
                              'signerName': context.read<AuthService>().currentUser?.displayName ?? '',
                            },
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
            context.push(
              '/projects/$projectId/contract/create',
              extra: {
                'projectTitle': project.title,
                'builder': builder,
                'ownerUid': currentUserUid,
              },
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
                      tooltip: '$i star${i > 1 ? 's' : ''}',
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

// ── Work tab (Phases + Updates) ──────────────────────────────────────────────

enum _WorkSection { phases, updates }

class _WorkTab extends StatefulWidget {
  const _WorkTab({
    required this.projectId,
    required this.projectService,
    required this.isOwner,
    required this.isBuilder,
    required this.onSectionChanged,
  });

  final String projectId;
  final ProjectService projectService;
  final bool isOwner;
  final bool isBuilder;
  final ValueChanged<int> onSectionChanged;

  @override
  State<_WorkTab> createState() => _WorkTabState();
}

class _WorkTabState extends State<_WorkTab> {
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
                label: Text('Phases'),
                icon: Icon(Icons.layers_outlined),
              ),
              ButtonSegment(
                value: _WorkSection.updates,
                label: Text('Updates'),
                icon: Icon(Icons.chat_bubble_outline),
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
              _UpdatesTab(
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

// ── Finance tab (Costs + Payments + Estimates) ────────────────────────────────

enum _FinanceSection { costs, payments, estimates, boq }

class _FinanceTab extends StatefulWidget {
  const _FinanceTab({
    required this.projectId,
    required this.project,
    required this.projectService,
    required this.paymentService,
    required this.paystackService,
    required this.deletionRequestService,
    required this.isOwner,
    required this.isBuilder,
    required this.currentUserUid,
    required this.currentUserName,
    required this.currentUserEmail,
    required this.onSectionChanged,
  });

  final String projectId;
  final Project project;
  final ProjectService projectService;
  final PaymentService paymentService;
  final PaystackService paystackService;
  final DeletionRequestService deletionRequestService;
  final bool isOwner;
  final bool isBuilder;
  final String currentUserUid;
  final String currentUserName;
  final String currentUserEmail;
  final ValueChanged<int> onSectionChanged;

  @override
  State<_FinanceTab> createState() => _FinanceTabState();
}

class _FinanceTabState extends State<_FinanceTab> {
  _FinanceSection _section = _FinanceSection.costs;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SegmentedButton<_FinanceSection>(
            expandedInsets: EdgeInsets.zero,
            segments: const [
              ButtonSegment(
                value: _FinanceSection.costs,
                label: Text('Costs'),
                icon: Icon(Icons.receipt_long_outlined),
              ),
              ButtonSegment(
                value: _FinanceSection.payments,
                label: Text('Payments'),
                icon: Icon(Icons.payments_outlined),
              ),
              ButtonSegment(
                value: _FinanceSection.estimates,
                label: Text('Estimates'),
                icon: Icon(Icons.analytics_outlined),
              ),
              ButtonSegment(
                value: _FinanceSection.boq,
                label: Text('BOQ'),
                icon: Icon(Icons.table_chart_outlined),
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
              _CostsTab(
                projectId: widget.projectId,
                currencySymbol: widget.project.currencySymbol,
                projectService: widget.projectService,
                isBuilder: widget.isBuilder,
                currentUserUid: widget.currentUserUid,
                currentUserName: widget.currentUserName,
                deletionRequestService: widget.deletionRequestService,
              ),
              _PaymentsTab(
                projectId: widget.projectId,
                paymentService: widget.paymentService,
                isBuilder: widget.isBuilder,
                isOwner: widget.isOwner,
                currentUserUid: widget.currentUserUid,
                currentUserName: widget.currentUserName,
                currentUserEmail: widget.currentUserEmail,
                deletionRequestService: widget.deletionRequestService,
                paystackService: widget.paystackService,
              ),
              _EstimatesTab(
                projectId: widget.projectId,
                projectService: widget.projectService,
              ),
              _BoqTab(projectId: widget.projectId),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Phases tab ─────────────────────────────────────────────────────────────────

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
            if (phases.isNotEmpty)
              _EvSummaryCard(phases: phases),
            // ── Content ──
            Expanded(
              child: phases.isEmpty
                  ? EmptyState(
                      icon: Icons.layers_outlined,
                      title: 'No phases yet',
                      message: 'Add a phase to track your project timeline.',
                      actionLabel:
                          widget.isOwner ? 'Add first phase' : null,
                      onAction: widget.isOwner
                          ? () => showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                showDragHandle: true,
                                builder: (_) => _AddPhaseSheet(
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
                          padding:
                              const EdgeInsets.fromLTRB(16, 8, 16, 96),
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
                                          onPressed: () => Navigator.pop(dlgCtx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        FilledButton(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: Theme.of(context).colorScheme.error,
                                            foregroundColor: Theme.of(context).colorScheme.onError,
                                          ),
                                          onPressed: () => Navigator.pop(dlgCtx, true),
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
                                onSubmitForApproval: () =>
                                    widget.projectService
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
      builder: (ctx) => _AddPhaseSheet(
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

    final bac = phasesWithEst.fold<double>(0, (s, p) => s + p.estimatedCostGhs!);
    final ev = phasesWithEst.fold<double>(
      0,
      (s, p) => s + p.estimatedCostGhs! * (p.percentComplete / 100.0),
    );
    final ac = phasesWithEst.fold<double>(0, (s, p) => s + (p.actualCostGhs ?? 0));

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
                    tooltip: 'Cost Performance Index: EV ÷ AC. >1 = under budget.',
                    value: cpi != null ? cpi.toStringAsFixed(2) : 'N/A',
                    color: kpiColor(cpi),
                  ),
                  const SizedBox(width: 12),
                  _EvKpi(
                    label: 'SPI',
                    tooltip: 'Schedule Performance: % of budget earned. >80% = on track.',
                    value: spi != null ? '${(spi * 100).toStringAsFixed(1)}%' : 'N/A',
                    color: kpiColor(spi),
                  ),
                  const SizedBox(width: 12),
                  _EvKpi(
                    label: 'EV',
                    tooltip: 'Earned Value: budget for work physically done.',
                    value: NumberFormat.compactCurrency(symbol: 'GHS ', decimalDigits: 0)
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
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
          if (isBuilder &&
              phase.status == PhaseStatus.inProgress)
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
          if (isOwner &&
              phase.status == PhaseStatus.pendingApproval) ...[
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
                      builder: (_) => _PhotoGallery(
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
                      placeholder: (_, __) => const ShimmerBox(width: 60, height: 60),
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

// ── BOQ tab ────────────────────────────────────────────────────────────────────

class _BoqTab extends StatelessWidget {
  const _BoqTab({required this.projectId});

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
            message: 'Create a project from an estimate to attach a Bill of Quantities.',
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
                            Text('Grand Total',
                                style: Theme.of(context).textTheme.labelMedium,),
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
                            Text('Floor area',
                                style: Theme.of(context).textTheme.labelMedium,),
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

class _CostsTab extends StatefulWidget {
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
  State<_CostsTab> createState() => _CostsTabState();
}

class _CostsTabState extends State<_CostsTab> {
  String _costQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CostEntry>>(
      stream: widget.projectService.costEntriesStream(widget.projectId),
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
              builder: (_) => _AddCostSheet(
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
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) => _CostEntryTile(
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
                                  onPressed: () => Navigator.pop(dlgCtx, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.error,
                                    foregroundColor: Theme.of(context).colorScheme.onError,
                                  ),
                                  onPressed: () => Navigator.pop(dlgCtx, true),
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
          return const EmptyState(
            icon: Icons.chat_bubble_outline,
            title: 'No updates yet',
            message: 'Tap + to post the first update.',
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
                        builder: (_) => _PhotoGallery(
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
                        placeholder: (_, __) => const ShimmerBox(width: 80, height: 80),
                        errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined),
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
          return const EmptyState(
            icon: Icons.folder_outlined,
            title: 'No documents yet',
            message: 'Tap the upload button to add files.',
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

    final expiryColor = doc.isExpired
        ? cs.error
        : doc.expiresWithin30Days
            ? Colors.orange
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
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
            if (doc.expiresAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      doc.isExpired
                          ? Icons.warning_rounded
                          : Icons.event_outlined,
                      size: 12,
                      color: expiryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      doc.isExpired
                          ? 'Expired ${DateFormat('d MMM yyyy').format(doc.expiresAt!)}'
                          : 'Expires ${DateFormat('d MMM yyyy').format(doc.expiresAt!)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: expiryColor,
                            fontWeight: doc.isExpired || doc.expiresWithin30Days
                                ? FontWeight.bold
                                : null,
                          ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        isThreeLine: doc.expiresAt != null,
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
  DateTime? _expiresAt;

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
        expiresAt: _expiresAt,
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text(
                      _expiresAt == null
                          ? 'Expiry date (optional)'
                          : 'Expires: ${DateFormat('d MMM yyyy').format(_expiresAt!)}',
                    ),
                    onPressed: _uploading
                        ? null
                        : () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now()
                                  .add(const Duration(days: 365)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 365 * 20)),
                            );
                            if (picked != null) {
                              setState(() => _expiresAt = picked);
                            }
                          },
                  ),
                ),
                if (_expiresAt != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Clear expiry',
                    onPressed: () => setState(() => _expiresAt = null),
                  ),
              ],
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
  DateTime? _startDate;
  DateTime? _endDate;
  int _percentComplete = 0;

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
    // Capture context-dependent services before any await (async gap safety).
    final auditService = sl<AuditService>();
    final actorUid = context.read<AuthService>().currentUser?.uid ?? '';
    final actorName = context.read<AuthService>().currentUser?.displayName ?? '';
    try {
      if (widget.editing != null) {
        await widget.projectService.updatePhase(
          widget.projectId,
          widget.editing!.id,
          {
            'name': _nameCtrl.text.trim(),
            'status': _status.firestoreValue,
            'percentComplete': _percentComplete,
            if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
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
          startDate: _startDate,
          endDate: _endDate,
          createdAt: DateTime.now(),
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
                      placeholder: (_, __) => const ShimmerBox(width: 60, height: 60),
                      errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined),
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

    // Enforce free-tier cost-entry limit.
    final auth = context.read<AuthService>();
    final tier = auth.currentUser?.subscriptionTier ?? SubscriptionTier.free;
    if (tier.maxCostEntriesPerProject < 999999) {
      final currentCount = await widget.projectService
          .costEntryCount(widget.projectId);
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

/// Compact metric card used in the Overview KPI row.
class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Column(
          children: [
            Icon(icon, size: 20, color: accent),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

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
          return const EmptyState(
            icon: Icons.analytics_outlined,
            title: 'No estimates yet',
            message: 'Tap the attach button to link a saved estimate.',
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

// ── Payments tab ───────────────────────────────────────────────────────────────

class _PaymentsTab extends StatefulWidget {
  const _PaymentsTab({
    required this.projectId,
    required this.paymentService,
    required this.isBuilder,
    required this.isOwner,
    required this.currentUserUid,
    required this.currentUserName,
    required this.currentUserEmail,
    required this.deletionRequestService,
    required this.paystackService,
  });
  final String projectId;
  final PaymentService paymentService;
  final bool isBuilder;
  final bool isOwner;
  final String currentUserUid;
  final String currentUserName;
  final String currentUserEmail;
  final DeletionRequestService deletionRequestService;
  final PaystackService paystackService;

  @override
  State<_PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<_PaymentsTab> {
  String _paymentQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PaymentRecord>>(
      stream: widget.paymentService.paymentsStream(widget.projectId),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final allPayments = snap.data ?? [];
        final payments = _paymentQuery.isEmpty
            ? allPayments
            : allPayments.where((p) {
                final q = _paymentQuery.toLowerCase();
                return p.description.toLowerCase().contains(q) ||
                    p.method.label.toLowerCase().contains(q) ||
                    (p.reference ?? '').toLowerCase().contains(q) ||
                    (p.phaseTitle ?? '').toLowerCase().contains(q);
              }).toList();

        if (allPayments.isEmpty) {
          return EmptyState(
            icon: Icons.payments_outlined,
            title: 'No payments recorded',
            message: 'Record your first payment transaction.',
            actionLabel: 'Record payment',
            onAction: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => _AddPaymentSheet(
                projectId: widget.projectId,
                authorUid: widget.currentUserUid,
                paymentService: widget.paymentService,
                projectService: sl<ProjectService>(),
              ),
            ),
          );
        }

        // Summary totals from all payments (not filtered)
        double totalOut = 0;
        double totalIn = 0;
        for (final p in allPayments) {
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
            // Search bar
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search payments…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _paymentQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _paymentQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: (v) => setState(() => _paymentQuery = v),
              ),
            ),
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
            if (widget.isOwner) ...[
              _PaystackButton(
                projectId: widget.projectId,
                currentUserEmail: widget.currentUserEmail,
                paystackService: widget.paystackService,
              ),
              const SizedBox(height: 12),
            ],
            if (payments.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No matching payments'),
                ),
              )
            else
              ...payments.map(
                (p) => _PaymentCard(
                  payment: p,
                  isBuilder: widget.isBuilder,
                  onDelete: () => widget.paymentService.deletePayment(
                    projectId: widget.projectId,
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
      await widget.deletionRequestService.request(
        DeletionRequest(
          itemId: payment.id,
          projectId: widget.projectId,
          itemType: DeletionItemType.payment,
          itemDescription: payment.description,
          requestedByUid: widget.currentUserUid,
          requestedByName: widget.currentUserName,
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
              '${payment.method.label}${payment.mobileMoneyNetwork != null ? ' (${payment.mobileMoneyNetwork!.label})' : ''} · ${dateFmt.format(payment.paymentDate)}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            if (payment.mobileMoneyPhone != null &&
                payment.mobileMoneyPhone!.isNotEmpty)
              Text(
                'Phone: ${payment.mobileMoneyPhone}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.outline,
                    ),
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
  final _momoPhoneCtrl = TextEditingController();

  PaymentDirection _direction = PaymentDirection.outbound;
  PaymentMethod _method = PaymentMethod.cash;
  MobileMoneyNetwork _momoNetwork = MobileMoneyNetwork.mtn;
  DateTime _paymentDate = DateTime.now();
  String? _selectedPhaseId;
  String? _selectedPhaseTitle;
  bool _saving = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _momoPhoneCtrl.dispose();
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
    // Capture before async gap.
    final auditService = sl<AuditService>();
    final actorName = context.read<AuthService>().currentUser?.displayName ?? '';
    try {
      final isMomo = _method == PaymentMethod.mobileMoney;
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
        mobileMoneyNetwork: isMomo ? _momoNetwork : null,
        mobileMoneyPhone: isMomo && _momoPhoneCtrl.text.trim().isNotEmpty
            ? _momoPhoneCtrl.text.trim()
            : null,
      );
      await widget.paymentService.addPayment(
        projectId: widget.projectId,
        payment: payment,
      );
      unawaited(
        auditService.logEvent(
          projectId: widget.projectId,
          type: AuditEventType.paymentAdded,
          actorUid: widget.authorUid,
          actorName: actorName,
          description:
              'Recorded payment: ${_direction.label} GHS ${payment.amountGhs.toStringAsFixed(2)} \u2014 ${_descCtrl.text.trim()}',
          metadata: {
            'amountGhs': payment.amountGhs,
            'direction': _direction.name,
          },
        ),
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

              // MoMo-specific fields
              if (_method == PaymentMethod.mobileMoney) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<MobileMoneyNetwork>(
                  initialValue: _momoNetwork,
                  decoration: const InputDecoration(
                    labelText: 'Network *',
                    border: OutlineInputBorder(),
                  ),
                  items: MobileMoneyNetwork.values
                      .map(
                        (n) =>
                            DropdownMenuItem(value: n, child: Text(n.label)),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _momoNetwork = v);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _momoPhoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Mobile money phone (optional)',
                    hintText: 'e.g. 0241234567',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ],
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

// ── Paystack button ────────────────────────────────────────────────────────────

class _PaystackButton extends StatefulWidget {
  const _PaystackButton({
    required this.projectId,
    required this.currentUserEmail,
    required this.paystackService,
  });

  final String projectId;
  final String currentUserEmail;
  final PaystackService paystackService;

  @override
  State<_PaystackButton> createState() => _PaystackButtonState();
}

class _PaystackButtonState extends State<_PaystackButton> {
  bool _loading = false;

  Future<void> _launch() async {
    final amountCtrl = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pay via Paystack'),
        content: TextField(
          controller: amountCtrl,
          decoration: const InputDecoration(
            labelText: 'Amount (GHS)',
            prefixText: 'GH₵ ',
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(amountCtrl.text.trim());
              Navigator.of(ctx).pop(v);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (amount == null || amount <= 0 || !mounted) return;

    setState(() => _loading = true);
    try {
      final ref = const Uuid().v4();
      final result = await widget.paystackService.initTransaction(
        amountGhs: amount,
        email: widget.currentUserEmail.isNotEmpty
            ? widget.currentUserEmail
            : 'noreply@buildwise.app',
        reference: ref,
        metadata: {'projectId': widget.projectId},
      );
      if (!mounted) return;
      final checkoutResult = await Navigator.of(context).push<PaystackCheckoutResult>(
        MaterialPageRoute(
          builder: (_) => PaystackCheckoutPage(
            authorizationUrl: result.authorizationUrl,
            reference: result.reference,
          ),
        ),
      );
      if (!mounted) return;
      if (checkoutResult?.success == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment successful! Ref: ${checkoutResult!.reference ?? result.reference}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paystack error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _loading ? null : _launch,
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.credit_card_outlined, size: 18),
        label: const Text('Pay via Paystack'),
      ),
    );
  }
}

// ── Chat tab ───────────────────────────────────────────────────────────────────

class _ChatTab extends StatefulWidget {
  const _ChatTab({
    required this.projectId,
    required this.currentUserUid,
    required this.currentUserName,
    required this.chatService,
  });

  final String projectId;
  final String currentUserUid;
  final String currentUserName;
  final ChatService chatService;

  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.chatService.sendMessage(
        projectId: widget.projectId,
        senderUid: widget.currentUserUid,
        senderName: widget.currentUserName,
        text: text,
      );
      _controller.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: widget.chatService.messagesStream(widget.projectId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final messages = snap.data ?? [];
              if (messages.isEmpty) {
                return const Center(
                  child: Text(
                    'No messages yet.\nStart the conversation!',
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (_, i) {
                  final msg = messages[i];
                  final isMe = msg.senderUid == widget.currentUserUid;
                  return Align(
                    alignment: isMe
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.72,
                      ),
                      decoration: BoxDecoration(
                        color: isMe
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          if (!isMe)
                            Text(
                              msg.senderName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          Text(msg.text),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('HH:mm').format(msg.createdAt),
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Type a message…',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                _sending
                    ? const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton.filled(
                        icon: const Icon(Icons.send),
                        onPressed: _send,
                      ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Budget alert banner ─────────────────────────────────────────────────────────

class _BudgetAlertBanner extends StatelessWidget {
  const _BudgetAlertBanner({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context) {
    final pct =
        (project.amountSpent / project.budget * 100).toStringAsFixed(0);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange[700],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Spend has reached $pct% of budget',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Full-screen single photo viewer (receipts & single-image contexts) ─────────

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
        title: Text(title, style: const TextStyle(color: Colors.white)),
      ),
      body: _ZoomableNetworkImage(url: url),
    );
  }
}

// ── Multi-photo gallery with swipe carousel ─────────────────────────────────

class _PhotoGallery extends StatefulWidget {
  const _PhotoGallery({required this.urls, required this.initialIndex});
  final List<String> urls;
  final int initialIndex;

  @override
  State<_PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<_PhotoGallery> {
  late final PageController _ctrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _ctrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.urls.length;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          total > 1 ? 'Photo ${_current + 1} of $total' : 'Photo',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PageView.builder(
        controller: _ctrl,
        itemCount: total,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) => _ZoomableNetworkImage(url: widget.urls[i]),
      ),
    );
  }
}

// ── Shared pinch-to-zoom image ───────────────────────────────────────────────

class _ZoomableNetworkImage extends StatelessWidget {
  const _ZoomableNetworkImage({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 5,
      child: Center(
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          placeholder: (_, __) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          errorWidget: (_, __, ___) => const Center(
            child: Icon(
              Icons.broken_image_outlined,
              size: 64,
              color: Colors.white54,
            ),
          ),
        ),
      ),
    );
  }
}
