// lib/core/models/task_item.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum TaskStatus { todo, inProgress, done }

extension TaskStatusLabel on TaskStatus {
  String get label => switch (this) {
        TaskStatus.todo => 'To Do',
        TaskStatus.inProgress => 'In Progress',
        TaskStatus.done => 'Done',
      };

  String get firestoreValue => switch (this) {
        TaskStatus.todo => 'todo',
        TaskStatus.inProgress => 'in_progress',
        TaskStatus.done => 'done',
      };
}

TaskStatus taskStatusFromString(String? s) => switch (s) {
      'in_progress' => TaskStatus.inProgress,
      'done' => TaskStatus.done,
      _ => TaskStatus.todo,
    };

enum TaskPriority { low, medium, high }

extension TaskPriorityLabel on TaskPriority {
  String get label => switch (this) {
        TaskPriority.low => 'Low',
        TaskPriority.medium => 'Medium',
        TaskPriority.high => 'High',
      };

  String get firestoreValue => name;
}

TaskPriority taskPriorityFromString(String? s) => switch (s) {
      'high' => TaskPriority.high,
      'medium' => TaskPriority.medium,
      _ => TaskPriority.low,
    };

@immutable
class TaskItem {
  const TaskItem({
    required this.id,
    required this.projectId,
    required this.title,
    required this.status,
    required this.priority,
    required this.createdAt,
    this.phaseId,
    this.assigneeUid,
    this.assigneeName,
    this.dueDate,
    this.notes,
  });

  final String id;
  final String projectId;
  final String? phaseId;
  final String title;
  final String? assigneeUid;
  final String? assigneeName;
  final DateTime? dueDate;
  final TaskStatus status;
  final TaskPriority priority;
  final String? notes;
  final DateTime createdAt;

  bool get isOverdue =>
      dueDate != null &&
      dueDate!.isBefore(DateTime.now()) &&
      status != TaskStatus.done;

  factory TaskItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return TaskItem(
      id: doc.id,
      projectId: d['projectId'] as String? ?? '',
      phaseId: d['phaseId'] as String?,
      title: d['title'] as String? ?? '',
      assigneeUid: d['assigneeUid'] as String?,
      assigneeName: d['assigneeName'] as String?,
      dueDate: (d['dueDate'] as Timestamp?)?.toDate(),
      status: taskStatusFromString(d['status'] as String?),
      priority: taskPriorityFromString(d['priority'] as String?),
      notes: d['notes'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        if (phaseId != null) 'phaseId': phaseId,
        'title': title,
        if (assigneeUid != null) 'assigneeUid': assigneeUid,
        if (assigneeName != null) 'assigneeName': assigneeName,
        if (dueDate != null) 'dueDate': Timestamp.fromDate(dueDate!),
        'status': status.firestoreValue,
        'priority': priority.firestoreValue,
        if (notes != null) 'notes': notes,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  TaskItem copyWith({
    String? title,
    String? phaseId,
    String? assigneeUid,
    String? assigneeName,
    DateTime? dueDate,
    TaskStatus? status,
    TaskPriority? priority,
    String? notes,
  }) =>
      TaskItem(
        id: id,
        projectId: projectId,
        phaseId: phaseId ?? this.phaseId,
        title: title ?? this.title,
        assigneeUid: assigneeUid ?? this.assigneeUid,
        assigneeName: assigneeName ?? this.assigneeName,
        dueDate: dueDate ?? this.dueDate,
        status: status ?? this.status,
        priority: priority ?? this.priority,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );
}
