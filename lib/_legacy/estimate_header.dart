// lib/features/estimate/widgets/estimate_header.dart
//
// currencySymbol is optional with a sensible default.

import 'package:flutter/material.dart';

class EstimateHeader extends StatelessWidget {
  final String title;
  final String? currencySymbol;

  const EstimateHeader({
    super.key,
    required this.title,
    this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final sym = currencySymbol ?? '₵';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        Chip(label: Text('Currency: $sym')),
      ],
    );
  }
}
