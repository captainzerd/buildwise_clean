// lib/features/payment/paystack_checkout_page.dart
//
// Loads a Paystack authorization URL in a WebView.
// Intercepts the redirect to `callbackUrl` (configured in your Paystack
// dashboard and returned by the Cloud Function) to detect success or cancel.

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaystackCheckoutResult {
  const PaystackCheckoutResult({required this.success, this.reference});
  final bool success;
  final String? reference;
}

class PaystackCheckoutPage extends StatefulWidget {
  const PaystackCheckoutPage({
    super.key,
    required this.authorizationUrl,
    required this.reference,
    this.callbackUrl = 'https://buildwise.app/paystack/callback',
  });

  final String authorizationUrl;
  final String reference;

  /// The URL Paystack redirects to after payment (set in your Paystack
  /// dashboard → Settings → API Keys & Webhooks → Callback URL).
  final String callbackUrl;

  @override
  State<PaystackCheckoutPage> createState() => _PaystackCheckoutPageState();
}

class _PaystackCheckoutPageState extends State<PaystackCheckoutPage> {
  late final WebViewController _wvc;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _wvc = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onWebResourceError: (_) => setState(() {
            _loading = false;
            _hasError = true;
          }),
          onNavigationRequest: (req) {
            if (req.url.startsWith(widget.callbackUrl)) {
              // Paystack appended ?trxref=xxx&reference=xxx
              final uri = Uri.tryParse(req.url);
              final ref =
                  uri?.queryParameters['reference'] ?? widget.reference;
              Navigator.of(context).pop(
                PaystackCheckoutResult(success: true, reference: ref),
              );
              return NavigationDecision.prevent;
            }
            // Paystack cancel: user taps "Cancel" on the Paystack page
            if (req.url.contains('paystack.com/close')) {
              Navigator.of(context).pop(
                const PaystackCheckoutResult(success: false),
              );
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
        title: const Text('Paystack Checkout'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel payment',
          onPressed: () => Navigator.of(context).pop(
            const PaystackCheckoutResult(success: false),
          ),
        ),
      ),
      body: _hasError
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.wifi_off_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Could not load payment page',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check your connection and try again.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.tonal(
                      onPressed: () {
                        setState(() {
                          _hasError = false;
                          _loading = true;
                        });
                        _wvc.loadRequest(Uri.parse(widget.authorizationUrl));
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                WebViewWidget(controller: _wvc),
                if (_loading)
                  const LinearProgressIndicator(),
              ],
            ),
    );
  }
}
