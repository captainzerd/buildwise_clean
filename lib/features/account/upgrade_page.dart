// lib/features/account/upgrade_page.dart
//
// Paywall / plans & pricing screen.
// Shown when a user tries to access a Pro or Business feature on the Free tier.
// Also reachable from Account → Plans & Pricing.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/models/app_user.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/paystack_service.dart';

class UpgradePage extends StatelessWidget {
  /// When [requiredTier] is provided, a banner is shown explaining why the
  /// user was redirected here (e.g. "Analytics requires Pro").
  const UpgradePage({super.key, this.requiredTier, this.featureName});

  final SubscriptionTier? requiredTier;
  final String? featureName;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final currentTier = auth.currentUser?.subscriptionTier ?? SubscriptionTier.free;
    final email = auth.currentUser?.email ?? '';
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Plans & Pricing')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Feature-locked banner ─────────────────────────────────────────
          if (featureName != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, color: cs.onPrimaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$featureName requires the ${requiredTier?.label ?? 'Pro'} plan.',
                      style: TextStyle(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          Text(
            'Choose your plan',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Upgrade anytime. Cancel anytime.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),

          // ── Free tier ─────────────────────────────────────────────────────
          _PlanCard(
            tier: SubscriptionTier.free,
            isCurrentPlan: currentTier == SubscriptionTier.free,
            features: const [
              '2 active projects',
              '1 cost estimate per month',
              'Basic project tracking',
              'Builder & vendor marketplace browsing',
            ],
            onSelect: null,
          ),
          const SizedBox(height: 16),

          // ── Pro tier ──────────────────────────────────────────────────────
          _PlanCard(
            tier: SubscriptionTier.pro,
            isCurrentPlan: currentTier == SubscriptionTier.pro,
            highlighted: true,
            features: const [
              'Unlimited projects',
              'Unlimited estimates',
              'Analytics dashboard',
              'PDF & CSV export',
              'Contract management',
              'Priority support',
            ],
            onSelect: currentTier == SubscriptionTier.pro
                ? null
                : () => _selectPlan(context, SubscriptionTier.pro, email),
          ),
          const SizedBox(height: 16),

          // ── Business tier ─────────────────────────────────────────────────
          _PlanCard(
            tier: SubscriptionTier.business,
            isCurrentPlan: currentTier == SubscriptionTier.business,
            features: const [
              'Everything in Pro',
              'Listed in builder/PM marketplace',
              'Verified documents badge',
              'Increased search visibility',
              'Team member invites (coming soon)',
            ],
            onSelect: currentTier == SubscriptionTier.business
                ? null
                : () => _selectPlan(context, SubscriptionTier.business, email),
          ),
          const SizedBox(height: 32),

          // ── FAQ note ──────────────────────────────────────────────────────
          Text(
            'Payments are processed securely by Paystack in GHS. '
            'You can cancel your subscription at any time from the Account page.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _selectPlan(
    BuildContext context,
    SubscriptionTier tier,
    String email,
  ) async {
    final paystack = PaystackService();
    final amountGhs = tier == SubscriptionTier.pro ? 150.0 : 300.0;
    final ref = const Uuid().v4();

    try {
      final result = await paystack.initTransaction(
        amountGhs: amountGhs,
        email: email,
        reference: ref,
        metadata: {'planTier': tier.name, 'uid': email},
      );

      if (!context.mounted) return;

      final success = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => _PaystackWebView(
            authorizationUrl: result.authorizationUrl,
            reference: result.reference,
          ),
        ),
      );

      if (!context.mounted) return;

      if (success == true) {
        // Call Cloud Function to verify and activate
        try {
          final fn = FirebaseFunctions.instance
              .httpsCallable('activateSubscription');
          await fn.call({
            'reference': result.reference,
            'tier': tier.name,
          });

          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully upgraded to ${tier.label}!'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
          context.pop();
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Subscription activation failed: $e')),
          );
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment initialisation failed: $e')),
      );
    }
  }
}

// ── Paystack WebView ──────────────────────────────────────────────────────────

class _PaystackWebView extends StatefulWidget {
  const _PaystackWebView({
    required this.authorizationUrl,
    required this.reference,
  });

  final String authorizationUrl;
  final String reference;

  @override
  State<_PaystackWebView> createState() => _PaystackWebViewState();
}

class _PaystackWebViewState extends State<_PaystackWebView> {
  late final WebViewController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (req) {
            // Paystack redirects to a callback URL on success
            final url = req.url.toLowerCase();
            if (url.contains('callback') ||
                url.contains('success') ||
                url.contains('buildwise://')) {
              Navigator.of(context).pop(true);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Payment'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: WebViewWidget(controller: _ctrl),
    );
  }
}

// ── Plan card ─────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.tier,
    required this.isCurrentPlan,
    required this.features,
    required this.onSelect,
    this.highlighted = false,
  });

  final SubscriptionTier tier;
  final bool isCurrentPlan;
  final bool highlighted;
  final List<String> features;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final borderColor = highlighted ? cs.primary : cs.outlineVariant;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: borderColor,
          width: highlighted ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
        color: highlighted ? cs.primaryContainer.withValues(alpha: 0.15) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tier.label,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tier.priceLabel,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
                if (highlighted)
                  Chip(
                    label: const Text('Popular'),
                    backgroundColor: cs.primary,
                    labelStyle: TextStyle(
                      color: cs.onPrimary,
                      fontSize: 11,
                    ),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(f, style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: isCurrentPlan
                  ? OutlinedButton(
                      onPressed: null,
                      child: const Text('Current plan'),
                    )
                  : tier == SubscriptionTier.free
                      ? const SizedBox.shrink()
                      : FilledButton(
                          onPressed: onSelect,
                          child: Text('Upgrade to ${tier.label}'),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Paywall gate widget ───────────────────────────────────────────────────────
//
// Wrap any widget that requires a subscription tier. If the user's tier is
// insufficient, shows a locked overlay with an upgrade CTA instead.
//
// Usage:
//   SubscriptionGate(
//     required: SubscriptionTier.pro,
//     featureName: 'Analytics',
//     child: AnalyticsPage(),
//   )

class SubscriptionGate extends StatelessWidget {
  const SubscriptionGate({
    super.key,
    required this.required,
    required this.featureName,
    required this.child,
  });

  final SubscriptionTier required;
  final String featureName;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final tier = auth.currentUser?.subscriptionTier ?? SubscriptionTier.free;

    final allowed = switch (required) {
      SubscriptionTier.free => true,
      SubscriptionTier.pro => tier != SubscriptionTier.free,
      SubscriptionTier.business => tier == SubscriptionTier.business,
    };

    if (allowed) return child;
    return _LockedScreen(requiredTier: required, featureName: featureName);
  }
}

class _LockedScreen extends StatelessWidget {
  const _LockedScreen({required this.requiredTier, required this.featureName});
  final SubscriptionTier requiredTier;
  final String featureName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 64, color: cs.primary),
            const SizedBox(height: 20),
            Text(
              '$featureName — ${requiredTier.label} Feature',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Upgrade to the ${requiredTier.label} plan to unlock $featureName '
              'and other powerful tools.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => context.push(
                '/account/upgrade',
                extra: {'tier': requiredTier.name, 'feature': featureName},
              ),
              icon: const Icon(Icons.rocket_launch_outlined),
              label: Text('Upgrade to ${requiredTier.label}'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
