import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import '../theme/app_colors.dart';
import 'unread_badge.dart';

/// Lists all conversations (mentorship + investor) for the current user.
class ChatsTab extends StatelessWidget {
  const ChatsTab({
    super.key,
    required this.userId,
    required this.isLoading,
    required this.onRefresh,
    required this.onOpenChat,
    this.emptyTitle = 'No chats yet',
    this.emptySubtitle =
        'Your mentorship and investor conversations will appear here.',
    this.emptyActionLabel,
    this.onEmptyAction,
  });

  final String userId;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String chatId, Map<String, dynamic> chatData)
      onOpenChat;
  final String emptyTitle;
  final String emptySubtitle;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortChats(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final sorted =
        List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);
    sorted.sort((a, b) {
      final aTime = a.data()['lastMessageAt'] as Timestamp?;
      final bTime = b.data()['lastMessageAt'] as Timestamp?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

  IconData _chatIcon(Map<String, dynamic> chat) {
    if (chat['chatType'] == 'investment') {
      return Icons.account_balance_wallet;
    }
    return Icons.school;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ChatService.chatsForUser(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildMessage(
            context,
            icon: Icons.error_outline,
            title: 'Could not load chats',
            subtitle: snapshot.error.toString(),
          );
        }

        final chats = _sortChats(snapshot.data?.docs ?? []);

        if (chats.isEmpty) {
          return RefreshIndicator(
            color: AppColors.accent,
            onRefresh: onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                _buildMessage(
                  context,
                  icon: Icons.chat_bubble_outline,
                  title: emptyTitle,
                  subtitle: emptySubtitle,
                  actionLabel: emptyActionLabel,
                  onAction: onEmptyAction,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.accent,
          onRefresh: onRefresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final doc = chats[index];
              final chat = doc.data();
              final otherName = ChatService.displayTitle(chat, userId);
              final subtitle = ChatService.displaySubtitle(chat);
              final lastMessage = chat['lastMessage']?.toString().trim() ?? '';
              final preview = lastMessage.isEmpty
                  ? 'Tap to start the conversation'
                  : lastMessage;
              final unread = ChatService.unreadCountForUser(chat, userId);
              final hasUnread = unread > 0;
              final isInvestment = chat['chatType'] == 'investment';
              final fm = context.fundMate;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: hasUnread ? fm.unreadTint : fm.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: hasUnread
                        ? AppColors.accent.withValues(alpha: 0.45)
                        : fm.cardBorder,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: fm.shadow,
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        backgroundColor: fm.avatarBg,
                        child: Icon(_chatIcon(chat), color: scheme.primary),
                      ),
                      if (hasUnread)
                        const Positioned(
                          right: -4,
                          top: -4,
                          child: UnreadBadge(count: 1, size: 18),
                        ),
                    ],
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          otherName,
                          style: TextStyle(
                            fontWeight:
                                hasUnread ? FontWeight.w800 : FontWeight.bold,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      if (isInvestment)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: fm.badgeBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Investor',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: fm.badgeText,
                            ),
                          ),
                        ),
                      if (unread > 0) UnreadBadge(count: unread),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasUnread && lastMessage.isNotEmpty
                            ? 'New message: $preview'
                            : preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: hasUnread
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                          fontSize: 13,
                          fontWeight:
                              hasUnread ? FontWeight.w600 : FontWeight.normal,
                          fontStyle: lastMessage.isEmpty
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: fm.badgeBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.chat_rounded, color: scheme.primary),
                  ),
                  onTap: isLoading ? null : () => onOpenChat(doc.id, chat),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMessage(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(icon, size: 72, color: scheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }
}
