// lib/core/models/boq_item.dart
import 'package:flutter/foundation.dart';

@immutable
class BoqItem {
  const BoqItem({
    required this.phase,
    required this.description,
    required this.unit,
    required this.quantity,
    required this.unitRateGhs,
  });

  final String phase;
  final String description;
  final String unit;
  final double quantity;
  final double unitRateGhs;

  double get totalGhs => quantity * unitRateGhs;

  factory BoqItem.fromMap(Map<String, dynamic> m) => BoqItem(
        phase: m['phase'] as String,
        description: m['description'] as String,
        unit: m['unit'] as String,
        quantity: (m['quantity'] as num).toDouble(),
        unitRateGhs: (m['unitRateGhs'] as num).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'phase': phase,
        'description': description,
        'unit': unit,
        'quantity': quantity,
        'unitRateGhs': unitRateGhs,
        'totalGhs': totalGhs,
      };
}
