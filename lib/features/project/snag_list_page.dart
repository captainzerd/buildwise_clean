import '../../core/config/service_locator.dart';
// lib/features/project/snag_list_page.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/snag_item.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/snag_service.dart';

class SnagListPage extends StatefulWidget {
  const SnagListPage({
    super.key,
    required this.projectId,
    required this.projectTitle,
    required this.isOwner,
    required this.isBuilder,
    required this.assignedBuilderUid,
    required this.assignedBuilderName,
    this.initialType,
  });

  final String projectId;
  final String projectTitle;
  final bool isOwner;
  final bool isBuilder;
  final String? assignedBuilderUid;
  final String? assignedBuilderName;
  final IssueType? initialType;

  @override
  State<SnagListPage> createState() => _SnagListPageState();
}

class _SnagListPageState extends State<SnagListPage> {
  IssueType? _typeFilter;
  IssueSeverity? _severityFilter;
  SnagCategory? _categoryFilter;

  @override
  void initState() {
    super.initState();
    _typeFilter = widget.initialType;
  }

  @override
  Widget build(BuildContext context) {
    final snagService = sl<SnagService>();

    return Scaffold(
      appBar: AppBar(title: Text('Issues — ${widget.projectTitle}')),
      body: StreamBuilder<List<SnagItem>>(
        stream: snagService.itemsStream(widget.projectId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final allItems = snap.data ?? [];

          // Apply filters
          final items = allItems.where((item) {
            if (_typeFilter != null && item.issueType != _typeFilter) {
              return false;
            }
            if (_severityFilter != null &&
                item.severity != _severityFilter) {
              return false;
            }
            if (_categoryFilter != null && item.category != _categoryFilter) {
              return false;
            }
            return true;
          }).toList();

          final openCount =
              allItems.where((i) => i.status == SnagStatus.open).length;
          final resolvedCount =
              allItems.where((i) => i.status == SnagStatus.resolved).length;
          final confirmedCount =
              allItems.where((i) => i.status == SnagStatus.confirmed).length;

          return Column(
            children: [
              // Stats bar
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _StatChip(
                        label: 'Open',
                        count: openCount,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 8),
                      _StatChip(
                        label: 'Resolved',
                        count: resolvedCount,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      _StatChip(
                        label: 'Confirmed',
                        count: confirmedCount,
                        color: Colors.green,
                      ),
                    ],
                  ),
                ),
              ),
              // Type filter chips
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: _typeFilter == null,
                        onSelected: (_) =>
                            setState(() => _typeFilter = null),
                      ),
                      const SizedBox(width: 8),
                      for (final type in IssueType.values) ...[
                        FilterChip(
                          avatar: Icon(type.icon, size: 14),
                          label: Text(type.label),
                          selected: _typeFilter == type,
                          onSelected: (_) => setState(
                            () => _typeFilter =
                                _typeFilter == type ? null : type,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ),
              // Severity filter chips
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Any'),
                        selected: _severityFilter == null,
                        onSelected: (_) =>
                            setState(() => _severityFilter = null),
                      ),
                      const SizedBox(width: 8),
                      for (final sev in IssueSeverity.values) ...[
                        FilterChip(
                          label: Text(sev.label),
                          selected: _severityFilter == sev,
                          selectedColor: sev.color.withValues(alpha: 0.2),
                          onSelected: (_) => setState(
                            () => _severityFilter =
                                _severityFilter == sev ? null : sev,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ),
              // Category filter chips
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: _categoryFilter == null,
                        onSelected: (_) =>
                            setState(() => _categoryFilter = null),
                      ),
                      const SizedBox(width: 8),
                      ...SnagCategory.values.map((c) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(c.displayName),
                              selected: _categoryFilter == c,
                              onSelected: (_) => setState(() =>
                                  _categoryFilter =
                                      _categoryFilter == c ? null : c),
                            ),
                          )),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              if (items.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      'No issues found.\nAdjust filters or add new issues.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                Expanded(
                  child: _GroupedSnagList(
                    items: items,
                    projectId: widget.projectId,
                    isOwner: widget.isOwner,
                    isBuilder: widget.isBuilder,
                    snagService: snagService,
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: widget.isOwner
          ? FloatingActionButton.extended(
              onPressed: () => _showAddSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Add issue'),
            )
          : null,
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddSnagSheet(
        projectId: widget.projectId,
        snagService: sl<SnagService>(),
        auth: context.read<AuthService>(),
        assignedBuilderUid: widget.assignedBuilderUid,
        assignedBuilderName: widget.assignedBuilderName,
      ),
    );
  }
}

// ── Grouped snag list ─────────────────────────────────────────────────────────

class _GroupedSnagList extends StatelessWidget {
  const _GroupedSnagList({
    required this.items,
    required this.projectId,
    required this.isOwner,
    required this.isBuilder,
    required this.snagService,
  });

  final List<SnagItem> items;
  final String projectId;
  final bool isOwner;
  final bool isBuilder;
  final SnagService snagService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Group by category preserving insertion order
    final grouped = <SnagCategory, List<SnagItem>>{};
    for (final s in items) {
      grouped.putIfAbsent(s.category, () => []).add(s);
    }

    // Build flat list: [header, card, card, ..., header, card, ...]
    final rows = <Widget>[];
    for (final entry in grouped.entries) {
      rows.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            entry.key.displayName,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      for (final s in entry.value) {
        rows.add(
          _IssueCardStandalone(
            item: s,
            projectId: projectId,
            isOwner: isOwner,
            isBuilder: isBuilder,
            snagService: snagService,
          ),
        );
        rows.add(const Divider(height: 0, indent: 16));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 96),
      children: rows,
    );
  }
}

// ── Stat chip ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
  });
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color,
        radius: 10,
        child: Text(
          '$count',
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

// ── Issue card (standalone page version) ──────────────────────────────────────

class _IssueCardStandalone extends StatelessWidget {
  const _IssueCardStandalone({
    required this.item,
    required this.projectId,
    required this.isOwner,
    required this.isBuilder,
    required this.snagService,
  });

  final SnagItem item;
  final String projectId;
  final bool isOwner;
  final bool isBuilder;
  final SnagService snagService;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSafety = item.issueType == IssueType.safetyIncident;

    final (statusIcon, statusColor) = switch (item.status) {
      SnagStatus.confirmed => (Icons.check_circle, Colors.green),
      SnagStatus.resolved => (Icons.check_circle_outline, Colors.orange),
      _ => (Icons.error_outline, cs.error),
    };

    return Card(
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(),
      color: isSafety
          ? cs.errorContainer.withValues(alpha: 0.2)
          : null,
      child: ListTile(
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.issueType.icon, size: 18, color: cs.primary),
            Icon(statusIcon, size: 14, color: statusColor),
          ],
        ),
        title: Row(
          children: [
            Expanded(child: Text(item.description)),
            // Severity badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: item.severity.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: item.severity.color.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                item.severity.label,
                style: TextStyle(
                  fontSize: 10,
                  color: item.severity.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type label
            Text(
              item.issueType.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            if (item.contractorName != null)
              Text(
                'Contractor: ${item.contractorName}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (item.assignedToName != null)
              Text(
                'Assigned to: ${item.assignedToName}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (item.dueDate != null)
              Text(
                'Due: ${DateFormat('d MMM yyyy').format(item.dueDate!)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: item.dueDate!.isBefore(DateTime.now()) &&
                              item.status == SnagStatus.open
                          ? cs.error
                          : null,
                    ),
              ),
            if (item.notes != null && item.notes!.isNotEmpty)
              Text(
                item.notes!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontStyle: FontStyle.italic),
              ),
            if (item.photoUrls.isNotEmpty) ...[
              const SizedBox(height: 4),
              SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: item.photoUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 4),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => _showPhoto(context, item.photoUrls[i]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CachedNetworkImage(
                        imageUrl: item.photoUrls[i],
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: _buildActions(context),
        isThreeLine: true,
      ),
    );
  }

  Widget? _buildActions(BuildContext context) {
    if (item.status == SnagStatus.open && isBuilder) {
      return TextButton(
        onPressed: () => _resolveDialog(context),
        child: const Text('Resolve'),
      );
    }
    if (item.status == SnagStatus.resolved && isOwner) {
      return FilledButton.tonal(
        onPressed: () => snagService.confirmItem(projectId, item.id),
        child: const Text('Confirm'),
      );
    }
    if (isOwner && item.status != SnagStatus.confirmed) {
      return IconButton(
        tooltip: 'Delete',
        icon: const Icon(Icons.delete_outline, size: 20),
        color: Theme.of(context).colorScheme.error,
        onPressed: () => snagService.deleteItem(projectId, item.id),
      );
    }
    return null;
  }

  Future<void> _resolveDialog(BuildContext context) async {
    final notesCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as resolved'),
        content: TextField(
          controller: notesCtrl,
          decoration: const InputDecoration(
            labelText: 'Resolution notes (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    notesCtrl.dispose();
    if (confirmed == true && context.mounted) {
      await snagService.resolveItem(
        projectId,
        item.id,
        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      );
    }
  }

  void _showPhoto(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: CachedNetworkImage(
          imageUrl: url,
          errorWidget: (_, __, ___) =>
              const Icon(Icons.broken_image_outlined),
        ),
      ),
    );
  }
}

// ── Add snag sheet ────────────────────────────────────────────────────────────

class _AddSnagSheet extends StatefulWidget {
  const _AddSnagSheet({
    required this.projectId,
    required this.snagService,
    required this.auth,
    this.assignedBuilderUid,
    this.assignedBuilderName,
  });

  final String projectId;
  final SnagService snagService;
  final AuthService auth;
  final String? assignedBuilderUid;
  final String? assignedBuilderName;

  @override
  State<_AddSnagSheet> createState() => _AddSnagSheetState();
}

class _AddSnagSheetState extends State<_AddSnagSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _contractorCtrl = TextEditingController();
  DateTime? _dueDate;
  bool _saving = false;
  final List<String> _photoUrls = [];
  bool _uploadingPhoto = false;
  IssueType _issueType = IssueType.defect;
  IssueSeverity _severity = IssueSeverity.medium;
  SnagCategory _category = SnagCategory.other;

  static const _maxPhotos = 5;

  @override
  void dispose() {
    _descCtrl.dispose();
    _notesCtrl.dispose();
    _contractorCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_photoUrls.length >= _maxPhotos) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );
    if (picked == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    try {
      final ref = FirebaseStorage.instance.ref(
        'projects/${widget.projectId}/snags/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final task = await ref.putFile(
        File(picked.path),
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await task.ref.getDownloadURL();
      if (mounted) setState(() => _photoUrls.add(url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final user = widget.auth.currentUser;
      final now = DateTime.now();
      final contractorName = _contractorCtrl.text.trim();
      final item = SnagItem(
        id: '',
        description: _descCtrl.text.trim(),
        createdAt: now,
        createdByUid: user?.uid ?? '',
        createdByName: user?.displayName ?? '',
        photoUrls: List.unmodifiable(_photoUrls),
        assignedToUid: widget.assignedBuilderUid,
        assignedToName: widget.assignedBuilderName,
        dueDate: _dueDate,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        issueType: _issueType,
        severity: _severity,
        contractorName: contractorName.isEmpty ? null : contractorName,
        category: _category,
      );
      await widget.snagService.addItem(widget.projectId, item);
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
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Report Issue',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            // Issue type chips
            Text(
              'Type',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final type in IssueType.values)
                  ChoiceChip(
                    avatar: Icon(type.icon, size: 14),
                    label: Text(type.label),
                    selected: _issueType == type,
                    onSelected: (_) =>
                        setState(() => _issueType = type),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Severity chips
            Text(
              'Severity',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final sev in IssueSeverity.values)
                  ChoiceChip(
                    label: Text(sev.label),
                    selected: _severity == sev,
                    selectedColor: sev.color.withValues(alpha: 0.2),
                    onSelected: (_) =>
                        setState(() => _severity = sev),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SnagCategory>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: SnagCategory.values
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.displayName),
                      ))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _category = v ?? SnagCategory.other),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description *',
                hintText: 'e.g. Cracked tile in bathroom',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contractorCtrl,
              decoration: const InputDecoration(
                labelText: 'Responsible contractor (optional)',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            if (_photoUrls.isNotEmpty) ...[
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photoUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: _photoUrls[i],
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => setState(() => _photoUrls.removeAt(i)),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 12,
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
            Row(
              children: [
                if (_photoUrls.length < _maxPhotos)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: _uploadingPhoto
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.camera_alt_outlined),
                      label: Text(
                        _photoUrls.isEmpty
                            ? 'Add photo'
                            : 'Add (${_photoUrls.length}/$_maxPhotos)',
                      ),
                      onPressed: _uploadingPhoto ? null : _pickPhoto,
                    ),
                  ),
                if (_photoUrls.length < _maxPhotos) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      _dueDate != null
                          ? DateFormat('d MMM').format(_dueDate!)
                          : 'Set due date',
                    ),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (d != null) setState(() => _dueDate = d);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Report issue'),
            ),
          ],
        ),
      ),
    );
  }
}
