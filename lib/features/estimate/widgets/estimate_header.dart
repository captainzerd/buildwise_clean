// lib/features/estimate/widgets/estimate_header.dart
//
// Small AppBar replacement that exposes currency selection and quick actions.

import 'package:flutter/material.dart';
import '../state/estimate_controller.dart';

class EstimateHeader extends StatelessWidget implements PreferredSizeWidget {
  final Currency currency;
  final ValueChanged<Currency> onCurrencyChanged;
  final VoidCallback? onOpenSaved;

  const EstimateHeader({
    super.key,
    required this.currency,
    required this.onCurrencyChanged,
    this.onOpenSaved,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('BuildWise — Estimator'),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Currency>(
              value: currency,
              onChanged: (c) {
                if (c != null) onCurrencyChanged(c);
              },
              items: const [
                DropdownMenuItem(value: Currency.ghs, child: Text('GHS ₵')),
                DropdownMenuItem(value: Currency.usd, child: Text('USD \$')),
                DropdownMenuItem(value: Currency.eur, child: Text('EUR €')),
              ],
            ),
          ),
        ),
        if (onOpenSaved != null)
          IconButton(
            tooltip: 'Saved',
            onPressed: onOpenSaved,
            icon: const Icon(Icons.folder_open),
          ),
        const SizedBox(width: 4),
      ],
    );
  }
}
