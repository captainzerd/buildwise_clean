// lib/features/admin/deletion_requests_admin_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/config/service_locator.dart';
import '../../core/models/deletion_request.dart';
import '../../core/services/deletion_request_service.dart';

class DeletionRequestsAdminPage extends StatelessWidget {
  const DeletionRequestsAdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = sl<DeletionRequestService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Pending Deletion Requests')),
      body: StreamBuilder<List<DeletionRequest>>(
        stream: service.allPendingStream(),
        builder: (ctx, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final requests = snap.data!;
          if (requests.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, size: 48),
                  SizedBox(height: 12),
                  Text('No pending deletion requests.'),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _RequestCard(
              request: requests[i],
              service: service,
            ),
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatefulWidget {
  const _RequestCard({required this.request, required this.service});
  final DeletionRequest request;
  final DeletionRequestService service;

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _busy = false;

  Future<void> _approve() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.service.approve(widget.request);
      messenger.showSnackBar(const SnackBar(content: Text('Approved.')));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deny() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.service.deny(widget.request);
      messenger.showSnackBar(const SnackBar(content: Text('Denied.')));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type + description
            Row(
              children: [
                _TypeChip(type: req.itemType),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    req.itemDescription,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Amount (if present)
            if (req.amountGhs != null) ...[
              Text(
                'Amount: GHS ${req.amountGhs!.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
            ],

            // Meta row
            Row(
              children: [
                Icon(Icons.person_outline, size: 13, color: cs.outline),
                const SizedBox(width: 4),
                Text(
                  req.requestedByName,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: cs.outline),
                ),
                const SizedBox(width: 12),
                Icon(Icons.schedule_outlined, size: 13, color: cs.outline),
                const SizedBox(width: 4),
                Text(
                  DateFormat('d MMM yyyy').format(req.createdAt),
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: cs.outline),
                ),
              ],
            ),

            // Project ID
            const SizedBox(height: 4),
            Text(
              'Project: ${req.projectId}',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: cs.outline),
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 12),

            // Actions
            if (_busy)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _deny,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.error,
                      side: BorderSide(color: cs.error),
                    ),
                    child: const Text('Deny'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _approve,
                    child: const Text('Approve'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});
  final DeletionItemType type;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          fontSize: 11,
          color: cs.onSecondaryContainer,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
