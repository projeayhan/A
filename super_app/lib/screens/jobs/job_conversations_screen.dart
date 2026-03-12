import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/jobs/job_models.dart';
import '../../core/providers/job_chat_provider.dart';
import '../../services/job_chat_service.dart';

/// İş ilanı konuşmaları listesi ekranı
class JobConversationsScreen extends ConsumerWidget {
  const JobConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(jobConversationsProvider);

    return Scaffold(
      backgroundColor: JobsColors.background(isDark),
      appBar: AppBar(
        backgroundColor: JobsColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('İş Mesajları'),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.conversations.isEmpty
              ? _buildEmptyState(isDark)
              : RefreshIndicator(
                  onRefresh: () => ref.read(jobConversationsProvider.notifier).refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: state.conversations.length,
                    itemBuilder: (context, index) {
                      return _buildConversationTile(
                        context,
                        isDark,
                        state.conversations[index],
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 72,
              color: JobsColors.textTertiary(isDark),
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz mesajınız yok',
              style: TextStyle(
                color: JobsColors.textPrimary(isDark),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'İş ilanlarından mesaj göndererek iletişime geçebilirsiniz',
              style: TextStyle(
                color: JobsColors.textSecondary(isDark),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationTile(
    BuildContext context,
    bool isDark,
    JobConversation conversation,
  ) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final unread = conversation.getUnreadCount(currentUserId);
    final isApplicant = conversation.applicantId == currentUserId;
    final otherUserName = isApplicant ? 'İlan Sahibi' : 'Başvuran';

    return InkWell(
      onTap: () {
        // We need the job listing to navigate to chat
        // For now, navigate with minimal info
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => _ChatFromConversation(
              conversation: conversation,
              currentUserId: currentUserId,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: JobsColors.border(isDark), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: JobsColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.work_outline,
                color: JobsColors.primary,
                size: 24,
              ),
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
                          conversation.jobTitle ?? 'İş İlanı',
                          style: TextStyle(
                            color: JobsColors.textPrimary(isDark),
                            fontSize: 15,
                            fontWeight: unread > 0 ? FontWeight.bold : FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conversation.lastMessageAt != null)
                        Text(
                          _formatTime(conversation.lastMessageAt!),
                          style: TextStyle(
                            color: unread > 0
                                ? JobsColors.primary
                                : JobsColors.textTertiary(isDark),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    otherUserName,
                    style: TextStyle(
                      color: JobsColors.textTertiary(isDark),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessage ?? 'Konuşma başlatıldı',
                          style: TextStyle(
                            color: unread > 0
                                ? JobsColors.textPrimary(isDark)
                                : JobsColors.textSecondary(isDark),
                            fontSize: 14,
                            fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unread > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: JobsColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$unread',
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
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays == 0) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Dün';
    } else if (diff.inDays < 7) {
      const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
      return days[time.weekday - 1];
    } else {
      return '${time.day}.${time.month}';
    }
  }
}

/// Konuşmadan chat ekranına geçiş - minimal JobListing wrapper
class _ChatFromConversation extends ConsumerWidget {
  final JobConversation conversation;
  final String currentUserId;

  const _ChatFromConversation({
    required this.conversation,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messagesState = ref.watch(jobMessagesProvider(conversation.id));
    final isApplicant = conversation.applicantId == currentUserId;
    final otherUserName = isApplicant ? 'İlan Sahibi' : 'Başvuran';

    return Scaffold(
      backgroundColor: JobsColors.background(isDark),
      appBar: AppBar(
        backgroundColor: JobsColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              otherUserName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              conversation.jobTitle ?? 'İş İlanı',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : messagesState.messages.isEmpty
                    ? Center(
                        child: Text(
                          'Henüz mesaj yok',
                          style: TextStyle(color: JobsColors.textSecondary(isDark)),
                        ),
                      )
                    : _MessageList(
                        messages: messagesState.messages,
                        currentUserId: currentUserId,
                        isDark: isDark,
                      ),
          ),
          _MessageInputBar(
            conversationId: conversation.id,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  final List<dynamic> messages;
  final String currentUserId;
  final bool isDark;

  const _MessageList({
    required this.messages,
    required this.currentUserId,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      reverse: false,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index] as JobChatMessage;
        final isMine = message.isMine(currentUserId);

        return Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: EdgeInsets.only(
              bottom: 6,
              left: isMine ? 60 : 0,
              right: isMine ? 0 : 60,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMine ? JobsColors.primary : JobsColors.card(isDark),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMine ? 16 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  message.content,
                  style: TextStyle(
                    color: isMine ? Colors.white : JobsColors.textPrimary(isDark),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: isMine
                        ? Colors.white.withValues(alpha: 0.7)
                        : JobsColors.textTertiary(isDark),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MessageInputBar extends ConsumerStatefulWidget {
  final String conversationId;
  final bool isDark;

  const _MessageInputBar({
    required this.conversationId,
    required this.isDark,
  });

  @override
  ConsumerState<_MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends ConsumerState<_MessageInputBar> {
  final _controller = TextEditingController();

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    ref.read(jobMessagesProvider(widget.conversationId).notifier).sendMessage(text);
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: 10 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: JobsColors.card(widget.isDark),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Mesaj yazın...',
                hintStyle: TextStyle(color: JobsColors.textTertiary(widget.isDark)),
                filled: true,
                fillColor: JobsColors.surface(widget.isDark),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: JobsColors.primaryGradient),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}
