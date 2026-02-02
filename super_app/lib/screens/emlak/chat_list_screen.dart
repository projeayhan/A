import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/chat_provider.dart';
import '../../services/emlak/chat_service.dart';
import '../../models/emlak/emlak_models.dart';
import '../../core/services/supabase_service.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final conversationsState = ref.watch(conversationsProvider);
    final currentUserId = SupabaseService.currentUser?.id;

    return Scaffold(
      backgroundColor: EmlakColors.background(isDark),
      appBar: AppBar(
        backgroundColor: EmlakColors.background(isDark),
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: EmlakColors.textPrimary(isDark),
          ),
        ),
        title: Text(
          'Mesajlar',
          style: TextStyle(
            color: EmlakColors.textPrimary(isDark),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: conversationsState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : conversationsState.error != null
              ? _buildErrorState(conversationsState.error!, isDark)
              : conversationsState.conversations.isEmpty
                  ? _buildEmptyState(isDark)
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.read(conversationsProvider.notifier).refresh(),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: conversationsState.conversations.length,
                        separatorBuilder: (_, __) => Divider(
                          color: EmlakColors.divider(isDark),
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final conversation =
                              conversationsState.conversations[index];
                          return _ConversationTile(
                            conversation: conversation,
                            currentUserId: currentUserId ?? '',
                            isDark: isDark,
                            onTap: () {
                              context.push('/emlak/chat/${conversation.id}');
                            },
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: EmlakColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 64,
              color: EmlakColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Henüz mesajınız yok',
            style: TextStyle(
              color: EmlakColors.textPrimary(isDark),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'İlan sahipleriyle iletişime geçtiğinizde\nmesajlarınız burada görünecek',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: EmlakColors.textSecondary(isDark),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => context.go('/emlak'),
            icon: const Icon(Icons.search_rounded),
            label: const Text('İlan Ara'),
            style: ElevatedButton.styleFrom(
              backgroundColor: EmlakColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: EmlakColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Bir hata oluştu',
            style: TextStyle(
              color: EmlakColors.textPrimary(isDark),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: EmlakColors.textSecondary(isDark),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () =>
                ref.read(conversationsProvider.notifier).refresh(),
            child: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final String currentUserId;
  final bool isDark;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unreadCount = conversation.getUnreadCount(currentUserId);
    final otherUserProfile = conversation.getOtherUserProfile(currentUserId);
    final otherUserName = otherUserProfile?['full_name'] as String? ?? 'Kullanıcı';
    final otherUserAvatar = otherUserProfile?['avatar_url'] as String?;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: EmlakColors.primary.withValues(alpha: 0.1),
                  backgroundImage:
                      otherUserAvatar != null ? NetworkImage(otherUserAvatar) : null,
                  child: otherUserAvatar == null
                      ? Text(
                          otherUserName.isNotEmpty
                              ? otherUserName[0].toUpperCase()
                              : 'K',
                          style: TextStyle(
                            color: EmlakColors.primary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: EmlakColors.error,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: EmlakColors.background(isDark),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        unreadCount > 9 ? '9+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and time
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          otherUserName,
                          style: TextStyle(
                            color: EmlakColors.textPrimary(isDark),
                            fontSize: 16,
                            fontWeight: unreadCount > 0
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conversation.lastMessageAt != null)
                        Text(
                          _formatTime(conversation.lastMessageAt!),
                          style: TextStyle(
                            color: unreadCount > 0
                                ? EmlakColors.primary
                                : EmlakColors.textTertiary(isDark),
                            fontSize: 12,
                            fontWeight: unreadCount > 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Property title
                  if (conversation.propertyTitle != null)
                    Row(
                      children: [
                        Icon(
                          Icons.home_outlined,
                          size: 14,
                          color: EmlakColors.textTertiary(isDark),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            conversation.propertyTitle!,
                            style: TextStyle(
                              color: EmlakColors.textTertiary(isDark),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 4),

                  // Last message
                  Row(
                    children: [
                      if (conversation.lastMessageSenderId == currentUserId)
                        Icon(
                          Icons.done_all_rounded,
                          size: 16,
                          color: EmlakColors.primary,
                        ),
                      if (conversation.lastMessageSenderId == currentUserId)
                        const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          conversation.lastMessage ?? 'Henüz mesaj yok',
                          style: TextStyle(
                            color: unreadCount > 0
                                ? EmlakColors.textPrimary(isDark)
                                : EmlakColors.textSecondary(isDark),
                            fontSize: 14,
                            fontWeight: unreadCount > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Arrow
            Icon(
              Icons.chevron_right_rounded,
              color: EmlakColors.textTertiary(isDark),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Şimdi';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} dk';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} sa';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün';
    } else {
      return '${dateTime.day}.${dateTime.month}.${dateTime.year}';
    }
  }
}
