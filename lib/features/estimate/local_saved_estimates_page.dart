// lib/features/estimate/local_saved_estimates_page.dart
import 'dart:convert'; // <-- needed for JsonEncoder
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/storage/storage_service.dart';
import '../../utils/csv_exporter.dart';

class LocalSavedEstimatesPage extends StatefulWidget {
  const LocalSavedEstimatesPage({super.key});

  @override
  State<LocalSavedEstimatesPage> createState() =>
      _LocalSavedEstimatesPageState();
}

class _LocalSavedEstimatesPageState extends State<LocalSavedEstimatesPage> {
  final storage = StorageService();
  late Future<List<_Item>> _items;

  @override
  void initState() {
    super.initState();
    _items = _load();
  }

  Future<List<_Item>> _load() async {
    final paths = await storage.listJsonPaths(subFolder: 'estimates');
    final out = <_Item>[];
    for (final path in paths) {
      try {
        final json = await storage.readJsonAtPath(path);
        out.add(_Item(path: path, data: json));
      } catch (_) {}
    }
    // newest first by filename (StorageService may already sort; keep stable)
    out.sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Estimates (Local)')),
      body: FutureBuilder(
        future: _items,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(child: Text('No saved estimates yet.'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final it = items[i];
              final name = (it.data['name'] as String?) ?? 'Untitled';
              final region = (it.data['region'] as String?) ?? '--';
              final created = (it.data['createdAt'] as String?) ??
                  (it.data['savedAt'] as String? ?? '');
              final outputs =
                  (it.data['outputs'] as Map?)?.cast<String, dynamic>() ??
                      const {};
              final totalGhs =
                  (outputs['totalGhs'] ?? outputs['grandTotalGhs']) as num?;
              final fx = (outputs['fx'] as Map?)?.cast<String, dynamic>();
              final fxCode = fx?['code'] as String?;
              final fxTotal = fx?['total'] as num?;

              return ListTile(
                title: Text('$name • $region'),
                subtitle: Text(created),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (totalGhs != null)
                      Text('GHS ${totalGhs.toStringAsFixed(0)}'),
                    if (fxCode != null && fxTotal != null)
                      Text('$fxCode ${fxTotal.toStringAsFixed(0)}'),
                  ],
                ),
                onTap: () => _openDetails(it),
              );
            },
          );
        },
      ),
    );
  }

  void _openDetails(_Item item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DetailSheet(
        item: item,
        onChanged: () => setState(() => _items = _load()),
      ),
    );
  }
}

class _Item {
  final String path;
  final Map<String, dynamic> data;
  _Item({required this.path, required this.data});
}

class _DetailSheet extends StatefulWidget {
  const _DetailSheet({required this.item, required this.onChanged});
  final _Item item;
  final VoidCallback onChanged;

  @override
  State<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<_DetailSheet> {
  @override
  Widget build(BuildContext context) {
    final s = widget.item.data;
    final name = (s['name'] as String?) ?? 'Untitled';
    final region = (s['region'] as String?) ?? '--';
    final created =
        (s['createdAt'] as String?) ?? (s['savedAt'] as String? ?? '');

    final outputs = (s['outputs'] as Map?)?.cast<String, dynamic>() ?? const {};
    final breakdownGhs = (outputs['breakdownGhs'] as Map? ?? {})
        .map<String, double>(
            (k, v) => MapEntry(k.toString(), (v as num).toDouble()),);
    final addonsGhs = (outputs['addonsGhs'] as Map? ?? {}).map<String, double>(
        (k, v) => MapEntry(k.toString(), (v as num).toDouble()),);
    final ohp = (outputs['ohpGhs'] as num?)?.toDouble() ?? 0.0;
    final contingency = (outputs['contingencyGhs'] as num?)?.toDouble() ?? 0.0;
    final taxes = (outputs['taxesGhs'] as num?)?.toDouble() ?? 0.0;
    final totalGhs = ((outputs['totalGhs'] ?? outputs['grandTotalGhs']) as num?)
            ?.toDouble() ??
        0.0;

    final fx = (outputs['fx'] as Map?)?.cast<String, dynamic>();
    final code = (fx?['code'] as String?) ?? 'GHS';
    final rate = (fx?['rate'] as num?)?.toDouble() ?? 1.0;
    double conv(double ghs) => ghs * rate;

    return DraggableScrollableSheet(
      expand: false,
      builder: (_, controller) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: controller,
            children: [
              Text(name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Region: $region • Created: $created'),
              const SizedBox(height: 8),
              Text('Total ($code): ${conv(totalGhs).toStringAsFixed(0)}'),
              const SizedBox(height: 16),
              Text('Breakdown', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...breakdownGhs.entries.map((e) => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key),
                      Text('GHS ${e.value.toStringAsFixed(0)}'),
                    ],
                  ),),
              if (addonsGhs.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Add-ons'),
                ...addonsGhs.entries.map((e) => Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key),
                        Text('GHS ${e.value.toStringAsFixed(0)}'),
                      ],
                    ),),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      final path = await CsvExporter.export(
                        projectName: name,
                        displayCode: code,
                        convert: conv,
                        breakdownGhs: breakdownGhs,
                        addonsGhs: addonsGhs,
                        ohpGhs: ohp,
                        contingencyGhs: contingency,
                        taxesGhs: taxes,
                        totalGhs: totalGhs,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('CSV saved: $path')),);
                      }
                    },
                    icon: const Icon(Icons.table_chart),
                    label: const Text('Export CSV'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SpendingSection(item: widget.item, onChanged: widget.onChanged),
            ],
          ),
        );
      },
    );
  }
}

class _SpendingSection extends StatefulWidget {
  const _SpendingSection({required this.item, required this.onChanged});
  final _Item item;
  final VoidCallback onChanged;

  @override
  State<_SpendingSection> createState() => _SpendingSectionState();
}

class _SpendingSectionState extends State<_SpendingSection> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _category = 'Materials';
  DateTime _date = DateTime.now();

  Map<String, dynamic> get _data => widget.item.data;

  List<Map<String, dynamic>> get _tx {
    final t = (_data['transactions'] as List?)?.cast<Map>() ?? const [];
    return t.map((e) => e.cast<String, dynamic>()).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tx = _tx;
    final spent = tx.fold<double>(
        0, (a, t) => a + ((t['amount'] as num?)?.toDouble() ?? 0),);
    final outputs =
        (_data['outputs'] as Map?)?.cast<String, dynamic>() ?? const {};
    final est = ((outputs['totalGhs'] ?? outputs['grandTotalGhs']) as num?)
            ?.toDouble() ??
        0.0;
    final variance = spent - est;
    final variancePct = est == 0 ? 0.0 : (variance / est) * 100.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        Text('Spending', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
            'Spent to date: GHS ${spent.toStringAsFixed(0)} • Variance: GHS ${variance.toStringAsFixed(0)} (${variancePct.toStringAsFixed(1)}%)',),
        const SizedBox(height: 8),
        for (final t in tx)
          ListTile(
            dense: true,
            title: Text(
                '${t['category']} • GHS ${(t['amount'] as num?)?.toDouble().toStringAsFixed(0)}',),
            subtitle: Text('${t['date']} — ${t['note'] ?? ''}'),
            trailing: IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteTx(t),
            ),
            onTap: () => _editTx(t),
          ),
        const SizedBox(height: 12),
        ExpansionTile(
          title: const Text('Add transaction'),
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _category,
                            items: const [
                              'Materials',
                              'Labour',
                              'Services',
                              'Other',
                            ]
                                .map((e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),)
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _category = v ?? 'Materials'),
                            decoration:
                                const InputDecoration(labelText: 'Category'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _amount,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Amount (GHS)',),
                            validator: (v) {
                              final n = double.tryParse(v ?? '');
                              if (n == null || n <= 0) return 'Enter amount';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _note,
                      decoration: const InputDecoration(labelText: 'Note'),
                    ),
                    Row(
                      children: [
                        Text(
                            'Date: ${_date.toIso8601String().substring(0, 10)}',),
                        const Spacer(),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) setState(() => _date = picked);
                          },
                          child: const Text('Change'),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: _addTx,
                        child: const Text('Add'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _addTx() async {
    if (!_formKey.currentState!.validate()) return;
    final list = _tx;
    list.add({
      'txId': DateTime.now().millisecondsSinceEpoch.toString(),
      'date': _date.toIso8601String().substring(0, 10),
      'amount': double.parse(_amount.text),
      'category': _category,
      'note': _note.text,
    });
    _data['transactions'] = list;
    await File(widget.item.path).writeAsString(
      const JsonEncoder.withIndent('  ').convert(_data),
      flush: true,
    );
    widget.onChanged();
  }

  Future<void> _deleteTx(Map<String, dynamic> t) async {
    final list = _tx..removeWhere((x) => x['txId'] == t['txId']);
    _data['transactions'] = list;
    await File(widget.item.path).writeAsString(
      const JsonEncoder.withIndent('  ').convert(_data),
      flush: true,
    );
    widget.onChanged();
  }

  Future<void> _editTx(Map<String, dynamic> t) async {
    _amount.text = ((t['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0);
    _note.text = (t['note'] as String?) ?? '';
    _category = (t['category'] as String?) ?? 'Materials';
    final d = (t['date'] as String?) ??
        DateTime.now().toIso8601String().substring(0, 10);
    _date = DateTime.tryParse('${d}T12:00:00') ??
        DateTime.now(); // <-- fixed interpolation
    await _deleteTx(t);
  }
}
