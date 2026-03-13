import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/config/service_locator.dart';
import '../../core/models/login_activity.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/login_activity_service.dart';

class LoginActivityPage extends StatelessWidget {
  const LoginActivityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Login Activity')),
      body: StreamBuilder<List<LoginActivity>>(
        stream: sl<LoginActivityService>().streamLoginActivity(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 56, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('No login activity recorded'),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (_, i) => _ActivityTile(activity: items[i]),
          );
        },
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.activity});
  final LoginActivity activity;

  IconData _platformIcon() => switch (activity.platform) {
        'android' => Icons.android,
        'ios' => Icons.apple,
        'web' => Icons.web_outlined,
        _ => Icons.devices_outlined,
      };

  String _methodLabel() => switch (activity.signInMethod) {
        'google' => 'Google Sign-In',
        'phone' => 'Phone OTP',
        _ => 'Email & Password',
      };

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy, HH:mm');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          _platformIcon(),
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(_methodLabel()),
        subtitle: Text(
          [
            fmt.format(activity.timestamp),
            if (activity.deviceModel != null) activity.deviceModel!,
          ].join(' · '),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Chip(
          label: Text(
            activity.platform,
            style: const TextStyle(fontSize: 10),
          ),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
