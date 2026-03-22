// lib/features/account/pm_profile_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/pm_profile.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/pm_profile_service.dart';
import '../../core/services/regional_index_provider.dart';
import '../../widgets/validators.dart';

class PmProfilePage extends StatefulWidget {
  const PmProfilePage({super.key});

  @override
  State<PmProfilePage> createState() => _PmProfilePageState();
}

class _PmProfilePageState extends State<PmProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _bioCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _yearsCtrl = TextEditingController();
  final _specializationsCtrl = TextEditingController();

  PmRole _role = PmRole.architect;
  String? _region;
  bool _isActive = true;
  bool _saving = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final auth = context.read<AuthService>();
    final service = context.read<PmProfileService>();
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
        _locationCtrl.text = snap.location ?? '';
        _yearsCtrl.text = snap.yearsExperience?.toString() ?? '';
        _specializationsCtrl.text = snap.specializations.join(', ');
        setState(() {
          _role = snap.role;
          _region = snap.region.isEmpty ? null : snap.region;
          _isActive = snap.isActive;
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
    _locationCtrl.dispose();
    _yearsCtrl.dispose();
    _specializationsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthService>();
      final service = context.read<PmProfileService>();
      final user = auth.currentUser!;
      final now = DateTime.now();

      final specializations = _specializationsCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final profile = PmProfile(
        uid: user.uid,
        displayName: user.displayName,
        role: _role,
        bio: _bioCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        email: user.email,
        location: _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
        region: _region ?? '',
        specializations: specializations,
        isActive: _isActive,
        yearsExperience: int.tryParse(_yearsCtrl.text.trim()),
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('PM Profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Your public profile is visible to property owners looking for '
              'a Project Manager.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 20),

            // Role
            DropdownButtonFormField<PmRole>(
              initialValue: _role,
              decoration: const InputDecoration(
                labelText: 'Professional role *',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final r in PmRole.values)
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
              validator: (v) =>
                  (v == null || v.trim().length < 20)
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

            // Active toggle
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Visible in PM Marketplace'),
              subtitle: const Text(
                'Turn off to hide your profile from property owners.',
              ),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
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
