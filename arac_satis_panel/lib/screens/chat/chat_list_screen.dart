import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../models/chat_models.dart';
import '../../providers/chat_provider.dart';

/// Mesaj Listesi Ekranı
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationsProvider);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Mesajlar'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          if (state.unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${state.unreadCount} yeni',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(conversationsProvider.notifier).refresh();
        },
        child: _buildBody(state),
      ),
    );
  }

  Widget _buildBody(ConversationsState state) {
    if (state.isLoading && state.conversations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Mesajlar yüklenemedi',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                ref.read(conversationsProvider.notifier).refresh();
              },
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    if (state.conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Henüz mesajınız yok',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'İlanlarla ilgili sorularınız olduğunda\nmesajlarınız burada görünecek',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.conversations.length,
      itemBuilder: (context, index) {
        final conversation = state.conversations[index];
        return _ConversationTile(
          conversation: conversation,
          currentUserId: _currentUserId ?? '',
          onTap: () {
            context.push('/chat/${conversation.id}');
          },
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final CarConversation conversation;
  final String currentUserId;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unreadCount = conversation.getUnreadCount(currentUserId);
    final otherUserProfile = conversation.getOtherUserProfile(currentUserId);
    final isSeller = conversation.isSeller(currentUserId);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar veya araç resmi
              _buildAvatar(otherUserProfile),
              const SizedBox(width: 12),

              // İçerik
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Üst satır: İsim ve tarih
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            otherUserProfile?.displayName ??
                                (isSeller ? 'Müşteri' : 'Satıcı'),
                            style: TextStyle(
                              fontWeight: unreadCount > 0
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (conversation.lastMessageAt != null)
                          Text(
                            _formatDate(conversation.lastMessageAt!),
                            style: TextStyle(
                              color: unreadCount > 0
                                  ? Colors.blue
                                  : Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Araç bilgisi
                    if (conversation.listing != null)
                      Text(
                        conversation.listing!.displayTitle,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                    const SizedBox(height: 4),

                    // Son mesaj
                    Row(
                      children: [
                        // Okundu işareti (gönderilen mesajlar için)
                        if (conversation.lastMessageSenderId == currentUserId)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.done_all,
                              size: 16,
                              color: Colors.blue[400],
                            ),
                          ),
                        Expanded(
                          child: Text(
                            conversation.lastMessage ?? 'Yeni konuşma',
                            style: TextStyle(
                              color: unreadCount > 0
                                  ? Colors.black87
                                  : Colors.grey[600],
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Okunmamış sayısı
                        if (unreadCount > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(UserProfile? profile) {
    // Önce araç resmi varsa onu göster
    if (conversation.listing?.firstImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          conversation.listing!.firstImage!,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildDefaultAvatar(profile),
        ),
      );
    }

    return _buildDefaultAvatar(profile);
  }

  Widget _buildDefaultAvatar(UserProfile? profile) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          profile?.initials ?? '?',
          style: TextStyle(
            color: Colors.blue[700],
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return 'Şimdi';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} dk';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} sa';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} gün';
    } else {
      return DateFormat('dd.MM').format(date);
    }
  }
}
