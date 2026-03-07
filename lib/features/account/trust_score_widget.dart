import 'package:flutter/material.dart';

/// Circular arc gauge showing a trust score from 0–100.
/// Colour bands: 0–39=red, 40–69=amber, 70–100=green.
/// Tappable to show a bottom sheet explaining the 6 components.
class TrustScoreWidget extends StatelessWidget {
  const TrustScoreWidget({
    super.key,
    required this.score,
    this.size = 80,
  });

  final int score;
  final double size;

  Color _color(BuildContext context) {
    if (score >= 70) return Colors.green;
    if (score >= 40) return Colors.amber[700]!;
    return Theme.of(context).colorScheme.error;
  }

  void _showBreakdown(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trust Score Breakdown',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            const _ScoreRow(
              label: 'ID Verified',
              points: 20,
              icon: Icons.verified_user_outlined,
            ),
            const _ScoreRow(
              label: 'Licence Verified',
              points: 20,
              icon: Icons.workspace_premium_outlined,
            ),
            const _ScoreRow(
              label: 'Average Rating (up to 25)',
              points: 25,
              icon: Icons.star_outlined,
            ),
            const _ScoreRow(
              label: 'Review Count (up to 10)',
              points: 10,
              icon: Icons.rate_review_outlined,
            ),
            const _ScoreRow(
              label: 'Projects Completed (up to 10)',
              points: 10,
              icon: Icons.done_all,
            ),
            const _ScoreRow(
              label: 'Profile Complete (bio, photo, phone, region)',
              points: 15,
              icon: Icons.person_outlined,
            ),
            const _ScoreRow(
              label: 'Phone Verified (bonus)',
              points: 9,
              icon: Icons.phone_outlined,
            ),
            const SizedBox(height: 8),
            Text(
              'Maximum score: 100 points',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    final pct = (score / 100).clamp(0.0, 1.0);

    return Semantics(
      label: 'Trust score: $score out of 100. Tap to see breakdown.',
      button: true,
      child: GestureDetector(
        onTap: () => _showBreakdown(context),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ExcludeSemantics(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: CircularProgressIndicator(
                    value: pct,
                    strokeWidth: 7,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    color: color,
                  ),
                ),
              ),
              ExcludeSemantics(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$score',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                    ),
                    Text(
                      'Trust',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.label,
    required this.points,
    required this.icon,
  });

  final String label;
  final int points;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(
            '+$points pts',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
