import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:firebase_storage/firebase_storage.dart';

import 'package:fundmate_app/services/chat_service.dart';
import 'package:fundmate_app/widgets/fundmate_app_bar.dart';
import 'package:fundmate_app/widgets/theme_toggle_button.dart';
import 'package:fundmate_app/theme/app_colors.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String title;
  final String subtitle;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.title,
    required this.subtitle,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _composerFocus = FocusNode();
  bool _isSending = false;
  bool _isUploading = false;
  String? _editingMessageId;
  Map<String, dynamic>? _pendingForward;
  int _messageCount = 0;
  DateTime? _lastMarkReadAt;

  String get userId => FirebaseAuth.instance.currentUser!.uid;
  String get userName =>
      FirebaseAuth.instance.currentUser?.email?.split('@').first ?? 'User';

  @override
  void initState() {
    super.initState();
    _markReadSafely();
  }

  @override
  void dispose() {
    _markReadSafely();
    _messageController.dispose();
    _scrollController.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  Future<void> _markReadSafely({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _lastMarkReadAt != null &&
        now.difference(_lastMarkReadAt!) < const Duration(seconds: 1)) {
      return;
    }
    _lastMarkReadAt = now;
    try {
      await ChatService.markAsRead(widget.chatId, userId);
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text;
    if (text.trim().isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      if (_editingMessageId != null) {
        await ChatService.editMessage(
          chatId: widget.chatId,
          messageId: _editingMessageId!,
          newText: text,
        );
        _editingMessageId = null;
      } else if (_pendingForward != null) {
        await ChatService.sendForwardedMessage(
          chatId: widget.chatId,
          senderId: userId,
          senderName: userName,
          forwardedFrom: _pendingForward!,
          comment: text,
        );
        _pendingForward = null;
      } else {
        await ChatService.sendTextMessage(
          chatId: widget.chatId,
          senderId: userId,
          senderName: userName,
          text: text,
        );
      }
      _messageController.clear();
      _markReadSafely();
      _scheduleScrollToBottom(animate: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _isSending = false);
  }

  Future<Uint8List?> _readPickedFileBytes(PlatformFile picked) async {
    if (picked.bytes != null && picked.bytes!.isNotEmpty) {
      return picked.bytes;
    }
    final path = picked.path;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (await file.exists()) {
        return file.readAsBytes();
      }
    }
    return null;
  }

  Future<void> _pickAndSendFile() async {
    if (_isUploading || _isSending) return;

    // On desktop, read from disk path — withData loads entire file in memory
    // and often returns null for larger files on Windows.
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.first;
    final bytes = await _readPickedFileBytes(picked);
    if (bytes == null || bytes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read the selected file'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    const maxBytes = 15 * 1024 * 1024;
    if (bytes.length > maxBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File is too large (max 15 MB)'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _isUploading = true);
    try {
      await ChatService.sendFileMessage(
        chatId: widget.chatId,
        senderId: userId,
        senderName: userName,
        data: bytes,
        fileName: picked.name,
      );
      _markReadSafely();
      _scheduleScrollToBottom(animate: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _isUploading = false);
  }

  void _scheduleScrollToBottom({bool animate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  void _onMessagesUpdated(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> messages,
  ) {
    final count = messages.length;
    if (count == 0) return;

    if (count != _messageCount) {
      final previousCount = _messageCount;
      _messageCount = count;
      _scheduleScrollToBottom(animate: false);

      if (previousCount == 0) {
        _markReadSafely(force: true);
      } else {
        final last = messages.last.data();
        if (last['senderId'] != userId) {
          _markReadSafely();
        }
      }
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortMessages(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final sorted = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);
    sorted.sort((a, b) {
      final aTime = a.data()['createdAt'] as Timestamp?;
      final bTime = b.data()['createdAt'] as Timestamp?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return -1;
      if (bTime == null) return 1;
      return aTime.compareTo(bTime);
    });
    return sorted;
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final hour =
        date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  Future<void> _showMessageOptions({
    required String messageId,
    required Map<String, dynamic> data,
    required bool isMe,
  }) async {
    final deleted = data['deleted'] == true;
    final type = data['type']?.toString() ?? 'text';
    final isText = type == 'text';
    final isFile = type == 'file';

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Message options',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (isFile && !deleted)
                  _messageOptionTile(
                    sheetContext,
                    value: 'open',
                    icon: Icons.open_in_new,
                    label: 'Open file',
                  ),
                _messageOptionTile(
                  sheetContext,
                  value: 'copy',
                  icon: Icons.copy,
                  label: 'Copy',
                ),
                if (isMe && isText && !deleted)
                  _messageOptionTile(
                    sheetContext,
                    value: 'edit',
                    icon: Icons.edit_outlined,
                    label: 'Edit',
                  ),
                if (!deleted)
                  _messageOptionTile(
                    sheetContext,
                    value: 'forward',
                    icon: Icons.forward,
                    label: 'Forward',
                  ),
                if (isMe && !deleted)
                  _messageOptionTile(
                    sheetContext,
                    value: 'delete',
                    icon: Icons.delete_outline,
                    label: 'Delete',
                    isDestructive: true,
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    switch (action) {
      case 'open':
        await _openFileUrl(data);
        break;
      case 'copy':
        await _copyMessage(data);
        break;
      case 'edit':
        if (isMe && isText && !deleted) _startEdit(messageId, data);
        break;
      case 'delete':
        if (isMe && !deleted) await _confirmDelete(messageId);
        break;
      case 'forward':
        if (!deleted) await _startForward(data);
        break;
    }
  }

  Widget _messageOptionTile(
    BuildContext sheetContext, {
    required String value,
    required IconData icon,
    required String label,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive
            ? Colors.red
            : Theme.of(sheetContext).colorScheme.primary,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isDestructive
              ? Colors.red
              : Theme.of(sheetContext).colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () => Navigator.pop(sheetContext, value),
    );
  }

  Future<void> _copyMessage(Map<String, dynamic> data) async {
    final type = data['type']?.toString() ?? 'text';
    String value;
    if (type == 'file') {
      value = data['fileUrl']?.toString() ?? data['fileName']?.toString() ?? '';
    } else {
      value = data['text']?.toString() ?? '';
    }
    if (value.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied to clipboard', style: TextStyle(color: Colors.white), ), ),
      );
    }
  }

  void _startEdit(String messageId, Map<String, dynamic> data) {
    setState(() {
      _editingMessageId = messageId;
      _pendingForward = null;
      _messageController.text = data['text']?.toString() ?? '';
    });
    _focusComposer();
  }

  Future<void> _startForward(Map<String, dynamic> data) async {
    final type = data['type']?.toString() ?? 'text';
    final originalSender = data['senderName']?.toString() ?? 'User';

    final forwardPayload = <String, dynamic>{
      'originalSender': originalSender,
      'type': type,
    };

    if (type == 'file') {
      final fileUrl = await _resolveFileUrl(data);
      if (fileUrl.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot forward — file link is unavailable'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      forwardPayload['fileName'] = data['fileName']?.toString() ?? 'file';
      forwardPayload['fileUrl'] = fileUrl;
      final storagePath = data['storagePath']?.toString();
      if (storagePath != null && storagePath.isNotEmpty) {
        forwardPayload['storagePath'] = storagePath;
      }
    } else {
      forwardPayload['text'] = data['text']?.toString() ?? '';
    }

    if (!mounted) return;
    setState(() {
      _editingMessageId = null;
      _pendingForward = forwardPayload;
      _messageController.clear();
    });
    _focusComposer();
  }

  void _focusComposer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _composerFocus.requestFocus();
    });
  }

  String? _composePreviewText() {
    if (_editingMessageId != null) {
      return 'Change your message below, then tap send to save.';
    }
    final forward = _pendingForward;
    if (forward == null) return null;

    final from = forward['originalSender']?.toString() ?? 'User';
    if (forward['type']?.toString() == 'file') {
      final name = forward['fileName']?.toString() ?? 'file';
      return 'Forwarding file from $from: $name. Add a comment (optional).';
    }
    final snippet = forward['text']?.toString() ?? '';
    if (snippet.isEmpty) return 'Forwarding from $from. Add a comment (optional).';
    final preview =
        snippet.length > 80 ? '${snippet.substring(0, 80)}…' : snippet;
    return 'Forwarding from $from: "$preview" — add a comment (optional).';
  }

  Widget _buildComposeBanner() {
    final isEditing = _editingMessageId != null;
    final preview = _composePreviewText();
    if (preview == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final fm = context.fundMate;

    return Material(
      color: fm.unreadTint,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.accent.withValues(alpha: 0.35)),
            bottom: BorderSide(color: fm.cardBorder),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isEditing ? Icons.edit_rounded : Icons.forward_rounded,
              size: 20,
              color: scheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEditing ? 'Edit message' : 'Forward message',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: 'Cancel',
              onPressed: () {
                setState(() {
                  _editingMessageId = null;
                  _pendingForward = null;
                  _messageController.clear();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String messageId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ChatService.deleteMessage(
        chatId: widget.chatId,
        messageId: messageId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Delete failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<String> _resolveFileUrl(Map<String, dynamic> data) async {
    final storagePath = data['storagePath']?.toString();
    if (storagePath != null && storagePath.isNotEmpty) {
      try {
        return await FirebaseStorage.instance.ref(storagePath).getDownloadURL();
      } catch (_) {}
    }
    return data['fileUrl']?.toString() ?? '';
  }

  Future<void> _openFileUrl(Map<String, dynamic> data) async {
    final url = await _resolveFileUrl(data);
    if (url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File is no longer available')),
        );
      }
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open file')),
        );
      }
    }
  }

  Widget _buildSeenIcon(bool seen) {
    return Icon(
      seen ? Icons.done_all : Icons.done,
      size: 14,
      color: seen ? const Color(0xFF26D0CE) : Colors.white70,
    );
  }

  Widget _buildMessageBubble({
    required Map<String, dynamic> data,
    required String messageId,
    required bool isMe,
    required Map<String, dynamic>? chatData,
  }) {
    final deleted = data['deleted'] == true;
    final type = data['type']?.toString() ?? 'text';
    final time = _formatTime(data['createdAt'] as Timestamp?);
    final edited = data['editedAt'] != null;
    final forwarded = data['forwardedFrom'] as Map<String, dynamic>?;
    final seen =
        chatData != null && ChatService.isMessageSeen(data, chatData, userId);
    final fm = context.fundMate;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    final outgoingText = fm.chatOutgoingText;
    final outgoingMuted = outgoingText.withValues(alpha: 0.75);

    void openOptions() => _showMessageOptions(
          messageId: messageId,
          data: data,
          isMe: isMe,
        );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: openOptions,
          onLongPress: openOptions,
          onSecondaryTap: openOptions,
          borderRadius: BorderRadius.circular(16),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: isMe ? fm.chatOutgoing : fm.card,
                border: isMe
                    ? null
                    : Border.all(color: fm.cardBorder.withValues(alpha: 0.8)),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: fm.shadow,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        data['senderName']?.toString() ?? 'User',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: onSurfaceVariant,
                      ),
                      ),
                    ),
                  if (forwarded != null) ...[
                    Text(
                      'Forwarded from ${forwarded['originalSender'] ?? 'User'}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        color: isMe ? outgoingMuted : onSurfaceVariant,
                      ),
                    ),
                    if (forwarded['type']?.toString() == 'file') ...[
                      const SizedBox(height: 2),
                      Text(
                        '📎 ${forwarded['fileName'] ?? 'File'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isMe ? outgoingMuted : onSurfaceVariant,
                        ),
                      ),
                    ] else if ((forwarded['text']?.toString() ?? '')
                        .isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        forwarded['text']?.toString() ?? '',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isMe ? outgoingMuted : onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Divider(
                      height: 1,
                      color: (isMe ? outgoingMuted : onSurfaceVariant)
                          .withValues(alpha: 0.35),
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (type == 'file' && !deleted)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.attach_file,
                          color: isMe ? outgoingText : Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            data['fileName']?.toString() ?? 'File',
                            style: TextStyle(
                              color: isMe ? outgoingText : onSurface,
                              fontSize: 15,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      data['text']?.toString() ?? '',
                      style: TextStyle(
                        color: isMe ? outgoingText : onSurface,
                        fontSize: 15,
                        fontStyle:
                            deleted ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        edited ? '$time · edited' : time,
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe ? outgoingMuted : onSurfaceVariant,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        _buildSeenIcon(seen),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: FundMateAppBar(
        title: widget.title,
        subtitle: widget.subtitle,
        showBackButton: true,
        actions: const [ThemeToggleButton()],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: ChatService.chatRef(widget.chatId).snapshots(),
              builder: (context, chatSnapshot) {
                final chatData = chatSnapshot.data?.data();

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: ChatService.messagesStream(widget.chatId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Could not load messages.\n${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      );
                    }

                    final messages = _sortMessages(snapshot.data?.docs ?? []);
                    if (messages.length != _messageCount) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        _onMessagesUpdated(messages);
                      });
                    }
                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 64,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                            const SizedBox(height: 12),
                            Text(
                              'No messages yet',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Say hello to start the conversation',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final doc = messages[index];
                        final data = doc.data();
                        final isMe = data['senderId'] == userId;
                        return _buildMessageBubble(
                          data: data,
                          messageId: doc.id,
                          isMe: isMe,
                          chatData: chatData,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          if (_editingMessageId != null || _pendingForward != null)
            _buildComposeBanner(),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              color: context.fundMate.card,
              border: Border(top: BorderSide(color: context.fundMate.cardBorder)),
              boxShadow: [
                BoxShadow(
                  color: context.fundMate.shadow,
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  IconButton(
                    onPressed: _isUploading ? null : _pickAndSendFile,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.attach_file,
                            color: Theme.of(context).colorScheme.primary),
                    tooltip: 'Share file',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _composerFocus,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: _editingMessageId != null
                            ? 'Edit your message...'
                            : _pendingForward != null
                                ? 'Add a comment (optional)...'
                                : 'Type a message...',
                        filled: true,
                        fillColor: context.fundMate.inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: AppColors.accent,
                    child: IconButton(
                      onPressed:
                          (_isSending || _isUploading) ? null : _sendMessage,
                      icon: _isSending
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.onSecondary,
                              ),
                            )
                          : Icon(
                              _editingMessageId != null
                                  ? Icons.check
                                  : Icons.send,
                              color: Theme.of(context).colorScheme.onSecondary,
                              size: 20,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
