// lib/core/services/chat_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat_message.dart';

class ChatService {
  ChatService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String projectId) =>
      _db.collection('projects').doc(projectId).collection('chat');

  /// Real-time stream of the last 50 messages, oldest-first for display.
  Stream<List<ChatMessage>> messagesStream(String projectId) =>
      _col(projectId)
          .orderBy('createdAt')
          .limitToLast(50)
          .snapshots()
          .map(
            (s) => s.docs
                .map(
                  (d) => ChatMessage.fromDoc(
                    d as DocumentSnapshot<Map<String, dynamic>>,
                  ),
                )
                .toList(),
          );

  Future<void> sendMessage({
    required String projectId,
    required String senderUid,
    required String senderName,
    required String text,
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentType,
    List<String> mentions = const [],
  }) async {
    if (text.trim().isEmpty && attachmentUrl == null) return;
    await _col(projectId).add(
      ChatMessage(
        id: '',
        senderUid: senderUid,
        senderName: senderName,
        text: text.trim(),
        createdAt: DateTime.now(),
        attachmentUrl: attachmentUrl,
        attachmentName: attachmentName,
        attachmentType: attachmentType,
        mentions: mentions,
      ).toMap(),
    );
  }
}
