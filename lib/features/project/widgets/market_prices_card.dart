// lib/features/project/widgets/market_prices_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/materials_price.dart';

class MarketPricesCard extends StatefulWidget {
  const MarketPricesCard({super.key, required this.snapshot});
  final MarketPricesSnapshot snapshot;

  @override
  State<MarketPricesCard> createState() => _MarketPricesCardState();
}

class _MarketPricesCardState extends State<MarketPricesCard> {
  bool _expanded = false;
  final _nf = NumberFormat('#,##0.00');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = widget.snapshot.items;
    final displayed = _expanded ? items : items.take(4).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  'Ghana Market Prices',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                Text(
                  'Updated ${DateFormat('d MMM').format(widget.snapshot.updatedAt)}',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: cs.outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final item in displayed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        item.name,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      'GHS ${_nf.format(item.priceGhs)}',
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                  ],
                ),
              ),
            if (items.length > 4) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded ? 'Show less' : 'Show ${items.length - 4} more',
                  style: TextStyle(
                    color: cs.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Prices are indicative — sourced from Accra suppliers, updated daily.',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: cs.outline),
            ),
          ],
        ),
      ),
    );
  }
}
