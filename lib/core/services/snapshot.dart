// lib/core/services/snapshot.dart
//
// Snapshot model for saving/loading/printing estimates.
// Matches all current call-sites:
//  - safeName, filename(), tryParse(String)
//  - optional project + transactions
//  - simple constructor with the 4 obvious fields (others optional)

import 'dart:convert';

class EstimateSnapshot {
  EstimateSnapshot({
    required this.currencyCode,
    required this.name,
    required this.region,
    required this.savedAt,
    String? id,
    String? createdAtIso,
    Map<String, dynamic>? inputs,
    Map<String, dynamic>? outputs,
    Map<String, dynamic>? project,
    List<Map<String, dynamic>>? transactions,
  })  : id = id ?? _randomId(),
        createdAtIso = createdAtIso ?? savedAt.toIso8601String(),
        inputs = inputs ?? <String, dynamic>{},
        outputs = outputs ?? <String, dynamic>{},
        project = project ?? <String, dynamic>{},
        transactions = transactions ?? <Map<String, dynamic>>[];

  final String id;
  final String name;
  final String region;
  final String currencyCode;
  final DateTime savedAt;
  final String createdAtIso;

  final Map<String, dynamic> inputs;
  final Map<String, dynamic> outputs;

  final Map<String, dynamic> project;
  final List<Map<String, dynamic>> transactions;

  String get safeName => name.trim().isEmpty
      ? 'Untitled'
      : name.replaceAll(RegExp(r'[^A-Za-z0-9 _.-]'), '').trim();

  String filename() {
    final d = savedAt.toIso8601String().substring(0, 10);
    return '${safeName}_$d.json';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'region': region,
        'currencyCode': currencyCode,
        'savedAt': savedAt.toIso8601String(),
        'createdAtIso': createdAtIso,
        'inputs': inputs,
        'outputs': outputs,
        'project': project,
        'transactions': transactions,
      };

  static EstimateSnapshot fromJson(Map<String, dynamic> m) {
    return EstimateSnapshot(
      id: (m['id'] ?? '').toString().isEmpty ? _randomId() : m['id'].toString(),
      name: (m['name'] ?? 'Untitled').toString(),
      region: (m['region'] ?? '').toString(),
      currencyCode: (m['currencyCode'] ?? 'GHS').toString(),
      savedAt:
          DateTime.tryParse((m['savedAt'] ?? '').toString()) ?? DateTime.now(),
      createdAtIso:
          (m['createdAtIso'] ?? DateTime.now().toIso8601String()).toString(),
      inputs: (m['inputs'] is Map)
          ? Map<String, dynamic>.from(m['inputs'])
          : <String, dynamic>{},
      outputs: (m['outputs'] is Map)
          ? Map<String, dynamic>.from(m['outputs'])
          : <String, dynamic>{},
      project: (m['project'] is Map)
          ? Map<String, dynamic>.from(m['project'])
          : <String, dynamic>{},
      transactions: (m['transactions'] is List)
          ? List<Map<String, dynamic>>.from(
              (m['transactions'] as List).map(
                (e) => (e is Map)
                    ? Map<String, dynamic>.from(e)
                    : <String, dynamic>{},
              ),
            )
          : <Map<String, dynamic>>[],
    );
  }

  static EstimateSnapshot fromParts({
    required String name,
    required String region,
    required String currencyCode,
    required Map<String, dynamic> inputs,
    required Map<String, dynamic> outputs,
    Map<String, dynamic>? project,
    List<Map<String, dynamic>>? transactions,
  }) {
    final now = DateTime.now();
    return EstimateSnapshot(
      name: name,
      region: region,
      currencyCode: currencyCode,
      savedAt: now,
      createdAtIso: now.toIso8601String(),
      inputs: inputs,
      outputs: outputs,
      project: project,
      transactions: transactions,
    );
  }

  static EstimateSnapshot? tryParse(String raw, {String? filename}) {
    try {
      final v = jsonDecode(raw);
      if (v is Map)
        return EstimateSnapshot.fromJson(Map<String, dynamic>.from(v));
      return null;
    } catch (_) {
      return null;
    }
  }
}

String _randomId() {
  final t = DateTime.now().millisecondsSinceEpoch;
  return 'est_$t';
}
