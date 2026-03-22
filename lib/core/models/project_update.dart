import 'package:cloud_firestore/cloud_firestore.dart';

class ProjectUpdate {
  final String id;
  final String authorUid;
  final String text;
  final List<String> photoUrls;
  final double? costDelta;
  final DateTime createdAt;
  final double? photoLat;
  final double? photoLng;
  final String? aiVerificationStatus; // null | 'pending' | 'verified' | 'flagged'
  final int? aiSuggestedProgress; // 0-100 (set by AI, future)
  final String? updateType; // 'daily' | 'milestone' | 'incident' | null

  ProjectUpdate({
    required this.id,
    required this.authorUid,
    required this.text,
    this.photoUrls = const [],
    this.costDelta,
    required this.createdAt,
    this.photoLat,
    this.photoLng,
    this.aiVerificationStatus,
    this.aiSuggestedProgress,
    this.updateType,
  });

  bool get hasGps => photoLat != null && photoLng != null;

  factory ProjectUpdate.fromMap(String id, Map<String, dynamic> m) =>
      ProjectUpdate(
        id: id,
        authorUid: m['authorUid'] ?? '',
        text: m['text'] ?? '',
        photoUrls: (m['photoUrls'] as List?)?.cast<String>() ?? const [],
        costDelta: (m['costDelta'] as num?)?.toDouble(),
        createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        photoLat: (m['photoLat'] as num?)?.toDouble(),
        photoLng: (m['photoLng'] as num?)?.toDouble(),
        aiVerificationStatus: m['aiVerificationStatus'] as String?,
        aiSuggestedProgress: (m['aiSuggestedProgress'] as num?)?.toInt(),
        updateType: m['updateType'] as String?,
      );

  factory ProjectUpdate.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      ProjectUpdate.fromMap(doc.id, doc.data() ?? {});

  Map<String, dynamic> toMap() => {
        'authorUid': authorUid,
        'text': text,
        'photoUrls': photoUrls,
        if (costDelta != null) 'costDelta': costDelta,
        'createdAt': Timestamp.fromDate(createdAt),
        if (photoLat != null) 'photoLat': photoLat,
        if (photoLng != null) 'photoLng': photoLng,
        if (aiVerificationStatus != null)
          'aiVerificationStatus': aiVerificationStatus,
        if (aiSuggestedProgress != null)
          'aiSuggestedProgress': aiSuggestedProgress,
        if (updateType != null) 'updateType': updateType,
      };
}
