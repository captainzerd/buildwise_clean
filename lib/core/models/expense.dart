// lib/core/models/expense.dart
import 'dart:convert';

class Expense {
  final String id;
  final String estimateId;
  final String phase; // e.g., "Foundation"
  final double amount; // stored in base currency (GHS)
  final String vendor;
  final String note;
  final DateTime date;

  const Expense({
    required this.id,
    required this.estimateId,
    required this.phase,
    required this.amount,
    required this.vendor,
    required this.note,
    required this.date,
  });

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
    id: json['id'] as String,
    estimateId: json['estimateId'] as String,
    phase: json['phase'] as String,
    amount: (json['amount'] as num).toDouble(),
    vendor: json['vendor'] as String? ?? '',
    note: json['note'] as String? ?? '',
    date: DateTime.parse(json['date'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'estimateId': estimateId,
    'phase': phase,
    'amount': amount,
    'vendor': vendor,
    'note': note,
    'date': date.toIso8601String(),
  };

  static List<Expense> listFromJson(String raw) {
    final list = (jsonDecode(raw) as List<dynamic>)
        .cast<Map<String, dynamic>>();
    return list.map(Expense.fromJson).toList();
  }

  static String listToJson(List<Expense> items) {
    final list = items.map((e) => e.toJson()).toList();
    return jsonEncode(list);
  }
}
