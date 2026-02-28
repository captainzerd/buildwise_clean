import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/app_notification.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/notification_service.dart';

class NotificationCentrePage extends StatelessWidget {
  const NotificationCentrePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final svc = context.read<NotificationService>();
    final uid = auth.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () => svc.markAllRead(uid),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: svc.notificationsStream(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_outlined, size: 64),
                  SizedBox(height: 12),
                  Text('No notifications yet'),
                ],
              ),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, i) => _NotifTile(
              notif: items[i],
              uid: uid,
              svc: svc,
            ),
          );
        },
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  const _NotifTile({
    required this.notif,
    required this.uid,
    required this.svc,
  });

  final AppNotification notif;
  final String uid;
  final NotificationService svc;

  IconData _iconFor(String? type) {
    switch (type) {
      case 'phase_new':
        return Icons.layers_outlined;
      case 'cost_new':
        return Icons.receipt_long_outlined;
      case 'update_new':
        return Icons.newspaper_outlined;
      case 'deletion_new':
      case 'deletion_approved':
      case 'deletion_denied':
        return Icons.delete_outline;
      case 'contract_new':
      case 'contract_signed':
        return Icons.handshake_outlined;
      case 'assignment':
        return Icons.assignment_ind_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final unread = !notif.read;
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        if (unread) svc.markRead(uid, notif.id);
        svc.routeFromData(notif.data);
      },
      child: Container(
        color: unread ? cs.primaryContainer.withValues(alpha: 0.15) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor:
                  unread ? cs.primaryContainer : cs.surfaceContainerHigh,
              foregroundColor: unread ? cs.onPrimaryContainer : cs.onSurface,
              child: Icon(_iconFor(notif.data['type']), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notif.title,
                    style: TextStyle(
                      fontWeight:
                          unread ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notif.body,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _timeAgo(notif.createdAt),
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: cs.outline),
                  ),
                ],
              ),
            ),
            if (unread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6, left: 8),
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
