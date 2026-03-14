// lib/core/services/sync_service.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/cost_entry.dart';
import '../models/payment_record.dart';
import '../storage/offline_queue_store.dart';
import 'connectivity_service.dart';
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
  }

  final ConnectivityService _connectivity;
  final OfflineQueueStore _queue;
  final ProjectService _projectService;
  final PaymentService _paymentService;

  bool _syncing = false;
  bool get isSyncing => _syncing;

  /// In-memory set of op IDs already replayed in this process lifetime.
  /// Guards against double-replay on rapid connect/disconnect cycles.
  final Set<String> _processedIds = {};

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
        await _replay(op);
        _processedIds.add(opId);
        succeeded++;
      } catch (e) {
        debugPrint('SyncService: replay failed for op ${op['op']}: $e');
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
        debugPrint('SyncService: unknown op type "$opType"');
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
