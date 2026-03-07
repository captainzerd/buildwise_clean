import '../../core/config/service_locator.dart';
import '../../core/data/ghana_labour_rates.dart';
// lib/features/project/labor_tracking_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/labor_record.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/boq_service.dart';
import '../../core/services/csv_service.dart';
import '../../core/services/labor_service.dart';

class LaborTrackingPage extends StatefulWidget {
  const LaborTrackingPage({
    super.key,
    required this.projectId,
    required this.projectTitle,
    required this.isOwner,
  });

  final String projectId;
  final String projectTitle;
  final bool isOwner;

  @override
  State<LaborTrackingPage> createState() => _LaborTrackingPageState();
}

class _LaborTrackingPageState extends State<LaborTrackingPage> {
  List<LaborRecord> _records = [];
  bool _exporting = false;

  Future<void> _exportPayroll() async {
    if (_records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No records to export.')),
      );
      return;
    }
    setState(() => _exporting = true);
    try {
      final boqRates = sl<BoqService>().rates;
      final file = await sl<CsvService>().exportPayroll(
        _records,
        employerSsnitRate: boqRates.ssnitEmployerRate,
        employeeSsnitRate: boqRates.ssnitEmployeeRate,
        label: 'payroll_${widget.projectTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}',
      );
      await Share.shareXFiles([XFile(file.path)], subject: 'Payroll — ${widget.projectTitle}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  double _computeWeeklyTotal(List<LaborRecord> records) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDay =
        DateTime(weekStart.year, weekStart.month, weekStart.day);
    return records
        .where((r) => !r.date.isBefore(weekStartDay))
        .fold<double>(0, (s, r) => s + r.totalGhs);
  }

  void _showRateReference(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => const _RateReferenceSheet(),
    );
  }

  void _showAddSheet(LaborService laborService) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddLaborSheet(
        projectId: widget.projectId,
        laborService: laborService,
        auth: context.read<AuthService>(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final laborService = sl<LaborService>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Labour — ${widget.projectTitle}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Rate reference',
            onPressed: () => _showRateReference(context),
          ),
          if (_exporting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              tooltip: 'Export payroll CSV',
              icon: const Icon(Icons.download_outlined),
              onPressed: _exportPayroll,
            ),
        ],
      ),
      body: StreamBuilder<List<LaborRecord>>(
        stream: laborService.recordsStream(widget.projectId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = snap.data ?? [];
          _records = records;

          // Weekly totals
          final weeklyTotal = _computeWeeklyTotal(records);
          final overallTotal =
              records.fold<double>(0, (s, r) => s + r.totalGhs);

          return Column(
            children: [
              _SummaryCard(
                weeklyTotal: weeklyTotal,
                overallTotal: overallTotal,
                workerCount: records.isNotEmpty
                    ? records.first.headcount
                    : 0,
              ),
              Expanded(
                child: records.isEmpty
                    ? const Center(
                        child: Text(
                          'No labour records yet.\nAdd daily attendance to track costs.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(0, 0, 0, 96),
                        itemCount: records.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 0, indent: 16),
                        itemBuilder: (_, i) => _LaborTile(
                          record: records[i],
                          projectId: widget.projectId,
                          isOwner: widget.isOwner,
                          laborService: laborService,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(laborService),
        icon: const Icon(Icons.add),
        label: const Text('Log labour'),
      ),
    );
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.weeklyTotal,
    required this.overallTotal,
    required this.workerCount,
  });

  final double weeklyTotal;
  final double overallTotal;
  final int workerCount;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _SummaryItem(
                label: 'This week',
                value: '₵ ${fmt.format(weeklyTotal)}',
                cs: cs,
              ),
            ),
            Container(width: 1, height: 40, color: cs.outlineVariant),
            Expanded(
              child: _SummaryItem(
                label: 'Total labour',
                value: '₵ ${fmt.format(overallTotal)}',
                cs: cs,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.cs,
  });
  final String label;
  final String value;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style:
              Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.outline),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
    );
  }
}

// ── Labor record tile ─────────────────────────────────────────────────────────

class _LaborTile extends StatelessWidget {
  const _LaborTile({
    required this.record,
    required this.projectId,
    required this.isOwner,
    required this.laborService,
  });

  final LaborRecord record;
  final String projectId;
  final bool isOwner;
  final LaborService laborService;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');

    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        child: Text(
          '${record.headcount}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(
        '${record.tradeType.label} · ₵ ${fmt.format(record.totalGhs)}',
      ),
      subtitle: Text(
        '${DateFormat('d MMM yyyy').format(record.date)} · '
        '${record.headcount} × ₵ ${fmt.format(record.dailyRateGhs)}/day'
        '${record.notes != null ? ' · ${record.notes}' : ''}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: isOwner
          ? IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline, size: 20),
              color: Theme.of(context).colorScheme.error,
              onPressed: () =>
                  laborService.deleteRecord(projectId, record.id),
            )
          : null,
    );
  }
}

// ── Rate reference sheet ───────────────────────────────────────────────────────

class _RateReferenceSheet extends StatelessWidget {
  const _RateReferenceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Ghana Labour Rate Reference (2024)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'Standard daily rates (GH₵) — GhBC / MESW guidelines',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Trade')),
                DataColumn(label: Text('Daily Rate (GH₵)'), numeric: true),
              ],
              rows: GhanaLabourRates.dailyRates.entries
                  .map(
                    (e) => DataRow(cells: [
                      DataCell(Text(e.key)),
                      DataCell(Text(e.value.toStringAsFixed(0))),
                    ],),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Add labour sheet ──────────────────────────────────────────────────────────

class _AddLaborSheet extends StatefulWidget {
  const _AddLaborSheet({
    required this.projectId,
    required this.laborService,
    required this.auth,
  });

  final String projectId;
  final LaborService laborService;
  final AuthService auth;

  @override
  State<_AddLaborSheet> createState() => _AddLaborSheetState();
}

class _AddLaborSheetState extends State<_AddLaborSheet> {
  final _formKey = GlobalKey<FormState>();
  final _headcountCtrl = TextEditingController(text: '1');
  final _rateCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  TradeType _tradeType = TradeType.mason;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _headcountCtrl.dispose();
    _rateCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final headcount = int.tryParse(_headcountCtrl.text.trim()) ?? 1;
      final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0;
      final total = headcount * rate;
      final user = widget.auth.currentUser;
      final record = LaborRecord(
        id: '',
        date: _date,
        tradeType: _tradeType,
        headcount: headcount,
        dailyRateGhs: rate,
        totalGhs: total,
        recordedByUid: user?.uid ?? '',
        recordedByName: user?.displayName ?? '',
        createdAt: DateTime.now(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      await widget.laborService.addRecord(widget.projectId, record);
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
    final headcount = int.tryParse(_headcountCtrl.text) ?? 1;
    final rate = double.tryParse(_rateCtrl.text) ?? 0.0;
    final total = headcount * rate;
    final fmt = NumberFormat('#,##0.00');

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
              'Log Labour',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            // Date
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _date = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                ),
                child: Text(DateFormat('d MMM yyyy').format(_date)),
              ),
            ),
            const SizedBox(height: 12),
            // Trade type
            DropdownButtonFormField<TradeType>(
              initialValue: _tradeType,
              decoration: const InputDecoration(
                labelText: 'Trade',
                border: OutlineInputBorder(),
              ),
              items: TradeType.values
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.label),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _tradeType = v!),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _headcountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Workers *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (int.tryParse(v) == null) return 'Enter a number';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _rateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Rate/day (GHS) *',
                      prefixText: '₵ ',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Invalid';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            if (total > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Total: ₵ ${fmt.format(total)}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                textAlign: TextAlign.end,
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
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
                  : const Text('Log labour'),
            ),
          ],
        ),
      ),
    );
  }
}
