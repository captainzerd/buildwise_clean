// lib/features/estimate/widgets/step_scaffold.dart
//
// Shared scaffold for each wizard step: scrollable content area + Back/Next
// footer row. Used by Step1–Step5.

import 'package:flutter/material.dart';

// ── Step scaffold ─────────────────────────────────────────────────────────────

class StepScaffold extends StatelessWidget {
  const StepScaffold({
    super.key,
    required this.child,
    required this.onNext,
    required this.onBack,
    required this.nextLabel,
    this.footer,
  });

  final Widget child;
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final String nextLabel;

  /// Replaces the default Back/Next row when provided.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: child,
          ),
        ),
        if (footer != null)
          footer!
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                if (onBack != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onBack,
                      child: const Text('Back'),
                    ),
                  ),
                if (onBack != null) const SizedBox(width: 12),
                if (onNext != null)
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: onNext,
                      child: Text(nextLabel),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

Widget sectionLabel(BuildContext context, String text) => Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
    );

// ── Info / error banner ───────────────────────────────────────────────────────

class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.icon,
    required this.message,
    required this.color,
    required this.textColor,
  });

  final IconData icon;
  final String message;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: textColor, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
