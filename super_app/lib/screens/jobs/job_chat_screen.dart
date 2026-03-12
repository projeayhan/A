import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/jobs/job_models.dart';
import '../../services/job_chat_service.dart';
import '../../core/providers/job_chat_provider.dart';

/// İş ilanı mesajlaşma ekranı
class JobChatScreen extends ConsumerStatefulWidget {
  final JobListing jobListing;
  final String otherUserId;
  final String otherUserName;

  const JobChatScreen({
    super.key,
    required this.jobListing,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  ConsumerState<JobChatScreen> createState() => _JobChatScreenState();
}

class _JobChatScreenState extends ConsumerState<JobChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  String? _conversationId;
  bool _isInitializing = true;

  String get _currentUserId => Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _initConversation();
  }

  Future<void> _initConversation() async {
    try {
      final service = JobChatService();

      // poster_id'yi bul - ilan sahibinin user_id'si lazım
      // job.poster.id poster tablosundaki ID, user_id değil
      // poster_id otomatik olarak ilanın user_id'sinden alınır
      final conversation = await service.getOrCreateConversation(
        jobListingId: widget.jobListing.id,
      );

      if (mounted) {
        setState(() {
          _conversationId = conversation.id;
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isInitializing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Konuşma başlatılamadı: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _sendMessage() {
    if (_conversationId == null) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    ref.read(jobMessagesProvider(_conversationId!).notifier).sendMessage(text);
    _messageController.clear();

    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: JobsColors.background(isDark),
      appBar: _buildAppBar(isDark),
      body: Column(
        children: [
          // Job info banner
          _buildJobBanner(isDark),
          // Messages
          Expanded(
            child: _isInitializing
                ? const Center(child: CircularProgressIndicator())
                : _conversationId == null
                    ? Center(
                        child: Text(
                          'Konuşma başlatılamadı',
                          style: TextStyle(color: JobsColors.textSecondary(isDark)),
                        ),
                      )
                    : _buildMessageList(isDark),
          ),
          // Input
          if (_conversationId != null) _buildMessageInput(isDark),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: JobsColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.otherUserName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            widget.jobListing.title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildJobBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: JobsColors.primary.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(color: JobsColors.border(isDark)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.work_outline, size: 18, color: JobsColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${widget.jobListing.title} - ${widget.jobListing.companyName}',
              style: TextStyle(
                color: JobsColors.textSecondary(isDark),
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(bool isDark) {
    final messagesState = ref.watch(jobMessagesProvider(_conversationId!));

    if (messagesState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (messagesState.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: JobsColors.textTertiary(isDark),
              ),
              const SizedBox(height: 16),
              Text(
                'Henüz mesaj yok',
                style: TextStyle(
                  color: JobsColors.textSecondary(isDark),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'İlan sahibine mesaj göndererek iletişime geçin',
                style: TextStyle(
                  color: JobsColors.textTertiary(isDark),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Auto scroll to bottom when new messages arrive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messagesState.messages.length,
      itemBuilder: (context, index) {
        final message = messagesState.messages[index];
        final isMine = message.isMine(_currentUserId);

        // Show date separator
        final showDate = index == 0 ||
            !_isSameDay(
              messagesState.messages[index - 1].createdAt,
              message.createdAt,
            );

        return Column(
          children: [
            if (showDate) _buildDateSeparator(isDark, message.createdAt),
            _buildMessageBubble(isDark, message, isMine),
          ],
        );
      },
    );
  }

  Widget _buildDateSeparator(bool isDark, DateTime date) {
    final now = DateTime.now();
    String text;
    if (_isSameDay(date, now)) {
      text = 'Bugün';
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      text = 'Dün';
    } else {
      text = '${date.day}.${date.month}.${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: JobsColors.surface(isDark),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: JobsColors.textTertiary(isDark),
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(bool isDark, JobChatMessage message, bool isMine) {
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: isMine ? Colors.white : JobsColors.textPrimary(isDark),
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: isMine
                        ? Colors.white.withValues(alpha: 0.7)
                        : JobsColors.textTertiary(isDark),
                    fontSize: 11,
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: message.isRead
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: 10 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: JobsColors.card(isDark),
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
              controller: _messageController,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Mesaj yazın...',
                hintStyle: TextStyle(color: JobsColors.textTertiary(isDark)),
                filled: true,
                fillColor: JobsColors.surface(isDark),
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
            onTap: _sendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: JobsColors.primaryGradient),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
