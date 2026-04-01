import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/car_models.dart';
import '../../models/chat_models.dart';
import '../../providers/chat_provider.dart';
import '../../shared/widgets/empty_state.dart';

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final conversationsState = ref.watch(conversationsProvider);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    if (conversationsState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (conversationsState.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: CarSalesColors.textTertiary(isDark),
            ),
            const SizedBox(height: 12),
            Text(
              'Mesajlar yuklenirken hata olustu',
              style: TextStyle(color: CarSalesColors.textSecondary(isDark)),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () =>
                  ref.read(conversationsProvider.notifier).refresh(),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    final conversations = conversationsState.conversations;

    if (conversations.isEmpty) {
      return const EmptyState(
        icon: Icons.message_rounded,
        message: 'Henuz mesajiniz yok',
        description: 'Ilanlariniza gelen mesajlar burada gorunecek.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(conversationsProvider.notifier).refresh();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: conversations.length,
        itemBuilder: (context, index) {
          final conversation = conversations[index];
          return _ConversationTile(
            conversation: conversation,
            currentUserId: currentUserId ?? '',
            isDark: isDark,
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final CarConversation conversation;
  final String currentUserId;
  final bool isDark;

  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final otherProfile = conversation.getOtherUserProfile(currentUserId);
    final unreadCount = conversation.getUnreadCount(currentUserId);
    final hasUnread = unreadCount > 0;

    return InkWell(
      onTap: () => context.push('/messages/${conversation.id}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hasUnread
              ? CarSalesColors.primary.withValues(alpha: 0.04)
              : CarSalesColors.card(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasUnread
                ? CarSalesColors.primary.withValues(alpha: 0.2)
                : CarSalesColors.border(isDark),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: CarSalesColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: otherProfile?.avatarUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        otherProfile!.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _buildInitials(otherProfile),
                      ),
                    )
                  : _buildInitials(otherProfile),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          otherProfile?.displayName ?? 'Kullanici',
                          style: TextStyle(
                            fontWeight: hasUnread
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontSize: 15,
                            color: CarSalesColors.textPrimary(isDark),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conversation.lastMessageAt != null)
                        Text(
                          _formatTime(conversation.lastMessageAt!),
                          style: TextStyle(
                            color: hasUnread
                                ? CarSalesColors.primary
                                : CarSalesColors.textTertiary(isDark),
                            fontSize: 12,
                            fontWeight: hasUnread
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Last message + listing info
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessage ?? '',
                          style: TextStyle(
                            color: hasUnread
                                ? CarSalesColors.textPrimary(isDark)
                                : CarSalesColors.textSecondary(isDark),
                            fontSize: 13,
                            fontWeight: hasUnread
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: CarSalesColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Listing reference
                  if (conversation.listing != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (conversation.listing!.firstImage != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              conversation.listing!.firstImage!,
                              width: 28,
                              height: 20,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        if (conversation.listing!.firstImage != null)
                          const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            conversation.listing!.displayTitle,
                            style: TextStyle(
                              color: CarSalesColors.textTertiary(isDark),
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitials(UserProfile? profile) {
    final initials = profile?.initials ?? '?';
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: CarSalesColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${dateTime.day}.${dateTime.month}.${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}g';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}s';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}dk';
    } else {
      return 'Simdi';
    }
  }
}
