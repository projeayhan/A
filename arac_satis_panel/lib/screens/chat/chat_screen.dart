import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../models/chat_models.dart';
import '../../providers/chat_provider.dart';

/// Chat Ekranı - Bireysel Konuşma
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

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

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
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    _messageController.clear();

    final success = await ref
        .read(messagesProvider(widget.conversationId).notifier)
        .sendMessage(content);

    if (success) {
      _scrollToBottom();
      // Konuşmalar listesini güncelle
      ref.read(conversationsProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(messagesProvider(widget.conversationId));

    // Mesajlar yüklendiğinde scroll'u en alta al
    ref.listen(messagesProvider(widget.conversationId), (prev, next) {
      if (prev?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: _buildAppBar(state.conversation),
      body: Column(
        children: [
          // Araç bilgi kartı
          if (state.conversation?.listing != null)
            _buildListingCard(state.conversation!.listing!),

          // Mesajlar
          Expanded(
            child: _buildMessageList(state),
          ),

          // Mesaj gönderme alanı
          _buildMessageInput(state),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(CarConversation? conversation) {
    final otherUser = conversation?.getOtherUserProfile(_currentUserId ?? '');
    final isSeller = conversation?.isSeller(_currentUserId ?? '') ?? false;

    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
      ),
      title: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.blue[50],
            backgroundImage: otherUser?.avatarUrl != null
                ? NetworkImage(otherUser!.avatarUrl!)
                : null,
            child: otherUser?.avatarUrl == null
                ? Text(
                    otherUser?.initials ?? '?',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          // İsim
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  otherUser?.displayName ?? (isSeller ? 'Müşteri' : 'Satıcı'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  isSeller ? 'Alıcı' : 'Satıcı',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Telefon butonu
        if (otherUser?.phone != null)
          IconButton(
            icon: const Icon(Icons.phone),
            onPressed: () {
              // TODO: Telefon araması
            },
          ),
        // Menü
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'listing') {
              // İlana git
              if (conversation?.listingId != null) {
                context.push('/listing/${conversation!.listingId}');
              }
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'listing',
              child: Row(
                children: [
                  Icon(Icons.directions_car, size: 20),
                  SizedBox(width: 8),
                  Text('İlanı Görüntüle'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildListingCard(CarListingInfo listing) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => context.push('/listing/${listing.id}'),
        child: Row(
          children: [
            // Araç resmi
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: listing.firstImage != null
                  ? Image.network(
                      listing.firstImage!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                    )
                  : _buildPlaceholderImage(),
            ),
            const SizedBox(width: 12),
            // Bilgiler
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.displayTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (listing.price != null)
                    Text(
                      NumberFormat.currency(
                        locale: 'tr_TR',
                        symbol: '₺',
                        decimalDigits: 0,
                      ).format(listing.price),
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 60,
      height: 60,
      color: Colors.grey[200],
      child: Icon(Icons.directions_car, color: Colors.grey[400]),
    );
  }

  Widget _buildMessageList(MessagesState state) {
    if (state.isLoading && state.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Mesajlar yüklenemedi',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (state.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Henüz mesaj yok',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'İlk mesajı gönderin!',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: state.messages.length,
      itemBuilder: (context, index) {
        final message = state.messages[index];
        final isMe = message.senderId == _currentUserId;

        // Tarih ayracı
        Widget? dateSeparator;
        if (index == 0 ||
            !_isSameDay(
              state.messages[index - 1].createdAt,
              message.createdAt,
            )) {
          dateSeparator = _buildDateSeparator(message.createdAt);
        }

        return Column(
          children: [
            if (dateSeparator != null) dateSeparator,
            _MessageBubble(
              message: message,
              isMe: isMe,
            ),
          ],
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    String text;

    if (_isSameDay(date, now)) {
      text = 'Bugün';
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      text = 'Dün';
    } else {
      text = DateFormat('d MMMM yyyy', 'tr_TR').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput(MessagesState state) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
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
          // Mesaj alanı
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _focusNode,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Mesajınızı yazın...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          // Gönder butonu
          Material(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: state.isSending ? null : _sendMessage,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                child: state.isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const _MessageBubble({
    required this.message,
    required this.isMe,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
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
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('HH:mm').format(message.createdAt),
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.grey[500],
                    fontSize: 11,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: message.isRead ? Colors.white : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
