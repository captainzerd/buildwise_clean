import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/models/id_verification.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/id_verification_service.dart';
import '../../core/config/service_locator.dart';

class IdVerificationPage extends StatefulWidget {
  const IdVerificationPage({super.key});

  @override
  State<IdVerificationPage> createState() => _IdVerificationPageState();
}

class _IdVerificationPageState extends State<IdVerificationPage> {
  final _formKey = GlobalKey<FormState>();
  String _idType = 'ghana_card';
  final _idNumberCtrl = TextEditingController();
  File? _frontFile;
  File? _backFile;
  bool _busy = false;
  String? _error;

  static const _idTypes = [
    ('ghana_card', 'Ghana Card'),
    ('passport', 'Passport'),
    ('drivers_licence', "Driver's Licence"),
    ('voters_id', "Voter's ID"),
  ];

  @override
  void dispose() {
    _idNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isFront) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;
    setState(() {
      if (isFront) {
        _frontFile = File(picked.path);
      } else {
        _backFile = File(picked.path);
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final uid = context.read<AuthService>().currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final verification = IdVerification(
        uid: uid,
        idType: _idType,
        idNumber: _idNumberCtrl.text.trim(),
        status: 'pending',
      );
      await sl<IdVerificationService>().submitVerification(
        uid,
        verification,
        frontFile: _frontFile,
        backFile: _backFile,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Submitted for review. We will notify you of the outcome.',
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _error = 'Submission failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().currentUser?.uid ?? '';
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('ID Verification')),
      body: StreamBuilder<IdVerification?>(
        stream: sl<IdVerificationService>().streamVerification(uid),
        builder: (context, snap) {
          final current = snap.data;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (current != null) ...[
                  _StatusBanner(status: current.status),
                  const SizedBox(height: 16),
                ],
                if (current?.status == 'verified') ...[
                  const Center(
                    child: Icon(
                      Icons.verified_user,
                      size: 64,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Your identity has been verified.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ] else ...[
                  Text(
                    'Submit a government-issued ID to verify your identity and improve your Trust Score.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _idType,
                          decoration: const InputDecoration(
                            labelText: 'ID Type',
                            border: OutlineInputBorder(),
                          ),
                          items: _idTypes
                              .map(
                                (t) => DropdownMenuItem(
                                  value: t.$1,
                                  child: Text(t.$2),
                                ),
                              )
                              .toList(),
                          onChanged: _busy
                              ? null
                              : (v) => setState(() => _idType = v!),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _idNumberCtrl,
                          decoration: const InputDecoration(
                            labelText: 'ID Number',
                            border: OutlineInputBorder(),
                          ),
                          enabled: !_busy,
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'ID number is required'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Document Photos',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _ImageUploadBox(
                                label: 'Front',
                                file: _frontFile,
                                onTap:
                                    _busy ? null : () => _pickImage(true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ImageUploadBox(
                                label: 'Back',
                                file: _backFile,
                                onTap:
                                    _busy ? null : () => _pickImage(false),
                              ),
                            ),
                          ],
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: TextStyle(color: cs.error),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _busy ? null : _submit,
                            icon: _busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.upload_outlined),
                            label: Text(
                              _busy ? 'Please wait…' : 'Submit for Verification',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (color, icon, text) = switch (status) {
      'verified' => (Colors.green, Icons.verified, 'Identity Verified'),
      'pending' => (Colors.amber[700]!, Icons.hourglass_bottom, 'Under Review'),
      'rejected' => (
          Theme.of(context).colorScheme.error,
          Icons.cancel_outlined,
          'Rejected — please resubmit',
        ),
      _ => (Colors.grey, Icons.help_outline, 'Not Verified'),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ImageUploadBox extends StatelessWidget {
  const _ImageUploadBox({
    required this.label,
    required this.file,
    required this.onTap,
  });

  final String label;
  final File? file;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
          ),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: file != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.file(file!, fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo_outlined, size: 32),
                  const SizedBox(height: 4),
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
      ),
    );
  }
}
