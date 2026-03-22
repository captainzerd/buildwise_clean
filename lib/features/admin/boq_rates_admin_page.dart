// lib/features/admin/boq_rates_admin_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/models/boq_rate_config.dart';

class BoqRatesAdminPage extends StatefulWidget {
  const BoqRatesAdminPage({super.key});

  @override
  State<BoqRatesAdminPage> createState() => _BoqRatesAdminPageState();
}

class _BoqRatesAdminPageState extends State<BoqRatesAdminPage> {
  final _formKey = GlobalKey<FormState>();
  final _db = FirebaseFirestore.instance;

  bool _loading = true;
  bool _saving = false;
  DateTime? _updatedAt;
  String? _error;

  // Controllers for each rate field. Keyed by "category.key".
  final _controllers = <String, TextEditingController>{};

  // Category metadata: label, description, unit hint per key
  static const _categories = <String, _CategoryMeta>{
    'substructure': _CategoryMeta(
      label: 'Substructure / Foundation',
      icon: Icons.foundation,
      rates: {
        'excavation': ('Excavation to reduced level & strip trenches', 'GHS/m³'),
        'blinding': ('Blinding concrete (50mm lean mix 1:3:6)', 'GHS/m³'),
        'dpm': ('Polythene damp-proof membrane (1000g)', 'GHS/m²'),
        'antiTermite': ('Anti-termite chemical treatment', 'GHS/m²'),
        'concrete': ('C25 in-situ concrete — footings & ground slab', 'GHS/m³'),
        'steel': ('Reinforcement bars Y12–Y16', 'GHS/ton'),
        'formwork': ('Softwood formwork to foundation walls', 'GHS/m²'),
        'hardcore': ('Hardcore fill & compaction (150mm)', 'GHS/m²'),
        'backfill': ('Earthwork backfill after foundation', 'GHS/m³'),
      },
    ),
    'superstructure': _CategoryMeta(
      label: 'Superstructure / Walling',
      icon: Icons.apartment,
      rates: {
        'blocks': ('6" hollow sandcrete blocks (supply)', 'GHS/block'),
        'blockLabour': ('Block-laying labour', 'GHS/block'),
        'cement': ('OPC cement (50 kg bag)', 'GHS/bag'),
        'sand': ('River/pit sand', 'GHS/m³'),
        'steel': ('Reinforcement bars — columns & ring beam', 'GHS/ton'),
        'concrete': ('C25 concrete — columns, ring beam & suspended slab', 'GHS/m³'),
      },
    ),
    'roofing': _CategoryMeta(
      label: 'Roofing',
      icon: Icons.roofing,
      rates: {
        'aluminiumSheets': ('Long-span aluminium roofing sheets (supply & fix)', 'GHS/m²'),
        'purlins': ('Purlins & battens (600mm c/c)', 'GHS/m²'),
        'rafters': ('Timber rafters (50×100mm)', 'GHS/lin m'),
        'fascia': ('Timber/UPVC fascia board', 'GHS/lin m'),
        'gutters': ('UPVC half-round gutters (supply & fix)', 'GHS/lin m'),
        'downpipes': ('UPVC downpipes incl. brackets & shoe', 'GHS/No.'),
        'ceiling': ('Ceiling board (Gyproc/POP) incl. framing', 'GHS/m²'),
      },
    ),
    'finishes': _CategoryMeta(
      label: 'Finishes',
      icon: Icons.brush,
      rates: {
        'plaster': ('Sand/cement plaster — walls (2 coats)', 'GHS/m²'),
        'screed': ('Cement/sand floor screed (50mm)', 'GHS/m²'),
        'tiles': ('Ceramic floor tiles — all rooms (supply & lay)', 'GHS/m²'),
        'wallTiles': ('Glazed wall tiles — bathrooms & kitchen', 'GHS/m²'),
        'paint': ('Interior & exterior paint (2 coats emulsion/gloss)', 'GHS/m²'),
        'ceiling': ('POP/gypsum ceiling (flat with cornice)', 'GHS/m²'),
        'skirting': ('Tile skirting (supply & fix)', 'GHS/lin m'),
        'doors': ('Flush door incl. frame & ironmongery', 'GHS/door'),
        'windows': ('Aluminium window incl. louvres & fixings', 'GHS/window'),
      },
    ),
    'mep': _CategoryMeta(
      label: 'Mechanical & Electrical',
      icon: Icons.electrical_services,
      rates: {
        'wiring': ('Electrical conduit wiring, cables & accessories', 'GHS/m²'),
        'consumerUnit': ('Consumer unit / distribution board (12-way)', 'GHS/No.'),
        'powerPoints': ('13A double power points incl. conduit run', 'GHS/No.'),
        'lightFittings': ('LED light fittings incl. switches & wiring', 'GHS/No.'),
        'plumbing': ('Plumbing — CPVC/uPVC supply & drainage', 'GHS/m²'),
        'overheadTank': ('2000L polyethylene overhead tank & galv. stand', 'GHS/No.'),
        'pump': ('Surface pump incl. pressure switch & fittings', 'GHS/No.'),
        'sanitarySet': ('Sanitary set — WC, pedestal basin, shower & taps', 'GHS/set'),
        'septicTank': ('Concrete septic tank (2-chamber)', 'GHS/No.'),
      },
    ),
    'external': _CategoryMeta(
      label: 'External Works',
      icon: Icons.landscape,
      rates: {
        'wallPct': ('Compound wall & gate', '% of external total'),
        'pavingPct': ('Paving / driveway', '% of external total'),
        'landscapingPct': ('Landscaping & site clearance', '% of external total'),
      },
    ),
    'generic': _CategoryMeta(
      label: 'Generic Phases',
      icon: Icons.category,
      rates: {
        'materialsPct': ('Materials allowance', '% of phase total'),
        'labourPct': ('Labour allowance', '% of phase total'),
      },
    ),
  };

  @override
  void initState() {
    super.initState();
    _initControllers(BoqRateConfig.defaults());
    _loadRates();
  }

  void _initControllers(BoqRateConfig config) {
    void addAll(String cat, Map<String, double> map) {
      for (final e in map.entries) {
        final key = '$cat.${e.key}';
        _controllers[key] = TextEditingController(text: e.value.toString());
      }
    }

    addAll('substructure', config.substructure);
    addAll('superstructure', config.superstructure);
    addAll('roofing', config.roofing);
    addAll('finishes', config.finishes);
    addAll('mep', config.mep);
    addAll('external', config.external);
    addAll('generic', config.generic);
  }

  void _updateControllers(BoqRateConfig config) {
    void setAll(String cat, Map<String, double> map) {
      for (final e in map.entries) {
        _controllers['$cat.${e.key}']?.text = e.value.toString();
      }
    }

    setAll('substructure', config.substructure);
    setAll('superstructure', config.superstructure);
    setAll('roofing', config.roofing);
    setAll('finishes', config.finishes);
    setAll('mep', config.mep);
    setAll('external', config.external);
    setAll('generic', config.generic);
  }

  Future<void> _loadRates() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final doc = await _db.collection('boq_rates').doc('default').get();
      if (doc.exists) {
        final config = BoqRateConfig.fromDoc(doc);
        _updateControllers(config);
        final raw = (doc.data() as Map<String, dynamic>)['updatedAt'];
        if (raw is Timestamp) {
          setState(() => _updatedAt = raw.toDate());
        }
      }
    } catch (e) {
      setState(() => _error = 'Failed to load rates: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Map<String, double> _readCategory(String cat) {
    final result = <String, double>{};
    final catMeta = _categories[cat]!;
    for (final key in catMeta.rates.keys) {
      final text = _controllers['$cat.$key']?.text ?? '';
      result[key] = double.tryParse(text) ?? 0;
    }
    return result;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final config = BoqRateConfig(
        substructure: _readCategory('substructure'),
        superstructure: _readCategory('superstructure'),
        roofing: _readCategory('roofing'),
        finishes: _readCategory('finishes'),
        mep: _readCategory('mep'),
        external: _readCategory('external'),
        generic: _readCategory('generic'),
      );

      final map = config.toMap();
      map['updatedAt'] = FieldValue.serverTimestamp();

      await _db.collection('boq_rates').doc('default').set(map);

      setState(() => _updatedAt = DateTime.now());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('BOQ rates saved successfully.')),
        );
      }
    } catch (e) {
      setState(() => _error = 'Save failed: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BOQ Unit Rates'),
        bottom: _updatedAt != null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Last updated: ${_updatedAt!.toLocal().toString().substring(0, 16)}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              )
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ..._categories.entries.map((catEntry) {
                    final catKey = catEntry.key;
                    final meta = catEntry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        leading: Icon(meta.icon),
                        title: Text(meta.label),
                        initiallyExpanded: true,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              children: meta.rates.entries.map((rateEntry) {
                                final rateKey = rateEntry.key;
                                final (desc, unit) = rateEntry.value;
                                final ctrlKey = '$catKey.$rateKey';
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: TextFormField(
                                    controller: _controllers[ctrlKey],
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: desc,
                                      suffixText: unit,
                                      border: const OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Required';
                                      }
                                      if (double.tryParse(v) == null) {
                                        return 'Enter a valid number';
                                      }
                                      return null;
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Save Rates'),
            ),
    );
  }
}

// ── Internal metadata types ────────────────────────────────────────────────────

class _CategoryMeta {
  final String label;
  final IconData icon;
  final Map<String, (String, String)> rates;

  const _CategoryMeta({
    required this.label,
    required this.icon,
    required this.rates,
  });
}
