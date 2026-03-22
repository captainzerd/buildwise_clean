// lib/core/widgets/offline_banner.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/connectivity_service.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (ctx, connectivity, __) {
        if (connectivity.isOnline) return const SizedBox.shrink();
        final cs = Theme.of(ctx).colorScheme;
        return Container(
          color: cs.error,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off, color: cs.onError, size: 14),
              const SizedBox(width: 6),
              Text(
                'Offline \u2014 changes will sync when reconnected',
                style: TextStyle(color: cs.onError, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}
