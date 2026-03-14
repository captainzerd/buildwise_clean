import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/config/service_locator.dart';
import '../../core/models/id_verification.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/id_verification_service.dart';

class IdVerificationAdminPage extends StatelessWidget {
  const IdVerificationAdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Identity Verification')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: sl<IdVerificationService>().streamAllPending(),
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
                  Icon(
                    Icons.verified_user_outlined,
                    size: 56,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 8),
                  Text('No pending verifications'),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final data = items[i];
              final uid = data['uid'] as String;
              final verification = IdVerification.fromMap(
                Map<String, dynamic>.from(data)..remove('uid'),
                uid,
              );
              return _VerificationCard(
                uid: uid,
                verification: verification,
              );
            },
          );
        },
      ),
    );
  }
}

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({
    required this.uid,
    required this.verification,
  });

  final String uid;
  final IdVerification verification;

  Future<void> _review(BuildContext context, String status) async {
    String? note;
    if (status == 'rejected') {
      note = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final ctrl = TextEditingController();
          return AlertDialog(
            title: const Text('Rejection Note'),
            content: TextField(
              controller: ctrl,
              decoration:
                  const InputDecoration(labelText: 'Reason for rejection'),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: const Text('Submit'),
              ),
            ],
          );
        },
      );
      if (note == null) return;
    }

    if (!context.mounted) return;
    final reviewerUid = context.read<AuthService>().currentUser?.uid ?? '';
    await sl<IdVerificationService>().adminReview(
      uid,
      status,
      note: note,
      reviewerUid: reviewerUid,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          status == 'verified'
              ? 'Identity verified successfully.'
              : 'Verification rejected.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy, HH:mm');
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .get(),
                    builder: (_, snap) {
                      if (!snap.hasData) return const Text('Loading...');
                      final d =
                          snap.data?.data() as Map<String, dynamic>? ?? {};
                      return Text(
                        d['displayName'] as String? ?? uid,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            _InfoRow('ID Type', verification.idType),
            _InfoRow('ID Number', verification.idNumber),
            if (verification.submittedAt != null)
              _InfoRow(
                'Submitted',
                fmt.format(verification.submittedAt!),
              ),
            const SizedBox(height: 12),
            if (verification.frontImageUrl != null ||
                verification.backImageUrl != null)
              Row(
                children: [
                  if (verification.frontImageUrl != null)
                    Expanded(
                      child: _DocPreview(
                        label: 'Front',
                        url: verification.frontImageUrl!,
                      ),
                    ),
                  if (verification.backImageUrl != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DocPreview(
                        label: 'Back',
                        url: verification.backImageUrl!,
                      ),
                    ),
                  ],
                ],
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          Theme.of(context).colorScheme.error,
                    ),
                    onPressed: () => _review(context, 'rejected'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.verified),
                    label: const Text('Verify'),
                    onPressed: () => _review(context, 'verified'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _DocPreview extends StatelessWidget {
  const _DocPreview({required this.label, required this.url});
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url,
            height: 100,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.broken_image_outlined),
          ),
        ),
      ],
    );
  }
}
