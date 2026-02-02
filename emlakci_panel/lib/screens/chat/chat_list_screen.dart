import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/realtor_provider.dart';
import '../../services/chat_service.dart';
import 'chat_screen.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(chatProvider.notifier).loadConversations());
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Mesajlar',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (chatState.totalUnreadCount > 0)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${chatState.totalUnreadCount} yeni',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          IconButton(
            onPressed: () => ref.read(chatProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
          ),
        ],
      ),
      body: chatState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : chatState.error != null
              ? _buildErrorState(chatState.error!)
              : chatState.conversations.isEmpty
                  ? _buildEmptyState()
                  : _buildConversationsList(chatState.conversations),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Color(0xFFEF4444),
            ),
            const SizedBox(height: 16),
            const Text(
              'Bir hata oluştu',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.read(chatProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Henüz mesajınız yok',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Müşterilerinizden gelen mesajlar\nburada görünecek',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationsList(List<Conversation> conversations) {
    return RefreshIndicator(
      onRefresh: () => ref.read(chatProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: conversations.length,
        itemBuilder: (context, index) {
          final conversation = conversations[index];
          return _buildConversationCard(conversation);
        },
      ),
    );
  }

  Widget _buildConversationCard(Conversation conversation) {
    final unreadCount = conversation.getUnreadCount(_currentUserId ?? '');
    final hasUnread = unreadCount > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: hasUnread ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasUnread ? const Color(0xFF3B82F6).withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openChat(conversation),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildPropertyImage(conversation),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (conversation.propertyTitle != null)
                        Text(
                          conversation.propertyTitle!,
                          style: TextStyle(
                            fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                            fontSize: 14,
                            color: const Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 4),
                      Text(
                        conversation.lastMessage ?? 'Henüz mesaj yok',
                        style: TextStyle(
                          color: hasUnread ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                          fontSize: 13,
                          fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTime(conversation.lastMessageAt),
                      style: TextStyle(
                        color: hasUnread ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (hasUnread)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      const Icon(
                        Icons.chevron_right,
                        color: Color(0xFF94A3B8),
                        size: 20,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPropertyImage(Conversation conversation) {
    final imageUrl = conversation.propertyImage;

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFFE2E8F0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: imageUrl != null
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.home,
                  color: Color(0xFF94A3B8),
                ),
              )
            : const Icon(
                Icons.home,
                color: Color(0xFF94A3B8),
              ),
      ),
    );
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';

    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays == 0) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (diff.inDays == 1) {
      return 'Dün';
    } else if (diff.inDays < 7) {
      return DateFormat('EEEE', 'tr').format(dateTime);
    } else {
      return DateFormat('dd.MM.yyyy').format(dateTime);
    }
  }

  void _openChat(Conversation conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(conversationId: conversation.id),
      ),
    ).then((_) {
      ref.read(chatProvider.notifier).refresh();
    });
  }
}
