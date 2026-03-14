// lib/features/estimate/widgets/step1_project.dart
//
// Step 1 of the estimate wizard: project name, region, currency.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/fx_service.dart';
import '../../../core/services/regional_index_provider.dart';
import '../../../core/widgets/tip_banner.dart';
import '../state/estimate_controller.dart';
import 'step_scaffold.dart';

// ── Step 1 ────────────────────────────────────────────────────────────────────

class Step1Project extends StatelessWidget {
  const Step1Project({super.key, required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EstimateController>();
    final regional = context.watch<RegionalIndexProvider>();
    final fx = context.watch<FxService>();

    return StepScaffold(
      onNext: onNext,
      onBack: null,
      nextLabel: 'Next: Building',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionLabel(context, 'Tell us about your project'),
          const TipBanner(
            tipKey: 'tip_estimate_region',
            message: 'Select your region for more accurate local material and '
                'labour rates.',
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: controller.projectNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Project name (optional)',
              prefixIcon: Icon(Icons.folder_outlined),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Region',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            initialValue: controller.region ??
                (regional.regionCodes.isNotEmpty
                    ? regional.regionCodes.first
                    : 'DEFAULT'),
            items: (regional.regionCodes.isNotEmpty
                    ? regional.regionCodes
                    : const ['DEFAULT'])
                .map(
                  (c) => DropdownMenuItem<String>(
                    value: c,
                    child: Text(c),
                  ),
                )
                .toList(),
            onChanged: controller.setRegion,
          ),
          const SizedBox(height: 16),
          EstimateCurrencyPicker(
            current: controller.currency,
            onChanged: controller.setCurrency,
            fxService: fx,
          ),
        ],
      ),
    );
  }
}

// ── Currency picker ────────────────────────────────────────────────────────────

class EstimateCurrencyPicker extends StatelessWidget {
  const EstimateCurrencyPicker({
    super.key,
    required this.current,
    required this.onChanged,
    required this.fxService,
  });

  final CurrencyInfo current;
  final ValueChanged<CurrencyInfo> onChanged;
  final FxService fxService;

  String _rateLabel(CurrencyInfo c) {
    if (c.code == 'GHS') return 'Base currency';
    final rate = fxService.rateFor(c.code);
    if (rate <= 0) return c.name;
    return '1 GHS = ${c.symbol}${rate.toStringAsFixed(4)}';
  }

  String _subtitleText() {
    final updated = fxService.lastUpdated;
    final suffix =
        updated != null ? 'rates ${_timeAgo(updated)}' : 'estimated rates';
    return '${current.code}  •  $suffix';
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return 'updated ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'updated ${diff.inHours}h ago';
    return 'updated ${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Currency'),
      subtitle: Text(_subtitleText()),
      trailing: const Icon(Icons.expand_more),
      onTap: () async {
        final picked = await showModalBottomSheet<CurrencyInfo>(
          context: context,
          showDragHandle: true,
          builder: (ctx) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    'Select currency',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ),
                for (final c in CurrencyInfo.values)
                  ListTile(
                    leading: SizedBox(
                      width: 32,
                      child: Text(
                        c.symbol,
                        style: const TextStyle(fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    title: Text('${c.code}  —  ${c.name}'),
                    subtitle: Text(_rateLabel(c)),
                    trailing: c == current
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(ctx).colorScheme.primary,
                          )
                        : null,
                    onTap: () => Navigator.of(ctx).pop(c),
                  ),
                SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
              ],
            ),
          ),
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}
