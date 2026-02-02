import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/realtor_provider.dart';
import '../../services/chat_service.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const ChatScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<ChatMessage> _messages = [];
  Conversation? _conversation;
  bool _isLoading = true;
  bool _isSending = false;
  RealtimeChannel? _channel;

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _unsubscribe();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final chatService = ref.read(chatServiceProvider);
      final conversation = await chatService.getConversation(widget.conversationId);
      final messages = await chatService.getMessages(widget.conversationId);

      // Mesajları okundu olarak işaretle
      await chatService.markMessagesAsRead(widget.conversationId);

      setState(() {
        _conversation = conversation;
        _messages = messages.reversed.toList(); // En eski en üstte
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _subscribeToMessages() {
    final chatService = ref.read(chatServiceProvider);
    _channel = chatService.subscribeToNewMessages(
      widget.conversationId,
      (message) {
        if (mounted) {
          setState(() {
            _messages.add(message);
          });
          _scrollToBottom();
          // Yeni mesaj geldiğinde okundu işaretle
          if (message.senderId != _currentUserId) {
            chatService.markMessagesAsRead(widget.conversationId);
          }
        }
      },
    );
  }

  Future<void> _unsubscribe() async {
    if (_channel != null) {
      final chatService = ref.read(chatServiceProvider);
      await chatService.unsubscribe(_channel!);
    }
  }

  void _scrollToBottom() {
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

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.sendMessage(
        conversationId: widget.conversationId,
        content: text,
      );
      // Mesaj realtime ile gelecek, burada eklememize gerek yok
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mesaj gönderilemedi: $e'), backgroundColor: Colors.red),
        );
        // Hata durumunda mesajı geri koy
        _messageController.text = text;
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Property Info Card
                if (_conversation?.property != null) _buildPropertyCard(),
                // Messages
                Expanded(child: _buildMessagesList()),
                // Input
                _buildMessageInput(),
              ],
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _conversation?.propertyTitle ?? 'Sohbet',
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'Müşteri ile görüşme',
            style: TextStyle(
              color: const Color(0xFF64748B),
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
          onPressed: _loadData,
        ),
      ],
    );
  }

  Widget _buildPropertyCard() {
    final property = _conversation!.property!;
    final imageUrl = _conversation!.propertyImage;
    final title = property['title'] as String? ?? '';
    final price = property['price'];
    final city = property['city'] as String? ?? '';
    final district = property['district'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 60,
              height: 60,
              color: const Color(0xFFE2E8F0),
              child: imageUrl != null
                  ? Image.network(imageUrl, fit: BoxFit.cover)
                  : const Icon(Icons.home, color: Color(0xFF94A3B8)),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '$district, $city',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
                if (price != null)
                  Text(
                    '${NumberFormat('#,###', 'tr').format(price)} ₺',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: const Color(0xFF94A3B8),
            ),
            const SizedBox(height: 16),
            const Text(
              'Henüz mesaj yok',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'İlk mesajı siz gönderin!',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final showDate = index == 0 ||
            !_isSameDay(_messages[index - 1].createdAt, message.createdAt);

        return Column(
          children: [
            if (showDate) _buildDateSeparator(message.createdAt),
            _buildMessageBubble(message),
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
      text = DateFormat('d MMMM yyyy', 'tr').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isMine = message.senderId == _currentUserId;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFF3B82F6) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
          border: isMine ? null : Border.all(color: const Color(0xFFE2E8F0)),
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
                color: isMine ? Colors.white : const Color(0xFF1E293B),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('HH:mm').format(message.createdAt),
                  style: TextStyle(
                    color: isMine
                        ? Colors.white.withValues(alpha: 0.7)
                        : const Color(0xFF94A3B8),
                    fontSize: 10,
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

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        children: [
          // Text Field
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: const InputDecoration(
                  hintText: 'Mesajınızı yazın...',
                  hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send Button
          Material(
            color: const Color(0xFF3B82F6),
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: _isSending ? null : _sendMessage,
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                child: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
