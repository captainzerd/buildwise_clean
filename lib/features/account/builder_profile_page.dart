import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/app_user.dart';
import '../../core/models/builder_profile.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/builder_profile_service.dart';
import '../../core/services/regional_index_provider.dart';
import '../../widgets/validators.dart';

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
  final _businessRegCtrl = TextEditingController();
  final _ncaLicenseCtrl = TextEditingController();

  BuilderRole _role = BuilderRole.contractor;
  String? _region;
  String? _photoUrl;
  String? _contractorGrade;
  String? _ncaClass;
  bool _isActive = true;
  bool _availableForHire = true;
  bool _saving = false;
  bool _uploading = false;
  bool _loading = true;
  String? _error;

  // Business reg doc state
  String? _businessRegUrl;
  String _businessRegStatus = 'unverified';

  // Insurance state
  String? _insurancePliUrl;
  DateTime? _insurancePliExpiry;
  String? _insurancePiiUrl;
  DateTime? _insurancePiiExpiry;
  String _insuranceStatus = 'unverified';

  static const _contractorGrades = [
    'D1',
    'D2',
    'D3',
    'D4',
    'G1',
    'G2',
    'G3',
    'G4',
    'G5',
    'G6',
    'G7',
    'G8',
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
        _minBudgetCtrl.text = snap.minimumBudgetGhs?.toStringAsFixed(0) ?? '';
        _projectsDoneCtrl.text =
            snap.projectsCompleted > 0 ? snap.projectsCompleted.toString() : '';
        _graTinCtrl.text = snap.graTin ?? '';
        _giaCtrl.text = snap.giaNumber ?? '';
        _gioeCtrl.text = snap.gioeNumber ?? '';
        _gredaCtrl.text = snap.gredaMembership ?? '';
        _ghanaCardCtrl.text = snap.ghanaCardNumber ?? '';
        _businessRegCtrl.text = snap.businessRegNumber ?? '';
        _ncaLicenseCtrl.text = snap.ncaLicenseNumber ?? '';
        setState(() {
          _role = snap.role;
          _region = snap.region.isEmpty ? null : snap.region;
          _isActive = snap.isActive;
          _availableForHire = snap.availableForHire;
          _photoUrl = snap.photoUrl;
          _contractorGrade = snap.contractorGrade;
          _ncaClass = snap.ncaClass;
          _businessRegUrl = snap.businessRegUrl;
          _businessRegStatus = snap.businessRegStatus;
          _insurancePliUrl = snap.insurancePliUrl;
          _insurancePliExpiry = snap.insurancePliExpiry;
          _insurancePiiUrl = snap.insurancePiiUrl;
          _insurancePiiExpiry = snap.insurancePiiExpiry;
          _insuranceStatus = snap.insuranceStatus;
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
    _businessRegCtrl.dispose();
    _ncaLicenseCtrl.dispose();
    super.dispose();
  }

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
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
      final ref =
          FirebaseStorage.instance.ref('profile_photos/builders/$uid.jpg');
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

  /// Upload a document file to Firebase Storage and return its download URL.
  Future<String?> _uploadDoc(String uid, String storagePath) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.isEmpty) return null;
    final f = result.files.first;
    if (f.path == null) return null;

    final ext = f.extension ?? 'pdf';
    final ref = FirebaseStorage.instance.ref('$storagePath.$ext');
    await ref.putFile(
      File(f.path!),
      SettableMetadata(
          contentType: ext == 'pdf' ? 'application/pdf' : 'image/jpeg',),
    );
    return ref.getDownloadURL();
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
        graTin:
            _graTinCtrl.text.trim().isEmpty ? null : _graTinCtrl.text.trim(),
        giaNumber: _giaCtrl.text.trim().isEmpty ? null : _giaCtrl.text.trim(),
        gioeNumber:
            _gioeCtrl.text.trim().isEmpty ? null : _gioeCtrl.text.trim(),
        gredaMembership:
            _gredaCtrl.text.trim().isEmpty ? null : _gredaCtrl.text.trim(),
        ghanaCardNumber: _ghanaCardCtrl.text.trim().isEmpty
            ? null
            : _ghanaCardCtrl.text.trim(),
        contractorGrade: _contractorGrade,
        businessRegNumber: _businessRegCtrl.text.trim().isEmpty
            ? null
            : _businessRegCtrl.text.trim(),
        businessRegUrl: _businessRegUrl,
        businessRegStatus: _businessRegStatus,
        ncaLicenseNumber: _ncaLicenseCtrl.text.trim().isEmpty
            ? null
            : _ncaLicenseCtrl.text.trim(),
        ncaClass: _ncaClass,
        insurancePliUrl: _insurancePliUrl,
        insurancePliExpiry: _insurancePliExpiry,
        insurancePiiUrl: _insurancePiiUrl,
        insurancePiiExpiry: _insurancePiiExpiry,
        insuranceStatus: _insuranceStatus,
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

    final displayName = context.read<AuthService>().currentUser?.displayName;

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
                          ? CachedNetworkImageProvider(_photoUrl!)
                              as ImageProvider
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
              validator: Validators.phone,
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
              validator: Validators.phone,
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
              initialValue: _contractorGrade,
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
            const SizedBox(height: 24),

            // ── Business Registration ────────────────────────────────────────
            Text(
              'Business Registration',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              'Certificate of Incorporation from the Registrar General\'s '
              'Department (RGD/DTIID). Verified by admin.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _businessRegCtrl,
              decoration: const InputDecoration(
                labelText: 'Certificate of Incorporation No. (optional)',
                hintText: 'e.g. CS-123456789',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business_outlined),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 10),
            _DocUploadRow(
              label: 'Certificate of Incorporation',
              url: _businessRegUrl,
              status: _businessRegStatus,
              onUpload: () async {
                final uid = context.read<AuthService>().currentUser?.uid ?? '';
                final url = await _uploadDoc(
                  uid,
                  'profile_docs/$uid/business_reg',
                );
                if (url != null && mounted) {
                  setState(() {
                    _businessRegUrl = url;
                    _businessRegStatus = 'pending';
                  });
                }
              },
            ),
            const SizedBox(height: 24),

            // ── NCA Licence ─────────────────────────────────────────────────
            Text(
              'NCA Licence (National Construction Authority)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              'Required for contractors operating in Ghana. '
              'Upload your NCA certificate for admin verification.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _ncaLicenseCtrl,
              decoration: const InputDecoration(
                labelText: 'NCA Licence Number (optional)',
                hintText: 'e.g. NCA/G3/2024/0012345',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _ncaClass,
              decoration: const InputDecoration(
                labelText: 'NCA Class (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.grade_outlined),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('— Select —')),
                for (final c in kNcaClasses)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _ncaClass = v),
            ),
            const SizedBox(height: 24),

            // ── Insurance ────────────────────────────────────────────────────
            Text(
              'Insurance',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              'Upload Public Liability Insurance (PLI) and/or '
              'Professional Indemnity Insurance (PII) certificates. '
              'Verified insurance boosts your trust score by 15 points.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 10),
            _InsuranceUploadTile(
              label: 'Public Liability Insurance (PLI)',
              url: _insurancePliUrl,
              expiry: _insurancePliExpiry,
              onUpload: () async {
                final uid = context.read<AuthService>().currentUser?.uid ?? '';
                final url = await _uploadDoc(
                  uid,
                  'profile_docs/$uid/insurance_pli',
                );
                if (url != null && mounted) {
                  setState(() {
                    _insurancePliUrl = url;
                    _insuranceStatus = 'pending';
                  });
                }
              },
              onPickExpiry: (picked) =>
                  setState(() => _insurancePliExpiry = picked),
            ),
            const SizedBox(height: 10),
            _InsuranceUploadTile(
              label: 'Professional Indemnity Insurance (PII)',
              url: _insurancePiiUrl,
              expiry: _insurancePiiExpiry,
              onUpload: () async {
                final uid = context.read<AuthService>().currentUser?.uid ?? '';
                final url = await _uploadDoc(
                  uid,
                  'profile_docs/$uid/insurance_pii',
                );
                if (url != null && mounted) {
                  setState(() {
                    _insurancePiiUrl = url;
                    _insuranceStatus = 'pending';
                  });
                }
              },
              onPickExpiry: (picked) =>
                  setState(() => _insurancePiiExpiry = picked),
            ),
            const SizedBox(height: 24),

            // ── Project Portfolio ────────────────────────────────────────────
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.photo_library_outlined,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              title: const Text('Project Portfolio'),
              subtitle: const Text(
                'Add past projects with photos and contract value.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/account/portfolio'),
            ),
            const Divider(),
            const SizedBox(height: 10),

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
                final tier =
                    auth.currentUser?.subscriptionTier ?? SubscriptionTier.free;
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

// ── Document upload row ───────────────────────────────────────────────────────

class _DocUploadRow extends StatelessWidget {
  const _DocUploadRow({
    required this.label,
    required this.url,
    required this.status,
    required this.onUpload,
  });

  final String label;
  final String? url;
  final String status;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'verified':
        statusColor = Colors.green;
        statusLabel = 'Verified';
      case 'pending':
        statusColor = Colors.orange;
        statusLabel = 'Pending review';
      case 'rejected':
        statusColor = cs.error;
        statusLabel = 'Rejected';
      default:
        statusColor = cs.outline;
        statusLabel = 'Not submitted';
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onUpload,
            icon: const Icon(Icons.upload_file_outlined, size: 18),
            label: Text(
              url != null ? 'Replace $label' : 'Upload $label',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            statusLabel,
            style: TextStyle(
              fontSize: 11,
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Insurance upload tile with expiry picker ──────────────────────────────────

class _InsuranceUploadTile extends StatelessWidget {
  const _InsuranceUploadTile({
    required this.label,
    required this.url,
    required this.expiry,
    required this.onUpload,
    required this.onPickExpiry,
  });

  final String label;
  final String? url;
  final DateTime? expiry;
  final VoidCallback onUpload;
  final void Function(DateTime picked) onPickExpiry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onUpload,
                icon: const Icon(Icons.upload_file_outlined, size: 16),
                label: Text(
                  url != null ? 'Replace document' : 'Upload certificate',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate:
                      expiry ?? DateTime.now().add(const Duration(days: 365)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                );
                if (picked != null) onPickExpiry(picked);
              },
              icon: const Icon(Icons.event_outlined, size: 16),
              label: Text(
                expiry != null
                    ? DateFormat('d MMM yy').format(expiry!)
                    : 'Expiry',
              ),
            ),
          ],
        ),
        if (url != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Document uploaded${expiry != null ? " · Expires ${DateFormat("d MMM yyyy").format(expiry!)}" : ""}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.green,
                  ),
            ),
          ),
      ],
    );
  }
}
