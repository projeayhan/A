import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../services/car_sales/car_chat_service.dart';

/// Araç Satış Chat Ekranı
class CarChatScreen extends StatefulWidget {
  final String conversationId;
  final Map<String, dynamic>? listing;

  const CarChatScreen({
    super.key,
    required this.conversationId,
    this.listing,
  });

  @override
  State<CarChatScreen> createState() => _CarChatScreenState();
}

class _CarChatScreenState extends State<CarChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final CarChatService _chatService = CarChatService();

  List<Map<String, dynamic>>? _messages; // null = loading state
  bool _isSending = false;
  RealtimeChannel? _channel;

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;
  bool get _isLoading => _messages == null;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    _channel = _chatService.subscribeToMessages(
      widget.conversationId,
      (message) {
        if (mounted && _messages != null) {
          setState(() {
            if (!_messages!.any((m) => m['id'] == message['id'])) {
              _messages!.add(message);
            }
          });
          _scrollToBottom();
        }
      },
    );
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await _chatService.getMessages(widget.conversationId);

      // markMessagesAsRead'i arka planda çalıştır
      _chatService.markMessagesAsRead(widget.conversationId).catchError((_) {});

      if (mounted) {
        setState(() {
          _messages = messages;
        });
        _setupRealtimeSubscription();
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Mesajlar yüklenemedi: $e');
      if (mounted) {
        setState(() {
          _messages = []; // Hata durumunda boş liste
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending || _messages == null) return;

    _messageController.clear();
    setState(() => _isSending = true);

    final message = await _chatService.sendMessage(
      conversationId: widget.conversationId,
      content: content,
    );

    if (mounted) {
      setState(() => _isSending = false);
      if (message != null && _messages != null) {
        if (!_messages!.any((m) => m['id'] == message['id'])) {
          setState(() => _messages!.add(message));
        }
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final listing = widget.listing;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        title: Row(
          children: [
            // Araç resmi
            if (listing != null && listing['images'] != null && (listing['images'] as List).isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  (listing['images'] as List).first,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 40,
                    height: 40,
                    color: Colors.grey[300],
                    child: const Icon(Icons.directions_car, size: 20),
                  ),
                ),
              )
            else
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.directions_car, color: Colors.blue),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing?['title'] ?? 'Araç',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (listing?['brand_name'] != null)
                    Text(
                      '${listing!['brand_name']} ${listing['model_name'] ?? ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Mesajlar
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages!.isEmpty
                    ? _buildEmptyState(isDark)
                    : _buildMessageList(isDark),
          ),

          // Mesaj gönderme alanı
          _buildMessageInput(isDark),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz mesaj yok',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'İlk mesajı gönderin!',
            style: TextStyle(
              color: isDark ? Colors.grey[500] : Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(bool isDark) {
    final messages = _messages!;
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isMe = message['sender_id'] == _currentUserId;

        // Tarih ayracı
        Widget? dateSeparator;
        if (index == 0 ||
            !_isSameDay(
              DateTime.parse(messages[index - 1]['created_at']),
              DateTime.parse(message['created_at']),
            )) {
          dateSeparator = _buildDateSeparator(
            DateTime.parse(message['created_at']),
            isDark,
          );
        }

        return Column(
          children: [
            if (dateSeparator != null) dateSeparator,
            _buildMessageBubble(message, isMe, isDark),
          ],
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildDateSeparator(DateTime date, bool isDark) {
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
            color: isDark ? Colors.grey[800] : Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[700],
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe, bool isDark) {
    final createdAt = DateTime.parse(message['created_at']);
    final isRead = message['is_read'] as bool? ?? false;

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
          color: isMe
              ? Colors.blue
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
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
              message['content'] ?? '',
              style: TextStyle(
                color: isMe
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black87),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('HH:mm').format(createdAt),
                  style: TextStyle(
                    color: isMe
                        ? Colors.white70
                        : (isDark ? Colors.grey[500] : Colors.grey[500]),
                    fontSize: 11,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: isRead ? Colors.white : Colors.white70,
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
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
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
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              minLines: 1,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: 'Mesajınızı yazın...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
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
                fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
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
              onTap: _isSending ? null : _sendMessage,
              borderRadius: BorderRadius.circular(24),
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
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
