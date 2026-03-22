// lib/core/services/task_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/task_comment.dart';
import '../models/task_item.dart';

class TaskService {
  final _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> _col(String projectId) =>
      _db.collection('projects').doc(projectId).collection('tasks');

  /// Stream all tasks for a project, optionally filtered to a phase.
  Stream<List<TaskItem>> tasksStream(
    String projectId, {
    String? phaseId,
  }) {
    Query<Map<String, dynamic>> q =
        _col(projectId).orderBy('createdAt', descending: false);
    if (phaseId != null) {
      q = q.where('phaseId', isEqualTo: phaseId);
    }
    return q.snapshots().map(
          (s) => s.docs
              .map(
                (d) => TaskItem.fromDoc(
                  d as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  /// Stream count of open (todo + inProgress) tasks for a project.
  Stream<int> openTaskCountStream(String projectId) {
    return _col(projectId)
        .where('status', whereIn: ['todo', 'in_progress'])
        .snapshots()
        .map((s) => s.docs.length);
  }

  Future<String> addTask(String projectId, TaskItem task) async {
    final id = _uuid.v4();
    final data = task.toMap()
      ..['projectId'] = projectId
      ..['createdAt'] = FieldValue.serverTimestamp();
    await _col(projectId).doc(id).set(data);
    return id;
  }

  Future<void> updateTask(
    String projectId,
    String taskId,
    Map<String, dynamic> fields,
  ) async {
    await _col(projectId).doc(taskId).update(fields);
  }

  Future<void> deleteTask(String projectId, String taskId) async {
    await _col(projectId).doc(taskId).delete();
  }

  // ── Task Comments ──────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _commentCol(
    String projectId,
    String taskId,
  ) =>
      _col(projectId).doc(taskId).collection('comments');

  /// Stream of comments for a task, oldest first.
  Stream<List<TaskComment>> commentsStream(String projectId, String taskId) =>
      _commentCol(projectId, taskId)
          .orderBy('createdAt')
          .snapshots()
          .map(
            (s) => s.docs
                .map(
                  (d) => TaskComment.fromDoc(
                    d as DocumentSnapshot<Map<String, dynamic>>,
                  ),
                )
                .toList(),
          );

  /// Add a comment to a task.
  Future<String> addComment(
    String projectId,
    String taskId,
    TaskComment comment,
  ) async {
    final id = _uuid.v4();
    await _commentCol(projectId, taskId).doc(id).set({
      ...comment.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return id;
  }

  /// Update comment text.
  Future<void> updateComment(
    String projectId,
    String taskId,
    String commentId,
    String newText,
  ) async {
    await _commentCol(projectId, taskId).doc(commentId).update({
      'text': newText,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete a comment.
  Future<void> deleteComment(
    String projectId,
    String taskId,
    String commentId,
  ) async {
    await _commentCol(projectId, taskId).doc(commentId).delete();
  }
}
