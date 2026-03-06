import '../../core/config/service_locator.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../project/create_project_page.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/boq_item.dart';
import '../../core/services/boq_service.dart';
import 'boq_page.dart';

import 'edit_saved_estimate_page.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

class EstimateViewPage extends StatelessWidget {
  const EstimateViewPage({
    super.key,
    this.projectId,
    this.estimateId,
    this.docRef,
    this.initialData,
  }) : assert(
          docRef != null || (projectId != null && estimateId != null),
          'Provide either docRef or both projectId and estimateId',
        );

  final String? projectId;
  final String? estimateId;
  final DocumentReference<Map<String, dynamic>>? docRef;
  final Map<String, dynamic>? initialData;

  @override
  Widget build(BuildContext context) {
    final docRef = this.docRef ??
        FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .collection('estimates')
            .doc(estimateId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estimate'),
        actions: [
          IconButton(
            tooltip: 'Share as PDF',
            onPressed: () async => _shareAsPdf(context, docRef),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          if (projectId != null && estimateId != null)
            IconButton(
              tooltip: 'Edit (title/notes/budget)',
              onPressed: () async {
                final snap = await docRef.get();
                if (!snap.exists) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Estimate not found.')),
                    );
                  }
                  return;
                }
                final initial = snap.data() ?? {};
                if (!context.mounted) return;
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EditSavedEstimatePage(
                      projectId: projectId!,
                      estimateId: estimateId!,
                      initial: initial,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.edit_outlined),
            ),
          IconButton(
            tooltip: 'Delete',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Delete estimate?'),
                  content: const Text('This action cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton.tonal(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await docRef.delete();
                if (context.mounted) Navigator.of(context).maybePop();
              }
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: docRef.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              initialData == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final m =
              (snap.data?.data() as Map<String, dynamic>?) ?? initialData ?? {};
          if (m.isEmpty) {
            return const Center(child: Text('Estimate not found.'));
          }

          final title = (m['projectName'] as String?)?.trim();
          final notes = (m['notes'] as String?)?.trim();
          final totalGhs = (m['grandTotalGhs'] as num?)?.toDouble();
          final fxSym = m['fxSymbol'] as String? ?? '';
          final totalFx = (m['grandTotalFx'] as num?)?.toDouble();
          final region = m['region'] as String? ?? '';
          final bt = m['buildingType'] as String? ?? '';
          final q = m['quality'] as String? ?? '';
          final foundation = m['foundation'] as String? ?? '';
          final soil = m['soil'] as String? ?? '';
          final floors = (m['floors'] as List?) ?? const [];
          final budget = (m['budgetAmount'] as num?)?.toDouble();

          // Cost breakdown maps (saved by EstimateController.toMap())
          final phaseBreakdown = (m['phaseBreakdownGhs'] as Map?)
                  ?.cast<String, dynamic>() ??
              const {};
          final addOns =
              (m['addOnsGhs'] as Map?)?.cast<String, dynamic>() ?? const {};
          final prelimGhs = (m['preliminariesGhs'] as num?)?.toDouble() ?? 0;
          final ohpGhs = (m['ohpGhs'] as num?)?.toDouble() ?? 0;
          final contingencyGhs =
              (m['contingencyGhs'] as num?)?.toDouble() ?? 0;
          final taxLines =
              (m['taxLinesGhs'] as Map?)?.cast<String, dynamic>() ?? const {};
          final permitGhs = (m['permitGhs'] as num?)?.toDouble() ?? 0;

          String ghsFmt(dynamic v) =>
              '₵ ${(v as num?)?.toDouble().toStringAsFixed(0) ?? '--'}';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (title != null && title.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              _kv(
                'Grand Total (GHS)',
                '₵ ${totalGhs?.toStringAsFixed(0) ?? '--'}',
              ),
              _kv(
                'Grand Total (${m['fxCode'] ?? 'FX'})',
                '${fxSym.isNotEmpty ? fxSym : ''} ${totalFx?.toStringAsFixed(0) ?? '--'}',
              ),
              if (budget != null)
                _kv('Budget (GHS)', '₵ ${budget.toStringAsFixed(0)}'),
              const Divider(height: 24),

              // ── Inputs ────────────────────────────────────────────────────
              Text('Inputs', style: Theme.of(context).textTheme.titleMedium),
              _kv('Region', region),
              _kv('Building Type', bt),
              _kv('Quality', q),
              _kv('Foundation', foundation),
              _kv('Soil', soil),
              const SizedBox(height: 8),
              Text('Floors', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              ...List.generate(floors.length, (i) {
                final f = floors[i] as Map? ?? {};
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '• Floor ${i + 1}: ${f['areaM2'] ?? '--'} m² × ${f['heightM'] ?? '--'} m',
                  ),
                );
              }),

              // ── Phase breakdown ───────────────────────────────────────────
              if (phaseBreakdown.isNotEmpty) ...[
                const Divider(height: 28),
                Text(
                  'Phase Breakdown',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                ...phaseBreakdown.entries.map(
                  (e) => _ExpandablePhaseRow(
                    phase: e.key,
                    amountLabel: ghsFmt(e.value),
                  ),
                ),
              ],

              // ── Add-ons ───────────────────────────────────────────────────
              if (addOns.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'External Works',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                ...addOns.entries
                    .map((e) => _kv(e.key, ghsFmt(e.value))),
              ],

              // ── Overheads & taxes ─────────────────────────────────────────
              const Divider(height: 24),
              Text(
                'Overheads & Statutory',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              if (prelimGhs > 0) _kv('Preliminaries', ghsFmt(prelimGhs)),
              if (ohpGhs > 0) _kv('Overhead & Profit', ghsFmt(ohpGhs)),
              if (contingencyGhs > 0) _kv('Contingency', ghsFmt(contingencyGhs)),
              ...taxLines.entries.map((e) => _kv(e.key, ghsFmt(e.value))),
              if (permitGhs > 0) _kv('Permit fees', ghsFmt(permitGhs)),

              if (notes != null && notes.isNotEmpty) ...[
                const Divider(height: 24),
                Text('Notes', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(notes),
              ],
              const Divider(height: 32),
              _findVendorsButton(region: region.isNotEmpty ? region : null),
              const SizedBox(height: 12),
              _createProjectButton(
                title: title,
                totalGhs: totalGhs,
                region: region.isNotEmpty ? region : null,
              ),
              const SizedBox(height: 12),
              if (phaseBreakdown.isNotEmpty)
                _viewBoqButton(
                  phaseBreakdown: phaseBreakdown,
                  floors: floors,
                  savedBoqItems: m['boqItems'] as List?,
                  projectName: title,
                ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  Widget _findVendorsButton({String? region}) {
    return Builder(
      builder: (context) {
        final auth = context.read<AuthService>();
        if (!auth.isSignedIn) return const SizedBox.shrink();
        return SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            onPressed: () => context.push(
              '/vendors',
              extra: region,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.store_outlined, size: 18),
                const SizedBox(width: 8),
                Text(region != null
                    ? 'Find Vendors in $region'
                    : 'Find Vendors',),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _createProjectButton({
    String? title,
    double? totalGhs,
    String? region,
  }) {
    return Builder(
      builder: (context) {
        final auth = context.read<AuthService>();
        if (!auth.isSignedIn) return const SizedBox.shrink();
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CreateProjectPage(
                  initialTitle: title,
                  initialBudget: totalGhs,
                  initialRegion: region,
                ),
              ),
            ),
            icon: const Icon(Icons.add_business_outlined, size: 18),
            label: const Text('Create Project from this Estimate'),
          ),
        );
      },
    );
  }

  Widget _viewBoqButton({
    required Map<String, dynamic> phaseBreakdown,
    required List floors,
    List? savedBoqItems,
    String? projectName,
  }) {
    final floorAreaSqm = floors.fold<double>(
      0,
      (acc, f) => acc + ((f as Map?)?['areaM2'] as num? ?? 0).toDouble(),
    );
    final phaseDoubles = phaseBreakdown.map(
      (k, v) => MapEntry(k, (v as num?)?.toDouble() ?? 0.0),
    );
    // Use the frozen items saved with the estimate when available so the BOQ
    // doesn't change if unit rates are updated in Firestore later.
    final precomputed = savedBoqItems
        ?.map((e) => BoqItem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    return Builder(
      builder: (context) => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => BoqPage(
                phaseBreakdown: phaseDoubles,
                floorAreaSqm: floorAreaSqm > 0 ? floorAreaSqm : 100,
                boqService: sl<BoqService>(),
                precomputedItems: precomputed,
                projectName: projectName,
              ),
            ),
          ),
          icon: const Icon(Icons.table_chart_outlined, size: 18),
          label: const Text('View Bill of Quantities (BoQ)'),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(k, style: const TextStyle(color: Colors.black54)),
            ),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Future<void> _shareAsPdf(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> docRef,
  ) async {
    try {
      final snap = await docRef.get();
      final m = snap.data() ?? initialData ?? {};
      if (m.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nothing to export.')),
          );
        }
        return;
      }

      final pdf = pw.Document();
      final title = (m['projectName'] as String?) ?? 'Estimate';
      final totalGhs = (m['grandTotalGhs'] as num?)?.toDouble() ?? 0;
      final fxSym = m['fxSymbol'] as String? ?? '';
      final totalFx = (m['grandTotalFx'] as num?)?.toDouble() ?? 0;
      final region = m['region'] as String? ?? '';
      final bt = m['buildingType'] as String? ?? '';
      final q = m['quality'] as String? ?? '';
      final foundation = m['foundation'] as String? ?? '';
      final soil = m['soil'] as String? ?? '';
      final floors = (m['floors'] as List?) ?? const [];
      final notes = (m['notes'] as String?)?.trim();

      pw.Widget row(String a, String b, {bool bold = false}) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    a,
                    style: pw.TextStyle(color: PdfColors.grey700),
                  ),
                ),
                pw.Text(
                  b,
                  style: bold
                      ? pw.TextStyle(fontWeight: pw.FontWeight.bold)
                      : null,
                ),
              ],
            ),
          );

      pdf.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 36),
          ),
          build: (ctx) => [
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            row(
              'Grand Total (GHS)',
              '₵ ${totalGhs.toStringAsFixed(2)}',
              bold: true,
            ),
            row(
              'Grand Total (FX)',
              '$fxSym ${totalFx.toStringAsFixed(2)}',
              bold: true,
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Inputs',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            row('Region', region),
            row('Building Type', bt),
            row('Quality', q),
            row('Foundation', foundation),
            row('Soil', soil),
            pw.SizedBox(height: 6),
            pw.Text(
              'Floors',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            ...List.generate(floors.length, (i) {
              final f = floors[i] as Map? ?? {};
              final line =
                  '• Floor ${i + 1}: ${f['areaM2'] ?? '--'} m² × ${f['heightM'] ?? '--'} m';
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 1),
                child: pw.Text(line),
              );
            }),
            if (notes != null && notes.isNotEmpty) ...[
              pw.SizedBox(height: 14),
              pw.Text(
                'Notes',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(notes),
            ],
          ],
        ),
      );

      final Uint8List bytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final safeName = title.replaceAll(RegExp(r'[^a-zA-Z0-9_\- ]'), '_');
      final file = File('${dir.path}/$safeName-$estimateId.pdf');
      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles(
        [
          XFile(
            file.path,
            mimeType: 'application/pdf',
            name: file.uri.pathSegments.last,
          ),
        ],
        text: 'Estimate — $title',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF export failed: $e')),
      );
    }
  }
}

// ── Typical materials per phase (Ghana construction reference) ────────────────

const Map<String, List<String>> _kPhaseMaterials = {
  'Foundation': [
    'Cement (42.5R bags)',
    'Sharp sand',
    'Granite / gravel (chippings)',
    'Reinforcing rods Y12–Y16',
    'Binding wire',
    'Formwork timber & plywood',
    'Hardcore / laterite fill',
  ],
  'Superstructure': [
    'Sandcrete blocks (6" or 9")',
    'Cement (42.5R bags)',
    'Sand (fine)',
    'Reinforcing rods Y10–Y20',
    'Binding wire',
    'DPC membrane',
    'Lintels (pre-cast or cast in-situ)',
  ],
  'Roof': [
    'Roof trusses (timber or steel)',
    'Roofing sheets / clay / concrete tiles',
    'Purlins (timber or galvanised)',
    'Roof nails & bolts',
    'Fascia & barge boards',
    'Gutter & downpipe (PVC / aluminium)',
    'Roofing felt / underlay',
  ],
  'Finishes': [
    'Cement & sand for plastering',
    'Floor tiles or terrazzo',
    'Wall tiles (wet areas)',
    'Paint — interior & exterior',
    'Screeding mix',
    'Ceiling boards (gypsum / PVC)',
    'Ceiling battens',
  ],
  'Electrical': [
    'PVC / XLPE cables (2.5mm², 4mm²)',
    'Consumer unit / distribution board',
    'Switch sockets & plates',
    'Conduit pipes & fittings',
    'Light fittings & bulbs',
    'Earth cable & rods',
  ],
  'Plumbing': [
    'HDPE / PVC pipes & fittings',
    'WC suite, wash-hand basin, bath / shower',
    'Electric or solar water heater',
    'Ball valves & gate valves',
    'Overhead / underground water tank',
    'Soak-away rings & cover slab',
  ],
  'Joinery': [
    'Timber / aluminium / UPVC door frames & leaves',
    'Louvre & casement / sliding windows',
    'Door hardware (hinges, locks, handles)',
    'Kitchen cabinets & countertop',
    'Wardrobes (built-in)',
  ],
  'External works': [
    'Concrete kerbs & edging',
    'Paving blocks / interlocking tiles',
    'Compound wall blocks & cement',
    'Septic tank rings & cover slabs',
    'Entrance gate & posts',
    'Landscaping / topsoil',
  ],
};

// ── Expandable phase row ───────────────────────────────────────────────────────

class _ExpandablePhaseRow extends StatefulWidget {
  const _ExpandablePhaseRow({
    required this.phase,
    required this.amountLabel,
  });

  final String phase;
  final String amountLabel;

  @override
  State<_ExpandablePhaseRow> createState() => _ExpandablePhaseRowState();
}

class _ExpandablePhaseRowState extends State<_ExpandablePhaseRow> {
  bool _expanded = false;

  // Find materials by matching the start of the phase name (case-insensitive).
  List<String> get _materials {
    final key = _kPhaseMaterials.keys.firstWhere(
      (k) => widget.phase.toLowerCase().startsWith(k.toLowerCase()),
      orElse: () => '',
    );
    return key.isNotEmpty ? _kPhaseMaterials[key]! : const [];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasMaterials = _materials.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: hasMaterials ? () => setState(() => _expanded = !_expanded) : null,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.phase,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                Text(
                  widget.amountLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (hasMaterials) ...[
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: cs.outline,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_expanded && hasMaterials)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Typical materials',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: cs.outline),
                ),
                const SizedBox(height: 6),
                for (final m in _materials)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: cs.primary)),
                        Expanded(
                          child: Text(
                            m,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
