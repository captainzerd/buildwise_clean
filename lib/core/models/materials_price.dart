// lib/core/models/materials_price.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class MaterialPriceItem {
  const MaterialPriceItem({
    required this.name,
    required this.unit,
    required this.priceGhs,
    required this.category,
  });

  final String name;
  final String unit;
  final double priceGhs;
  final String category;

  factory MaterialPriceItem.fromMap(Map<String, dynamic> m) => MaterialPriceItem(
        name: m['name'] as String? ?? '',
        unit: m['unit'] as String? ?? '',
        priceGhs: (m['priceGhs'] as num?)?.toDouble() ?? 0,
        category: m['category'] as String? ?? 'General',
      );
}

@immutable
class MarketPricesSnapshot {
  const MarketPricesSnapshot({
    required this.updatedAt,
    required this.items,
  });

  final DateTime updatedAt;
  final List<MaterialPriceItem> items;

  factory MarketPricesSnapshot.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return MarketPricesSnapshot(
      updatedAt:
          (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      items: (d['items'] as List<dynamic>? ?? [])
          .map((e) => MaterialPriceItem.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
