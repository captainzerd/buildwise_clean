// lib/features/estimate/estimate_page.dart
//
// 5-step guided estimate wizard.
//   Step 1 — Project   : name · region · currency
//   Step 2 — Building  : type · quality · foundation · soil · roof
//   Step 3 — Floors    : dynamic floor list
//   Step 4 — Extras    : external works · commercials · permits · budget
//   Step 5 — Review    : summary + "Compute Estimate" button
//
// On successful compute → pushes EstimateResultPage.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/catalog_service.dart';
import '../../core/services/fx_service.dart';
import '../../core/widgets/app_page_route.dart';
import 'estimate_result_page.dart';
import 'saved_estimates_page.dart';
import 'state/estimate_controller.dart';
import 'widgets/step_scaffold.dart';
import 'widgets/step1_project.dart';
import 'widgets/step2_building.dart';
import 'widgets/step3_floors.dart';
import 'widgets/step4_extras.dart';
import 'widgets/step5_review.dart';

class EstimatePage extends StatefulWidget {
  const EstimatePage({super.key});

  @override
  State<EstimatePage> createState() => _EstimatePageState();
}

class _EstimatePageState extends State<EstimatePage> {
  final _pageCtrl = PageController();
  int _step = 0;
  static const _totalSteps = 5;

  bool _isDirty(EstimateController controller) =>
      _step > 0 ||
      controller.projectNameCtrl.text.isNotEmpty ||
      controller.region != null;

  static String _hoursAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  void _next() {
    if (_step < _totalSteps - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _back() {
    if (_step > 0) {
      _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EstimateController>();
    final catalog = context.watch<CatalogService>();
    final fx = context.watch<FxService>();
    final auth = context.read<AuthService>();

    const stepTitles = ['Project', 'Building', 'Floors', 'Extras', 'Review'];

    return PopScope(
      canPop: !_isDirty(controller),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        final discard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Discard changes?'),
            content: const Text('Your estimate progress will be lost.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Keep editing'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Discard'),
              ),
            ],
          ),
        );
        if (discard == true && mounted) {
          nav.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(stepTitles[_step]),
          actions: [
            IconButton(
              tooltip: 'Saved estimates',
              icon: const Icon(Icons.history),
              onPressed: auth.isSignedIn
                  ? () => Navigator.of(context).push(
                        AppPageRoute<void>(
                          builder: (_) => const SavedEstimatesPage(),
                        ),
                      )
                  : () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sign in to view saved estimates'),
                        ),
                      ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Step ${_step + 1} of $_totalSteps',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                LinearProgressIndicator(
                  value: (_step + 1) / _totalSteps,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ],
            ),
          ),
        ),
        body: Column(
          children: [
            if (catalog.isUsingFallback)
              InfoBanner(
                icon: Icons.info_outline,
                message: 'Using built-in rates — live catalog unavailable.',
                color: Theme.of(context).colorScheme.tertiaryContainer,
                textColor: Theme.of(context).colorScheme.onTertiaryContainer,
              ),
            if (fx.error != null)
              InfoBanner(
                icon: Icons.currency_exchange,
                message: fx.lastUpdated != null
                    ? 'Exchange rates last updated ${_hoursAgo(fx.lastUpdated!)} — showing cached rates.'
                    : 'Live exchange rates unavailable — showing default rates.',
                color: Theme.of(context).colorScheme.secondaryContainer,
                textColor: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _step = i),
                children: [
                  Step1Project(onNext: _next),
                  Step2Building(onNext: _next, onBack: _back),
                  Step3Floors(onNext: _next, onBack: _back),
                  Step4Extras(onNext: _next, onBack: _back),
                  Step5Review(
                    onBack: _back,
                    onCompute: () => _compute(context, controller, catalog),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _compute(
    BuildContext context,
    EstimateController controller,
    CatalogService catalog,
  ) async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await catalog.ensureLoaded();
    await controller.compute();
    if (!mounted) return;
    if (controller.hasResult) {
      nav.push(
        MaterialPageRoute<void>(builder: (_) => const EstimateResultPage()),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(controller.computeError ?? 'Please complete the form'),
        ),
      );
    }
  }
}
