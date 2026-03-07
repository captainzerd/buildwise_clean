// lib/features/project/tabs/documents_tab.dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/project_document.dart';
import '../../../core/services/project_service.dart';
import '../../../core/widgets/empty_state.dart';

class DocsTab extends StatelessWidget {
  const DocsTab({
    required this.projectId,
    required this.projectService,
    required this.currentUserUid,
    required this.ownerUid,
    required this.observerUids,
  });

  final String projectId;
  final ProjectService projectService;
  final String currentUserUid;
  final String ownerUid;
  final List<String> observerUids;

  bool _canView(ProjectDocument doc) {
    return switch (doc.visibility) {
      DocumentVisibility.all => true,
      DocumentVisibility.ownerOnly => currentUserUid == ownerUid,
      DocumentVisibility.ownerAndObservers =>
        currentUserUid == ownerUid || observerUids.contains(currentUserUid),
    };
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProjectDocument>>(
      stream: projectService.documentsStream(projectId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = (snap.data ?? []).where(_canView).toList();
        if (docs.isEmpty) {
          return const EmptyState(
            icon: Icons.folder_outlined,
            title: 'No documents yet',
            message: 'Tap the upload button to add files.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (_, i) => _DocTile(
            doc: docs[i],
            projectId: projectId,
            projectService: projectService,
          ),
        );
      },
    );
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({
    required this.doc,
    required this.projectId,
    required this.projectService,
  });

  final ProjectDocument doc;
  final String projectId;
  final ProjectService projectService;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sizeLabel =
        doc.sizeBytes != null ? _formatBytes(doc.sizeBytes!) : null;

    final expiryColor = doc.isExpired
        ? cs.error
        : doc.expiresWithin30Days
            ? Colors.orange
            : null;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Icon(
            _iconForType(doc.contentType),
            color: cs.onPrimaryContainer,
            size: 20,
          ),
        ),
        title: Text(doc.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                doc.category.label,
                DateFormat('d MMM yyyy').format(doc.createdAt),
                if (sizeLabel != null) sizeLabel,
              ].join(' · '),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: cs.outline),
            ),
            if (doc.expiresAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      doc.isExpired
                          ? Icons.warning_rounded
                          : Icons.event_outlined,
                      size: 12,
                      color: expiryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      doc.isExpired
                          ? 'Expired ${DateFormat('d MMM yyyy').format(doc.expiresAt!)}'
                          : 'Expires ${DateFormat('d MMM yyyy').format(doc.expiresAt!)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: expiryColor,
                            fontWeight: doc.isExpired || doc.expiresWithin30Days
                                ? FontWeight.bold
                                : null,
                          ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        isThreeLine: doc.expiresAt != null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.open_in_new_outlined),
              tooltip: 'Open',
              onPressed: () => _open(context),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: cs.error),
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(doc.url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open file.')),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text('Remove "${doc.name}" from this project?'),
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
      await projectService.deleteDocument(
        projectId,
        doc.id,
        storagePath: doc.storagePath,
      );
    }
  }

  IconData _iconForType(String? type) {
    if (type == null) return Icons.insert_drive_file_outlined;
    if (type.startsWith('image/')) return Icons.image_outlined;
    if (type == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (type.contains('word')) return Icons.description_outlined;
    if (type.contains('sheet') || type.contains('excel')) {
      return Icons.table_chart_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

// ── Upload document sheet ──────────────────────────────────────────────────────


class ProjectUploadDocSheet extends StatefulWidget {
  const ProjectUploadDocSheet({
    required this.projectId,
    required this.uploaderUid,
    required this.projectService,
  });

  final String projectId;
  final String uploaderUid;
  final ProjectService projectService;

  @override
  State<ProjectUploadDocSheet> createState() => ProjectUploadDocSheetState();
}

class ProjectUploadDocSheetState extends State<ProjectUploadDocSheet> {
  DocumentCategory _category = DocumentCategory.other;
  DocumentVisibility _visibility = DocumentVisibility.all;
  PlatformFile? _picked;
  final _nameCtrl = TextEditingController();
  bool _uploading = false;
  DateTime? _expiresAt;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    setState(() {
      _picked = f;
      if (_nameCtrl.text.trim().isEmpty) {
        // Pre-fill name without extension
        final namePart = f.name.contains('.')
            ? f.name.substring(0, f.name.lastIndexOf('.'))
            : f.name;
        _nameCtrl.text = namePart;
      }
    });
  }

  Future<void> _upload() async {
    if (_picked == null || _picked!.path == null) return;
    final displayName = _nameCtrl.text.trim();
    setState(() => _uploading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.projectService.uploadDocument(
        projectId: widget.projectId,
        uploaderUid: widget.uploaderUid,
        file: File(_picked!.path!),
        fileName: _picked!.name,
        category: _category,
        displayName: displayName.isNotEmpty ? displayName : null,
        contentType: _picked!.extension != null
            ? _mimeFromExt(_picked!.extension!)
            : null,
        expiresAt: _expiresAt,
        visibility: _visibility,
      );
      if (mounted) {
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '"${displayName.isNotEmpty ? displayName : _picked!.name}" uploaded.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        messenger.showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  String? _mimeFromExt(String ext) => switch (ext.toLowerCase()) {
        'pdf' => 'application/pdf',
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'doc' => 'application/msword',
        'docx' =>
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'xls' => 'application/vnd.ms-excel',
        'xlsx' =>
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload Document',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 20),
          Text('Category', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: DocumentCategory.values.map((cat) {
              return ChoiceChip(
                label: Text(cat.label),
                selected: _category == cat,
                onSelected:
                    _uploading ? null : (_) => setState(() => _category = cat),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _uploading ? null : _pickFile,
            icon: const Icon(Icons.attach_file),
            label: Text(
              _picked == null ? 'Pick file' : _picked!.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_picked != null) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Document name',
                border: OutlineInputBorder(),
                helperText: 'Rename (optional)',
              ),
              enabled: !_uploading,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text(
                      _expiresAt == null
                          ? 'Expiry date (optional)'
                          : 'Expires: ${DateFormat('d MMM yyyy').format(_expiresAt!)}',
                    ),
                    onPressed: _uploading
                        ? null
                        : () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate:
                                  DateTime.now().add(const Duration(days: 365)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 365 * 20)),
                            );
                            if (picked != null) {
                              setState(() => _expiresAt = picked);
                            }
                          },
                  ),
                ),
                if (_expiresAt != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Clear expiry',
                    onPressed: () => setState(() => _expiresAt = null),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<DocumentVisibility>(
              initialValue: _visibility,
              decoration: const InputDecoration(
                labelText: 'Visibility',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.visibility_outlined),
              ),
              items: DocumentVisibility.values
                  .map(
                    (v) => DropdownMenuItem(
                      value: v,
                      child: Text(v.label),
                    ),
                  )
                  .toList(),
              onChanged:
                  _uploading ? null : (v) => setState(() => _visibility = v!),
            ),
          ],
          if (_uploading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _picked == null || _uploading ? null : _upload,
              icon: const Icon(Icons.upload),
              label: const Text('Upload'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add phase sheet ────────────────────────────────────────────────────────────

