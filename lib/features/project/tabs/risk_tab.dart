// lib/features/project/tabs/risk_tab.dart
import 'package:flutter/material.dart';

import '../../../core/config/service_locator.dart';
import '../../../core/models/risk_item.dart';
import '../../../core/services/risk_service.dart';

class RisksTab extends StatelessWidget {
  const RisksTab({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RiskItem>>(
      stream: sl<RiskService>().risksStream(projectId),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final risks = snap.data ?? [];
        if (risks.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                const SizedBox(height: 12),
                const Text('No risks logged'),
                const SizedBox(height: 8),
                Text(
                  'Tap + to add a risk item.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          );
        }
        final open = risks.where((r) => r.status == RiskStatus.open).toList();
        final other = risks.where((r) => r.status != RiskStatus.open).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (open.isNotEmpty) ...[
              Text(
                'Open Risks',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              for (final r in open) _RiskCard(risk: r, projectId: projectId),
              const SizedBox(height: 16),
            ],
            if (other.isNotEmpty) ...[
              Text(
                'Resolved / Closed',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 8),
              for (final r in other) _RiskCard(risk: r, projectId: projectId),
            ],
          ],
        );
      },
    );
  }
}

class _RiskCard extends StatelessWidget {
  const _RiskCard({required this.risk, required this.projectId});
  final RiskItem risk;
  final String projectId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: risk.riskColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      risk.riskLevel,
                      style: TextStyle(
                        fontSize: 11,
                        color: risk.riskColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      risk.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  Text(
                    'P${risk.probability}×I${risk.impact}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.outline,
                        ),
                  ),
                ],
              ),
              if (risk.mitigationPlan != null &&
                  risk.mitigationPlan!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  risk.mitigationPlan!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.outline,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Chip(
                    label: Text(
                      risk.category[0].toUpperCase() +
                          risk.category.substring(1),
                    ),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                    labelStyle: const TextStyle(fontSize: 11),
                  ),
                  const Spacer(),
                  if (risk.status == RiskStatus.open)
                    TextButton(
                      onPressed: () async {
                        await sl<RiskService>().updateRisk(
                          projectId,
                          risk.id,
                          {'status': 'mitigated'},
                        );
                      },
                      child: const Text('Mark Mitigated'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: risk.riskColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    risk.riskLevel,
                    style: TextStyle(
                      fontSize: 12,
                      color: risk.riskColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    risk.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _detailRow(
              context,
              'Category',
              risk.category[0].toUpperCase() + risk.category.substring(1),
            ),
            _detailRow(context, 'Probability', '${risk.probability} / 5'),
            _detailRow(context, 'Impact', '${risk.impact} / 5'),
            _detailRow(context, 'Risk Score', '${risk.riskScore} / 25'),
            _detailRow(context, 'Status', risk.status.label),
            if (risk.mitigationPlan != null) ...[
              const SizedBox(height: 12),
              Text(
                'Mitigation Plan',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(risk.mitigationPlan!),
            ],
            if (risk.notes != null) ...[
              const SizedBox(height: 8),
              Text(
                'Notes',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(risk.notes!),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                if (risk.status == RiskStatus.open)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await sl<RiskService>().updateRisk(
                          projectId,
                          risk.id,
                          {'status': 'mitigated'},
                        );
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      child: const Text('Mark Mitigated'),
                    ),
                  ),
                if (risk.status == RiskStatus.open) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: () async {
                      await sl<RiskService>().deleteRisk(projectId, risk.id);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
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
}

class ProjectAddRiskSheet extends StatefulWidget {
  const ProjectAddRiskSheet({super.key, required this.projectId});
  final String projectId;

  @override
  State<ProjectAddRiskSheet> createState() => ProjectAddRiskSheetState();
}

class ProjectAddRiskSheetState extends State<ProjectAddRiskSheet> {
  final _titleCtrl = TextEditingController();
  final _mitigationCtrl = TextEditingController();
  String _category = 'financial';
  int _probability = 2;
  int _impact = 2;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _mitigationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final score = _probability * _impact;
    final levelColor = switch (score) {
      >= 15 => Colors.red,
      >= 9 => Colors.deepOrange,
      >= 4 => Colors.amber,
      _ => Colors.green,
    };

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('New Risk', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: levelColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Score: $score',
                  style: TextStyle(
                    color: levelColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Risk title *',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
            items: riskCategories
                .map((c) => DropdownMenuItem(value: c.$1, child: Text(c.$2)))
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 12),
          Text('Probability: $_probability / 5'),
          Slider(
            value: _probability.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: '$_probability',
            onChanged: (v) => setState(() => _probability = v.round()),
          ),
          Text('Impact: $_impact / 5'),
          Slider(
            value: _impact.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: '$_impact',
            onChanged: (v) => setState(() => _impact = v.round()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _mitigationCtrl,
            decoration: const InputDecoration(
              labelText: 'Mitigation plan (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving
                  ? null
                  : () async {
                      final title = _titleCtrl.text.trim();
                      if (title.isEmpty) return;
                      setState(() => _saving = true);
                      await sl<RiskService>().addRisk(
                        widget.projectId,
                        RiskItem(
                          id: '',
                          projectId: widget.projectId,
                          title: title,
                          category: _category,
                          probability: _probability,
                          impact: _impact,
                          status: RiskStatus.open,
                          mitigationPlan: _mitigationCtrl.text.trim().isEmpty
                              ? null
                              : _mitigationCtrl.text.trim(),
                          createdAt: DateTime.now(),
                        ),
                      );
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                    },
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Log Risk'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Land Ownership Status Card (Overview tab)
// ─────────────────────────────────────────

