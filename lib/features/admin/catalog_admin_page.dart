// lib/features/admin/catalog_admin_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/catalog_version.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/catalog_service.dart';

class CatalogAdminPage extends StatefulWidget {
  const CatalogAdminPage({super.key});

  @override
  State<CatalogAdminPage> createState() => _CatalogAdminPageState();
}

class _CatalogAdminPageState extends State<CatalogAdminPage> {
  final _formKey = GlobalKey<FormState>();

  // ── Base rates ──
  final _economyCtrl = TextEditingController();
  final _standardCtrl = TextEditingController();
  final _premiumCtrl = TextEditingController();

  // ── Add-on rates ──
  final _wallCtrl = TextEditingController();
  final _drivewayCtrl = TextEditingController();
  final _septicCtrl = TextEditingController();

  // ── Defaults ──
  final _prelimCtrl = TextEditingController();
  final _ohpCtrl = TextEditingController();
  final _permitCtrl = TextEditingController();
  final _contingencyCtrl = TextEditingController();

  bool _initialized = false;
  bool _publishing = false;
  String? _successMessage;
  String? _errorMessage;

  @override
  void dispose() {
    _economyCtrl.dispose();
    _standardCtrl.dispose();
    _premiumCtrl.dispose();
    _wallCtrl.dispose();
    _drivewayCtrl.dispose();
    _septicCtrl.dispose();
    _prelimCtrl.dispose();
    _ohpCtrl.dispose();
    _permitCtrl.dispose();
    _contingencyCtrl.dispose();
    super.dispose();
  }

  void _initFromVersion(CatalogVersion v) {
    _economyCtrl.text =
        (v.baseRatesPerM2['Economy'] ?? 3500.0).toStringAsFixed(0);
    _standardCtrl.text =
        (v.baseRatesPerM2['Standard'] ?? 4500.0).toStringAsFixed(0);
    _premiumCtrl.text =
        (v.baseRatesPerM2['Premium'] ?? 6000.0).toStringAsFixed(0);
    _wallCtrl.text =
        (v.addOnRates['compoundWallPerM'] ?? 1200.0).toStringAsFixed(0);
    _drivewayCtrl.text =
        (v.addOnRates['drivewayPerM2'] ?? 350.0).toStringAsFixed(0);
    _septicCtrl.text =
        (v.addOnRates['septicLump'] ?? 18000.0).toStringAsFixed(0);
    _prelimCtrl.text = v.preliminariesDefaultPct.toStringAsFixed(1);
    _ohpCtrl.text = v.ohpDefaultPct.toStringAsFixed(1);
    _permitCtrl.text = v.permitDefaultPct.toStringAsFixed(1);
    _contingencyCtrl.text = v.contingencyDefaultPct.toStringAsFixed(1);
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _publishing = true;
      _successMessage = null;
      _errorMessage = null;
    });

    try {
      final catalog = context.read<CatalogService>();
      final auth = context.read<AuthService>();
      final current = catalog.activeVersion;

      final now = DateTime.now();
      final versionId =
          'v_${now.year}_${now.month.toString().padLeft(2, '0')}'
          '_${now.day.toString().padLeft(2, '0')}'
          '_${now.millisecondsSinceEpoch % 100000}';

      final newVersion = CatalogVersion(
        id: versionId,
        effectiveDate: now,
        publishedBy: auth.currentUser?.uid,
        publishedByName: auth.currentUser?.displayName,
        baseRatesPerM2: {
          'Economy': double.parse(_economyCtrl.text),
          'Standard': double.parse(_standardCtrl.text),
          'Premium': double.parse(_premiumCtrl.text),
        },
        regionalIndices: current.regionalIndices,
        addOnRates: {
          'compoundWallPerM': double.parse(_wallCtrl.text),
          'drivewayPerM2': double.parse(_drivewayCtrl.text),
          'septicLump': double.parse(_septicCtrl.text),
        },
        phaseWeights: current.phaseWeights,
        preliminariesDefaultPct: double.parse(_prelimCtrl.text),
        ohpDefaultPct: double.parse(_ohpCtrl.text),
        permitDefaultPct: double.parse(_permitCtrl.text),
        contingencyDefaultPct: double.parse(_contingencyCtrl.text),
        taxLines: current.taxLines,
      );

      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // Write new version doc.
      batch.set(
        db.collection('cost_catalog').doc(versionId),
        newVersion.toMap(),
      );

      // Update config to point to the new version.
      batch.set(
        db.collection('cost_catalog').doc('config'),
        {'activeVersion': versionId},
        SetOptions(merge: true),
      );

      await batch.commit();

      // Refresh the in-memory catalog.
      await catalog.refresh();

      if (!mounted) return;
      setState(() {
        _successMessage = 'Version "$versionId" published successfully.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Publish failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _publishing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogService>();
    final version = catalog.activeVersion;

    if (!_initialized) {
      _initialized = true;
      _initFromVersion(version);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalog Management'),
        actions: [
          if (catalog.isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Refresh from Firestore',
            icon: const Icon(Icons.refresh),
            onPressed: catalog.isLoading
                ? null
                : () async {
                    await catalog.refresh();
                    if (!mounted) return;
                    setState(() => _initFromVersion(catalog.activeVersion));
                  },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Current version card
            _CurrentVersionCard(version: version),
            const SizedBox(height: 16),

            // Success / error banners
            if (_successMessage != null)
              _Banner(
                message: _successMessage!,
                color: Colors.green.shade50,
                textColor: Colors.green.shade900,
                icon: Icons.check_circle_outline,
              ),
            if (_errorMessage != null)
              _Banner(
                message: _errorMessage!,
                color: Theme.of(context).colorScheme.errorContainer,
                textColor: Theme.of(context).colorScheme.onErrorContainer,
                icon: Icons.error_outline,
              ),

            // ── Unit rates ──
            _section(
              context,
              title: 'Unit Rates (GHS / m²)',
              children: [
                _rateField(
                  controller: _economyCtrl,
                  label: 'Economy',
                  hint: '3500',
                ),
                const SizedBox(height: 12),
                _rateField(
                  controller: _standardCtrl,
                  label: 'Standard',
                  hint: '4500',
                ),
                const SizedBox(height: 12),
                _rateField(
                  controller: _premiumCtrl,
                  label: 'Premium',
                  hint: '6000',
                ),
              ],
            ),

            // ── Add-on rates ──
            _section(
              context,
              title: 'Add-on Rates',
              children: [
                _rateField(
                  controller: _wallCtrl,
                  label: 'Compound wall (GHS/m)',
                  hint: '1200',
                ),
                const SizedBox(height: 12),
                _rateField(
                  controller: _drivewayCtrl,
                  label: 'Driveway (GHS/m²)',
                  hint: '350',
                ),
                const SizedBox(height: 12),
                _rateField(
                  controller: _septicCtrl,
                  label: 'Septic/Soakaway (lump sum GHS)',
                  hint: '18000',
                ),
              ],
            ),

            // ── Default percentages ──
            _section(
              context,
              title: 'Default Percentages',
              children: [
                _pctField(
                  controller: _prelimCtrl,
                  label: 'Preliminaries %',
                ),
                const SizedBox(height: 12),
                _pctField(controller: _ohpCtrl, label: 'OHP %'),
                const SizedBox(height: 12),
                _pctField(controller: _permitCtrl, label: 'Permit %'),
                const SizedBox(height: 12),
                _pctField(
                  controller: _contingencyCtrl,
                  label: 'Contingency %',
                ),
              ],
            ),

            // ── Tax lines (display only) ──
            _section(
              context,
              title: 'Tax Lines (read-only)',
              children: [
                for (final t in version.taxLines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(t.name),
                        Text('${t.pct.toStringAsFixed(1)}%'),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  'Tax lines are managed via Firestore directly.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),

            // ── Regional indices (display only) ──
            _section(
              context,
              title: 'Regional Indices (read-only)',
              children: [
                for (final e in version.regionalIndices.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key),
                        Text(e.value.toStringAsFixed(2)),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  'Regional indices are managed via Firestore directly.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Publish button
            FilledButton.icon(
              onPressed: _publishing ? null : _publish,
              icon: _publishing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.publish),
              label: Text(_publishing ? 'Publishing…' : 'Publish New Version'),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _rateField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, hintText: hint),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (v) {
        final n = double.tryParse(v ?? '');
        if (n == null || n <= 0) return 'Enter a positive number';
        return null;
      },
    );
  }

  Widget _pctField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, suffixText: '%'),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (v) {
        final n = double.tryParse(v ?? '');
        if (n == null || n < 0 || n > 100) return 'Enter 0–100';
        return null;
      },
    );
  }
}

// ── Current version card ───────────────────────────────────────────────────────

class _CurrentVersionCard extends StatelessWidget {
  const _CurrentVersionCard({required this.version});
  final CatalogVersion version;

  @override
  Widget build(BuildContext context) {
    final isBuiltIn = version.id == 'built-in';
    final colorScheme = Theme.of(context).colorScheme;
    final dateStr = DateFormat('d MMM yyyy').format(version.effectiveDate);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isBuiltIn
            ? colorScheme.tertiaryContainer
            : colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isBuiltIn ? Icons.info_outline : Icons.check_circle_outline,
                color: isBuiltIn
                    ? colorScheme.onTertiaryContainer
                    : colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isBuiltIn ? 'Using built-in defaults' : 'Active version',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isBuiltIn
                        ? colorScheme.onTertiaryContainer
                        : colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _infoRow(
            context,
            'Version ID',
            version.id,
            isBuiltIn: isBuiltIn,
          ),
          _infoRow(
            context,
            'Effective',
            dateStr,
            isBuiltIn: isBuiltIn,
          ),
          if (version.publishedByName != null)
            _infoRow(
              context,
              'Published by',
              version.publishedByName!,
              isBuiltIn: isBuiltIn,
            ),
        ],
      ),
    );
  }

  Widget _infoRow(
    BuildContext context,
    String label,
    String value, {
    required bool isBuiltIn,
  }) {
    final color = isBuiltIn
        ? Theme.of(context).colorScheme.onTertiaryContainer
        : Theme.of(context).colorScheme.onPrimaryContainer;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: color, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Banner ─────────────────────────────────────────────────────────────────────

class _Banner extends StatelessWidget {
  const _Banner({
    required this.message,
    required this.color,
    required this.textColor,
    required this.icon,
  });

  final String message;
  final Color color;
  final Color textColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: textColor, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
