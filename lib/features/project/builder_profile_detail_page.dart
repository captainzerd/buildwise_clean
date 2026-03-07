import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/service_locator.dart';
import '../../core/models/builder_profile.dart';
import '../../core/models/portfolio_item.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/builder_profile_service.dart';
import '../../core/services/portfolio_service.dart';

class BuilderProfileDetailPage extends StatefulWidget {
  const BuilderProfileDetailPage({
    super.key,
    required this.builder,
    this.onSelect,
  });

  final BuilderProfile builder;
  final void Function(BuilderProfile)? onSelect;

  @override
  State<BuilderProfileDetailPage> createState() =>
      _BuilderProfileDetailPageState();
}

class _BuilderProfileDetailPageState extends State<BuilderProfileDetailPage> {
  bool _submittingReview = false;

  Future<void> _showReviewDialog(BuildContext context) async {
    final auth = context.read<AuthService>();
    final service = context.read<BuilderProfileService>();
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    double qualityRating = 0;
    double timelinessRating = 0;
    double communicationRating = 0;
    double valueRating = 0;
    double safetyRating = 0;
    final commentCtrl = TextEditingController();
    String? errorMsg;

    Widget starRow(
      String label,
      double current,
      void Function(double) onChanged,
    ) {
      return StatefulBuilder(
        builder: (ctx2, setStar) => Row(
          children: [
            SizedBox(
              width: 120,
              child: Text(label, style: const TextStyle(fontSize: 13)),
            ),
            for (int i = 1; i <= 5; i++)
              GestureDetector(
                onTap: () {
                  onChanged(i.toDouble());
                  setStar(() {});
                },
                child: Icon(
                  i <= current
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 28,
                  color: Colors.amber[700],
                ),
              ),
          ],
        ),
      );
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Leave a Review'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rate ${widget.builder.displayName}',
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                starRow(
                  'Quality',
                  qualityRating,
                  (v) => setDlgState(() => qualityRating = v),
                ),
                starRow(
                  'Timeliness',
                  timelinessRating,
                  (v) => setDlgState(() => timelinessRating = v),
                ),
                starRow(
                  'Communication',
                  communicationRating,
                  (v) => setDlgState(() => communicationRating = v),
                ),
                starRow(
                  'Value',
                  valueRating,
                  (v) => setDlgState(() => valueRating = v),
                ),
                starRow(
                  'Safety',
                  safetyRating,
                  (v) => setDlgState(() => safetyRating = v),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: commentCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Comment (optional)',
                    border: OutlineInputBorder(),
                    hintText: 'Describe your experience...',
                  ),
                  maxLines: 3,
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMsg!,
                    style: TextStyle(
                      color: Theme.of(ctx).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: (qualityRating == 0 ||
                      timelinessRating == 0 ||
                      communicationRating == 0 ||
                      valueRating == 0 ||
                      safetyRating == 0)
                  ? null
                  : () async {
                      setDlgState(() => errorMsg = null);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        setState(() => _submittingReview = true);
                        Navigator.of(ctx).pop();
                        await service.addReview(
                          builderUid: widget.builder.uid,
                          reviewerUid: uid,
                          quality: qualityRating,
                          timeliness: timelinessRating,
                          communication: communicationRating,
                          value: valueRating,
                          safety: safetyRating,
                          comment: commentCtrl.text.trim(),
                        );
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Review submitted'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Error: $e'), duration: const Duration(seconds: 10)),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _submittingReview = false);
                        }
                      }
                    },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );

    commentCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final currentUid = context.watch<AuthService>().currentUser?.uid;
    final b = widget.builder;

    final reviewsStream = FirebaseFirestore.instance
        .collection('pm_profiles')
        .doc(b.uid)
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(b.displayName.isNotEmpty ? b.displayName : 'Builder'),
        actions: [
          if (widget.onSelect != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onSelect!(b);
              },
              child: const Text('Select'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: cs.primaryContainer,
                    backgroundImage: b.photoUrl != null
                        ? CachedNetworkImageProvider(b.photoUrl!)
                        : null,
                    child: b.photoUrl == null
                        ? Text(
                            _initials(b.displayName),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: cs.onPrimaryContainer,
                            ),
                          )
                        : null,
                  ),
                  if (b.trustScore >= 70)
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Tooltip(
                        message:
                            'Trust Score ${b.trustScore}/100 — Highly Verified',
                        child: Icon(
                          Icons.verified_rounded,
                          size: 22,
                          color: cs.primary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.displayName.isNotEmpty ? b.displayName : 'Unnamed',
                      style: tt.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Chip(
                      label: Text(b.role.label),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 18,
                          color: Colors.amber[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${b.averageRating.toStringAsFixed(1)}  '
                          '(${b.reviewCount} review${b.reviewCount == 1 ? '' : 's'})',
                          style: tt.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Trust score pill
                    _TrustScorePill(score: b.trustScore),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          b.availableForHire
                              ? Icons.check_circle_outline
                              : Icons.cancel_outlined,
                          size: 14,
                          color: b.availableForHire ? Colors.green : cs.error,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          b.availableForHire
                              ? 'Available for hire'
                              : 'Currently unavailable',
                          style: tt.bodySmall?.copyWith(
                            color: b.availableForHire ? Colors.green : cs.error,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Verification badges ──────────────────────────────────────────
          _VerificationBadgeRow(builder: b),

          const SizedBox(height: 16),

          // ── Reputation scores ────────────────────────────────────────────
          if (b.reviewCount > 0 ||
              b.projectSuccessScore > 0 ||
              b.safetyComplianceScore > 0) ...[
            Text('Reputation Scores', style: tt.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ScoreCard(
                    label: 'Project Success',
                    score: b.projectSuccessScore,
                    icon: Icons.trending_up_rounded,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ScoreCard(
                    label: 'Safety',
                    score: b.safetyComplianceScore,
                    icon: Icons.shield_outlined,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DisputeCard(count: b.disputeCount),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // ── Contact buttons ──────────────────────────────────────────────
          if (b.phone != null || b.whatsappNumber != null)
            Row(
              children: [
                if (b.phone != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.phone_outlined, size: 18),
                      label: const Text('Call'),
                      onPressed: () => _launch('tel:${b.phone}'),
                    ),
                  ),
                if (b.phone != null && b.whatsappNumber != null)
                  const SizedBox(width: 8),
                if (b.whatsappNumber != null)
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => _launchWhatsApp(
                        b.whatsappNumber!,
                        'Hi ${b.displayName}, I found your profile on WyseBrix.',
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_outlined, size: 18),
                          SizedBox(width: 6),
                          Text('WhatsApp'),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

          const SizedBox(height: 16),

          // ── Bio ──────────────────────────────────────────────────────────
          if (b.bio.isNotEmpty) ...[
            Text('About', style: tt.titleSmall),
            const SizedBox(height: 6),
            Text(b.bio, style: tt.bodyMedium),
            const SizedBox(height: 16),
          ],

          // ── Info card ────────────────────────────────────────────────────
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  if (b.location != null)
                    _InfoRow(
                      icon: Icons.place_outlined,
                      label: 'Location',
                      value: b.location!,
                    ),
                  if (b.region.isNotEmpty)
                    _InfoRow(
                      icon: Icons.map_outlined,
                      label: 'Region',
                      value: b.region,
                    ),
                  if (b.yearsExperience != null)
                    _InfoRow(
                      icon: Icons.work_history_outlined,
                      label: 'Experience',
                      value:
                          '${b.yearsExperience} year${b.yearsExperience == 1 ? "" : "s"}',
                    ),
                  if (b.projectsCompleted > 0)
                    _InfoRow(
                      icon: Icons.check_circle_outline,
                      label: 'Projects',
                      value: '${b.projectsCompleted} completed',
                    ),
                  if (b.minimumBudgetGhs != null)
                    _InfoRow(
                      icon: Icons.payments_outlined,
                      label: 'Min. Budget',
                      value:
                          'GHS ${NumberFormat('#,##0').format(b.minimumBudgetGhs)}',
                    ),
                  if (b.ncaClass != null)
                    _InfoRow(
                      icon: Icons.badge_outlined,
                      label: 'NCA Class',
                      value: b.ncaClass!,
                    ),
                  if (b.contractorGrade != null)
                    _InfoRow(
                      icon: Icons.grade_outlined,
                      label: 'Grade',
                      value: b.contractorGrade!,
                    ),
                  if (b.email != null)
                    _InfoRow(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: b.email!,
                    ),
                ],
              ),
            ),
          ),

          // ── Specializations ──────────────────────────────────────────────
          if (b.specializations.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Specializations', style: tt.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final s in b.specializations)
                  Chip(
                    label: Text(s),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
          ],

          const SizedBox(height: 20),

          // ── Portfolio ────────────────────────────────────────────────────
          _PortfolioSection(builderUid: b.uid),

          const SizedBox(height: 20),

          // ── Reviews ──────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text('Reviews', style: tt.titleSmall),
              ),
              if (currentUid != null && currentUid != b.uid) ...[
                if (_submittingReview)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton.icon(
                    icon: const Icon(Icons.rate_review_outlined, size: 16),
                    label: const Text('Leave a Review'),
                    onPressed: () => _showReviewDialog(context),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          StreamBuilder<QuerySnapshot>(
            stream: reviewsStream,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? const [];
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No reviews yet.',
                    style: tt.bodySmall?.copyWith(color: cs.outline),
                  ),
                );
              }
              return Column(
                children: [for (final doc in docs) _ReviewTile(doc: doc)],
              );
            },
          ),

          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchWhatsApp(String number, String message) async {
    final clean = number.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse(
      'https://wa.me/$clean?text=${Uri.encodeComponent(message)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

// ── Trust score pill ──────────────────────────────────────────────────────────

class _TrustScorePill extends StatelessWidget {
  const _TrustScorePill({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 70
        ? Colors.green
        : score >= 40
            ? Colors.orange
            : Colors.grey;

    return Tooltip(
      message: 'Trust Score: $score / 100\n'
          'Based on ID verification, NCA licence, business registration, '
          'insurance, reviews, and profile completeness.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.security_outlined, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              'Trust Score: $score/100',
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Verification badge row ────────────────────────────────────────────────────

class _VerificationBadgeRow extends StatelessWidget {
  const _VerificationBadgeRow({required this.builder});
  final BuilderProfile builder;

  @override
  Widget build(BuildContext context) {
    final badges = <_Badge>[];

    if (builder.licenceVerificationStatus == 'verified' &&
        builder.licenceDocUrls.containsKey('nca')) {
      badges.add(
        const _Badge(
          icon: Icons.badge_outlined,
          label: 'NCA Licensed',
          color: Colors.blue,
        ),
      );
    }

    if (builder.businessRegStatus == 'verified') {
      badges.add(
        const _Badge(
          icon: Icons.business_outlined,
          label: 'Business Reg.',
          color: Colors.indigo,
        ),
      );
    }

    if (builder.isInsuranceValid) {
      badges.add(
        const _Badge(
          icon: Icons.shield_outlined,
          label: 'Insured',
          color: Colors.teal,
        ),
      );
    }

    if (builder.licenceVerificationStatus == 'verified' &&
        builder.giaNumber != null) {
      badges.add(
        const _Badge(
          icon: Icons.architecture_outlined,
          label: 'GIA Member',
          color: Colors.purple,
        ),
      );
    }

    if (builder.licenceVerificationStatus == 'verified' &&
        builder.gioeNumber != null) {
      badges.add(
        const _Badge(
          icon: Icons.engineering_outlined,
          label: 'GIOE Member',
          color: Colors.deepOrange,
        ),
      );
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: badges,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

// ── Reputation score cards ────────────────────────────────────────────────────

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.label,
    required this.score,
    required this.icon,
    required this.color,
  });
  final String label;
  final double score;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                '${score.round()}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      );
}

class _DisputeCard extends StatelessWidget {
  const _DisputeCard({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = count == 0 ? Colors.green : Colors.orange;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Icon(Icons.gavel_outlined, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Disputes',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Portfolio section ─────────────────────────────────────────────────────────

class _PortfolioSection extends StatelessWidget {
  const _PortfolioSection({required this.builderUid});
  final String builderUid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PortfolioItem>>(
      stream: sl<PortfolioService>().portfolioStream(builderUid),
      builder: (context, snap) {
        final items = snap.data ?? [];
        if (snap.connectionState == ConnectionState.waiting && items.isEmpty) {
          return const SizedBox.shrink();
        }
        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Portfolio', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _PortfolioItemCard(item: items[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PortfolioItemCard extends StatelessWidget {
  const _PortfolioItemCard({required this.item});
  final PortfolioItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0', 'en_GH');

    return SizedBox(
      width: 180,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.photoUrls.isNotEmpty)
              CachedNetworkImage(
                imageUrl: item.photoUrls.first,
                height: 110,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(height: 110, color: cs.surfaceContainerHighest),
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.broken_image_outlined),
              )
            else
              Container(
                height: 80,
                color: cs.surfaceContainerHighest,
                child: Center(
                  child: Icon(Icons.image_outlined, color: cs.outline),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.labelMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.projectType} · ${item.completedYear}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.outline,
                        ),
                  ),
                  if (item.contractValueGhs != null)
                    Text(
                      'GHS ${fmt.format(item.contractValueGhs)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: cs.primary,
                          ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Info row ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.outline),
          const SizedBox(width: 8),
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.outline),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

// ── Review tile ───────────────────────────────────────────────────────────────

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.doc});
  final DocumentSnapshot doc;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rating = (data['rating'] as num?)?.toDouble() ?? 0;
    final comment = (data['comment'] as String?)?.trim() ?? '';
    final ts = data['createdAt'];
    DateTime? date;
    if (ts is Timestamp) date = ts.toDate();

    // 5-dimension mini scores
    final quality = (data['quality'] as num?)?.toDouble();
    final timeliness = (data['timeliness'] as num?)?.toDouble();
    final communication = (data['communication'] as num?)?.toDouble();
    final value = (data['value'] as num?)?.toDouble();
    final safety = (data['safety'] as num?)?.toDouble();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 1; i <= 5; i++)
                      Icon(
                        i <= rating ? Icons.star_rounded : Icons.star_outline,
                        size: 16,
                        color: Colors.amber[700],
                      ),
                  ],
                ),
                const Spacer(),
                if (date != null)
                  Text(
                    DateFormat('d MMM yyyy').format(date),
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: cs.outline),
                  ),
              ],
            ),
            if (quality != null) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                children: [
                  _MiniScore(label: 'Quality', score: quality),
                  _MiniScore(label: 'Timeliness', score: timeliness ?? 0),
                  _MiniScore(label: 'Comms', score: communication ?? 0),
                  _MiniScore(label: 'Value', score: value ?? 0),
                  _MiniScore(label: 'Safety', score: safety ?? 0),
                ],
              ),
            ],
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(comment, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniScore extends StatelessWidget {
  const _MiniScore({required this.label, required this.score});
  final String label;
  final double score;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
        Text(
          score.toStringAsFixed(1),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Icon(Icons.star_rounded, size: 11, color: Colors.amber[700]),
      ],
    );
  }
}
