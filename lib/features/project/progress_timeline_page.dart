// lib/features/project/progress_timeline_page.dart
//
// P2.2 – Build Progress Timeline Photo Feed
// Reverse-chronological scrollable photo feed showing all build photos grouped
// by phase.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config/service_locator.dart';
import '../../core/models/phase.dart';
import '../../core/services/project_service.dart';
import '../../core/widgets/empty_state.dart';
import 'widgets/project_shared_widgets.dart';

class ProgressTimelinePage extends StatelessWidget {
  const ProgressTimelinePage({
    super.key,
    required this.projectId,
    required this.projectTitle,
  });

  final String projectId;
  final String projectTitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Build Timeline'),
            if (projectTitle.isNotEmpty)
              Text(
                projectTitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Share update',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _share(context),
          ),
        ],
      ),
      body: StreamBuilder<List<Phase>>(
        stream: sl<ProjectService>().phasesStream(projectId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final phasesWithPhotos = (snap.data ?? [])
              .where((p) => p.completionPhotoUrls.isNotEmpty)
              .toList()
            ..sort((a, b) => b.order.compareTo(a.order));

          if (phasesWithPhotos.isEmpty) {
            return const EmptyState(
              icon: Icons.timeline,
              title: 'No photos yet',
              message:
                  'Progress photos will appear here as your builder uploads them.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: phasesWithPhotos.length,
            separatorBuilder: (_, __) => const Divider(height: 32),
            itemBuilder: (context, index) {
              final phase = phasesWithPhotos[index];
              return _PhaseSection(phase: phase, projectId: projectId);
            },
          );
        },
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    final phases = await sl<ProjectService>().phasesStream(projectId).first;
    final phasesWithPhotos =
        phases.where((p) => p.completionPhotoUrls.isNotEmpty).toList();
    final photoCount =
        phasesWithPhotos.fold<int>(0, (sum, p) => sum + p.completionPhotoUrls.length);
    final phaseCount = phasesWithPhotos.length;

    await Share.share(
      'Build update for $projectTitle: $photoCount photo${photoCount == 1 ? '' : 's'}'
      ' across $phaseCount phase${phaseCount == 1 ? '' : 's'}.',
    );
  }
}

// ── Phase section ──────────────────────────────────────────────────────────────

class _PhaseSection extends StatelessWidget {
  const _PhaseSection({required this.phase, required this.projectId});

  final Phase phase;
  final String projectId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final date = phase.actualEndDate ?? phase.actualStartDate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  phase.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 8),
              _StatusChip(status: phase.status),
              if (date != null) ...[
                const SizedBox(width: 8),
                Text(
                  DateFormat('d MMM yyyy').format(date),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.outline,
                      ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Horizontal photo strip
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: phase.completionPhotoUrls.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, photoIndex) {
              final url = phase.completionPhotoUrls[photoIndex];
              return GestureDetector(
                onTap: () => _openGallery(context, photoIndex),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: url,
                    width: 140,
                    height: 160,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 140,
                      height: 160,
                      color: cs.surfaceContainerHighest,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 140,
                      height: 160,
                      color: cs.surfaceContainerHighest,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: cs.outline,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openGallery(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProjectPhotoGallery(
          urls: phase.completionPhotoUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

// ── Status chip ────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final PhaseStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final (label, bg, fg) = switch (status) {
      PhaseStatus.completed => (
          'Completed',
          cs.primaryContainer,
          cs.onPrimaryContainer,
        ),
      PhaseStatus.inProgress => (
          'In Progress',
          cs.secondaryContainer,
          cs.onSecondaryContainer,
        ),
      PhaseStatus.pendingApproval => (
          'Awaiting Approval',
          cs.tertiaryContainer,
          cs.onTertiaryContainer,
        ),
      PhaseStatus.pending => (
          'Pending',
          cs.surfaceContainerHighest,
          cs.onSurface,
        ),
    };

    return Chip(
      label: Text(label, style: TextStyle(fontSize: 11, color: fg)),
      backgroundColor: bg,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}
