// lib/features/account/upgrade_page.dart
//
// Paywall / plans & pricing screen.
// Shown when a user tries to access a Pro or Business feature on the Free tier.
// Also reachable from Account → Plans & Pricing.
//
// Pricing: authoritative base in GHS, shown in user's local currency via FxService.
// Payment flows:
//   • Mobile Money (Ghana) — Paystack WebView → activateSubscription CF (always GHS)
//   • Card / Apple Pay / Google Pay — Stripe PaymentSheet → activateStripeSubscription CF

import 'dart:ui' as ui;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/config/service_locator.dart';
import '../../core/models/app_user.dart';
import '../../core/models/currency.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/fx_service.dart';
import '../../core/services/paystack_service.dart';
import '../../core/services/stripe_service.dart';

class UpgradePage extends StatefulWidget {
  /// When [requiredTier] is provided, a banner is shown explaining why the
  /// user was redirected here (e.g. "Analytics requires Pro").
  const UpgradePage({super.key, this.requiredTier, this.featureName});

  final SubscriptionTier? requiredTier;
  final String? featureName;

  @override
  State<UpgradePage> createState() => _UpgradePageState();
}

class _UpgradePageState extends State<UpgradePage> {
  late CurrencyInfo _currency;

  @override
  void initState() {
    super.initState();
    _currency = _detectLocaleCurrency();
  }

  // ── Locale → currency ──────────────────────────────────────────────────────

  static CurrencyInfo _detectLocaleCurrency() {
    final locale = ui.PlatformDispatcher.instance.locale;
    final country = locale.countryCode?.toUpperCase() ?? '';
    return switch (country) {
      'GH' => CurrencyInfo.ghs,
      'GB' => CurrencyInfo.gbp,
      'CA' => CurrencyInfo.cad,
      'AU' => CurrencyInfo.aud,
      'NG' => CurrencyInfo.ngn,
      'DE' ||
      'FR' ||
      'ES' ||
      'IT' ||
      'NL' ||
      'BE' ||
      'PT' ||
      'AT' ||
      'FI' ||
      'IE' ||
      'GR' ||
      'LU' ||
      'SI' ||
      'SK' ||
      'EE' ||
      'LV' ||
      'LT' =>
        CurrencyInfo.eur,
      _ => CurrencyInfo.usd,
    };
  }

  // ── Price helpers ──────────────────────────────────────────────────────────

  double _convertedAmount(SubscriptionTier tier, FxService fx) {
    final ghs = tier.amountPesewas / 100.0;
    if (_currency.code == 'GHS') return ghs;
    final converted = fx.convertFromGhs(amountGhs: ghs, to: _currency.code);
    return converted > 0 ? converted : tier.amountUsdCents / 100.0;
  }

  String _priceDisplay(SubscriptionTier tier, FxService fx) {
    if (tier == SubscriptionTier.free) return 'Free forever';
    final amount = _convertedAmount(tier, fx);
    final suffix = tier == SubscriptionTier.projectPass ? ' one-time' : ' / mo';
    return '${_currency.symbol}${_fmt(amount)}$suffix';
  }

  // Show the GHS base price as context for non-GHS users
  String? _ghsNote(SubscriptionTier tier) {
    if (_currency.code == 'GHS') return null;
    final ghs = tier.amountPesewas / 100;
    final suffix = tier == SubscriptionTier.projectPass ? ' one-time' : '/mo';
    return 'GH₵$ghs $suffix for Ghana residents';
  }

  static String _fmt(double amount) {
    if (amount >= 1000) return NumberFormat('#,##0').format(amount.round());
    return amount.round().toString();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final fx = context.watch<FxService>();
    final currentTier = auth.currentUser?.subscriptionTier ?? SubscriptionTier.free;
    final email = auth.currentUser?.email ?? '';
    final uid = auth.currentUser?.uid ?? '';
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Plans & Pricing')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Feature-locked banner ──────────────────────────────────────────
          if (widget.featureName != null) ...[
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
                      '${widget.featureName} requires the '
                      '${widget.requiredTier?.label ?? 'Pro'} plan.',
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
          const SizedBox(height: 4),
          Text(
            'Upgrade anytime. Cancel anytime.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),

          // ── Currency picker ────────────────────────────────────────────────
          _CurrencyPicker(
            selected: _currency,
            onChanged: (c) => setState(() => _currency = c),
          ),
          const SizedBox(height: 20),

          // ── Free tier ─────────────────────────────────────────────────────
          _PlanCard(
            tier: SubscriptionTier.free,
            isCurrentPlan: currentTier == SubscriptionTier.free,
            priceDisplay: 'Free forever',
            features: const [
              'Unlimited cost estimates',
              '1 active project',
              'Up to 5 cost entries per project',
              'Builder & vendor marketplace browsing',
            ],
            onSelect: null,
          ),
          const SizedBox(height: 16),

          // ── Project Pass (Builder Pass) ────────────────────────────────────
          _PlanCard(
            tier: SubscriptionTier.projectPass,
            isCurrentPlan: currentTier == SubscriptionTier.projectPass,
            priceDisplay: _priceDisplay(SubscriptionTier.projectPass, fx),
            ghsNote: _ghsNote(SubscriptionTier.projectPass),
            gbpNote: '~£17 one-time',
            badge: 'Best for self-builders',
            features: const [
              '1 project — full access for 24 months',
              'Unlimited cost entries & photos',
              'PDF & CSV reports',
              'Contract management',
              'One-time payment — no subscription',
            ],
            onSelect: currentTier == SubscriptionTier.projectPass
                ? null
                : () => _selectPlan(
                    context, SubscriptionTier.projectPass, email, uid, fx,
                  ),
          ),
          const SizedBox(height: 16),

          // ── Pro tier ──────────────────────────────────────────────────────
          _PlanCard(
            tier: SubscriptionTier.pro,
            isCurrentPlan: currentTier == SubscriptionTier.pro,
            highlighted: true,
            priceDisplay: _priceDisplay(SubscriptionTier.pro, fx),
            ghsNote: _ghsNote(SubscriptionTier.pro),
            gbpNote: '~£5.99/month',
            features: const [
              'Unlimited projects',
              'Analytics dashboard',
              'PDF & CSV export',
              'Contract management',
              'Priority support',
            ],
            onSelect: currentTier == SubscriptionTier.pro
                ? null
                : () => _selectPlan(context, SubscriptionTier.pro, email, uid, fx),
          ),
          const SizedBox(height: 16),

          // ── Business tier ─────────────────────────────────────────────────
          _PlanCard(
            tier: SubscriptionTier.business,
            isCurrentPlan: currentTier == SubscriptionTier.business,
            priceDisplay: _priceDisplay(SubscriptionTier.business, fx),
            ghsNote: _ghsNote(SubscriptionTier.business),
            gbpNote: '~£15/month',
            features: const [
              'Everything in Pro',
              'Listed in builder/PM marketplace',
              'Verified documents badge',
              'Increased search visibility',
              'Team member invites (coming soon)',
            ],
            onSelect: currentTier == SubscriptionTier.business
                ? null
                : () => _selectPlan(
                    context, SubscriptionTier.business, email, uid, fx,
                  ),
          ),
          const SizedBox(height: 16),

          // ── Builder SKU tier (supply-side) ────────────────────────────────
          _PlanCard(
            tier: SubscriptionTier.builderSku,
            isCurrentPlan: currentTier == SubscriptionTier.builderSku,
            priceDisplay: _priceDisplay(SubscriptionTier.builderSku, fx),
            ghsNote: _ghsNote(SubscriptionTier.builderSku),
            gbpNote: '~£1.80/month',
            badge: 'For professionals',
            features: const [
              'Marketplace visibility',
              'Verified badge display',
              'Access client projects',
            ],
            ctaLabel: 'Get Builder Pass',
            onSelect: currentTier == SubscriptionTier.builderSku
                ? null
                : () => _selectPlan(
                    context, SubscriptionTier.builderSku, email, uid, fx,
                  ),
          ),
          const SizedBox(height: 28),

          // ── Rate freshness note ────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (fx.isLoading)
                const SizedBox(
                  height: 10,
                  width: 10,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                )
              else
                Icon(Icons.refresh, size: 12, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  fx.lastUpdated != null
                      ? 'Rates updated ${_rateAge(fx.lastUpdated!)} · '
                          'Pay by mobile money (Ghana) or card worldwide'
                      : 'Pay by mobile money (Ghana) or card worldwide',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  static String _rateAge(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 2) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  // ── Payment flows ──────────────────────────────────────────────────────────

  Future<void> _selectPlan(
    BuildContext context,
    SubscriptionTier tier,
    String email,
    String uid,
    FxService fx,
  ) async {
    final localAmount = _convertedAmount(tier, fx);
    final ghsAmount = tier.amountPesewas / 100.0;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _PaymentMethodSheet(
        tier: tier,
        currency: _currency,
        localAmount: localAmount,
        ghsAmount: ghsAmount,
        onPaystack: () => _paystackFlow(context, tier, email),
        onStripe: () => _stripeFlow(context, tier, email, uid, localAmount),
      ),
    );
  }

  Future<void> _paystackFlow(
    BuildContext context,
    SubscriptionTier tier,
    String email,
  ) async {
    final paystack = PaystackService();
    final ref = const Uuid().v4();

    try {
      final result = await paystack.initTransaction(
        amountGhs: tier.amountPesewas / 100,
        email: email,
        reference: ref,
        metadata: {'planTier': tier.name},
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
      if (success != true) return;

      try {
        await FirebaseFunctions.instance
            .httpsCallable('activateSubscription')
            .call({'reference': result.reference, 'tier': tier.name});
        if (!context.mounted) return;
        _showSuccess(context, tier);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Activation failed: $e')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment initialisation failed: $e')),
      );
    }
  }

  Future<void> _stripeFlow(
    BuildContext context,
    SubscriptionTier tier,
    String email,
    String uid,
    double localAmount,
  ) async {
    final stripe = sl<StripeService>();
    final currency = _currency.code.toLowerCase();
    final minorUnits = (localAmount * 100).round();

    try {
      final paymentIntentId = await stripe.presentPaymentSheet(
        email: email,
        amountMinorUnits: minorUnits,
        currency: currency,
        tier: tier.name,
        uid: uid,
      );

      if (!context.mounted) return;

      try {
        await FirebaseFunctions.instance
            .httpsCallable('activateStripeSubscription')
            .call({'paymentIntentId': paymentIntentId, 'tier': tier.name});
        if (!context.mounted) return;
        _showSuccess(context, tier);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Activation failed: $e')),
        );
      }
    } on StripeException catch (e) {
      // User cancelled — no error shown
      if (e.error.code == FailureCode.Canceled) return;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: ${e.error.localizedMessage}'), duration: const Duration(seconds: 10)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment error: $e'), duration: const Duration(seconds: 10)),
      );
    }
  }

  void _showSuccess(BuildContext context, SubscriptionTier tier) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Successfully upgraded to ${tier.label}!'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
    context.pop();
  }
}

// ── Currency picker ───────────────────────────────────────────────────────────

class _CurrencyPicker extends StatelessWidget {
  const _CurrencyPicker({required this.selected, required this.onChanged});

  final CurrencyInfo selected;
  final ValueChanged<CurrencyInfo> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Show prices in:',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: CurrencyInfo.values.map((c) {
              final isSelected = c == selected;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('${c.symbol} ${c.code}'),
                  selected: isSelected,
                  onSelected: (_) => onChanged(c),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ── Payment method picker ─────────────────────────────────────────────────────

class _PaymentMethodSheet extends StatelessWidget {
  const _PaymentMethodSheet({
    required this.tier,
    required this.currency,
    required this.localAmount,
    required this.ghsAmount,
    required this.onPaystack,
    required this.onStripe,
  });

  final SubscriptionTier tier;
  final CurrencyInfo currency;
  final double localAmount;
  final double ghsAmount;
  final VoidCallback onPaystack;
  final VoidCallback onStripe;

  static String _fmt(double amount) {
    if (amount >= 1000) return NumberFormat('#,##0').format(amount.round());
    return amount.round().toString();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final suffix = tier == SubscriptionTier.projectPass ? '' : ' / mo';
    final localDisplay = '${currency.symbol}${_fmt(localAmount)}$suffix';
    final ghsDisplay = 'GH₵${_fmt(ghsAmount)}$suffix';
    final isGhs = currency.code == 'GHS';
    final isOneTime = tier == SubscriptionTier.projectPass;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose payment method',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              isOneTime
                  ? 'Project Pass · $localDisplay (one-time)'
                  : 'Upgrading to ${tier.label} · $localDisplay',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),
            _MethodTile(
              icon: Icons.phone_android_outlined,
              title: 'Mobile Money (Ghana)',
              subtitle: 'MTN · Vodafone · AirtelTigo · $ghsDisplay',
              onTap: () {
                Navigator.pop(context);
                onPaystack();
              },
            ),
            const SizedBox(height: 12),
            _MethodTile(
              icon: Icons.credit_card_outlined,
              title: 'Card / Apple Pay / Google Pay',
              subtitle: isGhs
                  ? 'Visa · Mastercard · $ghsDisplay'
                  : 'Visa · Mastercard · $localDisplay',
              onTap: () {
                Navigator.pop(context);
                onStripe();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: cs.onPrimaryContainer, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
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
    required this.priceDisplay,
    this.ghsNote,
    this.gbpNote,
    this.highlighted = false,
    this.badge,
    this.ctaLabel,
  });

  final SubscriptionTier tier;
  final bool isCurrentPlan;
  final bool highlighted;
  final List<String> features;
  final VoidCallback? onSelect;
  final String priceDisplay;
  final String? ghsNote;
  /// Hardcoded GBP approximate price shown below the primary price.
  final String? gbpNote;
  final String? badge; // e.g. "Best for self-builders"
  /// Custom CTA label override (e.g. "Get Builder Pass" for supply-side tiers).
  final String? ctaLabel;

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
                        priceDisplay,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (ghsNote != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          ghsNote!,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                        ),
                      ],
                      if (gbpNote != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          gbpNote!,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (highlighted || badge != null)
                  Chip(
                    label: Text(highlighted ? 'Popular' : badge!),
                    backgroundColor: highlighted ? cs.primary : cs.tertiaryContainer,
                    labelStyle: TextStyle(
                      color: highlighted ? cs.onPrimary : cs.onTertiaryContainer,
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
                          child: Text(
                            ctaLabel ??
                                (tier == SubscriptionTier.projectPass
                                    ? 'Buy Builder Pass'
                                    : 'Upgrade to ${tier.label}'),
                          ),
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
      SubscriptionTier.projectPass =>
        tier != SubscriptionTier.free,
      SubscriptionTier.pro =>
        tier == SubscriptionTier.pro || tier == SubscriptionTier.business,
      SubscriptionTier.business => tier == SubscriptionTier.business,
      SubscriptionTier.builderSku => tier == SubscriptionTier.builderSku,
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
