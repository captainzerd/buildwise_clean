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

class SnagListPage extends StatelessWidget {
  const SnagListPage({
    super.key,
    required this.projectId,
    required this.projectTitle,
    required this.isOwner,
    required this.isBuilder,
    required this.assignedBuilderUid,
    required this.assignedBuilderName,
  });

  final String projectId;
  final String projectTitle;
  final bool isOwner;
  final bool isBuilder;
  final String? assignedBuilderUid;
  final String? assignedBuilderName;

  @override
  Widget build(BuildContext context) {
    final snagService = sl<SnagService>();

    return Scaffold(
      appBar: AppBar(title: Text('Snag List — $projectTitle')),
      body: StreamBuilder<List<SnagItem>>(
        stream: snagService.itemsStream(projectId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? [];

          final openCount =
              items.where((i) => i.status == SnagStatus.open).length;
          final resolvedCount =
              items.where((i) => i.status == SnagStatus.resolved).length;
          final confirmedCount =
              items.where((i) => i.status == SnagStatus.confirmed).length;

          return Column(
            children: [
              // Stats bar
              Padding(
                padding: const EdgeInsets.all(12),
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
              if (items.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      'No snag items yet.\nAdd items that need to be fixed.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 96),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 0, indent: 16),
                    itemBuilder: (_, i) => _SnagTile(
                      item: items[i],
                      projectId: projectId,
                      isOwner: isOwner,
                      isBuilder: isBuilder,
                      snagService: snagService,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: () => _showAddSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Add snag'),
            )
          : null,
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddSnagSheet(
        projectId: projectId,
        snagService: sl<SnagService>(),
        auth: context.read<AuthService>(),
        assignedBuilderUid: assignedBuilderUid,
        assignedBuilderName: assignedBuilderName,
      ),
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

// ── Snag tile ─────────────────────────────────────────────────────────────────

class _SnagTile extends StatelessWidget {
  const _SnagTile({
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
    final (icon, color) = switch (item.status) {
      SnagStatus.confirmed => (Icons.check_circle, Colors.green),
      SnagStatus.resolved => (Icons.check_circle_outline, Colors.orange),
      _ => (Icons.error_outline, cs.error),
    };

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(item.description),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined),
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
  DateTime? _dueDate;
  bool _saving = false;
  final List<String> _photoUrls = [];
  bool _uploadingPhoto = false;

  static const _maxPhotos = 5;

  @override
  void dispose() {
    _descCtrl.dispose();
    _notesCtrl.dispose();
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
              'Add Snag Item',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
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
                  : const Text('Add snag item'),
            ),
          ],
        ),
      ),
    );
  }
}
