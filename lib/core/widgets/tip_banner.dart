// lib/core/widgets/tip_banner.dart
//
// A dismissable contextual tip that is shown once per device.
// The dismissed state is persisted in SharedPreferences using [tipKey].
// Once dismissed the widget renders as SizedBox.shrink().
//
// Usage:
//   TipBanner(
//     tipKey: 'tip_estimate_region',
//     message: 'Select your region for more accurate local rates.',
//   )

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TipBanner extends StatefulWidget {
  const TipBanner({
    super.key,
    required this.tipKey,
    required this.message,
    this.icon = Icons.lightbulb_outline,
  });

  /// Unique key stored in SharedPreferences to track dismissal.
  final String tipKey;
  final String message;
  final IconData icon;

  @override
  State<TipBanner> createState() => _TipBannerState();
}

class _TipBannerState extends State<TipBanner> {
  // null = loading; true = visible; false = dismissed
  bool? _visible;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(widget.tipKey) ?? false;
    if (mounted) setState(() => _visible = !dismissed);
  }

  Future<void> _dismiss() async {
    setState(() => _visible = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(widget.tipKey, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_visible != true) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
          color: cs.secondaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              widget.icon,
              size: 18,
              color: cs.onSecondaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.message,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSecondaryContainer,
                      height: 1.4,
                    ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              color: cs.onSecondaryContainer,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
              tooltip: 'Dismiss',
              onPressed: _dismiss,
            ),
          ],
        ),
      ),
    );
  }
}
