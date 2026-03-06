import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/models/app_user.dart';
import '../../core/models/builder_profile.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/builder_profile_service.dart';
import '../../core/services/regional_index_provider.dart';

class BuilderProfilePage extends StatefulWidget {
  const BuilderProfilePage({super.key});

  @override
  State<BuilderProfilePage> createState() => _BuilderProfilePageState();
}

class _BuilderProfilePageState extends State<BuilderProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _bioCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _yearsCtrl = TextEditingController();
  final _specializationsCtrl = TextEditingController();
  final _minBudgetCtrl = TextEditingController();
  final _projectsDoneCtrl = TextEditingController();
  final _graTinCtrl = TextEditingController();
  final _giaCtrl = TextEditingController();
  final _gioeCtrl = TextEditingController();
  final _gredaCtrl = TextEditingController();
  final _ghanaCardCtrl = TextEditingController();

  BuilderRole _role = BuilderRole.contractor;
  String? _region;
  String? _photoUrl;
  String? _contractorGrade;
  bool _isActive = true;
  bool _availableForHire = true;
  bool _saving = false;
  bool _uploading = false;
  bool _loading = true;
  String? _error;

  static const _contractorGrades = [
    'D1', 'D2', 'D3', 'D4',
    'G1', 'G2', 'G3', 'G4', 'G5', 'G6', 'G7', 'G8',
  ];

  static const _graTinPattern = r'^GHA-\d{9}-\d$';
  static const _ghanaCardPattern = r'^GHA-\d{9}-\d$';

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final auth = context.read<AuthService>();
    final service = context.read<BuilderProfileService>();
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final snap = await service.profileStream(uid).first;
      if (snap != null && mounted) {
        _bioCtrl.text = snap.bio;
        _phoneCtrl.text = snap.phone ?? '';
        _whatsappCtrl.text = snap.whatsappNumber ?? '';
        _locationCtrl.text = snap.location ?? '';
        _yearsCtrl.text = snap.yearsExperience?.toString() ?? '';
        _specializationsCtrl.text = snap.specializations.join(', ');
        _minBudgetCtrl.text =
            snap.minimumBudgetGhs?.toStringAsFixed(0) ?? '';
        _projectsDoneCtrl.text =
            snap.projectsCompleted > 0 ? snap.projectsCompleted.toString() : '';
        _graTinCtrl.text = snap.graTin ?? '';
        _giaCtrl.text = snap.giaNumber ?? '';
        _gioeCtrl.text = snap.gioeNumber ?? '';
        _gredaCtrl.text = snap.gredaMembership ?? '';
        _ghanaCardCtrl.text = snap.ghanaCardNumber ?? '';
        setState(() {
          _role = snap.role;
          _region = snap.region.isEmpty ? null : snap.region;
          _isActive = snap.isActive;
          _availableForHire = snap.availableForHire;
          _photoUrl = snap.photoUrl;
          _contractorGrade = snap.contractorGrade;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _locationCtrl.dispose();
    _yearsCtrl.dispose();
    _specializationsCtrl.dispose();
    _minBudgetCtrl.dispose();
    _projectsDoneCtrl.dispose();
    _graTinCtrl.dispose();
    _giaCtrl.dispose();
    _gioeCtrl.dispose();
    _gredaCtrl.dispose();
    _ghanaCardCtrl.dispose();
    super.dispose();
  }

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts =
        name.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  Future<void> _pickAndUploadPhoto() async {
    final auth = context.read<AuthService>();
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    final xfile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
    );
    if (xfile == null || !mounted) return;

    setState(() => _uploading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ref = FirebaseStorage.instance
          .ref('profile_photos/builders/$uid.jpg');
      final task = await ref.putFile(
        File(xfile.path),
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await task.ref.getDownloadURL();
      if (mounted) {
        setState(() => _photoUrl = url);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Photo updated — save to confirm.'),
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthService>();
      final service = context.read<BuilderProfileService>();
      final user = auth.currentUser!;
      final now = DateTime.now();

      final specializations = _specializationsCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final profile = BuilderProfile(
        uid: user.uid,
        displayName: user.displayName,
        role: _role,
        bio: _bioCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        whatsappNumber: _whatsappCtrl.text.trim().isEmpty
            ? null
            : _whatsappCtrl.text.trim(),
        email: user.email,
        photoUrl: _photoUrl,
        location: _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
        region: _region ?? '',
        specializations: specializations,
        isActive: _isActive,
        availableForHire: _availableForHire,
        yearsExperience: int.tryParse(_yearsCtrl.text.trim()),
        minimumBudgetGhs: double.tryParse(_minBudgetCtrl.text.trim()),
        projectsCompleted: int.tryParse(_projectsDoneCtrl.text.trim()) ?? 0,
        graTin: _graTinCtrl.text.trim().isEmpty
            ? null
            : _graTinCtrl.text.trim(),
        giaNumber: _giaCtrl.text.trim().isEmpty
            ? null
            : _giaCtrl.text.trim(),
        gioeNumber: _gioeCtrl.text.trim().isEmpty
            ? null
            : _gioeCtrl.text.trim(),
        gredaMembership: _gredaCtrl.text.trim().isEmpty
            ? null
            : _gredaCtrl.text.trim(),
        ghanaCardNumber: _ghanaCardCtrl.text.trim().isEmpty
            ? null
            : _ghanaCardCtrl.text.trim(),
        contractorGrade: _contractorGrade,
        createdAt: now,
        updatedAt: now,
      );

      await service.createOrUpdate(profile);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved successfully.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final regions = context.read<RegionalIndexProvider>().regionCodes;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final displayName =
        context.read<AuthService>().currentUser?.displayName;

    return Scaffold(
      appBar: AppBar(title: const Text('Builder Profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Profile photo ───────────────────────────────────────────────
            Center(
              child: GestureDetector(
                onTap: _uploading ? null : _pickAndUploadPhoto,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundImage: _photoUrl != null
                          ? CachedNetworkImageProvider(_photoUrl!) as ImageProvider
                          : null,
                      child: _photoUrl == null
                          ? Text(
                              _initials(displayName),
                              style: const TextStyle(fontSize: 28),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(6),
                        child: _uploading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt,
                                size: 14,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Your public profile is visible to property owners looking for '
              'a builder.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 20),

            // Role
            DropdownButtonFormField<BuilderRole>(
              initialValue: _role,
              decoration: const InputDecoration(
                labelText: 'Professional role *',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final r in BuilderRole.values)
                  DropdownMenuItem(value: r, child: Text(r.label)),
              ],
              onChanged: (v) => setState(() => _role = v ?? _role),
            ),
            const SizedBox(height: 14),

            // Bio
            TextFormField(
              controller: _bioCtrl,
              decoration: const InputDecoration(
                labelText: 'Bio / About *',
                hintText: 'Describe your experience and services…',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v == null || v.trim().length < 20)
                  ? 'Please write at least 20 characters'
                  : null,
            ),
            const SizedBox(height: 14),

            // Phone
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                prefixText: '+',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),

            // WhatsApp
            TextFormField(
              controller: _whatsappCtrl,
              decoration: const InputDecoration(
                labelText: 'WhatsApp number (optional)',
                prefixText: '+',
                hintText: 'e.g. 233241234567',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),

            // Location
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Location (optional)',
                hintText: 'e.g. Accra, East Legon',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),

            // Region
            DropdownButtonFormField<String>(
              initialValue: _region,
              decoration: const InputDecoration(
                labelText: 'Primary region',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('— Select —')),
                for (final r in regions)
                  DropdownMenuItem(value: r, child: Text(r)),
              ],
              onChanged: (v) => setState(() => _region = v),
            ),
            const SizedBox(height: 14),

            // Years experience
            TextFormField(
              controller: _yearsCtrl,
              decoration: const InputDecoration(
                labelText: 'Years of experience (optional)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                final n = int.tryParse(v);
                if (n == null || n < 0 || n > 60) return 'Enter 0–60';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Projects completed
            TextFormField(
              controller: _projectsDoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Projects completed (optional)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 14),

            // Minimum budget
            TextFormField(
              controller: _minBudgetCtrl,
              decoration: const InputDecoration(
                labelText: 'Minimum project budget — GHS (optional)',
                prefixText: '₵ ',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 14),

            // Specializations
            TextFormField(
              controller: _specializationsCtrl,
              decoration: const InputDecoration(
                labelText: 'Specializations (comma-separated, optional)',
                hintText: 'e.g. Residential, Renovation, Commercial',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),

            // ── Professional credentials ─────────────────────────────────
            const SizedBox(height: 4),
            Text(
              'Professional Credentials',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              'These are verified by admin and unlock the trust badge on your '
              'public profile.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _graTinCtrl,
              decoration: const InputDecoration(
                labelText: 'GRA TIN (optional)',
                hintText: 'GHA-000000000-0',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                if (!RegExp(_graTinPattern).hasMatch(v.trim())) {
                  return 'Format must be GHA-000000000-0';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _contractorGrade,
              decoration: const InputDecoration(
                labelText: 'Contractor Grade (optional)',
                hintText: 'Select grade',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('— None —')),
                for (final g in _contractorGrades)
                  DropdownMenuItem(value: g, child: Text(g)),
              ],
              onChanged: (v) => setState(() => _contractorGrade = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _giaCtrl,
              decoration: const InputDecoration(
                labelText: 'GIA Membership No. (optional)',
                hintText: 'Ghana Institution of Architects',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _gioeCtrl,
              decoration: const InputDecoration(
                labelText: 'GIOE Membership No. (optional)',
                hintText: 'Ghana Institution of Engineers',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _gredaCtrl,
              decoration: const InputDecoration(
                labelText: 'GREDA Membership No. (optional)',
                hintText: 'Ghana Real Estate Developers Association',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ghanaCardCtrl,
              decoration: const InputDecoration(
                labelText: 'Ghana Card Number (optional)',
                hintText: 'GHA-000000000-0',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                if (!RegExp(_ghanaCardPattern).hasMatch(v.trim())) {
                  return 'Format must be GHA-000000000-0';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Available for hire toggle
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Available for hire'),
              subtitle: const Text(
                'Turn off if you are fully booked.',
              ),
              value: _availableForHire,
              onChanged: (v) => setState(() => _availableForHire = v),
            ),

            // Visible in marketplace toggle — requires Business tier
            Builder(
              builder: (context) {
                final auth = context.watch<AuthService>();
                final tier = auth.currentUser?.subscriptionTier ??
                    SubscriptionTier.free;
                final canList = tier.canListInMarketplace;
                return SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Visible in Find a Builder'),
                  subtitle: Text(
                    canList
                        ? 'Turn off to hide your profile from property owners.'
                        : 'Requires the Business plan to list in the marketplace.',
                  ),
                  value: _isActive && canList,
                  onChanged: canList
                      ? (v) => setState(() => _isActive = v)
                      : (_) => context.push(
                            '/account/upgrade',
                            extra: {
                              'tier': SubscriptionTier.business.name,
                              'feature': 'Builder Marketplace Listing',
                            },
                          ),
                );
              },
            ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving…' : 'Save profile'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
