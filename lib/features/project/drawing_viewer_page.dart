// lib/features/project/drawing_viewer_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/service_locator.dart';
import '../../core/models/drawing.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/drawing_service.dart';

class DrawingViewerPage extends StatelessWidget {
  const DrawingViewerPage({
    super.key,
    required this.drawing,
    required this.projectId,
  });

  final Drawing drawing;
  final String projectId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(drawing.name),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              label: Text(
                '${drawing.annotations.length} pin${drawing.annotations.length == 1 ? '' : 's'}',
              ),
              avatar: const Icon(Icons.location_pin, size: 16),
            ),
          ),
        ],
      ),
      body: drawing.fileType == 'pdf'
          ? _PdfFallback(drawing: drawing)
          : _ImageViewer(
              drawing: drawing,
              projectId: projectId,
            ),
    );
  }
}

// ── PDF fallback ──────────────────────────────────────────────────────────────

class _PdfFallback extends StatelessWidget {
  const _PdfFallback({required this.drawing});

  final Drawing drawing;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.picture_as_pdf_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'PDF viewing coming soon',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the button below to open this drawing in your browser.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Open in Browser'),
              onPressed: () async {
                // Capture messenger before the first await to avoid
                // using context across an async gap.
                final messenger = ScaffoldMessenger.of(context);
                final uri = Uri.tryParse(drawing.fileUrl);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  if (context.mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Could not open the file URL.'),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Image viewer with annotations ────────────────────────────────────────────

class _ImageViewer extends StatefulWidget {
  const _ImageViewer({required this.drawing, required this.projectId});

  final Drawing drawing;
  final String projectId;

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  // Temporary pending pin position (normalised 0–1).
  Offset? _pendingPin;
  final _commentCtrl = TextEditingController();
  bool _saving = false;

  // The key lets us measure the rendered image size for hit-testing.
  final _imageKey = GlobalKey();

  // TransformationController tracks zoom/pan so tap positions can be
  // converted from gesture space to scene (image) space.
  final _transformCtrl = TransformationController();

  @override
  void initState() {
    super.initState();
    // Trigger a rebuild after the first frame so annotation pins can
    // resolve _imageKey.currentContext once the image widget is mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _transformCtrl.dispose();
    super.dispose();
  }

  void _onTapUp(TapUpDetails details) {
    final rb = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return;
    final sz = rb.size;
    // Convert from gesture space to scene (image) space before normalising,
    // so zoom/pan applied by InteractiveViewer is accounted for.
    final scene = _transformCtrl.toScene(details.localPosition);
    final nx = (scene.dx / sz.width).clamp(0.0, 1.0);
    final ny = (scene.dy / sz.height).clamp(0.0, 1.0);

    setState(() {
      _pendingPin = Offset(nx, ny);
      _commentCtrl.clear();
    });
    _showAnnotationCard();
  }

  void _cancelPending() {
    setState(() => _pendingPin = null);
    _commentCtrl.clear();
  }

  Future<void> _saveAnnotation() async {
    if (_saving) return;
    final comment = _commentCtrl.text.trim();
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a comment.')),
      );
      return;
    }
    if (_pendingPin == null) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);

    try {
      final auth = context.read<AuthService>();
      final uid = auth.currentUser?.uid ?? '';
      final name = auth.currentUser?.displayName ?? 'Unknown';
      final ann = DrawingAnnotation(
        id: const Uuid().v4(),
        x: _pendingPin!.dx,
        y: _pendingPin!.dy,
        comment: comment,
        authorUid: uid,
        authorName: name,
        createdAt: DateTime.now(),
      );
      await sl<DrawingService>().addAnnotation(
        widget.projectId,
        widget.drawing.id,
        ann,
      );
      if (!mounted) return;
      setState(() => _pendingPin = null);
      _commentCtrl.clear();
      messenger.showSnackBar(
        const SnackBar(content: Text('Annotation saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Error saving annotation: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showAnnotationCard() {
    // The sheet dismisses itself (via Navigator.pop) before _saveAnnotation is
    // called, so any _saving state change happens after the sheet is gone.
    // The saving parameter has therefore been removed from _AnnotationInputSheet
    // to avoid a stale-snapshot confusion.
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      isDismissible: true,
      builder: (_) => _AnnotationInputSheet(
        controller: _commentCtrl,
        onCancel: () {
          Navigator.of(context).pop();
          _cancelPending();
        },
        onSave: () {
          Navigator.of(context).pop();
          _saveAnnotation();
        },
      ),
    );
  }

  void _showAnnotationDetail(DrawingAnnotation ann) {
    showDialog<void>(
      context: context,
      builder: (_) => _AnnotationDetailDialog(annotation: ann),
    );
  }

  @override
  Widget build(BuildContext context) {
    final annotations = widget.drawing.annotations;

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 6.0,
      transformationController: _transformCtrl,
      child: GestureDetector(
        onTapUp: _onTapUp,
        child: Stack(
          children: [
            // Note: Stack is sized by Image.network (no independent height constraint),
            // so Image origin == Stack origin. Pin Positioned offsets are correct.
            // If a fixed Stack height is ever added, recalculate using image RenderBox offset.
            // Base image
            Image.network(
              widget.drawing.fileUrl,
              key: _imageKey,
              fit: BoxFit.contain,
              width: double.infinity,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (_, __, ___) => const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.broken_image_outlined, size: 48),
                    SizedBox(height: 8),
                    Text('Could not load image'),
                  ],
                ),
              ),
            ),
            // Existing annotation pins
            for (final ann in annotations)
              _AnnotationPin(
                annotation: ann,
                imageKey: _imageKey,
                onTap: () => _showAnnotationDetail(ann),
              ),
            // Pending (unsaved) pin
            if (_pendingPin != null)
              _PendingPin(
                position: _pendingPin!,
                imageKey: _imageKey,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Annotation pin overlay ────────────────────────────────────────────────────

class _AnnotationPin extends StatelessWidget {
  const _AnnotationPin({
    required this.annotation,
    required this.imageKey,
    required this.onTap,
  });

  final DrawingAnnotation annotation;
  final GlobalKey imageKey;
  final VoidCallback onTap;

  static const double _pinSize = 28;

  @override
  Widget build(BuildContext context) {
    final rb = imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return const SizedBox.shrink();

    final size = rb.size;
    final dx = annotation.x * size.width - _pinSize / 2;
    final dy = annotation.y * size.height - _pinSize;

    return Positioned(
      left: dx,
      top: dy,
      child: GestureDetector(
        onTap: onTap,
        child: Tooltip(
          message: annotation.comment,
          child: Container(
            width: _pinSize,
            height: _pinSize,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(blurRadius: 4, color: Colors.black38),
              ],
            ),
            child: const Icon(
              Icons.location_pin,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingPin extends StatelessWidget {
  const _PendingPin({required this.position, required this.imageKey});

  final Offset position;
  final GlobalKey imageKey;

  static const double _pinSize = 28;

  @override
  Widget build(BuildContext context) {
    final rb = imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return const SizedBox.shrink();

    final size = rb.size;
    final dx = position.dx * size.width - _pinSize / 2;
    final dy = position.dy * size.height - _pinSize;

    return Positioned(
      left: dx,
      top: dy,
      child: Container(
        width: _pinSize,
        height: _pinSize,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(blurRadius: 4, color: Colors.black38),
          ],
        ),
        child: const Icon(
          Icons.add_location_outlined,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }
}

// ── Annotation input sheet ────────────────────────────────────────────────────

// The sheet is a StatelessWidget; it does not reflect _saving state changes
// because the sheet is dismissed (via onSave → Navigator.pop) before
// _saveAnnotation begins its async work. The saving parameter is intentionally
// omitted to avoid stale-snapshot confusion.
class _AnnotationInputSheet extends StatelessWidget {
  const _AnnotationInputSheet({
    required this.controller,
    required this.onCancel,
    required this.onSave,
  });

  final TextEditingController controller;
  final VoidCallback onCancel;
  final VoidCallback onSave;

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add annotation',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Add comment…',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            maxLines: 3,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: onSave,
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Annotation detail dialog ──────────────────────────────────────────────────

class _AnnotationDetailDialog extends StatelessWidget {
  const _AnnotationDetailDialog({required this.annotation});

  final DrawingAnnotation annotation;

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('dd MMM yyyy, HH:mm').format(annotation.createdAt);
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.location_pin,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          const Text('Annotation'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(annotation.comment),
          const SizedBox(height: 12),
          Text(
            '${annotation.authorName} · $dateStr',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
