// lib/features/project/widgets/photo_evidence_section.dart
//
// Widget that lets builders upload geotagged progress photos for a phase.
// Requires at least [minPhotos] photos before the phase can be submitted for
// owner approval (anti-fraud feature for diaspora clients).

import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/widgets/shimmer_box.dart';
import 'project_shared_widgets.dart';

class PhotoEvidenceSection extends StatefulWidget {
  const PhotoEvidenceSection({
    super.key,
    required this.projectId,
    required this.phaseId,
    required this.photoUrls,
    required this.onPhotosChanged,
    this.minPhotos = 2,
  });

  final String projectId;
  final String phaseId;
  final List<String> photoUrls;

  /// Called after photos are successfully added or removed so the parent can
  /// refresh its state (e.g. re-evaluate the submit-for-approval guard).
  final VoidCallback onPhotosChanged;

  /// Minimum number of photos required before approval can be submitted.
  final int minPhotos;

  @override
  State<PhotoEvidenceSection> createState() => _PhotoEvidenceSectionState();
}

class _PhotoEvidenceSectionState extends State<PhotoEvidenceSection> {
  bool _uploading = false;
  double _uploadProgress = 0;
  StreamSubscription<TaskSnapshot>? _uploadSub;

  @override
  void dispose() {
    _uploadSub?.cancel();
    super.dispose();
  }

  // ── Photo picker ──────────────────────────────────────────────────────────

  Future<void> _pickPhoto(ImageSource source) async {
    // Guard against double-tap: set uploading flag before any async gap.
    if (_uploading) return;
    setState(() {
      _uploading = true;
      _uploadProgress = 0;
    });

    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1920,
      );
      if (file == null) {
        if (mounted) setState(() => _uploading = false);
        return;
      }
      await _uploadPhoto(file);
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick photo: $e')),
        );
      }
    }
  }

  // ── Geolocation (best-effort) ─────────────────────────────────────────────

  Future<String?> _fetchGeoTag() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      return '${pos.latitude.toStringAsFixed(5)}, '
          '${pos.longitude.toStringAsFixed(5)}';
    } catch (_) {
      return null; // Never block upload for location failure
    }
  }

  // ── Firebase Storage upload ───────────────────────────────────────────────

  Future<void> _uploadPhoto(XFile file) async {
    // Note: _uploading = true is already set by _pickPhoto before calling here.
    try {
      // Capture geotag in parallel with upload prep (best-effort)
      final geoFuture = _fetchGeoTag();

      final uuid = const Uuid().v4();
      final storagePath =
          'projects/${widget.projectId}/phases/${widget.phaseId}/photos/$uuid.jpg';

      final ref = FirebaseStorage.instance.ref(storagePath);
      final uploadTask = ref.putFile(
        File(file.path),
        SettableMetadata(contentType: 'image/jpeg'),
      );

      _uploadSub = uploadTask.snapshotEvents.listen((snapshot) {
        if (!mounted) return;
        setState(() {
          _uploadProgress =
              snapshot.bytesTransferred / (snapshot.totalBytes == 0
                  ? 1
                  : snapshot.totalBytes);
        });
      });

      await uploadTask;
      await _uploadSub?.cancel();
      _uploadSub = null;
      final downloadUrl = await ref.getDownloadURL();
      final geoTag = await geoFuture;

      // Persist URL (and optional geotag as metadata) to Firestore
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('phases')
          .doc(widget.phaseId)
          .update({
        'completionPhotoUrls': FieldValue.arrayUnion([downloadUrl]),
        if (geoTag != null)
          'photoGeoTags.$uuid': geoTag, // store per-photo geotag
      });

      if (mounted) {
        setState(() {
          _uploading = false;
        });
        widget.onPhotosChanged();
        if (geoTag != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Photo uploaded  •  GPS: $geoTag')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Photo uploaded (no GPS — location permission denied)',
              ),
            ),
          );
        }
      }
    } catch (e) {
      await _uploadSub?.cancel();
      _uploadSub = null;
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  // ── Source picker bottom sheet ────────────────────────────────────────────

  void _showSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final photoCount = widget.photoUrls.length;
    final meetsMinimum = photoCount >= widget.minPhotos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header row ──
        Row(
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 16,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              'Progress Photos',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const Spacer(),
            // Photo count badge
            _PhotoCountChip(
              count: photoCount,
              minPhotos: widget.minPhotos,
            ),
          ],
        ),
        const SizedBox(height: 8),

        // ── Photo grid ──
        if (widget.photoUrls.isNotEmpty)
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.photoUrls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ProjectPhotoGallery(
                      urls: widget.photoUrls,
                      initialIndex: i,
                    ),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: widget.photoUrls[i],
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        const ShimmerBox(width: 60, height: 60),
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
          ),

        if (widget.photoUrls.isNotEmpty) const SizedBox(height: 8),

        // ── Upload progress ──
        if (_uploading) ...[
          LinearProgressIndicator(value: _uploadProgress),
          const SizedBox(height: 6),
          Text(
            'Uploading… ${(_uploadProgress * 100).toStringAsFixed(0)}%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
        ],

        // ── Helper text when below minimum ──
        if (!meetsMinimum)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Add at least ${widget.minPhotos} progress photos to submit for approval'
              '${photoCount > 0 ? ' (${widget.minPhotos - photoCount} more needed)' : ''}.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.error,
                  ),
            ),
          ),

        // ── Add Photo button ──
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.add_a_photo_outlined, size: 16),
            label: const Text('Add Photo'),
            onPressed: _uploading ? null : _showSourceSheet,
          ),
        ),
      ],
    );
  }
}

// ── Photo count chip ──────────────────────────────────────────────────────────

class _PhotoCountChip extends StatelessWidget {
  const _PhotoCountChip({required this.count, required this.minPhotos});
  final int count;
  final int minPhotos;

  @override
  Widget build(BuildContext context) {
    final meetsMinimum = count >= minPhotos;
    final bg = meetsMinimum ? Colors.green.shade100 : Colors.grey.shade200;
    final fg = meetsMinimum ? Colors.green.shade800 : Colors.grey.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count == 1 ? '1 photo' : '$count photos',
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
