// lib/features/account/portfolio_page.dart
//
// Lets a builder manage their public past-project portfolio.
// Each item includes photos, project type, region, value, and client name.

import 'dart:io';
import '../../core/errors/app_exception.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/portfolio_item.dart';
import '../../core/services/auth_service.dart';
import '../../core/config/service_locator.dart';
import '../../core/services/portfolio_service.dart';
import '../../core/services/regional_index_provider.dart';

class PortfolioPage extends StatelessWidget {
  const PortfolioPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Project Portfolio')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, uid),
        icon: const Icon(Icons.add),
        label: const Text('Add project'),
      ),
      body: StreamBuilder<List<PortfolioItem>>(
        stream: sl<PortfolioService>().portfolioStream(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No portfolio items yet',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Showcase your past projects to attract clients.',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _PortfolioCard(item: items[i], uid: uid),
          );
        },
      ),
    );
  }

  void _showAddSheet(BuildContext context, String uid) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _AddPortfolioSheet(uid: uid),
    );
  }
}

// ── Portfolio item card ───────────────────────────────────────────────────────

class _PortfolioCard extends StatelessWidget {
  const _PortfolioCard({required this.item, required this.uid});
  final PortfolioItem item;
  final String uid;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0', 'en_GH');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo strip
          if (item.photoUrls.isNotEmpty)
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: item.photoUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 2),
                itemBuilder: (_, i) => CachedNetworkImage(
                  imageUrl: item.photoUrls[i],
                  width: 200,
                  height: 140,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 200,
                    color: cs.surfaceContainerHighest,
                  ),
                  errorWidget: (_, __, ___) =>
                      const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: cs.error,
                      tooltip: 'Delete',
                      onPressed: () => _confirmDelete(context),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    _Tag(item.projectType),
                    _Tag(item.region),
                    _Tag(item.completedYear.toString()),
                    if (item.contractValueGhs != null)
                      _Tag('GHS ${fmt.format(item.contractValueGhs)}'),
                  ],
                ),
                if (item.description != null &&
                    item.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (item.clientName != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 14, color: cs.outline),
                      const SizedBox(width: 4),
                      Text(
                        item.clientName!,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      if (item.clientVerified) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.verified_outlined,
                          size: 14,
                          color: Colors.green,
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete portfolio item?'),
        content: Text('Remove "${item.title}" from your portfolio?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        await sl<PortfolioService>().deleteItem(uid, item.id);
      }
    });
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Chip(
        label: Text(label),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
      );
}

// ── Add portfolio item sheet ──────────────────────────────────────────────────

class _AddPortfolioSheet extends StatefulWidget {
  const _AddPortfolioSheet({required this.uid});
  final String uid;
  @override
  State<_AddPortfolioSheet> createState() => _AddPortfolioSheetState();
}

class _AddPortfolioSheetState extends State<_AddPortfolioSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _clientCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();

  String _projectType = 'Residential';
  String? _region;
  int _year = DateTime.now().year;
  final _photos = <File>[];
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _clientCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final picked = await ImagePicker().pickMultiImage(
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (picked.isNotEmpty && mounted) {
      setState(() {
        final remaining = 5 - _photos.length;
        _photos.addAll(
          picked.take(remaining).map((x) => File(x.path)),
        );
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final item = PortfolioItem(
        id: '',
        title: _titleCtrl.text.trim(),
        projectType: _projectType,
        region: _region ?? '',
        completedYear: _year,
        contractValueGhs: double.tryParse(_valueCtrl.text.trim()),
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        photoUrls: const [],
        clientName:
            _clientCtrl.text.trim().isEmpty ? null : _clientCtrl.text.trim(),
      );

      await sl<PortfolioService>().addItem(
        widget.uid,
        item,
        photos: _photos,
      );

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppException.from(e).message), duration: const Duration(seconds: 10)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final regions = context.read<RegionalIndexProvider>().regionCodes;
    final years = List.generate(30, (i) => DateTime.now().year - i);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add Portfolio Project',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Project title *',
                  hintText: 'e.g. 3-bed Residential, East Legon',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: _projectType,
                decoration: const InputDecoration(
                  labelText: 'Project type *',
                  border: OutlineInputBorder(),
                ),
                items: kPortfolioProjectTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _projectType = v!),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _region,
                      decoration: const InputDecoration(
                        labelText: 'Region *',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('— Select —'),
                        ),
                        for (final r in regions)
                          DropdownMenuItem(value: r, child: Text(r)),
                      ],
                      onChanged: (v) => setState(() => _region = v),
                      validator: (v) => v == null ? 'Select a region' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _year,
                      decoration: const InputDecoration(
                        labelText: 'Year completed *',
                        border: OutlineInputBorder(),
                      ),
                      items: years
                          .map(
                            (y) => DropdownMenuItem(
                              value: y,
                              child: Text(y.toString()),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _year = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _valueCtrl,
                decoration: const InputDecoration(
                  labelText: 'Contract value — GHS (optional)',
                  prefixText: '₵ ',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _clientCtrl,
                decoration: const InputDecoration(
                  labelText: 'Client / employer name (optional)',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Scope of work, key achievements…',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),

              // Photo picker
              if (_photos.isNotEmpty) ...[
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _photos[i],
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => setState(() => _photos.removeAt(i)),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              if (_photos.length < 5)
                OutlinedButton.icon(
                  onPressed: _pickPhotos,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                    _photos.isEmpty
                        ? 'Add photos (up to 5)'
                        : 'Add more (${5 - _photos.length} remaining)',
                  ),
                ),
              const SizedBox(height: 20),

              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving…' : 'Save project'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
