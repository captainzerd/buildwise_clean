// lib/core/models/task_comment.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// A comment on a task.
/// Stored at: projects/{projectId}/tasks/{taskId}/comments/{commentId}
@immutable
class TaskComment {
  const TaskComment({
    required this.id,
    required this.taskId,
    required this.projectId,
    required this.authorUid,
    required this.authorName,
    required this.text,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String taskId;
  final String projectId;
  final String authorUid;
  final String authorName;
  final String text;
  final DateTime createdAt;
  final DateTime? updatedAt;

  factory TaskComment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return TaskComment(
      id: doc.id,
      taskId: d['taskId'] as String? ?? '',
      projectId: d['projectId'] as String? ?? '',
      authorUid: d['authorUid'] as String? ?? '',
      authorName: d['authorName'] as String? ?? 'Unknown',
      text: d['text'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'taskId': taskId,
        'projectId': projectId,
        'authorUid': authorUid,
        'authorName': authorName,
        'text': text,
        'createdAt': Timestamp.fromDate(createdAt),
        if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      };
}
