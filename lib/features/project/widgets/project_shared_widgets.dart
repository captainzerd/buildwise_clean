// lib/features/project/widgets/project_shared_widgets.dart
// Shared widgets used across multiple project detail tabs.
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/config/service_locator.dart';
import '../../../core/models/task_item.dart';
import '../../../core/models/task_comment.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/task_service.dart';

class ProjectFullScreenPhoto extends StatelessWidget {
  const ProjectFullScreenPhoto({required this.url, required this.title});
  final String url;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, style: const TextStyle(color: Colors.white)),
      ),
      body: ProjectZoomableNetworkImage(url: url),
    );
  }
}

// ── Multi-photo gallery with swipe carousel ─────────────────────────────────

class ProjectPhotoGallery extends StatefulWidget {
  const ProjectPhotoGallery({required this.urls, required this.initialIndex});
  final List<String> urls;
  final int initialIndex;

  @override
  State<ProjectPhotoGallery> createState() => ProjectPhotoGalleryState();
}

class ProjectPhotoGalleryState extends State<ProjectPhotoGallery> {
  late final PageController _ctrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _ctrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.urls.length;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          total > 1 ? 'Photo ${_current + 1} of $total' : 'Photo',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PageView.builder(
        controller: _ctrl,
        itemCount: total,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) => ProjectZoomableNetworkImage(url: widget.urls[i]),
      ),
    );
  }
}

// ── Shared pinch-to-zoom image ───────────────────────────────────────────────

class ProjectZoomableNetworkImage extends StatelessWidget {
  const ProjectZoomableNetworkImage({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 5,
      child: Center(
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          placeholder: (_, __) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          errorWidget: (_, __, ___) => const Center(
            child: Icon(
              Icons.broken_image_outlined,
              size: 64,
              color: Colors.white54,
            ),
          ),
        ),
      ),
    );
  }
}

class ProjectTasksSheet extends StatelessWidget {
  const ProjectTasksSheet({required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
            child: Row(
              children: [
                Text(
                  'Tasks',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Add task',
                  onPressed: () => _showAddTask(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<TaskItem>>(
              stream: sl<TaskService>().tasksStream(projectId),
              builder: (_, snap) {
                final tasks = snap.data ?? [];
                if (tasks.isEmpty) {
                  return const Center(
                    child: Text('No tasks yet. Tap + to add one.'),
                  );
                }
                return ListView.builder(
                  controller: ctrl,
                  itemCount: tasks.length,
                  itemBuilder: (_, i) {
                    final task = tasks[i];
                    return ProjectTaskTile(
                      task: task,
                      projectId: projectId,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTask(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ProjectAddTaskSheet(projectId: projectId),
    );
  }
}

class ProjectTaskTile extends StatelessWidget {
  const ProjectTaskTile({required this.task, required this.projectId});
  final TaskItem task;
  final String projectId;

  Color _priorityColor(BuildContext ctx) => switch (task.priority) {
        TaskPriority.high => Theme.of(ctx).colorScheme.error,
        TaskPriority.medium => Colors.amber,
        TaskPriority.low => Colors.green,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => ProjectTaskDetailSheet(
          task: task,
          projectId: projectId,
        ),
      ),
      leading: Checkbox(
        value: task.status == TaskStatus.done,
        onChanged: (checked) {
          sl<TaskService>().updateTask(projectId, task.id, {
            'status': checked == true ? 'done' : 'todo',
          });
        },
      ),
      title: Text(
        task.title,
        style: TextStyle(
          decoration: task.status == TaskStatus.done
              ? TextDecoration.lineThrough
              : null,
          color: task.status == TaskStatus.done ? cs.outline : null,
        ),
      ),
      subtitle: task.dueDate != null
          ? Text(
              'Due ${DateFormat('d MMM').format(task.dueDate!)}',
              style: TextStyle(
                color: task.isOverdue ? cs.error : cs.outline,
                fontSize: 12,
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _priorityColor(context),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () => sl<TaskService>().deleteTask(projectId, task.id),
          ),
        ],
      ),
    );
  }
}

/// Task detail sheet showing task info and comment thread.
class ProjectTaskDetailSheet extends StatefulWidget {
  const ProjectTaskDetailSheet({required this.task, required this.projectId});
  final TaskItem task;
  final String projectId;

  @override
  State<ProjectTaskDetailSheet> createState() => ProjectTaskDetailSheetState();
}

class ProjectTaskDetailSheetState extends State<ProjectTaskDetailSheet> {
  final _commentCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    final user = sl<AuthService>().currentUser;
    if (user == null) return;

    setState(() => _sending = true);
    try {
      await sl<TaskService>().addComment(
        widget.projectId,
        widget.task.id,
        TaskComment(
          id: '',
          taskId: widget.task.id,
          projectId: widget.projectId,
          authorUid: user.uid,
          authorName: user.displayName.isNotEmpty ? user.displayName : (user.email.isNotEmpty ? user.email : 'Me'),
          text: text,
          createdAt: DateTime.now(),
        ),
      );
      _commentCtrl.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final task = widget.task;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Chip(
                      label: Text(task.status.name,
                          style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(task.priority.name,
                          style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      backgroundColor: switch (task.priority) {
                        TaskPriority.high => cs.errorContainer,
                        TaskPriority.medium => Colors.amber.shade100,
                        TaskPriority.low => Colors.green.shade100,
                      },
                    ),
                  ],
                ),
                if (task.notes != null && task.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(task.notes!,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Comments',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<TaskComment>>(
              stream:
                  sl<TaskService>().commentsStream(widget.projectId, task.id),
              builder: (_, snap) {
                final comments = snap.data ?? [];
                if (comments.isEmpty) {
                  return Center(
                    child: Text(
                      'No comments yet.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.outline,
                          ),
                    ),
                  );
                }
                return ListView.builder(
                  controller: ctrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: comments.length,
                  itemBuilder: (_, i) {
                    final c = comments[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: cs.secondaryContainer,
                            child: Text(
                              c.authorName.isNotEmpty
                                  ? c.authorName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSecondaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      c.authorName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('d MMM, HH:mm')
                                          .format(c.createdAt),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: cs.outline,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(c.text,
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Write a comment…',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    minLines: 1,
                    maxLines: 3,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                  onPressed: _sending ? null : _sendComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProjectAddTaskSheet extends StatefulWidget {
  const ProjectAddTaskSheet({required this.projectId, this.phaseId});
  final String projectId;
  final String? phaseId;

  @override
  State<ProjectAddTaskSheet> createState() => ProjectAddTaskSheetState();
}

class ProjectAddTaskSheetState extends State<ProjectAddTaskSheet> {
  final _titleCtrl = TextEditingController();
  TaskPriority _priority = TaskPriority.medium;
  DateTime? _dueDate;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New Task', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Task title *',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<TaskPriority>(
            initialValue: _priority,
            decoration: const InputDecoration(
              labelText: 'Priority',
              border: OutlineInputBorder(),
            ),
            items: TaskPriority.values
                .map(
                  (p) => DropdownMenuItem(
                    value: p,
                    child: Text(p.label),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _priority = v ?? _priority),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 7)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
              );
              if (picked != null) setState(() => _dueDate = picked);
            },
            borderRadius: BorderRadius.circular(4),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Due date (optional)',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
              ),
              child: Text(
                _dueDate != null
                    ? DateFormat('d MMM yyyy').format(_dueDate!)
                    : 'Not set',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _dueDate == null
                          ? Theme.of(context).colorScheme.outline
                          : null,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving
                  ? null
                  : () async {
                      final title = _titleCtrl.text.trim();
                      if (title.isEmpty) return;
                      setState(() => _saving = true);
                      await sl<TaskService>().addTask(
                        widget.projectId,
                        TaskItem(
                          id: '',
                          projectId: widget.projectId,
                          phaseId: widget.phaseId,
                          title: title,
                          priority: _priority,
                          status: TaskStatus.todo,
                          dueDate: _dueDate,
                          createdAt: DateTime.now(),
                        ),
                      );
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                    },
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Add Task'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Risks tab ─────────────────────────────────────────────────────────────────


