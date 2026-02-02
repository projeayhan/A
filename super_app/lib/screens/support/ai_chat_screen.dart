import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/ai_chat_service.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  String? _sessionId;
  bool _isLoading = false;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    // Check for existing active session
    final existingSessionId = await AiChatService.getActiveSessionId();

    if (existingSessionId != null) {
      _sessionId = existingSessionId;
      // Load chat history
      final history = await AiChatService.getChatHistory(existingSessionId);
      setState(() {
        _messages.addAll(history.map((msg) => ChatMessage(
          role: msg['role'],
          content: msg['content'],
          timestamp: DateTime.tryParse(msg['created_at'] ?? ''),
        )));
      });
    } else {
      // Add welcome message
      _messages.add(ChatMessage(
        role: 'assistant',
        content: 'Merhaba! 👋 Ben Oda Asistan, OdaBase müşteri temsilcinizim.\n\n'
            'Size nasıl yardımcı olabilirim?\n\n'
            '🍔 Yemek siparişi\n'
            '🛒 Market alışverişi\n'
            '🚕 Taksi çağırma\n'
            '🏠 Emlak ilanları\n'
            '🚗 Araç kiralama & satış\n'
            '💼 İş ilanları\n'
            '⚙️ Hesap ayarları\n\n'
            'Aşağıdaki hızlı sorulardan birini seçebilir veya kendi sorunuzu yazabilirsiniz.',
        timestamp: DateTime.now(),
      ));
    }

    setState(() {
      _isInitializing = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;

    _messageController.clear();

    setState(() {
      _messages.add(ChatMessage(
        role: 'user',
        content: message,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });
    _scrollToBottom();

    final response = await AiChatService.sendMessage(
      message: message,
      sessionId: _sessionId,
    );

    setState(() {
      _isLoading = false;

      if (response['success'] == true) {
        _sessionId = response['session_id'];
        _messages.add(ChatMessage(
          role: 'assistant',
          content: response['message'],
          timestamp: DateTime.now(),
        ));
      } else {
        _messages.add(ChatMessage(
          role: 'assistant',
          content: 'Üzgünüm, bir hata oluştu. Lütfen tekrar deneyin veya canlı desteğe bağlanın.',
          timestamp: DateTime.now(),
          isError: true,
        ));
      }
    });
    _scrollToBottom();
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.support_agent, color: AppColors.warning),
              ),
              title: const Text('Canlı Desteğe Bağlan'),
              subtitle: const Text('Bir temsilciye aktarılın'),
              onTap: () {
                Navigator.pop(context);
                _escalateToHuman();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.refresh, color: AppColors.primary),
              ),
              title: const Text('Yeni Sohbet Başlat'),
              subtitle: const Text('Mevcut sohbeti kapatıp yeni başlat'),
              onTap: () {
                Navigator.pop(context);
                _startNewChat();
              },
            ),
            if (_sessionId != null) ...[
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.star, color: AppColors.success),
                ),
                title: const Text('Sohbeti Değerlendir'),
                subtitle: const Text('Bu sohbet faydalı oldu mu?'),
                onTap: () {
                  Navigator.pop(context);
                  _showRatingDialog();
                },
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _escalateToHuman() async {
    if (_sessionId == null) return;

    final result = await AiChatService.escalateToHuman(
      _sessionId!,
      'Kullanıcı canlı destek talep etti',
    );

    if (result && mounted) {
      setState(() {
        _messages.add(ChatMessage(
          role: 'system',
          content: 'Talebiniz alındı. En kısa sürede bir temsilcimiz size yardımcı olacak. '
              'Lütfen bekleyin veya bildirimlerinizi kontrol edin.',
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
    }
  }

  Future<void> _startNewChat() async {
    if (_sessionId != null) {
      await AiChatService.closeSession(_sessionId!);
    }

    setState(() {
      _sessionId = null;
      _messages.clear();
      _messages.add(ChatMessage(
        role: 'assistant',
        content: 'Yeni bir sohbet başlattınız. Size nasıl yardımcı olabilirim?',
        timestamp: DateTime.now(),
      ));
    });
  }

  void _showRatingDialog() {
    int selectedRating = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Sohbeti Değerlendir'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Bu sohbet size yardımcı oldu mu?'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < selectedRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 36,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        selectedRating = index + 1;
                      });
                    },
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: selectedRating > 0
                  ? () async {
                      if (_sessionId != null) {
                        await AiChatService.rateSession(_sessionId!, selectedRating);
                      }
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Değerlendirmeniz için teşekkürler!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    }
                  : null,
              child: const Text('Gönder'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF5F5F5),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Oda Asistan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Çevrimiçi',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showOptionsMenu,
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: _isInitializing
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isLoading) {
                        return _buildTypingIndicator();
                      }
                      return _buildMessageBubble(_messages[index], isDark);
                    },
                  ),
          ),

          // Quick actions
          if (_messages.length <= 2) _buildQuickActions(),

          // Input area
          _buildInputArea(isDark),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isDark) {
    final isUser = message.role == 'user';
    final isSystem = message.role == 'system';

    if (isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.info, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message.content,
                style: const TextStyle(color: AppColors.info),
              ),
            ),
          ],
        ),
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser) ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isUser
                      ? AppColors.primary
                      : (isDark ? AppColors.surfaceDark : Colors.white),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isUser
                            ? Colors.white
                            : (isDark ? Colors.white : Colors.black87),
                        fontSize: 15,
                      ),
                    ),
                    if (message.timestamp != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(message.timestamp!),
                        style: TextStyle(
                          fontSize: 10,
                          color: isUser
                              ? Colors.white70
                              : (isDark ? Colors.grey[500] : Colors.grey[600]),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (isUser) const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDot(0),
                  const SizedBox(width: 4),
                  _buildDot(1),
                  const SizedBox(width: 4),
                  _buildDot(2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.4 + (value * 0.4)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    final quickQuestions = [
      'Siparişimi nasıl iptal ederim?',
      'Taksi nasıl çağırırım?',
      'Adres nasıl eklerim?',
      'İade nasıl yapılır?',
      'Kupon kodu nasıl kullanılır?',
      'Kurye nerede?',
    ];

    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: quickQuestions.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(
                quickQuestions[index],
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
              onPressed: () {
                _messageController.text = quickQuestions[index];
                _sendMessage();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
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
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.backgroundDark : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Mesajınızı yazın...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(24),
            ),
            child: IconButton(
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white),
              onPressed: _isLoading ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (now.difference(time).inDays == 0) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.day}/${time.month} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}

class ChatMessage {
  final String role;
  final String content;
  final DateTime? timestamp;
  final bool isError;

  ChatMessage({
    required this.role,
    required this.content,
    this.timestamp,
    this.isError = false,
  });
}
