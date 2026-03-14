import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/builder_profile.dart';
import '../../core/services/builder_profile_service.dart';

class LicenceVerificationAdminPage extends StatelessWidget {
  const LicenceVerificationAdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Licence Verification')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('pm_profiles')
            .where('licenceVerificationStatus', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.workspace_premium_outlined,
                    size: 56,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 8),
                  Text('No pending licence verifications'),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final profile = BuilderProfile.fromDoc(
                docs[i] as DocumentSnapshot<Map<String, dynamic>>,
              );
              return _LicenceCard(profile: profile);
            },
          );
        },
      ),
    );
  }
}

class _LicenceCard extends StatelessWidget {
  const _LicenceCard({required this.profile});
  final BuilderProfile profile;

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

    await FirebaseFirestore.instance
        .collection('pm_profiles')
        .doc(profile.uid)
        .update({
      'licenceVerificationStatus': status,
      if (status == 'verified')
        'licenceVerifiedAt': FieldValue.serverTimestamp(),
      if (note != null) 'licenceRejectionNote': note,
    });

    // Update trust score
    if (context.mounted) {
      await context
          .read<BuilderProfileService>()
          .updateTrustScore(profile.uid);
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          status == 'verified'
              ? 'Licence verified successfully.'
              : 'Licence verification rejected.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              profile.displayName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(profile.role.label),
            const Divider(height: 16),
            if (profile.licenceDocUrls.isEmpty)
              const Text('No licence documents uploaded.')
            else ...[
              Text(
                'Uploaded Documents:',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              ...profile.licenceDocUrls.entries.map(
                (e) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: Text(e.key.toUpperCase()),
                  trailing: TextButton(
                    onPressed: () async {
                      final uri = Uri.parse(e.value);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    child: const Text('View'),
                  ),
                ),
              ),
            ],
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
