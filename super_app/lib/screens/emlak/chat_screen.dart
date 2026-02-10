import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/providers/chat_provider.dart';
import '../../services/emlak/chat_service.dart';
import '../../models/emlak/emlak_models.dart';
import '../../core/services/supabase_service.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const ChatScreen({
    super.key,
    required this.conversationId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    _messageController.clear();
    await ref.read(messagesProvider(widget.conversationId).notifier).sendMessage(content);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messagesState = ref.watch(messagesProvider(widget.conversationId));
    final conversationAsync = ref.watch(conversationDetailProvider(widget.conversationId));
    final currentUserId = SupabaseService.currentUser?.id ?? '';

    // Mesajlar yüklendiğinde en alta scroll
    ref.listen(messagesProvider(widget.conversationId), (previous, next) {
      if (previous?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: EmlakColors.background(isDark),
      appBar: _buildAppBar(context, conversationAsync, currentUserId, isDark),
      body: Column(
        children: [
          // Property card
          conversationAsync.whenOrNull(
            data: (conversation) => conversation?.property != null
                ? _PropertyInfoCard(
                    property: conversation!.property!,
                    isDark: isDark,
                    onTap: () {
                      if (conversation.propertyId != null) {
                        context.push('/emlak/property/${conversation.propertyId}');
                      }
                    },
                  )
                : null,
          ) ?? const SizedBox.shrink(),

          // Messages
          Expanded(
            child: messagesState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : messagesState.messages.isEmpty
                    ? _buildEmptyMessages(isDark)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messagesState.messages.length,
                        itemBuilder: (context, index) {
                          final message = messagesState.messages[index];
                          final isMe = message.senderId == currentUserId;
                          final showDate = index == 0 ||
                              !_isSameDay(
                                messagesState.messages[index - 1].createdAt,
                                message.createdAt,
                              );

                          return Column(
                            children: [
                              if (showDate)
                                _DateSeparator(
                                  date: message.createdAt,
                                  isDark: isDark,
                                ),
                              _MessageBubble(
                                message: message,
                                isMe: isMe,
                                isDark: isDark,
                              ),
                            ],
                          );
                        },
                      ),
          ),

          // Input
          _MessageInput(
            controller: _messageController,
            focusNode: _focusNode,
            isSending: messagesState.isSending,
            isDark: isDark,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    AsyncValue<Conversation?> conversationAsync,
    String currentUserId,
    bool isDark,
  ) {
    return AppBar(
      backgroundColor: EmlakColors.background(isDark),
      elevation: 0,
      leading: IconButton(
        onPressed: () => context.pop(),
        icon: Icon(
          Icons.arrow_back_ios_rounded,
          color: EmlakColors.textPrimary(isDark),
        ),
      ),
      title: conversationAsync.when(
        data: (conversation) {
          if (conversation == null) {
            return Text(
              'Mesaj',
              style: TextStyle(
                color: EmlakColors.textPrimary(isDark),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            );
          }

          final otherProfile = conversation.getOtherUserProfile(currentUserId);
          final name = otherProfile?['full_name'] as String? ?? 'Kullanıcı';
          final avatar = otherProfile?['avatar_url'] as String?;

          return Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: EmlakColors.primary.withValues(alpha: 0.1),
                backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                child: avatar == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'K',
                        style: TextStyle(
                          color: EmlakColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: EmlakColors.textPrimary(isDark),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'İlan Sahibi',
                      style: TextStyle(
                        color: EmlakColors.textSecondary(isDark),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, __) => Text(
          'Mesaj',
          style: TextStyle(
            color: EmlakColors.textPrimary(isDark),
          ),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () {
            // TODO: Telefon arama
          },
          icon: Icon(
            Icons.phone_outlined,
            color: EmlakColors.primary,
          ),
        ),
        IconButton(
          onPressed: () {
            // TODO: Daha fazla seçenek
          },
          icon: Icon(
            Icons.more_vert_rounded,
            color: EmlakColors.textPrimary(isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyMessages(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 64,
            color: EmlakColors.textTertiary(isDark),
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz mesaj yok',
            style: TextStyle(
              color: EmlakColors.textSecondary(isDark),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sohbeti başlatmak için bir mesaj gönderin',
            style: TextStyle(
              color: EmlakColors.textTertiary(isDark),
              fontSize: 14,
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

// ============================================
// Property Info Card
// ============================================

class _PropertyInfoCard extends StatelessWidget {
  final Map<String, dynamic> property;
  final bool isDark;
  final VoidCallback onTap;

  const _PropertyInfoCard({
    required this.property,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = property['title'] as String? ?? 'İlan';
    final images = property['images'] as List<dynamic>?;
    final imageUrl = images?.isNotEmpty == true ? images!.first as String : null;
    final price = property['price'] as num?;
    final city = property['city'] as String?;
    final district = property['district'] as String?;

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: EmlakColors.surface(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: EmlakColors.border(isDark),
          ),
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 60,
                        height: 60,
                        color: EmlakColors.primary.withValues(alpha: 0.1),
                        child: Icon(
                          Icons.home_outlined,
                          color: EmlakColors.primary,
                        ),
                      ),
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      color: EmlakColors.primary.withValues(alpha: 0.1),
                      child: Icon(
                        Icons.home_outlined,
                        color: EmlakColors.primary,
                      ),
                    ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: EmlakColors.textPrimary(isDark),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (city != null || district != null)
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: EmlakColors.textTertiary(isDark),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          [district, city].where((e) => e != null).join(', '),
                          style: TextStyle(
                            color: EmlakColors.textSecondary(isDark),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  if (price != null)
                    Text(
                      _formatPrice(price.toDouble()),
                      style: TextStyle(
                        color: EmlakColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),

            Icon(
              Icons.chevron_right_rounded,
              color: EmlakColors.textTertiary(isDark),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M TL';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K TL';
    }
    return '${price.toStringAsFixed(0)} TL';
  }
}

// ============================================
// Date Separator
// ============================================

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  final bool isDark;

  const _DateSeparator({
    required this.date,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: EmlakColors.divider(isDark),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _formatDate(date),
              style: TextStyle(
                color: EmlakColors.textTertiary(isDark),
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: EmlakColors.divider(isDark),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Bugün';
    } else if (dateOnly == yesterday) {
      return 'Dün';
    } else {
      final months = [
        'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
        'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }
  }
}

// ============================================
// Message Bubble
// ============================================

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool isDark;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 4,
          bottom: 4,
          left: isMe ? 48 : 0,
          right: isMe ? 0 : 48,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? EmlakColors.primary
              : isDark
                  ? EmlakColors.cardDark
                  : EmlakColors.surfaceLight,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
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
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: isMe ? Colors.white : EmlakColors.textPrimary(isDark),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.7)
                        : EmlakColors.textTertiary(isDark),
                    fontSize: 11,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead
                        ? Icons.done_all_rounded
                        : Icons.done_rounded,
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

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

// ============================================
// Message Input
// ============================================

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final bool isDark;
  final VoidCallback onSend;

  const _MessageInput({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.isDark,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: EmlakColors.background(isDark),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Attachment button
          IconButton(
            onPressed: () {
              // TODO: Dosya ekleme
            },
            icon: Icon(
              Icons.attach_file_rounded,
              color: EmlakColors.textSecondary(isDark),
            ),
          ),

          // Input field
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: EmlakColors.inputBackground(isDark),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  hintText: 'Mesaj yazın...',
                  hintStyle: TextStyle(
                    color: EmlakColors.textTertiary(isDark),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                style: TextStyle(
                  color: EmlakColors.textPrimary(isDark),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                minLines: 1,
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send button
          Container(
            decoration: BoxDecoration(
              color: EmlakColors.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: isSending ? null : onSend,
              icon: isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
