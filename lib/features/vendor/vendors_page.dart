import '../../core/config/service_locator.dart';
// lib/features/vendor/vendors_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/project.dart';
import '../../core/models/rfq_request.dart';
import '../../core/models/vendor.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/project_service.dart';
import '../../core/services/rfq_service.dart';
import '../../core/services/vendor_service.dart';

class VendorsPage extends StatefulWidget {
  const VendorsPage({super.key, this.initialRegion, this.embedded = false});

  /// Pre-filter by region (e.g. launched from an estimate).
  final String? initialRegion;

  /// When [true] the page is hosted inside a tab shell that already provides
  /// an AppBar, so this widget omits its own.
  final bool embedded;

  @override
  State<VendorsPage> createState() => _VendorsPageState();
}

class _VendorsPageState extends State<VendorsPage> {
  String _search = '';
  String? _categoryFilter;

  List<Vendor> _applyFilters(List<Vendor> all) {
    var list = all;
    if (widget.initialRegion != null) {
      list = list
          .where((v) => v.region == null || v.region == widget.initialRegion)
          .toList();
    }
    if (_categoryFilter != null) {
      list = list.where((v) => v.category == _categoryFilter).toList();
    }
    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      list = list
          .where((v) =>
              v.name.toLowerCase().contains(q) ||
              (v.category?.toLowerCase().contains(q) ?? false) ||
              v.trades.any((t) => t.toLowerCase().contains(q)) ||
              (v.location?.toLowerCase().contains(q) ?? false),)
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<VendorService>();

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: widget.initialRegion != null
                  ? Text('Vendors in ${widget.initialRegion}')
                  : const Text('Vendors'),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search vendors…',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Vendor>>(
              stream: service.listAll(),
              builder: (ctx, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final all = snap.data!;
                final categories = {
                  for (final v in all)
                    if (v.category != null && v.category!.isNotEmpty)
                      v.category!,
                }.toList()
                  ..sort();

                final vendors = _applyFilters(all);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (categories.isNotEmpty)
                      _CategoryFilterBar(
                        categories: categories,
                        selected: _categoryFilter,
                        onSelected: (c) =>
                            setState(() => _categoryFilter = c),
                      ),
                    if (vendors.isEmpty)
                      const Expanded(child: _EmptyState())
                    else
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isTablet = constraints.maxWidth >= 600;
                            const padding =
                                EdgeInsets.fromLTRB(16, 12, 16, 96);
                            Widget buildCard(int i) => _VendorCard(
                                  vendor: vendors[i],
                                  service: service,
                                  onEdit: () => _showEditVendor(
                                    context,
                                    service,
                                    vendors[i],
                                  ),
                                );
                            return isTablet
                                ? GridView.builder(
                                    padding: padding,
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 10,
                                      crossAxisSpacing: 10,
                                      childAspectRatio: 2.0,
                                    ),
                                    itemCount: vendors.length,
                                    itemBuilder: (_, i) => buildCard(i),
                                  )
                                : ListView.separated(
                                    padding: padding,
                                    itemCount: vendors.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (_, i) => buildCard(i),
                                  );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add vendor',
        onPressed: () => _showAddVendor(context, service),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddVendor(BuildContext context, VendorService service) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddVendorSheet(service: service),
    );
  }

  void _showEditVendor(BuildContext context, VendorService service, Vendor vendor) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddVendorSheet(service: service, vendor: vendor),
    );
  }
}

// ─────────────────────────────────────────────
// Category filter chips
// ─────────────────────────────────────────────

class _CategoryFilterBar extends StatelessWidget {
  const _CategoryFilterBar({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<String> categories;
  final String? selected;
  final void Function(String?) onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            label: const Text('All'),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
          const SizedBox(width: 6),
          for (final cat in categories) ...[
            FilterChip(
              label: Text(cat),
              selected: selected == cat,
              onSelected: (_) =>
                  onSelected(selected == cat ? null : cat),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Vendor card
// ─────────────────────────────────────────────

class _VendorCard extends StatelessWidget {
  const _VendorCard({
    required this.vendor,
    required this.service,
    required this.onEdit,
  });
  final Vendor vendor;
  final VendorService service;
  final VoidCallback onEdit;

  void _showRequestQuote(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _NewRfqSheet(vendor: vendor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    vendor.name.isNotEmpty
                        ? vendor.name[0].toUpperCase()
                        : '?',
                    style:
                        TextStyle(color: cs.onPrimaryContainer),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vendor.name,
                        style:
                            Theme.of(context).textTheme.titleMedium,
                      ),
                      if (vendor.category != null)
                        Text(
                          vendor.category!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: cs.outline),
                        ),
                    ],
                  ),
                ),
                _StarRating(
                  rating: vendor.rating,
                  count: vendor.ratingsCount,
                ),
              ],
            ),
            if (vendor.location != null || vendor.region != null) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                children: [
                  if (vendor.location != null)
                    _Contact(
                      icon: Icons.place_outlined,
                      label: vendor.location!,
                    ),
                  if (vendor.region != null)
                    _Contact(
                      icon: Icons.map_outlined,
                      label: vendor.region!,
                    ),
                ],
              ),
            ],
            if (vendor.trades.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final t in vendor.trades)
                    Chip(
                      label: Text(t),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
            ],
            if (vendor.phone != null || vendor.email != null ||
                vendor.whatsappNumber != null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                children: [
                  if (vendor.phone != null)
                    _Contact(
                        icon: Icons.phone_outlined,
                        label: vendor.phone!,),
                  if (vendor.email != null)
                    _Contact(
                        icon: Icons.email_outlined,
                        label: vendor.email!,),
                  if (vendor.website != null)
                    _Contact(
                        icon: Icons.language_outlined,
                        label: vendor.website!,),
                ],
              ),
            ],
            if (vendor.whatsappNumber != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.chat_outlined, size: 16),
                  label: const Text('WhatsApp'),
                  onPressed: () => _launchWhatsApp(
                    context,
                    vendor.whatsappNumber!,
                    'Hi ${vendor.name}, I found you on BuildWise.',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () => _showRequestQuote(context),
                child: const Text('Request Quote'),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.star_outline, size: 16),
                  label: const Text('Rate'),
                  onPressed: () =>
                      _showRateDialog(context, vendor, service),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                  onPressed: onEdit,
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: cs.error,
                  ),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Delete'),
                  onPressed: () =>
                      _confirmDelete(context, vendor, service),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchWhatsApp(
    BuildContext context,
    String number,
    String message,
  ) async {
    final clean = number.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse(
      'https://wa.me/$clean?text=${Uri.encodeComponent(message)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp')),
      );
    }
  }

  Future<void> _showRateDialog(
    BuildContext context,
    Vendor vendor,
    VendorService service,
  ) async {
    int picked = 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('Rate ${vendor.name}'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 1; i <= 5; i++)
                IconButton(
                  tooltip: '$i star${i > 1 ? 's' : ''}',
                  icon: Icon(
                    i <= picked ? Icons.star_rounded : Icons.star_outline,
                    color: Colors.amber,
                  ),
                  onPressed: () => setSt(() => picked = i),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: picked == 0
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && picked > 0) {
      try {
        await service.rate(vendor.id, picked);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Vendor vendor,
    VendorService service,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete vendor?'),
        content: Text('Remove "${vendor.name}" from the list?'),
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
    if (confirmed == true) {
      try {
        await service.delete(vendor.id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}

class _StarRating extends StatelessWidget {
  const _StarRating({required this.rating, required this.count});
  final double rating;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) {
      return Text(
        'No ratings',
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: Theme.of(context).colorScheme.outline),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: 16, color: Colors.amber[700]),
        const SizedBox(width: 2),
        Text(
          '${rating.toStringAsFixed(1)} ($count)',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _Contact extends StatelessWidget {
  const _Contact({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Add vendor bottom sheet
// ─────────────────────────────────────────────

class _AddVendorSheet extends StatefulWidget {
  const _AddVendorSheet({required this.service, this.vendor});
  final VendorService service;
  final Vendor? vendor;

  @override
  State<_AddVendorSheet> createState() => _AddVendorSheetState();
}

class _AddVendorSheetState extends State<_AddVendorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _catCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _tradesCtrl = TextEditingController();
  bool _saving = false;

  bool get _isEdit => widget.vendor != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final v = widget.vendor!;
      _nameCtrl.text = v.name;
      _catCtrl.text = v.category ?? '';
      _phoneCtrl.text = v.phone ?? '';
      _emailCtrl.text = v.email ?? '';
      _websiteCtrl.text = v.website ?? '';
      _locationCtrl.text = v.location ?? '';
      _regionCtrl.text = v.region ?? '';
      _whatsappCtrl.text = v.whatsappNumber ?? '';
      _tradesCtrl.text = v.trades.join(', ');
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _catCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _websiteCtrl.dispose();
    _locationCtrl.dispose();
    _regionCtrl.dispose();
    _whatsappCtrl.dispose();
    _tradesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final cat = _catCtrl.text.trim().isEmpty ? null : _catCtrl.text.trim();
    final phone = _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim();
    final website = _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim();
    final location = _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim();
    final region = _regionCtrl.text.trim().isEmpty ? null : _regionCtrl.text.trim();
    final whatsapp = _whatsappCtrl.text.trim().isEmpty ? null : _whatsappCtrl.text.trim();
    final trades = _tradesCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    try {
      if (_isEdit) {
        await widget.service.update(
          widget.vendor!.id,
          name: _nameCtrl.text.trim(),
          category: cat,
          phone: phone,
          email: email,
          website: website,
          location: location,
          region: region,
          whatsappNumber: whatsapp,
          trades: trades,
        );
      } else {
        final vendor = Vendor(
          id: '',
          name: _nameCtrl.text.trim(),
          category: cat,
          phone: phone,
          email: email,
          website: website,
          location: location,
          region: region,
          whatsappNumber: whatsapp,
          trades: trades,
          ratingsCount: 0,
          ratingsSum: 0,
        );
        await widget.service.create(vendor);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEdit ? 'Edit Vendor' : 'Add Vendor',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name *',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _catCtrl,
              decoration: const InputDecoration(
                labelText: 'Category (optional)',
                hintText: 'e.g. Cement, Electrician, Plumber',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email (optional)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _whatsappCtrl,
              decoration: const InputDecoration(
                labelText: 'WhatsApp number (optional)',
                hintText: 'e.g. 233241234567',
                prefixText: '+',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _websiteCtrl,
              decoration: const InputDecoration(
                labelText: 'Website (optional)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Location (optional)',
                hintText: 'e.g. Accra, Tema',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _regionCtrl,
              decoration: const InputDecoration(
                labelText: 'Region (optional)',
                hintText: 'e.g. Greater Accra',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tradesCtrl,
              decoration: const InputDecoration(
                labelText: 'Trades / supplies (comma-separated, optional)',
                hintText: 'e.g. Cement, Iron rods, Electricals',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white,),
                      )
                    : Text(_isEdit ? 'Update vendor' : 'Save vendor'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.store_mall_directory_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No vendors yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first vendor.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// RFQ (Request for Quote) sheet
// ─────────────────────────────────────────────

class _NewRfqSheet extends StatefulWidget {
  const _NewRfqSheet({required this.vendor});
  final Vendor vendor;

  @override
  State<_NewRfqSheet> createState() => _NewRfqSheetState();
}

class _NewRfqSheetState extends State<_NewRfqSheet> {
  final _descCtrl = TextEditingController();
  DateTime? _dueDate;
  Project? _selectedProject;
  List<Project> _projects = [];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final auth = context.read<AuthService>();
    final uid = auth.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    final projectService = sl<ProjectService>();
    final list = await projectService
        .projectsForOwner(uid, limit: 50)
        .first;
    if (mounted) setState(() => _projects = list);
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
    );
    if (picked != null && mounted) setState(() => _dueDate = picked);
  }

  Future<void> _send() async {
    if (_descCtrl.text.trim().isEmpty || _selectedProject == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthService>();
      final rfqService = sl<RfqService>();
      final now = DateTime.now();
      final rfq = RfqRequest(
        id: const Uuid().v4(),
        projectId: _selectedProject!.id,
        projectTitle: _selectedProject!.title,
        ownerUid: auth.currentUser?.uid ?? '',
        vendorId: widget.vendor.id,
        vendorName: widget.vendor.name,
        description: _descCtrl.text.trim(),
        dueDate: _dueDate,
        status: RfqStatus.sent,
        createdAt: now,
        updatedAt: now,
      );
      await rfqService.createRfq(rfq);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy');

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Request Quote from ${widget.vendor.name}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
          // Project picker
          if (_projects.isEmpty)
            const Text(
              'No projects found. Create a project first.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            )
          else
            DropdownButtonFormField<Project>(
              decoration: const InputDecoration(
                labelText: 'Project *',
                border: OutlineInputBorder(),
              ),
              initialValue: _selectedProject,
              items: [
                for (final p in _projects)
                  DropdownMenuItem(value: p, child: Text(p.title)),
              ],
              onChanged: (p) => setState(() => _selectedProject = p),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'What do you need quoted? *',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDueDate,
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Quote due by (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              child: Text(
                _dueDate != null ? dateFmt.format(_dueDate!) : 'Tap to set',
                style: TextStyle(
                  fontSize: 13,
                  color: _dueDate != null ? null : Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_saving ||
                      _descCtrl.text.trim().isEmpty ||
                      _selectedProject == null)
                  ? null
                  : _send,
              child: Text(_saving ? 'Sending…' : 'Send Request'),
            ),
          ),
        ],
      ),
    );
  }
}
