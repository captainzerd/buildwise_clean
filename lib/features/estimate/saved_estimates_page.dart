// lib/features/estimate/saved_estimates_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';
import '../project/create_project_page.dart';
import 'estimate_view_page.dart';

class SavedEstimatesPage extends StatelessWidget {
  const SavedEstimatesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bookmark_border, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Sign in to view your saved estimates.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.go('/sign-in'),
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // IMPORTANT: ensure when you save an estimate you write userId = currentUser.uid
    // and createdAt = FieldValue.serverTimestamp()
    final query = FirebaseFirestore.instance
        .collectionGroup('estimates')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Estimates')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load saved estimates.\n${snap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = snap.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No saved estimates yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final hPad = constraints.maxWidth >= 600
                  ? (constraints.maxWidth - 600) / 2
                  : 0.0;
              return ListView.separated(
                padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 96),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (_, i) {
              final doc = docs[i];
              final m = doc.data();

              final projectName = (m['projectName'] as String?) ??
                  (m['projectNameInput'] as String?) ??
                  'Project';

              final totalGhs = (m['grandTotalGhs'] is num)
                  ? (m['grandTotalGhs'] as num).toDouble()
                  : null;

              final fxCode = (m['fxCode'] as String?) ?? 'GHS';
              final fxSym =
                  (m['fxSymbol'] as String?) ?? (fxCode == 'GHS' ? '₵' : '');
              final totalFx = (m['grandTotalFx'] is num)
                  ? (m['grandTotalFx'] as num).toDouble()
                  : null;

              final createdTs = m['createdAt'];
              DateTime? created;
              if (createdTs is Timestamp) created = createdTs.toDate();

              return ListTile(
                title: Text(
                  '$projectName • ₵ ${totalGhs != null ? totalGhs.toStringAsFixed(2) : '--'}',
                ),
                subtitle: Text(
                  [
                    if (totalFx != null && fxSym.isNotEmpty && fxSym != '₵')
                      '$fxSym ${totalFx.toStringAsFixed(2)}',
                    if (created != null)
                      DateFormat('d MMM yyyy').format(created),
                  ].where((s) => s.isNotEmpty).join('  •  '),
                ),
                trailing: PopupMenuButton<_EstimateAction>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (action) {
                    switch (action) {
                      case _EstimateAction.view:
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => EstimateViewPage(
                              docRef: doc.reference,
                              initialData: m,
                            ),
                          ),
                        );
                      case _EstimateAction.createProject:
                        final auth = context.read<AuthService>();
                        if (!auth.isSignedIn) return;
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CreateProjectPage(
                              initialTitle: projectName,
                              initialBudget: totalGhs,
                            ),
                          ),
                        );
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _EstimateAction.view,
                      child: ListTile(
                        leading: Icon(Icons.description_outlined),
                        title: Text('View estimate'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: _EstimateAction.createProject,
                      child: ListTile(
                        leading: Icon(Icons.add_business_outlined),
                        title: Text('Create project'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EstimateViewPage(
                      docRef: doc.reference,
                      initialData: m,
                    ),
                  ),
                ),
              );
            },
          );
            },
          );
        },
      ),
    );
  }
}

enum _EstimateAction { view, createProject }
