// lib/features/admin/admin_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';


class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _emailCtrl = TextEditingController();
  final _rolesCtrl = TextEditingController(text: 'admin');
  bool _busy = false;
  String? _msg;

  Future<void> _setRoles() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final current = FirebaseAuth.instance.currentUser;
      if (current == null) throw Exception('Please sign in as an admin first.');

      final callable =
          FirebaseFunctions.instance.httpsCallable('setUserRoles');
      final roles = _rolesCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final res = await callable.call(<String, dynamic>{
        'email': _emailCtrl.text.trim(),
        'roles': roles,
      });

      setState(() => _msg = 'OK: ${res.data}');
    } catch (e) {
      setState(() => _msg = 'Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _rolesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Live stats ──
          const _StatsCard(),

          const SizedBox(height: 12),

          // ── Catalog management ──
          _AdminTile(
            icon: Icons.price_change_outlined,
            title: 'Cost Catalog',
            subtitle: 'View rates and publish new catalog versions',
            onTap: () => context.push('/admin/catalog'),
          ),

          const SizedBox(height: 12),

          // ── User management ──
          _AdminTile(
            icon: Icons.people_outline,
            title: 'Users',
            subtitle: 'View all users and change roles',
            onTap: () => context.push('/admin/users'),
          ),

          const SizedBox(height: 12),

          // ── Complaints management ──
          _AdminTile(
            icon: Icons.report_problem_outlined,
            title: 'Complaints',
            subtitle: 'View all complaints and update their status',
            onTap: () => context.push('/admin/complaints'),
          ),

          const SizedBox(height: 12),

          // ── Pending deletion requests ──
          _AdminTile(
            icon: Icons.delete_sweep_outlined,
            title: 'Pending Deletions',
            subtitle: 'Review and approve builder deletion requests',
            onTap: () => context.push('/admin/deletion-requests'),
          ),

          const SizedBox(height: 12),

          // ── Audit log ──
          _AdminTile(
            icon: Icons.history_outlined,
            title: 'Audit Log',
            subtitle: 'View all project events across all users',
            onTap: () => context.push('/admin/audit'),
          ),

          const SizedBox(height: 12),

          // ── BOQ Unit Rates ──
          _AdminTile(
            icon: Icons.construction,
            title: 'BOQ Unit Rates',
            subtitle: 'Edit Bill of Quantities unit rates for all phases',
            onTap: () => context.push('/admin/boq-rates'),
          ),

          const SizedBox(height: 12),

          // ── Change orders ──
          _AdminTile(
            icon: Icons.change_circle_outlined,
            title: 'Change Orders',
            subtitle: 'Review variation orders across all projects',
            onTap: () => context.push('/admin/variation-orders'),
          ),

          const SizedBox(height: 12),

          // ── Site inspections ──
          _AdminTile(
            icon: Icons.location_city_outlined,
            title: 'Site Inspections',
            subtitle: 'View scheduled and completed site visits',
            onTap: () => context.push('/admin/site-visits'),
          ),

          const SizedBox(height: 12),

          // ── Set user roles ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(
                  'Set User Roles',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Target user email',
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _rolesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Roles (comma separated)',
                    helperText: 'Valid roles: admin, owner, pm',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : _setRoles,
                  icon: const Icon(Icons.security),
                  label: const Text('Apply roles'),
                ),
                if (_busy) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
                if (_msg != null) ...[
                  const SizedBox(height: 12),
                  Text(_msg!, textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
        ),
        ],
      ),
    );
  }
}

// ── Stats card ────────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  const _StatsCard();

  Stream<int> _count(String collection) => FirebaseFirestore.instance
      .collection(collection)
      .snapshots()
      .map((s) => s.size);

  Stream<int> _openComplaints() => FirebaseFirestore.instance
      .collection('complaints')
      .where('status', isEqualTo: 'open')
      .snapshots()
      .map((s) => s.size);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              _StatCell(label: 'Users', stream: _count('users')),
              const VerticalDivider(width: 1),
              _StatCell(label: 'Projects', stream: _count('projects')),
              const VerticalDivider(width: 1),
              _StatCell(label: 'Open Complaints', stream: _openComplaints()),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.stream});
  final String label;
  final Stream<int> stream;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: StreamBuilder<int>(
        stream: stream,
        builder: (_, snap) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              snap.hasData ? '${snap.data}' : '—',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
