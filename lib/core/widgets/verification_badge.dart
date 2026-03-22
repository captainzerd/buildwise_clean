// lib/core/widgets/verification_badge.dart
//
// Shared verification badge row for BuilderProfile.
// Shows compact colour-coded chips for each verified credential tier.

import 'package:flutter/material.dart';

import '../models/builder_profile.dart';

/// A row of compact verification badges for a [BuilderProfile].
///
/// Shows only badges that ARE verified. If none are verified, shows a small
/// grey "Unverified" chip.
///
/// Set [compact] to true for smaller chips used in list cards.
class VerificationBadgeRow extends StatelessWidget {
  const VerificationBadgeRow({
    super.key,
    required this.profile,
    this.compact = false,
  });

  final BuilderProfile profile;

  /// When true, renders slightly smaller chips suitable for list card contexts.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final badges = <_VerificationBadge>[];

    // ID Verified (green) — Ghana Card number on file (admin-trusted)
    if (profile.ghanaCardNumber != null) {
      badges.add(
        _VerificationBadge(
          icon: Icons.person_pin_outlined,
          label: 'ID Verified',
          color: Colors.green,
          compact: compact,
        ),
      );
    }

    // NCA Licensed (blue) — licence verified by admin AND NCA doc present
    if (profile.licenceVerificationStatus == 'verified' &&
        profile.licenceDocUrls.containsKey('nca')) {
      badges.add(
        _VerificationBadge(
          icon: Icons.badge_outlined,
          label: profile.ncaClass != null
              ? 'NCA ${profile.ncaClass}'
              : 'NCA Licensed',
          color: Colors.blue,
          compact: compact,
        ),
      );
    }

    // Insured (amber/gold) — insurance verified and not expired
    if (profile.isInsuranceValid) {
      badges.add(
        _VerificationBadge(
          icon: Icons.shield_outlined,
          label: 'Insured',
          color: Colors.amber.shade700,
          compact: compact,
        ),
      );
    }

    // Business Registered (grey-blue / indigo) — biz reg verified
    if (profile.businessRegStatus == 'verified') {
      badges.add(
        _VerificationBadge(
          icon: Icons.business_outlined,
          label: 'Biz Reg.',
          color: Colors.indigo,
          compact: compact,
        ),
      );
    }

    // GIA Member (purple) — Ghana Institute of Architects
    if (profile.licenceVerificationStatus == 'verified' &&
        profile.giaNumber != null) {
      badges.add(
        _VerificationBadge(
          icon: Icons.architecture_outlined,
          label: 'GIA',
          color: Colors.purple,
          compact: compact,
        ),
      );
    }

    // GIOE Member (deep orange) — Ghana Institution of Engineers
    if (profile.licenceVerificationStatus == 'verified' &&
        profile.gioeNumber != null) {
      badges.add(
        _VerificationBadge(
          icon: Icons.engineering_outlined,
          label: 'GIOE',
          color: Colors.deepOrange,
          compact: compact,
        ),
      );
    }

    if (badges.isEmpty) {
      return _VerificationBadge(
        icon: Icons.help_outline,
        label: 'Unverified',
        color: Colors.grey,
        compact: compact,
      );
    }

    return Wrap(
      spacing: compact ? 6 : 8,
      runSpacing: compact ? 4 : 6,
      children: badges,
    );
  }
}

// ── Private badge widget ───────────────────────────────────────────────────────

class _VerificationBadge extends StatelessWidget {
  const _VerificationBadge({
    required this.icon,
    required this.label,
    required this.color,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 11.0 : 13.0;
    final fontSize = compact ? 10.0 : 11.0;
    final hPad = compact ? 6.0 : 8.0;
    final vPad = compact ? 2.0 : 4.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(compact ? 8 : 16),
        border: Border.all(color: color.withValues(alpha: compact ? 0.3 : 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          SizedBox(width: compact ? 3 : 4),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
