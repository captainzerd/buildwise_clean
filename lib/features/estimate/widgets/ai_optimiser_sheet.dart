// lib/features/estimate/widgets/ai_optimiser_sheet.dart
//
// Bottom sheet that calls the `analyseEstimateCosts` Cloud Function and
// displays AI-generated cost-optimisation suggestions powered by Claude.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AiOptimiserSheet extends StatefulWidget {
  const AiOptimiserSheet({
    super.key,
    required this.typology,
    required this.quality,
    required this.region,
    required this.floorAreaM2,
    required this.floors,
    required this.totalGhs,
    required this.breakdownGhs,
    required this.preliminariesPct,
    required this.ohpPct,
    required this.contingencyPct,
  });

  final String typology;
  final String quality;
  final String region;
  final double floorAreaM2;
  final int floors;
  final double totalGhs;
  final Map<String, double> breakdownGhs;
  final double preliminariesPct;
  final double ohpPct;
  final double contingencyPct;

  @override
  State<AiOptimiserSheet> createState() => _AiOptimiserSheetState();
}

class _AiOptimiserSheetState extends State<AiOptimiserSheet> {
  bool _loading = false;
  String? _headline;
  List<_Suggestion> _suggestions = [];
  String? _error;

  final _nf = NumberFormat('#,##0.00');

  Future<void> _analyse() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _headline = null;
      _suggestions = [];
    });
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'analyseEstimateCosts',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );
      final result = await callable.call(<String, dynamic>{
        'typology': widget.typology,
        'quality': widget.quality,
        'region': widget.region,
        'floorAreaM2': widget.floorAreaM2,
        'floors': widget.floors,
        'totalGhs': widget.totalGhs,
        'breakdownGhs': widget.breakdownGhs,
        'preliminariesPct': widget.preliminariesPct,
        'ohpPct': widget.ohpPct,
        'contingencyPct': widget.contingencyPct,
      });
      final data = result.data as Map<String, dynamic>;
      final rawSuggestions = (data['suggestions'] as List<dynamic>? ?? []);
      setState(() {
        _headline = data['headline'] as String? ?? '';
        _suggestions = rawSuggestions
            .map((e) => _Suggestion.fromMap(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _error = e.message ?? 'Analysis failed. Please try again.';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Unexpected error. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: cs.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'AI Cost Optimiser',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'GHS ${_nf.format(widget.totalGhs)} · ${widget.typology} · ${widget.region}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.outline),
                  ),
                  const SizedBox(height: 20),

                  if (_suggestions.isEmpty && !_loading && _error == null) ...[
                    Text(
                      'Tap "Analyse" to get AI-powered suggestions for reducing your construction costs based on Ghana market conditions.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Powered by Claude AI. Suggestions are indicative — consult a QS for detailed advice.',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: cs.outline),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _analyse,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Analyse Costs'),
                      ),
                    ),
                  ],

                  if (_loading) ...[
                    const SizedBox(height: 32),
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        'Analysing your estimate\u2026',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: cs.outline),
                      ),
                    ),
                  ],

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(color: cs.onErrorContainer),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _analyse,
                      child: const Text('Retry'),
                    ),
                  ],

                  if (_suggestions.isNotEmpty) ...[
                    if (_headline != null && _headline!.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _headline!,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(color: cs.onPrimaryContainer),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    for (final s in _suggestions) ...[
                      _SuggestionCard(suggestion: s),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Suggestions are indicative only. Engage a Quantity Surveyor for a detailed cost plan.',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: cs.outline),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _analyse,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Re-analyse'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.suggestion});
  final _Suggestion suggestion;

  Color _categoryColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return switch (suggestion.category) {
      'Materials' => Colors.orange,
      'Specification' => cs.primary,
      'Design' => Colors.purple,
      'Programme' => Colors.teal,
      'Procurement' => Colors.green,
      _ => cs.secondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final catColor = _categoryColor(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    suggestion.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (suggestion.potentialSavingPct > 0)
                  Chip(
                    label: Text(
                      '~${suggestion.potentialSavingPct.toStringAsFixed(0)}% saving',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold,),
                    ),
                    backgroundColor: Colors.green.withValues(alpha: 0.15),
                    side: BorderSide.none,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Chip(
              label: Text(
                suggestion.category,
                style: TextStyle(
                    color: catColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,),
              ),
              side: BorderSide(color: catColor.withValues(alpha: 0.4)),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(height: 8),
            Text(
              suggestion.description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Suggestion {
  const _Suggestion({
    required this.title,
    required this.description,
    required this.potentialSavingPct,
    required this.category,
  });

  final String title;
  final String description;
  final double potentialSavingPct;
  final String category;

  factory _Suggestion.fromMap(Map<String, dynamic> m) => _Suggestion(
        title: m['title'] as String? ?? '',
        description: m['description'] as String? ?? '',
        potentialSavingPct:
            (m['potentialSavingPct'] as num?)?.toDouble() ?? 0.0,
        category: m['category'] as String? ?? 'General',
      );
}
