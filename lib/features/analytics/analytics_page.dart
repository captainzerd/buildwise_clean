import '../../core/config/service_locator.dart';
// lib/features/analytics/analytics_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/app_user.dart';
import '../../core/models/builder_contract.dart';
import '../../core/models/cost_entry.dart';
import '../../core/models/phase.dart';
import '../../core/models/project.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/contract_service.dart';
import '../../core/services/project_service.dart';
import '../../core/widgets/shimmer_box.dart';
import '../account/upgrade_page.dart';
import 'widgets/budget_utilisation_card.dart';
import 'widgets/phase_progress_chart.dart';
import 'widgets/spend_chart.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  int _limit = 20;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;
    final projectService = sl<ProjectService>();
    final uid = user?.uid ?? '';

    final hasBasic = user?.canAccessBasicAnalytics ?? false;
    final hasPortfolio = user?.canAccessPortfolioAnalytics ?? false;

    // No access at all — show the Pro gate (existing behaviour for free users).
    if (!hasBasic) {
      return SubscriptionGate(
        required: SubscriptionTier.projectPass,
        featureName: 'Analytics',
        child: const SizedBox.shrink(),
      );
    }

    return StreamBuilder<List<Project>>(
      stream: projectService.projectsForOwner(uid, limit: _limit),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _AnalyticsSkeleton();
        }
        final projects = snap.data ?? [];
        if (projects.isEmpty) {
          return const _EmptyState();
        }
        return _AnalyticsDashboard(
          projects: projects,
          projectService: projectService,
          contractService: sl<ContractService>(),
          uid: uid,
          hasPortfolio: hasPortfolio,
          hasMore: projects.length >= _limit,
          onLoadMore: () => setState(() => _limit += 20),
        );
      },
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _AnalyticsSkeleton extends StatelessWidget {
  const _AnalyticsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        ShimmerBox(height: 80, radius: 12),
        SizedBox(height: 16),
        ShimmerBox(height: 200, radius: 12),
        SizedBox(height: 16),
        ShimmerBox(height: 200, radius: 12),
        SizedBox(height: 16),
        ShimmerBox(height: 200, radius: 12),
      ],
    );
  }
}

// ── Analytics dashboard (basic + optional portfolio) ─────────────────────────

class _AnalyticsDashboard extends StatefulWidget {
  const _AnalyticsDashboard({
    required this.projects,
    required this.projectService,
    required this.contractService,
    required this.uid,
    required this.hasPortfolio,
    required this.hasMore,
    required this.onLoadMore,
  });
  final List<Project> projects;
  final ProjectService projectService;
  final ContractService contractService;
  final String uid;
  final bool hasPortfolio;
  final bool hasMore;
  final VoidCallback onLoadMore;

  @override
  State<_AnalyticsDashboard> createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<_AnalyticsDashboard> {
  // project id → cost entries (loaded lazily)
  final _costs = <String, List<CostEntry>>{};
  final _phases = <String, List<Phase>>{};
  List<BuilderContract> _contracts = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(_AnalyticsDashboard old) {
    super.didUpdateWidget(old);
    if (old.projects != widget.projects) _loadData();
  }

  Future<void> _loadData() async {
    if (_loading) return;
    setState(() => _loading = true);
    // Load all projects concurrently to avoid N+1 sequential Firestore reads.
    await Future.wait([
      ...widget.projects.map((p) async {
        try {
          final results = await Future.wait([
            widget.projectService.costEntriesStream(p.id).first,
            widget.projectService.phasesStream(p.id).first,
          ]);
          if (mounted) {
            setState(() {
              _costs[p.id] = results[0] as List<CostEntry>;
              _phases[p.id] = results[1] as List<Phase>;
            });
          }
        } catch (_) {
          // Skip projects that fail to load
        }
      }),
      // Load contracts for retention summary
      widget.contractService.contractsForMember(widget.uid).first.then((contracts) {
        if (mounted) setState(() => _contracts = contracts);
      }).catchError((_) {}),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final projects = widget.projects;
    final allCosts = _costs.values.expand((e) => e).toList();
    final allPhases = _phases.values.expand((e) => e).toList();

    // Use the first project for the single-project basic analytics section.
    final firstProject = projects.first;
    final firstProjectCosts = _costs[firstProject.id] ?? [];
    final firstProjectPhases = _phases[firstProject.id] ?? [];

    final totalBudget = projects.fold<double>(0, (a, p) => a + p.budget);
    final totalSpent = projects.fold<double>(0, (a, p) => a + p.amountSpent);
    final fmt = NumberFormat('#,##0.00');

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ════════════════════════════════════════════════════════════════
          // BASIC ANALYTICS — Project Pass and above
          // ════════════════════════════════════════════════════════════════

          // ── Single-project budget utilisation ──
          BudgetUtilisationCard(
            budgetGhs: firstProject.budget,
            spentGhs: firstProject.amountSpent,
            title: firstProject.title,
          ),
          const SizedBox(height: 16),

          // ── Single-project spend chart ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _loading && firstProjectCosts.isEmpty
                  ? const SizedBox(
                      height: 180,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : SpendChart(
                      costs: firstProjectCosts,
                      projectTitle: firstProject.title,
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Single-project phase progress ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _loading && firstProjectPhases.isEmpty
                  ? const SizedBox(
                      height: 160,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : PhaseProgressChart(phases: firstProjectPhases),
            ),
          ),
          const SizedBox(height: 24),

          // ════════════════════════════════════════════════════════════════
          // PORTFOLIO ANALYTICS — Pro and Business only
          // ════════════════════════════════════════════════════════════════

          if (!widget.hasPortfolio) ...[
            // Upsell card for users who have basic access but not portfolio.
            _PortfolioUpsellCard(),
          ] else ...[
            // ── Portfolio summary row ──
            _SummaryBar(
              projects: projects,
              totalBudget: totalBudget,
              totalSpent: totalSpent,
              fmt: fmt,
            ),
            const SizedBox(height: 16),

            // ── Overall portfolio budget utilisation ──
            BudgetUtilisationCard(
              budgetGhs: totalBudget,
              spentGhs: totalSpent,
              title: 'Portfolio Budget Utilisation',
            ),
            const SizedBox(height: 16),

            // ── Cumulative spend chart (all projects combined) ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _loading && allCosts.isEmpty
                    ? const SizedBox(
                        height: 180,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : SpendChart(
                        costs: allCosts,
                        projectTitle: 'All Projects',
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Phase status breakdown across all projects ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _loading && allPhases.isEmpty
                    ? const SizedBox(
                        height: 160,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : PhaseProgressChart(phases: allPhases),
              ),
            ),
            const SizedBox(height: 16),

            // ── Retention summary ──
            if (_contracts.isNotEmpty) ...[
              _RetentionSummaryCard(contracts: _contracts),
              const SizedBox(height: 16),
            ],

            // ── Per-project budget cards ──
            Text(
              'Per-Project Budget',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...projects.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: BudgetUtilisationCard(
                  budgetGhs: p.budget,
                  spentGhs: p.amountSpent,
                  title: p.title,
                ),
              ),
            ),
            if (widget.hasMore)
              Center(
                child: TextButton.icon(
                  onPressed: widget.onLoadMore,
                  icon: const Icon(Icons.expand_more),
                  label: const Text('Load more'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Portfolio upsell card ─────────────────────────────────────────────────────

class _PortfolioUpsellCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart_rounded, color: cs.secondary, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Portfolio Analytics',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onSecondaryContainer,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'See spend trends across all your projects, retention summaries, '
              'and multi-project phase breakdowns. Available on the Pro plan.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSecondaryContainer,
                  ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pushNamed('/account/upgrade'),
              icon: const Icon(Icons.rocket_launch_outlined),
              label: const Text('Upgrade to Pro'),
              style: FilledButton.styleFrom(
                backgroundColor: cs.secondary,
                foregroundColor: cs.onSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Summary stats bar ─────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.projects,
    required this.totalBudget,
    required this.totalSpent,
    required this.fmt,
  });
  final List<Project> projects;
  final double totalBudget;
  final double totalSpent;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final active = projects.where((p) => p.status == ProjectStatus.active).length;
    final completed =
        projects.where((p) => p.status == ProjectStatus.completed).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              _StatCell(label: 'Projects', value: '${projects.length}'),
              const VerticalDivider(width: 1),
              _StatCell(label: 'Active', value: '$active'),
              const VerticalDivider(width: 1),
              _StatCell(label: 'Completed', value: '$completed'),
              const VerticalDivider(width: 1),
              _StatCell(
                label: 'Total Spent',
                value: 'GHS\n${fmt.format(totalSpent)}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Retention summary card ────────────────────────────────────────────────────

class _RetentionSummaryCard extends StatelessWidget {
  const _RetentionSummaryCard({required this.contracts});
  final List<BuilderContract> contracts;

  @override
  Widget build(BuildContext context) {
    final activeContracts = contracts
        .where((c) => c.status == ContractStatus.active)
        .toList();
    final totalContractValue =
        activeContracts.fold<double>(0, (s, c) => s + c.totalAmountGhs);
    final totalRetentionHeld = activeContracts
        .where((c) => c.retentionReleasedAt == null)
        .fold<double>(0, (s, c) => s + c.retentionAmountGhs);
    final totalRetentionReleased = activeContracts
        .where((c) => c.retentionReleasedAt != null)
        .fold<double>(0, (s, c) => s + c.retentionAmountGhs);
    final fmt = NumberFormat('#,##0.00');
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_outline, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Retention Summary',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                Text(
                  '${activeContracts.length} active contract${activeContracts.length == 1 ? '' : 's'}',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: cs.outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _RetentionRow(
              label: 'Total Contract Value',
              value: 'GHS ${fmt.format(totalContractValue)}',
              color: cs.onSurface,
            ),
            const Divider(height: 20),
            _RetentionRow(
              label: 'Retention Held',
              value: 'GHS ${fmt.format(totalRetentionHeld)}',
              color: cs.error,
            ),
            const SizedBox(height: 8),
            _RetentionRow(
              label: 'Retention Released',
              value: 'GHS ${fmt.format(totalRetentionReleased)}',
              color: Colors.green,
            ),
            if (totalContractValue > 0) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: totalRetentionReleased /
                      (totalRetentionHeld + totalRetentionReleased + 0.001),
                  minHeight: 6,
                  backgroundColor: cs.error.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Release progress',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: cs.outline),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RetentionRow extends StatelessWidget {
  const _RetentionRow({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No projects yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first project to see analytics here.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
