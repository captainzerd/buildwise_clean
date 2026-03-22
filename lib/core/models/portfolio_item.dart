// lib/core/models/portfolio_item.dart
//
// A single past-project entry on a contractor's public profile.
// Stored at: pm_profiles/{uid}/portfolio/{id}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Ghana construction project categories shown in the portfolio picker.
const kPortfolioProjectTypes = [
  'Residential',
  'Commercial',
  'Industrial',
  'Infrastructure',
  'Renovation / Remodelling',
  'Institutional',
  'Hospitality',
  'Mixed-Use',
];

@immutable
class PortfolioItem {
  const PortfolioItem({
    required this.id,
    required this.title,
    required this.projectType,
    required this.region,
    required this.completedYear,
    this.contractValueGhs,
    this.description,
    this.photoUrls = const [],
    this.clientName,
    this.clientVerified = false,
  });

  final String id;

  /// Short project title (e.g. "3-bedroom residential, East Legon").
  final String title;

  /// One of [kPortfolioProjectTypes].
  final String projectType;

  /// Ghana region where the project was built.
  final String region;

  /// Year the project was completed.
  final int completedYear;

  /// Contract value in Ghanaian Cedis (optional).
  final double? contractValueGhs;

  /// Free-form description of scope and achievements.
  final String? description;

  /// Firebase Storage download URLs of project photos (up to 5).
  final List<String> photoUrls;

  /// Client / employer name shown on the public portfolio.
  final String? clientName;

  /// True once the client has confirmed this project via email (future feature).
  final bool clientVerified;

  factory PortfolioItem.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return PortfolioItem(
      id: doc.id,
      title: d['title'] as String? ?? '',
      projectType: d['projectType'] as String? ?? 'Residential',
      region: d['region'] as String? ?? '',
      completedYear:
          (d['completedYear'] as num?)?.toInt() ?? DateTime.now().year,
      contractValueGhs: (d['contractValueGhs'] as num?)?.toDouble(),
      description: d['description'] as String?,
      photoUrls: (d['photoUrls'] as List?)?.cast<String>() ?? const [],
      clientName: d['clientName'] as String?,
      clientVerified: d['clientVerified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'projectType': projectType,
        'region': region,
        'completedYear': completedYear,
        if (contractValueGhs != null) 'contractValueGhs': contractValueGhs,
        if (description != null) 'description': description,
        'photoUrls': photoUrls,
        if (clientName != null) 'clientName': clientName,
        'clientVerified': clientVerified,
      };
}
