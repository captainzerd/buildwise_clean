// lib/features/project/drawings_page.dart

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/config/service_locator.dart';
import '../../core/models/drawing.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/drawing_service.dart';
import '../../core/widgets/empty_state.dart';
import 'drawing_viewer_page.dart';

class DrawingsPage extends StatelessWidget {
  const DrawingsPage({
    super.key,
    required this.projectId,
  });

  final String projectId;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final service = sl<DrawingService>();
    final canUpload = auth.currentUser != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Drawings'),
      ),
      body: StreamBuilder<List<Drawing>>(
        stream: service.drawingsStream(projectId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final drawings = snap.data ?? [];
          if (drawings.isEmpty) {
            return const EmptyState(
              icon: Icons.architecture_outlined,
              title: 'No drawings yet',
              message:
                  'Upload architectural drawings or blueprints to annotate them with your team.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: drawings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _DrawingTile(
              drawing: drawings[i],
              projectId: projectId,
            ),
          );
        },
      ),
      floatingActionButton: canUpload
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Upload Drawing'),
              onPressed: () => _showUploadSheet(context, auth, service),
            )
          : null,
    );
  }

  void _showUploadSheet(
    BuildContext context,
    AuthService auth,
    DrawingService service,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _UploadDrawingSheet(
        projectId: projectId,
        auth: auth,
        service: service,
      ),
    );
  }
}

// ── Drawing list tile ─────────────────────────────────────────────────────────

class _DrawingTile extends StatelessWidget {
  const _DrawingTile({required this.drawing, required this.projectId});

  final Drawing drawing;
  final String projectId;

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('dd MMM yyyy').format(drawing.uploadedAt);
    final annotationCount = drawing.annotations.length;
    final icon = drawing.fileType == 'pdf'
        ? Icons.picture_as_pdf_outlined
        : Icons.image_outlined;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, size: 36),
        title: Text(
          drawing.name,
          style: Theme.of(context).textTheme.titleSmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '$dateStr · ${drawing.uploadedByName}'
          '${annotationCount > 0 ? ' · $annotationCount annotation${annotationCount == 1 ? '' : 's'}' : ''}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => DrawingViewerPage(
              drawing: drawing,
              projectId: projectId,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Upload bottom sheet ───────────────────────────────────────────────────────

class _UploadDrawingSheet extends StatefulWidget {
  const _UploadDrawingSheet({
    required this.projectId,
    required this.auth,
    required this.service,
  });

  final String projectId;
  final AuthService auth;
  final DrawingService service;

  @override
  State<_UploadDrawingSheet> createState() => _UploadDrawingSheetState();
}

class _UploadDrawingSheetState extends State<_UploadDrawingSheet> {
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  File? _pickedFile;
  String? _pickedFileName;
  bool _uploading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _pickedFile = File(result.files.single.path!);
        _pickedFileName = result.files.single.name;
        // Pre-fill the name field with the filename (without extension)
        if (_nameCtrl.text.isEmpty) {
          final parts = result.files.single.name.split('.');
          _nameCtrl.text =
              parts.length > 1 ? parts.take(parts.length - 1).join('.') : parts.first;
        }
      });
    }
  }

  Future<void> _upload() async {
    if (_uploading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a file first.')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    setState(() => _uploading = true);
    try {
      final uid = widget.auth.currentUser?.uid ?? '';
      final name = widget.auth.currentUser?.displayName ?? 'Unknown';
      await widget.service.uploadDrawing(
        widget.projectId,
        name: _nameCtrl.text.trim(),
        file: _pickedFile!,
        uploadedByUid: uid,
        uploadedByName: name,
      );
      if (!mounted) return;
      nav.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Drawing uploaded successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Upload Drawing',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Drawing name *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.attach_file_outlined),
              label: Text(
                _pickedFileName ?? 'Pick File (PDF / JPG / PNG)',
              ),
              onPressed: _uploading ? null : _pickFile,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _uploading ? null : _upload,
              child: _uploading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Upload'),
            ),
          ],
        ),
      ),
    );
  }
}
