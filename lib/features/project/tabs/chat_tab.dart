// lib/features/project/tabs/chat_tab.dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/service_locator.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/project.dart';
import '../../../core/models/project_document.dart';
import '../../../core/models/team_member.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/services/project_service.dart';

class ChatTab extends StatefulWidget {
  const ChatTab({
    required this.projectId,
    required this.currentUserUid,
    required this.currentUserName,
    required this.chatService,
  });

  final String projectId;
  final String currentUserUid;
  final String currentUserName;
  final ChatService chatService;

  @override
  State<ChatTab> createState() => ChatTabState();
}

class ChatTabState extends State<ChatTab> {
  final _controller = TextEditingController();
  bool _sending = false;

  // Attachment state
  String? _pendingAttachmentUrl;
  String? _pendingAttachmentName;
  String? _pendingAttachmentType;
  bool _uploadingAttachment = false;

  // @mention state
  final List<String> _mentions = [];
  String _mentionQuery = '';
  bool _showMentionBar = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final text = _controller.text;
    final cursorPos = _controller.selection.baseOffset;
    if (cursorPos < 0) return;

    // Find if cursor is immediately after a '@...' token
    final beforeCursor = text.substring(0, cursorPos);
    final atIdx = beforeCursor.lastIndexOf('@');
    if (atIdx != -1) {
      final afterAt = beforeCursor.substring(atIdx + 1);
      // Only show mention bar if no space in the query
      if (!afterAt.contains(' ') && afterAt.length <= 20) {
        setState(() {
          _mentionQuery = afterAt;
          _showMentionBar = true;
        });
        return;
      }
    }
    setState(() => _showMentionBar = false);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    if (picked.path == null) return;

    setState(() => _uploadingAttachment = true);
    try {
      final file = File(picked.path!);
      final ext = picked.extension?.toLowerCase() ?? '';
      final type = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)
          ? 'image'
          : ext == 'pdf'
              ? 'pdf'
              : 'file';

      final url = await sl<ProjectService>().uploadDocument(
        projectId: widget.projectId,
        uploaderUid: widget.currentUserUid,
        file: file,
        fileName: picked.name,
        category: DocumentCategory.other,
        displayName: picked.name,
        contentType:
            picked.extension != null ? 'application/${picked.extension}' : null,
      );
      setState(() {
        _pendingAttachmentUrl = url;
        _pendingAttachmentName = picked.name;
        _pendingAttachmentType = type;
        _uploadingAttachment = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
      setState(() => _uploadingAttachment = false);
    }
  }

  void _selectMention(TeamMember member) {
    // Replace the @query in the text field with @name + space
    final text = _controller.text;
    final cursorPos = _controller.selection.baseOffset;
    final beforeCursor = text.substring(0, cursorPos);
    final atIdx = beforeCursor.lastIndexOf('@');
    if (atIdx == -1) return;

    final newText =
        '${text.substring(0, atIdx)}@${member.displayName} ${text.substring(cursorPos)}';
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
          offset: atIdx + member.displayName.length + 2),
    );
    setState(() {
      if (!_mentions.contains(member.uid)) _mentions.add(member.uid);
      _showMentionBar = false;
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if ((text.isEmpty && _pendingAttachmentUrl == null) || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.chatService.sendMessage(
        projectId: widget.projectId,
        senderUid: widget.currentUserUid,
        senderName: widget.currentUserName,
        text: text,
        attachmentUrl: _pendingAttachmentUrl,
        attachmentName: _pendingAttachmentName,
        attachmentType: _pendingAttachmentType,
        mentions: List<String>.from(_mentions),
      );
      _controller.clear();
      setState(() {
        _pendingAttachmentUrl = null;
        _pendingAttachmentName = null;
        _pendingAttachmentType = null;
        _mentions.clear();
        _showMentionBar = false;
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Project?>(
      stream: sl<ProjectService>().projectStream(widget.projectId),
      builder: (context, projectSnap) {
        final teamMembers = projectSnap.data?.teamMembers ?? [];
        return Column(
          children: [
            Expanded(
              child: StreamBuilder<List<ChatMessage>>(
                stream: widget.chatService.messagesStream(widget.projectId),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final messages = snap.data ?? [];
                  if (messages.isEmpty) {
                    return const Center(
                      child: Text(
                        'No messages yet.\nStart the conversation!',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final msg = messages[i];
                      final isMe = msg.senderUid == widget.currentUserUid;
                      return Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.72,
                          ),
                          decoration: BoxDecoration(
                            color: isMe
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              if (!isMe)
                                Text(
                                  msg.senderName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              if (msg.text.isNotEmpty)
                                _buildMessageText(context, msg),
                              if (msg.attachmentUrl != null) ...[
                                const SizedBox(height: 4),
                                _AttachmentChip(
                                  name: msg.attachmentName ?? 'File',
                                  type: msg.attachmentType ?? 'file',
                                  url: msg.attachmentUrl!,
                                ),
                              ],
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('HH:mm').format(msg.createdAt),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            // @mention suggestion bar
            if (_showMentionBar && teamMembers.isNotEmpty) ...[
              _MentionBar(
                query: _mentionQuery,
                members: teamMembers
                    .where(
                      (m) => m.displayName
                          .toLowerCase()
                          .contains(_mentionQuery.toLowerCase()),
                    )
                    .take(5)
                    .toList(),
                onSelect: _selectMention,
              ),
            ],
            // Attachment preview
            if (_pendingAttachmentUrl != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.attach_file,
                        size: 16, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _pendingAttachmentName ?? 'Attachment',
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => setState(() {
                        _pendingAttachmentUrl = null;
                        _pendingAttachmentName = null;
                        _pendingAttachmentType = null;
                      }),
                    ),
                  ],
                ),
              ),
            ],
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    _uploadingAttachment
                        ? const SizedBox(
                            width: 40,
                            height: 40,
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.attach_file),
                            onPressed: _pickAttachment,
                            tooltip: 'Attach file',
                          ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'Type a message…',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          isDense: true,
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        minLines: 1,
                        maxLines: 4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _sending
                        ? const SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton.filled(
                            icon: const Icon(Icons.send),
                            onPressed: _send,
                          ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMessageText(BuildContext context, ChatMessage msg) {
    final cs = Theme.of(context).colorScheme;
    if (msg.mentions.isEmpty) return Text(msg.text);

    // Bold @name mentions in text — highlight @word patterns
    final spans = <TextSpan>[];
    String remaining = msg.text;
    // Simple approach: highlight words starting with '@'
    final words = remaining.split(' ');
    for (var i = 0; i < words.length; i++) {
      if (words[i].startsWith('@')) {
        spans.add(
          TextSpan(
            text: words[i],
            style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary),
          ),
        );
      } else {
        spans.add(TextSpan(text: words[i]));
      }
      if (i < words.length - 1) spans.add(const TextSpan(text: ' '));
    }
    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: spans,
      ),
    );
  }
}

class _MentionBar extends StatelessWidget {
  const _MentionBar({
    required this.query,
    required this.members,
    required this.onSelect,
  });

  final String query;
  final List<TeamMember> members;
  final ValueChanged<TeamMember> onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (members.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: members
            .map(
              (m) => ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: cs.secondaryContainer,
                  child: Text(
                    m.displayName.isNotEmpty
                        ? m.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                title: Text('@${m.displayName}',
                    style: const TextStyle(fontSize: 13)),
                onTap: () => onSelect(m),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({
    required this.name,
    required this.type,
    required this.url,
  });

  final String name;
  final String type;
  final String url;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = switch (type) {
      'image' => Icons.image_outlined,
      'pdf' => Icons.picture_as_pdf_outlined,
      _ => Icons.attach_file,
    };
    return GestureDetector(
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: cs.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: cs.onSecondaryContainer),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                name,
                style: TextStyle(fontSize: 12, color: cs.onSecondaryContainer),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
