// lib/core/services/storage_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/estimate.dart';
import '../models/expense.dart';

class StorageService {
  static const _kEstimates = 'bw_estimates';
  static const _kExpenses = 'bw_expenses';

  const StorageService();

  // ----- Estimates -----
  Future<List<Estimate>> listEstimates() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kEstimates);
    if (raw == null || raw.isEmpty) return <Estimate>[];
    final list = (jsonDecode(raw) as List<dynamic>)
        .cast<Map<String, dynamic>>();
    return list.map(Estimate.fromJson).toList();
  }

  Future<void> saveEstimate(Estimate e) async {
    final sp = await SharedPreferences.getInstance();
    final all = await listEstimates();
    final idx = all.indexWhere((x) => x.projectId == e.projectId);
    if (idx >= 0) {
      all[idx] = e;
    } else {
      all.add(e);
    }
    final raw = jsonEncode(all.map((x) => x.toJson()).toList());
    await sp.setString(_kEstimates, raw);
  }

  Future<void> deleteEstimate(String projectId) async {
    final sp = await SharedPreferences.getInstance();
    final all = await listEstimates();
    all.removeWhere((x) => x.projectId == projectId);
    final raw = jsonEncode(all.map((x) => x.toJson()).toList());
    await sp.setString(_kEstimates, raw);

    // cascade delete expenses for this estimate
    final expenses = await listAllExpenses();
    final remaining = expenses.where((e) => e.estimateId != projectId).toList();
    await sp.setString(_kExpenses, Expense.listToJson(remaining));
  }

  // ----- Expenses -----
  Future<List<Expense>> listAllExpenses() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kExpenses);
    if (raw == null || raw.isEmpty) return <Expense>[];
    return Expense.listFromJson(raw);
  }

  Future<List<Expense>> listExpensesFor(String estimateId) async {
    final all = await listAllExpenses();
    return all.where((e) => e.estimateId == estimateId).toList();
  }

  Future<void> saveExpense(Expense e) async {
    final sp = await SharedPreferences.getInstance();
    final all = await listAllExpenses();
    final idx = all.indexWhere((x) => x.id == e.id);
    if (idx >= 0) {
      all[idx] = e;
    } else {
      all.add(e);
    }
    await sp.setString(_kExpenses, Expense.listToJson(all));
  }

  Future<void> deleteExpense(String id) async {
    final sp = await SharedPreferences.getInstance();
    final all = await listAllExpenses();
    all.removeWhere((x) => x.id == id);
    await sp.setString(_kExpenses, Expense.listToJson(all));
  }
}
