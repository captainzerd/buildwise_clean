// lib/core/services/sync_service.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/cost_entry.dart';
import '../models/payment_record.dart';
import '../storage/offline_queue_store.dart';
import 'connectivity_service.dart';
import 'logger_service.dart';
import 'notification_service.dart';
import 'payment_service.dart';
import 'project_service.dart';

class SyncService extends ChangeNotifier {
  SyncService({
    required ConnectivityService connectivity,
    required OfflineQueueStore queue,
    required ProjectService projectService,
    required PaymentService paymentService,
  })  : _connectivity = connectivity,
        _queue = queue,
        _projectService = projectService,
        _paymentService = paymentService {
    _connectivity.addListener(_onConnectivityChanged);
    _loadProcessedIds();
  }

  final ConnectivityService _connectivity;
  final OfflineQueueStore _queue;
  final ProjectService _projectService;
  final PaymentService _paymentService;

  bool _syncing = false;
  bool get isSyncing => _syncing;

  static const _kSyncProcessedKey = 'sync_processed_ids';
  static const _kTtlDays = 7;
  Set<String> _processedIds = {};

  /// Loads processed IDs from SharedPreferences, pruning entries older than [_kTtlDays].
  Future<void> _loadProcessedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kSyncProcessedKey) ?? [];
    final cutoff = DateTime.now()
        .subtract(const Duration(days: _kTtlDays))
        .millisecondsSinceEpoch;
    _processedIds = raw.where((entry) {
      final parts = entry.split(':');
      if (parts.length < 2) return false;
      final ts = int.tryParse(parts.last) ?? 0;
      return ts > cutoff;
    }).map((entry) {
      // Strip the trailing :timestamp to get the raw ID
      final idx = entry.lastIndexOf(':');
      return entry.substring(0, idx);
    }).toSet();
  }

  /// Persists the current _processedIds set to SharedPreferences as {id}:{epochMs} pairs.
  Future<void> _saveProcessedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final entries = _processedIds.map((id) => '$id:$now').toList();
    await prefs.setStringList(_kSyncProcessedKey, entries);
  }

  void _onConnectivityChanged() {
    if (_connectivity.isOnline) {
      _flush();
    }
  }

  Future<void> _flush() async {
    if (_syncing) return;
    final ops = await _queue.readAll();
    if (ops.isEmpty) return;

    _syncing = true;
    notifyListeners();

    int succeeded = 0;
    final failed = <Map<String, dynamic>>[];

    for (final op in ops) {
      final opId = op['id'] as String? ?? const Uuid().v4();
      if (_processedIds.contains(opId)) {
        // Already replayed in this session — skip to avoid duplicate writes.
        succeeded++;
        continue;
      }
      try {
        await _replayWithRetry(op);
        _processedIds.add(opId);
        succeeded++;
        await _saveProcessedIds();
      } catch (e) {
        LoggerService.error('SyncService: replay failed for op ${op['op']}', error: e);
        failed.add(op);
      }
    }

    // Replace queue with only failed ops
    await _queue.dequeueAll();
    for (final f in failed) {
      await _queue.enqueue(f);
    }

    _syncing = false;
    notifyListeners();

    if (succeeded > 0) {
      _showSnackbar(
        'Synced $succeeded offline operation${succeeded == 1 ? '' : 's'}.',
      );
    }
  }

  static const _maxRetries = 3;

  Future<void> _replayWithRetry(Map<String, dynamic> op) async {
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        await _replay(op);
        return;
      } catch (e) {
        if (attempt == _maxRetries) rethrow;
        final delay = Duration(
          milliseconds: (pow(2, attempt) * 500).toInt(),
        );
        LoggerService.warning('SyncService: attempt ${attempt + 1} failed, retrying in ${delay.inMilliseconds}ms');
        await Future<void>.delayed(delay);
      }
    }
  }

  Future<void> _replay(Map<String, dynamic> op) async {
    final opType = op['op'] as String? ?? '';
    final projectId = op['projectId'] as String? ?? '';
    final payload = Map<String, dynamic>.from(
      (op['payload'] as Map?) ?? {},
    );

    switch (opType) {
      case 'addCostEntry':
        final entry = CostEntry(
          id: '',
          authorUid: payload['authorUid'] as String? ?? '',
          description: payload['description'] as String? ?? '',
          category: payload['category'] as String? ?? 'Other',
          amountGhs: (payload['amountGhs'] as num?)?.toDouble() ?? 0,
          createdAt: DateTime.tryParse(
                payload['createdAt'] as String? ?? '',
              ) ??
              DateTime.now(),
          phaseId: payload['phaseId'] as String?,
        );
        await _projectService.addCostEntry(projectId, entry);

      case 'addUpdate':
        await _projectService.addUpdate(
          projectId: projectId,
          authorUid: payload['authorUid'] as String? ?? '',
          text: payload['text'] as String? ?? '',
        );

      case 'addPayment':
        final record = PaymentRecord(
          id: '',
          authorUid: payload['authorUid'] as String? ?? '',
          direction: PaymentDirection.values.firstWhere(
            (e) => e.name == payload['direction'],
            orElse: () => PaymentDirection.outbound,
          ),
          amountGhs: (payload['amountGhs'] as num?)?.toDouble() ?? 0,
          description: payload['description'] as String? ?? '',
          method: PaymentMethod.values.firstWhere(
            (e) => e.name == payload['method'],
            orElse: () => PaymentMethod.cash,
          ),
          paymentDate: DateTime.tryParse(
                payload['paymentDate'] as String? ?? '',
              ) ??
              DateTime.now(),
          createdAt: DateTime.now(),
        );
        await _paymentService.addPayment(
          projectId: projectId,
          payment: record,
        );

      default:
        LoggerService.warning('SyncService: unknown op type "$opType"');
    }
  }

  void _showSnackbar(String message) {
    final ctx = NotificationService.navigatorKey.currentContext;
    if (ctx != null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _connectivity.removeListener(_onConnectivityChanged);
    super.dispose();
  }
}
