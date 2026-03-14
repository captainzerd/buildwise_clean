// lib/core/models/chat_message.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderUid,
    required this.senderName,
    required this.text,
    required this.createdAt,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentType,
    this.mentions = const [],
  });

  final String id;
  final String senderUid;
  final String senderName;
  final String text;
  final DateTime createdAt;

  /// Optional file attachment URL (Firebase Storage download URL).
  final String? attachmentUrl;

  /// Original file name of the attachment.
  final String? attachmentName;

  /// Attachment MIME category: 'image' | 'pdf' | 'file'.
  final String? attachmentType;

  /// List of mentioned user UIDs (shown as bold @name in the bubble).
  final List<String> mentions;

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ChatMessage(
      id: doc.id,
      senderUid: d['senderUid'] as String? ?? '',
      senderName: d['senderName'] as String? ?? 'Unknown',
      text: d['text'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      attachmentUrl: d['attachmentUrl'] as String?,
      attachmentName: d['attachmentName'] as String?,
      attachmentType: d['attachmentType'] as String?,
      mentions: (d['mentions'] as List?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toMap() => {
        'senderUid': senderUid,
        'senderName': senderName,
        'text': text,
        'createdAt': Timestamp.fromDate(createdAt),
        if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
        if (attachmentName != null) 'attachmentName': attachmentName,
        if (attachmentType != null) 'attachmentType': attachmentType,
        if (mentions.isNotEmpty) 'mentions': mentions,
      };
}
