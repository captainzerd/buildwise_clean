// lib/features/account/edit_profile_page.dart
//
// Lets a signed-in user update their display name, phone number, and avatar.
// Changes are written to Firestore users/{uid} and Firebase Auth displayName.

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';
import '../../core/utils/validators.dart' as core_validators;
import '../../widgets/validators.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;

  /// Current preview URL (may be the existing URL, a newly uploaded URL, or
  /// null if the user cleared / never had a photo).
  String? _photoUrl;
  bool _photoChanged = false;
  bool _uploading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    _nameCtrl = TextEditingController(text: user?.displayName ?? '');
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
    _photoUrl = user?.photoUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ── Photo handling ──────────────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    final uid = context.read<AuthService>().currentUser?.uid;
    if (uid == null) return;

    final xfile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 600,
    );
    if (xfile == null || !mounted) return;

    setState(() => _uploading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ref = FirebaseStorage.instance.ref('profile_photos/users/$uid.jpg');
      await ref.putFile(
        File(xfile.path),
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await ref.getDownloadURL();
      if (mounted) {
        setState(() {
          _photoUrl = url;
          _photoChanged = true;
        });
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _clearPhoto() {
    setState(() {
      _photoUrl = null;
      _photoChanged = true;
    });
  }

  // ── Save ────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final auth = context.read<AuthService>();
      final name = _nameCtrl.text.trim();
      final phone = _phoneCtrl.text.trim();
      final existing = auth.currentUser;

      await auth.updateProfile(
        displayName: name != existing?.displayName ? name : null,
        phone: phone.isNotEmpty
            ? (phone != existing?.phone ? phone : null)
            : null,
        clearPhone: phone.isEmpty && existing?.phone != null,
        photoUrl: _photoChanged && _photoUrl != null ? _photoUrl : null,
        clearPhoto: _photoChanged && _photoUrl == null,
      );

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // ── Avatar ────────────────────────────────────────────────────────
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  _uploading
                      ? Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cs.surfaceContainerHighest,
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : GestureDetector(
                          onTap: _pickPhoto,
                          child: CircleAvatar(
                            radius: 48,
                            backgroundColor: cs.primaryContainer,
                            backgroundImage: _photoUrl != null
                                ? CachedNetworkImageProvider(_photoUrl!)
                                : null,
                            child: _photoUrl == null
                                ? Text(
                                    _initials(_nameCtrl.text),
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: cs.onPrimaryContainer,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                  // Edit button
                  if (!_uploading)
                    Material(
                      shape: const CircleBorder(),
                      color: cs.primary,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _pickPhoto,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.camera_alt_outlined,
                            size: 16,
                            color: cs.onPrimary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Clear photo link
            if (_photoUrl != null && !_uploading) ...[
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: _clearPhoto,
                  child: Text(
                    'Remove photo',
                    style: TextStyle(
                      color: cs.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 28),

            // ── Name ──────────────────────────────────────────────────────────
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Full name *',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}), // refresh initials
              validator: Validators.displayName,
            ),
            const SizedBox(height: 16),

            // ── Phone ─────────────────────────────────────────────────────────
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Phone number (optional)',
                hintText: 'e.g. +233 20 000 0000',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
              validator: core_validators.Validators.phone,
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
