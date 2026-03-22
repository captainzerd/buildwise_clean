import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/service_locator.dart';
import '../../core/models/certification.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/certification_service.dart';

class CertificationsPage extends StatelessWidget {
  const CertificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Certifications')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context, uid),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Certification>>(
        stream: sl<CertificationService>().stream(uid),
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
                    Icons.workspace_premium_outlined,
                    size: 56,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 8),
                  Text('No certifications yet'),
                  SizedBox(height: 4),
                  Text(
                    'Tap + to add a certificate',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (_, i) =>
                _CertTile(cert: items[i], uid: uid),
          );
        },
      ),
    );
  }

  void _showAddSheet(BuildContext context, String uid) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddCertSheet(uid: uid),
    );
  }
}

class _CertTile extends StatelessWidget {
  const _CertTile({required this.cert, required this.uid});
  final Certification cert;
  final String uid;

  Color _expiryColor(BuildContext context) {
    if (cert.isExpired) return Theme.of(context).colorScheme.error;
    if (cert.isExpiringSoon) return Colors.amber[700]!;
    return Colors.green;
  }

  String _expiryLabel() {
    if (cert.expiryDate == null) return 'No expiry';
    if (cert.isExpired) return 'Expired';
    if (cert.isExpiringSoon) return 'Expiring soon';
    return 'Valid';
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM yyyy');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cert.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(cert.issuingBody),
                  if (cert.certificateNumber != null)
                    Text(
                      'No. ${cert.certificateNumber}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'Issued: ${fmt.format(cert.issueDate)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (cert.expiryDate != null)
                    Text(
                      'Expires: ${fmt.format(cert.expiryDate!)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _expiryColor(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _expiryColor(context)),
                  ),
                  child: Text(
                    _expiryLabel(),
                    style: TextStyle(
                      color: _expiryColor(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: Theme.of(context).colorScheme.error,
                  iconSize: 20,
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete Certification'),
                        content: Text('Remove "${cert.name}"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.error,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await sl<CertificationService>().delete(uid, cert.id);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddCertSheet extends StatefulWidget {
  const _AddCertSheet({required this.uid});
  final String uid;

  @override
  State<_AddCertSheet> createState() => _AddCertSheetState();
}

class _AddCertSheetState extends State<_AddCertSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  DateTime _issueDate = DateTime.now();
  DateTime? _expiryDate;
  File? _docFile;
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bodyCtrl.dispose();
    _numberCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.single.path == null) return;
    setState(() => _docFile = File(result.files.single.path!));
  }

  Future<void> _pickDate({required bool isIssue}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isIssue ? _issueDate : (_expiryDate ?? DateTime.now()),
      firstDate: DateTime(1990),
      lastDate: DateTime(2050),
    );
    if (picked == null) return;
    setState(() {
      if (isIssue) {
        _issueDate = picked;
      } else {
        _expiryDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final certId = const Uuid().v4();
      String? docUrl;
      if (_docFile != null) {
        final ext = p.extension(_docFile!.path).replaceFirst('.', '');
        docUrl = await sl<CertificationService>().uploadCertDocument(
          widget.uid,
          certId,
          _docFile!,
          ext,
        );
      }
      final cert = Certification(
        id: certId,
        name: _nameCtrl.text.trim(),
        issuingBody: _bodyCtrl.text.trim(),
        issueDate: _issueDate,
        expiryDate: _expiryDate,
        certificateNumber: _numberCtrl.text.trim().isNotEmpty
            ? _numberCtrl.text.trim()
            : null,
        documentUrl: docUrl,
      );
      await sl<CertificationService>().add(widget.uid, cert);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add Certification',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Certificate Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bodyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Issuing Body *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _numberCtrl,
                decoration: const InputDecoration(
                  labelText: 'Certificate Number (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text('Issued: ${fmt.format(_issueDate)}'),
                      onPressed: () => _pickDate(isIssue: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event_outlined, size: 16),
                      label: Text(
                        _expiryDate != null
                            ? 'Expires: ${fmt.format(_expiryDate!)}'
                            : 'Set expiry',
                      ),
                      onPressed: () => _pickDate(isIssue: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.attach_file),
                label: Text(
                  _docFile != null
                      ? p.basename(_docFile!.path)
                      : 'Upload document (PDF/image)',
                ),
                onPressed: _busy ? null : _pickFile,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
