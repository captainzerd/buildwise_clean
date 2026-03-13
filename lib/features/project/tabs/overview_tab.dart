// lib/features/project/tabs/overview_tab.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/service_locator.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/builder_contract.dart';
import '../../../core/models/pm_profile.dart';
import '../../../core/models/deletion_request.dart';
import '../../../core/models/invitation.dart';
import '../../../core/models/land_ownership_record.dart';
import '../../../core/models/phase.dart';
import '../../../core/models/project.dart';
import '../../../core/models/site_visit.dart';
import '../../../core/models/snag_item.dart';
import '../../../core/models/team_member.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/models/builder_profile.dart';
import '../../../core/services/builder_profile_service.dart';
import '../../../core/services/contract_service.dart';
import '../../../core/services/deletion_request_service.dart';
import '../../../core/services/invitation_service.dart';
import '../../../core/services/land_ownership_service.dart';
import '../../../core/services/project_service.dart';
import '../../../core/services/risk_service.dart';
import '../../../core/services/site_visit_service.dart';
import '../../../core/services/snag_service.dart';
import '../../../core/services/task_service.dart';
import '../builder_marketplace_page.dart';
import '../pm_marketplace_page.dart';
import '../pm_profile_detail_page.dart';
import '../widgets/budget_health_card.dart';
import '../widgets/hire_pm_sheet.dart';
import '../widgets/market_prices_card.dart';
import '../widgets/whatsapp_contact_button.dart';
import '../../../core/models/materials_price.dart';
import '../../../core/services/materials_price_service.dart';

class OverviewTab extends StatefulWidget {
  const OverviewTab({
    super.key,
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
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  bool _removingPm = false;

  // Convenience getters so the existing build/method bodies below don't need
  // updating for widget.* access patterns.
  Project get project => widget.project;
  String get projectId => widget.projectId;
  ProjectService get projectService => widget.projectService;
  BuilderProfileService get builderProfileService => widget.builderProfileService;
  ContractService get contractService => widget.contractService;
  String get currentUserUid => widget.currentUserUid;
  bool get isOwner => widget.isOwner;
  DeletionRequestService get deletionRequestService => widget.deletionRequestService;

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
        _InfoCard(
          children: [
            if ((project.location ?? '').isNotEmpty)
              _kv(
                context,
                Icons.place_outlined,
                'Location',
                project.location!,
              ),
            if (project.latitude != null)
              _kv(
                context,
                Icons.my_location,
                'GPS',
                '${project.latitude!.toStringAsFixed(5)}, '
                    '${project.longitude!.toStringAsFixed(5)}',
              ),
            if (project.region.isNotEmpty)
              _kv(
                context,
                Icons.map_outlined,
                'Region',
                project.region,
              ),
            if (project.projectType != null)
              _kv(
                context,
                Icons.apartment_outlined,
                'Type',
                project.projectType![0].toUpperCase() +
                    project.projectType!.substring(1).replaceAll('_', ' '),
              ),
            if (project.buildingType != null)
              _kv(
                context,
                Icons.home_outlined,
                'Building',
                project.buildingType![0].toUpperCase() +
                    project.buildingType!.substring(1).replaceAll('_', ' '),
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
            if (project.architecturePlanUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: InkWell(
                  onTap: () async {
                    final uri = Uri.parse(project.architecturePlanUrl!);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication,);
                    }
                  },
                  child: Row(
                    children: [
                      Icon(
                        Icons.picture_as_pdf_outlined,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'View Architecture Plan',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 16),

        // ── Stage progress bar ────────────────────────────────────────────────
        StreamBuilder<List<Phase>>(
          stream: projectService.phasesStream(projectId),
          builder: (ctx, pSnap) {
            final phases = pSnap.data ?? [];
            if (phases.isEmpty) return const SizedBox.shrink();
            return Column(
              children: [
                _StageProgressBar(phases: phases),
                const SizedBox(height: 16),
              ],
            );
          },
        ),

        // ── Quick-stats row ──────────────────────────────────────────────────
        _QuickStatsRow(projectId: projectId),

        const SizedBox(height: 16),

        // ── Risk alert banner ─────────────────────────────────────────────────
        StreamBuilder<int>(
          stream: sl<RiskService>().openHighRiskCountStream(projectId),
          builder: (ctx, snap) {
            final count = snap.data ?? 0;
            if (count == 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$count high-severity risk${count > 1 ? 's' : ''} require attention',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('View Risks'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        // ── KPI row ──────────────────────────────────────────────────────────
        StreamBuilder<List<Phase>>(
          stream: projectService.phasesStream(projectId),
          builder: (ctx, phaseSnap) {
            final phases = phaseSnap.data ?? [];
            final done = phases
                .where(
                  (p) => p.status == PhaseStatus.completed,
                )
                .length;
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

        // ── Budget health card ────────────────────────────────────────────────
        StreamBuilder<List<Phase>>(
          stream: projectService.phasesStream(projectId),
          builder: (ctx, phSnap) {
            final phases = phSnap.data ?? [];
            return BudgetHealthCard(project: project, phases: phases);
          },
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
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
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
                        icon:
                            const Icon(Icons.person_search_outlined, size: 18),
                        label: Text(
                          project.assignedPmUid == null
                              ? 'Assign Builder'
                              : 'Change Builder',
                        ),
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
                        icon:
                            const Icon(Icons.person_remove_outlined, size: 18),
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
                  // WhatsApp deeplink — Phase 2 in-app chat deferred
                  StreamBuilder<BuilderProfile?>(
                    stream: builderProfileService
                        .profileStream(project.assignedPmUid!),
                    builder: (ctx, snap) {
                      final phone = snap.data?.phone ?? '';
                      if (phone.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: WhatsAppContactButton(
                            phone: phone,
                            label: 'Message Builder on WhatsApp',
                            message:
                                'Hi, I am contacting you about project: ${project.title}',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ── PM assignment card ────────────────────────────────────────────────
        _AssignedPmSection(
          project: project,
          isOwner: isOwner,
          onFindPm: () => _openPmMarketplace(context),
          onRemovePm: () => _removePmFromProject(context),
          onViewProfile: (pm) => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PmProfileDetailPage(pm: pm),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ── Team members card ─────────────────────────────────────────────────
        _TeamMembersCard(
          project: project,
          projectId: projectId,
          projectService: projectService,
          isOwner: isOwner,
          currentUserUid: currentUserUid,
        ),

        const SizedBox(height: 16),

        // ── Quick-action cards: Site Visits + Snag List ───────────────────────
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.visibility_outlined,
                label: 'Site Visits',
                onTap: () => context.push(
                  '/projects/$projectId/site-visits',
                  extra: {'projectTitle': project.title},
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.checklist_outlined,
                label: 'Snag List',
                onTap: () {
                  final auth = context.read<AuthService>();
                  final isOwnerLocal =
                      project.ownerUid == auth.currentUser?.uid;
                  final isBuilderLocal = auth.role.isProfessional;
                  context.push(
                    '/projects/$projectId/snag',
                    extra: {
                      'projectTitle': project.title,
                      'isOwner': isOwnerLocal,
                      'isBuilder': isBuilderLocal,
                      'assignedBuilderUid': project.assignedPmUid,
                      'assignedBuilderName': project.assignedPmName,
                    },
                  );
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── Land ownership status ──────────────────────────────────────────
        _LandOwnershipStatusCard(
          projectId: projectId,
          projectTitle: project.title,
          isOwner: isOwner,
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
          stream:
              contractService.activeContractStream(projectId, currentUserUid),
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
                        Icon(
                          Icons.description_outlined,
                          size: 18,
                          color: cs.outline,
                        ),
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
                              'signerName': context
                                      .read<AuthService>()
                                      .currentUser
                                      ?.displayName ??
                                  '',
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

        const SizedBox(height: 16),

        // ── Ghana market prices card ──────────────────────────────────────────
        StreamBuilder<MarketPricesSnapshot?>(
          stream: MaterialsPriceService().snapshotStream(),
          builder: (ctx, mpSnap) {
            final mp = mpSnap.data;
            if (mp == null || mp.items.isEmpty) return const SizedBox.shrink();
            return MarketPricesCard(snapshot: mp);
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
          onSelect: (builder) {
            Navigator.of(context).pop();
            if (context.mounted) _handleBuilderSelected(context, builder);
          },
        ),
      ),
    );
  }

  Future<void> _handleBuilderSelected(
      BuildContext context, BuilderProfile builder,) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Assign Builder?'),
        content: Text(
          'Assign ${builder.displayName} as the builder for this project?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await projectService.assignPm(
        projectId,
        pmUid: builder.uid,
        pmName: builder.displayName,
      );
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('${builder.displayName} assigned as builder')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(AppException.from(e).message),
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
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

  void _openPmMarketplace(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PmMarketplacePage(
          onSelect: (pm) {
            Navigator.of(context).pop();
            _handlePmSelected(context, pm);
          },
        ),
      ),
    );
  }

  Future<void> _handlePmSelected(BuildContext context, PmProfile pm) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => HirePmSheet(pm: pm, project: project),
    );
    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${pm.displayName} assigned as PM')),
      );
    }
  }

  Future<void> _removePmFromProject(BuildContext context) async {
    if (_removingPm) return;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Project Manager?'),
        content: const Text(
          'This will unassign the current Project Manager from this project.',
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
    if (confirmed != true) return;
    setState(() => _removingPm = true);
    try {
      await projectService.removePm(projectId);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Project Manager removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(AppException.from(e).message),
            duration: const Duration(seconds: 10),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _removingPm = false);
    }
  }

  Future<void> _ratePm(BuildContext context) async {
    double qualityRating = 5;
    double timelinessRating = 5;
    double communicationRating = 5;
    double valueRating = 5;
    double safetyRating = 5;
    final commentCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          Widget starRow(
              String label, double current, void Function(double) onChanged,) {
            return Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(label, style: const TextStyle(fontSize: 12)),
                ),
                for (int i = 1; i <= 5; i++)
                  GestureDetector(
                    onTap: () => setDlgState(() => onChanged(i.toDouble())),
                    child: Icon(
                      i <= current ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 24,
                    ),
                  ),
              ],
            );
          }

          return AlertDialog(
            title: const Text('Rate Builder'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                starRow('Quality', qualityRating, (v) => qualityRating = v),
                starRow(
                  'Timeliness',
                  timelinessRating,
                  (v) => timelinessRating = v,
                ),
                starRow(
                  'Communication',
                  communicationRating,
                  (v) => communicationRating = v,
                ),
                starRow('Value', valueRating, (v) => valueRating = v),
                starRow('Safety', safetyRating, (v) => safetyRating = v),
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
          );
        },
      ),
    );

    if (confirmed == true && project.assignedPmUid != null && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await builderProfileService.addReview(
          builderUid: project.assignedPmUid!,
          reviewerUid: currentUserUid,
          quality: qualityRating,
          timeliness: timelinessRating,
          communication: communicationRating,
          value: valueRating,
          safety: safetyRating,
          comment: commentCtrl.text.trim(),
        );
        messenger.showSnackBar(
          const SnackBar(content: Text('Rating submitted')),
        );
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(AppException.from(e).message), duration: const Duration(seconds: 10)));
      }
    }
    commentCtrl.dispose();
  }
}

// ── Progress tab (Phases + Updates) ──────────────────────────────────────────────

// ── Assigned PM section ───────────────────────────────────────────────────────

class _AssignedPmSection extends StatelessWidget {
  const _AssignedPmSection({
    required this.project,
    required this.isOwner,
    required this.onFindPm,
    required this.onRemovePm,
    required this.onViewProfile,
  });

  final Project project;
  final bool isOwner;
  final VoidCallback onFindPm;
  final VoidCallback onRemovePm;
  final void Function(PmProfile pm) onViewProfile;

  bool get _hasPm =>
      project.assignedPmUid != null && project.assignedPmUid!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: cs.tertiaryContainer,
                  child: Icon(
                    Icons.manage_accounts_outlined,
                    color: cs.onTertiaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Project Manager',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      Text(
                        _hasPm
                            ? (project.assignedPmName ?? 'PM Assigned')
                            : 'No Project Manager',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: _hasPm ? null : cs.outline,
                            ),
                      ),
                    ],
                  ),
                ),
                if (_hasPm && isOwner)
                  IconButton(
                    icon: Icon(
                      Icons.person_remove_outlined,
                      color: cs.error,
                      size: 20,
                    ),
                    tooltip: 'Remove PM',
                    onPressed: onRemovePm,
                  ),
              ],
            ),
            if (!_hasPm) ...[
              const SizedBox(height: 8),
              Text(
                'Assign a PM to oversee this project.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.outline,
                    ),
              ),
            ],
            const SizedBox(height: 12),
            if (_hasPm)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.person_outlined, size: 18),
                  label: const Text('View Profile'),
                  onPressed: () {
                    // Navigate to PM profile detail using a minimal PmProfile
                    // built from the stored name and uid. The Project model does
                    // not store assignedPmRole, so we use PmRole.values.first
                    // (architect) as a generic fallback — the real profile page
                    // will fetch the full document from Firestore.
                    final pm = PmProfile(
                      uid: project.assignedPmUid!,
                      displayName: project.assignedPmName ?? '',
                      role: PmRole.values.first,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );
                    onViewProfile(pm);
                  },
                ),
              )
            else if (isOwner)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.person_search_outlined, size: 18),
                  label: const Text('Find a PM'),
                  onPressed: onFindPm,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContractStatusChip extends StatelessWidget {
  const _ContractStatusChip({required this.status});
  final ContractStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      ContractStatus.pendingBuilder => (
          cs.secondaryContainer,
          cs.onSecondaryContainer
        ),
      ContractStatus.active => (
          Colors.green.withValues(alpha: 0.15),
          Colors.green[800]!
        ),
      ContractStatus.declined => (cs.errorContainer, cs.onErrorContainer),
      ContractStatus.cancelled => (
          cs.surfaceContainerHighest,
          cs.onSurfaceVariant
        ),
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


class _BudgetAlertBanner extends StatelessWidget {
  const _BudgetAlertBanner({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context) {
    final pct = (project.amountSpent / project.budget * 100).toStringAsFixed(0);
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


class _StageProgressBar extends StatelessWidget {
  const _StageProgressBar({required this.phases});
  final List<Phase> phases;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sorted = [...phases]..sort((a, b) => a.order.compareTo(b.order));
    final total = sorted.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.linear_scale, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  'Construction Stages',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                Text(
                  '${sorted.where((p) => p.status == PhaseStatus.completed).length}/$total done',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.outline,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < sorted.length; i++) ...[
                    _StageStep(
                      phase: sorted[i],
                      index: i,
                      isLast: i == total - 1,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageStep extends StatelessWidget {
  const _StageStep({
    required this.phase,
    required this.index,
    required this.isLast,
  });

  final Phase phase;
  final int index;
  final bool isLast;

  Color _color(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return switch (phase.status) {
      PhaseStatus.completed => Colors.green,
      PhaseStatus.inProgress => cs.primary,
      PhaseStatus.pendingApproval => Colors.amber,
      PhaseStatus.pending => cs.surfaceContainerHighest,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    final isDone = phase.status == PhaseStatus.completed;
    final isActive = phase.status == PhaseStatus.inProgress;

    return Row(
      children: [
        Column(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: color,
              child: isDone
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : isActive
                      ? const Icon(Icons.play_arrow,
                          size: 14, color: Colors.white,)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 56,
              child: Text(
                phase.name,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                    ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (!isLast)
          Container(
            width: 20,
            height: 2,
            color: isDone
                ? Colors.green
                : Theme.of(context).colorScheme.outlineVariant,
          ),
      ],
    );
  }
}

// ── Quick-stats row ───────────────────────────────────────────────────────────

class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        // Open tasks
        Expanded(
          child: StreamBuilder<int>(
            stream: sl<TaskService>().openTaskCountStream(projectId),
            builder: (_, snap) => _MiniStatCard(
              icon: Icons.task_alt_outlined,
              label: 'Open Tasks',
              value: '${snap.data ?? 0}',
              accent: cs.tertiary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Open snags
        Expanded(
          child: StreamBuilder<List<SnagItem>>(
            stream: sl<SnagService>().itemsStream(projectId),
            builder: (_, snap) {
              final open = (snap.data ?? [])
                  .where((s) => s.status != SnagStatus.confirmed)
                  .length;
              return _MiniStatCard(
                icon: Icons.bug_report_outlined,
                label: 'Open Snags',
                value: '$open',
                accent: open > 0 ? cs.error : Colors.green,
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        // Last inspection
        Expanded(
          child: StreamBuilder<List<SiteVisit>>(
            stream: sl<SiteVisitService>().visitsStream(projectId),
            builder: (_, snap) {
              final visits = (snap.data ?? [])
                  .where((v) => v.status == VisitStatus.completed)
                  .toList()
                ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
              final last = visits.isNotEmpty ? visits.first : null;
              final outcomeColor = switch (last?.outcome) {
                VisitOutcome.passed => Colors.green,
                VisitOutcome.failed => cs.error,
                VisitOutcome.needsReinspection => Colors.amber,
                null => cs.outline,
              };
              return _MiniStatCard(
                icon: Icons.fact_check_outlined,
                label: 'Last Inspection',
                value: last == null
                    ? 'None'
                    : last.outcome?.label ??
                        DateFormat('d MMM').format(last.scheduledAt),
                accent: outcomeColor,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: accent, size: 22),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick-action card ─────────────────────────────────────────────────────────


class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child:
                    Text(label, style: Theme.of(context).textTheme.bodyMedium),
              ),
              Icon(Icons.chevron_right, size: 18, color: cs.outline),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Team members card ─────────────────────────────────────────────────────────

class _TeamMembersCard extends StatelessWidget {
  const _TeamMembersCard({
    required this.project,
    required this.projectId,
    required this.projectService,
    required this.isOwner,
    required this.currentUserUid,
  });

  final Project project;
  final String projectId;
  final ProjectService projectService;
  final bool isOwner;
  final String currentUserUid;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final members = project.teamMembers;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.group_outlined, size: 18, color: cs.outline),
                const SizedBox(width: 8),
                Text(
                  'Project Team',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                if (isOwner)
                  TextButton.icon(
                    icon: const Icon(Icons.person_add_outlined, size: 16),
                    label: const Text('Add'),
                    onPressed: () => _showAddMemberSheet(context),
                  ),
              ],
            ),
            if (members.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'No team members added yet.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.outline,
                    ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              for (final m in members)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: cs.secondaryContainer,
                    child: Text(
                      m.displayName.isNotEmpty
                          ? m.displayName[0].toUpperCase()
                          : '?',
                      style: TextStyle(color: cs.onSecondaryContainer),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(m.displayName),
                      const SizedBox(width: 6),
                      Chip(
                        label: Text(
                          m.permissionTier == 'observer'
                              ? 'Observer'
                              : 'Collab',
                          style: const TextStyle(fontSize: 10),
                        ),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        backgroundColor: m.permissionTier == 'observer'
                            ? cs.surfaceContainerHighest
                            : cs.primaryContainer,
                        labelStyle: TextStyle(
                          color: m.permissionTier == 'observer'
                              ? cs.onSurfaceVariant
                              : cs.onPrimaryContainer,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    m.role[0].toUpperCase() + m.role.substring(1),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: isOwner
                      ? IconButton(
                          icon: Icon(
                            Icons.remove_circle_outline,
                            color: cs.error,
                            size: 20,
                          ),
                          onPressed: () async {
                            await projectService.removeTeamMember(
                              projectId,
                              m.uid,
                            );
                          },
                        )
                      : null,
                ),
            ],
            if (isOwner) ...[
              const Divider(height: 24),
              Text(
                'Pending Invitations',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<Invitation>>(
                stream:
                    sl<InvitationService>().projectInvitationsStream(projectId),
                builder: (context, snap) {
                  final invitations = snap.data ?? [];
                  if (invitations.isEmpty) {
                    return Text(
                      'No pending invitations.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.outline,
                          ),
                    );
                  }
                  return Column(
                    children: invitations
                        .map(
                          (inv) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.mail_outline),
                            title: Text(inv.inviteeEmail),
                            subtitle: Text(
                              '${inv.role} · ${inv.permissionTier}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.cancel_outlined,
                                  color: cs.error, size: 20,),
                              tooltip: 'Cancel invitation',
                              onPressed: () async {
                                await sl<InvitationService>()
                                    .cancelInvitation(inv.id);
                              },
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAddMemberSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddMemberSheet(
        projectId: projectId,
        projectService: projectService,
        project: project,
      ),
    );
  }
}

/// Two-tab sheet: Search (instant add) + Invite (email invite link).
class _AddMemberSheet extends StatefulWidget {
  const _AddMemberSheet({
    required this.projectId,
    required this.projectService,
    required this.project,
  });

  final String projectId;
  final ProjectService projectService;
  final Project project;

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Add Team Member',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          TabBar(
            controller: _tabCtrl,
            tabs: const [
              Tab(text: 'Search user'),
              Tab(text: 'Invite by email'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _SearchTab(
                  scrollCtrl: ctrl,
                  projectId: widget.projectId,
                  projectService: widget.projectService,
                ),
                _InviteTab(
                  scrollCtrl: ctrl,
                  projectId: widget.projectId,
                  project: widget.project,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Search tab — searches existing WyseBrix users by email, adds directly.

class _SearchTab extends StatefulWidget {
  const _SearchTab({
    required this.scrollCtrl,
    required this.projectId,
    required this.projectService,
  });

  final ScrollController scrollCtrl;
  final String projectId;
  final ProjectService projectService;

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  final _emailCtrl = TextEditingController();
  String _role = 'contractor';
  String _permissionTier = 'collaborator';
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  bool _adding = false;
  Map<String, dynamic>? _selected;

  Future<void> _search() async {
    final q = _emailCtrl.text.trim();
    if (q.length < 3) return;
    setState(() => _searching = true);
    try {
      final r = await sl<InvitationService>().searchUsers(q);
      setState(() {
        _results = r;
        _searching = false;
      });
    } catch (_) {
      setState(() => _searching = false);
    }
  }

  Future<void> _add() async {
    if (_selected == null) return;
    setState(() => _adding = true);
    try {
      await widget.projectService.addTeamMember(
        widget.projectId,
        TeamMember(
          uid: _selected!['id'] as String,
          displayName: _selected!['displayName'] as String? ?? '',
          role: _role,
          joinedAt: DateTime.now(),
          permissionTier: _permissionTier,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppException.from(e).message)),
        );
      }
      setState(() => _adding = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: widget.scrollCtrl,
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Search by email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                ),
                keyboardType: TextInputType.emailAddress,
                onSubmitted: (_) => _search(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _searching ? null : _search,
              child: _searching
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Search'),
            ),
          ],
        ),
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...(_results.map((r) {
            final isSelected = _selected?['id'] == r['id'];
            return Card(
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              child: ListTile(
                leading: CircleAvatar(
                  child: Text((r['displayName'] as String? ?? '?')[0]),
                ),
                title: Text(r['displayName'] as String? ?? ''),
                subtitle: Text(r['email'] as String? ?? ''),
                onTap: () {
                  setState(() {
                    _selected = isSelected ? null : r;
                    // Auto-fill role from professionalType
                    if (!isSelected) {
                      final pt = r['professionalType'] as String? ?? '';
                      _role = _roleFromProfessionalType(pt);
                      _permissionTier = defaultPermissionTierForRole(_role);
                    }
                  });
                },
              ),
            );
          })),
        ],
        if (_selected != null) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _role,
            decoration: const InputDecoration(
              labelText: 'Role',
              border: OutlineInputBorder(),
            ),
            items: teamRoles
                .map((r) => DropdownMenuItem(value: r.$1, child: Text(r.$2)))
                .toList(),
            onChanged: (v) => setState(() {
              _role = v ?? _role;
              _permissionTier = defaultPermissionTierForRole(_role);
            }),
          ),
          const SizedBox(height: 12),
          _PermissionTierSelector(
            value: _permissionTier,
            onChanged: (v) => setState(() => _permissionTier = v),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _adding ? null : _add,
              child: _adding
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Add to project'),
            ),
          ),
        ],
      ],
    );
  }

  String _roleFromProfessionalType(String pt) => switch (pt) {
        'contractor' => 'contractor',
        'architect' => 'architect',
        'engineer' => 'engineer',
        'inspector' => 'inspector',
        'electrician' => 'electrician',
        'plumber' => 'plumber',
        _ => 'other',
      };
}

/// Invite tab — sends email invite link via Cloud Function.
class _InviteTab extends StatefulWidget {
  const _InviteTab({
    required this.scrollCtrl,
    required this.projectId,
    required this.project,
  });

  final ScrollController scrollCtrl;
  final String projectId;
  final Project project;

  @override
  State<_InviteTab> createState() => _InviteTabState();
}

class _InviteTabState extends State<_InviteTab> {
  final _emailCtrl = TextEditingController();
  String _role = 'contractor';
  String _permissionTier = 'collaborator';
  bool _creating = false;
  String? _link;

  Future<void> _createInvite() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;

    final auth = sl<AuthService>();
    final user = auth.currentUser;
    if (user == null) return;

    setState(() => _creating = true);
    try {
      final token = await sl<InvitationService>().createInvitation(
        projectId: widget.projectId,
        projectTitle: widget.project.title,
        inviterUid: user.uid,
        inviterName: user.displayName.isEmpty ? user.email : user.displayName,
        inviteeEmail: email,
        role: _role,
        permissionTier: _permissionTier,
      );
      setState(() {
        _link = 'wysebrix://join?token=$token';
        _creating = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppException.from(e).message)),
        );
      }
      setState(() => _creating = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      controller: widget.scrollCtrl,
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _emailCtrl,
          decoration: const InputDecoration(
            labelText: 'Invitee email *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.email_outlined),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _role,
          decoration: const InputDecoration(
            labelText: 'Role',
            border: OutlineInputBorder(),
          ),
          items: teamRoles
              .map((r) => DropdownMenuItem(value: r.$1, child: Text(r.$2)))
              .toList(),
          onChanged: (v) => setState(() {
            _role = v ?? _role;
            _permissionTier = defaultPermissionTierForRole(_role);
          }),
        ),
        const SizedBox(height: 12),
        _PermissionTierSelector(
          value: _permissionTier,
          onChanged: (v) => setState(() => _permissionTier = v),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _creating ? null : _createInvite,
            child: _creating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Create invite link'),
          ),
        ),
        if (_link != null) ...[
          const SizedBox(height: 16),
          Card(
            color: cs.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invite link (valid 7 days)',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: cs.onSecondaryContainer,
                        ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    _link!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSecondaryContainer,
                          fontFamily: 'monospace',
                        ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy link'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _link!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Link copied to clipboard'),),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Segmented permission tier selector.
class _PermissionTierSelector extends StatelessWidget {
  const _PermissionTierSelector({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'collaborator',
          label: Text('Collaborator'),
          icon: Icon(Icons.edit_outlined, size: 16),
        ),
        ButtonSegment(
          value: 'observer',
          label: Text('Observer'),
          icon: Icon(Icons.visibility_outlined, size: 16),
        ),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

// ── Tasks sheet (project-level task management) ───────────────────────────────

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
      messenger.showSnackBar(SnackBar(content: Text(AppException.from(e).message), duration: const Duration(seconds: 10)));
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
      messenger.showSnackBar(SnackBar(content: Text(AppException.from(e).message), duration: const Duration(seconds: 10)));
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


class _LandOwnershipStatusCard extends StatelessWidget {
  const _LandOwnershipStatusCard({
    required this.projectId,
    required this.projectTitle,
    required this.isOwner,
  });

  final String projectId;
  final String projectTitle;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return StreamBuilder<LandOwnershipRecord?>(
      stream: sl<LandOwnershipService>().recordStream(projectId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final record = snap.data;

        final (statusColor, statusIcon, statusText) = record == null
            ? (cs.outline, Icons.real_estate_agent_outlined, 'No land record')
            : switch (record.status) {
                LandOwnershipStatus.verified => (
                    Colors.green,
                    Icons.verified_outlined,
                    'Land verified'
                  ),
                LandOwnershipStatus.inProgress => (
                    Colors.amber[700]!,
                    Icons.pending_outlined,
                    'Verification in progress'
                  ),
                LandOwnershipStatus.disputed => (
                    cs.error,
                    Icons.warning_amber_outlined,
                    'Land disputed'
                  ),
                LandOwnershipStatus.notStarted => (
                    cs.outline,
                    Icons.real_estate_agent_outlined,
                    'Land title not started'
                  ),
              };

        return Card(
          child: ListTile(
            leading: Icon(statusIcon, color: statusColor),
            title: Text(
              'Land Ownership',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            subtitle: Text(
              record?.titleDeedNumber != null
                  ? '$statusText · Deed: ${record!.titleDeedNumber}'
                  : statusText,
              style: TextStyle(color: statusColor, fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(
              '/projects/$projectId/due-diligence',
              extra: {
                'projectTitle': projectTitle,
                'isOwner': isOwner,
              },
            ),
          ),
        );
      },
    );
  }
}
