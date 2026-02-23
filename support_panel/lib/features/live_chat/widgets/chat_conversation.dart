import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/support_auth_service.dart';
import '../../../core/services/ticket_service.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/providers/chat_providers.dart';
import '../../../core/models/support_models.dart';
import 'canned_responses_popup.dart';
import 'whisper_panel.dart';

class ChatConversation extends ConsumerStatefulWidget {
  final String ticketId;
  const ChatConversation({super.key, required this.ticketId});

  @override
  ConsumerState<ChatConversation> createState() => _ChatConversationState();
}

class _ChatConversationState extends ConsumerState<ChatConversation> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _showWhisper = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Update collision lock
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatServiceProvider).updateCollisionLock(widget.ticketId);
      ref.read(chatServiceProvider).markMessagesAsRead(widget.ticketId);
    });
  }

  @override
  void dispose() {
    ref.read(chatServiceProvider).releaseCollisionLock(widget.ticketId);
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(liveChatMessagesProvider(widget.ticketId));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.background : AppColors.lightBackground;
    final cardColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    return Column(
      children: [
        // Chat header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: cardColor,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              const Icon(Icons.chat, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Ticket #${widget.ticketId.substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              // Whisper toggle
              IconButton(
                icon: Icon(_showWhisper ? Icons.visibility_off : Icons.visibility, size: 20, color: textMuted),
                onPressed: () => setState(() => _showWhisper = !_showWhisper),
                tooltip: _showWhisper ? 'Whisper panelini kapat' : 'Whisper (iç not)',
              ),
            ],
          ),
        ),

        // Messages area
        Expanded(
          child: Row(
            children: [
              // Main conversation
              Expanded(
                child: Container(
                  color: bgColor,
                  child: messagesAsync.when(
                    data: (messages) {
                      final visibleMessages = messages.where((m) => m.messageType != 'whisper' || m.isWhisper).toList();

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_scrollCtrl.hasClients) {
                          _scrollCtrl.animateTo(
                            _scrollCtrl.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                          );
                        }
                      });

                      if (visibleMessages.isEmpty) {
                        return Center(child: Text('Henüz mesaj yok', style: TextStyle(color: textMuted)));
                      }

                      return ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(16),
                        itemCount: visibleMessages.length,
                        itemBuilder: (context, index) {
                          final msg = visibleMessages[index];
                          return _buildMessageBubble(msg, isDark, textMuted);
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Hata: $e')),
                  ),
                ),
              ),

              // Whisper panel
              if (_showWhisper)
                WhisperPanel(ticketId: widget.ticketId),
            ],
          ),
        ),

        // Message input
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            border: Border(top: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageCtrl,
                  decoration: InputDecoration(
                    hintText: 'Mesaj yazın... (/ ile hazır yanıt)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: bgColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.flash_on, color: AppColors.warning, size: 20),
                      onPressed: _showCannedResponsesDialog,
                      tooltip: 'Hazır yanıtlar',
                    ),
                  ),
                  maxLines: 3,
                  minLines: 1,
                  onChanged: (text) {
                    if (text == '/') {
                      _showCannedResponsesDialog();
                    }
                  },
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _sending ? null : _sendMessage,
                icon: _sending
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send, size: 18),
                label: const Text('Gönder'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(TicketMessage msg, bool isDark, Color textMuted) {
    final isAgent = msg.isAgent;
    final isSystem = msg.isSystem;
    final isWhisper = msg.isWhisper;

    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: textMuted.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(msg.message, style: TextStyle(color: textMuted, fontSize: 12, fontStyle: FontStyle.italic)),
          ),
        ),
      );
    }

    if (isWhisper) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.5),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.visibility_off, size: 14, color: AppColors.warning),
                    const SizedBox(width: 4),
                    Text('Whisper - ${msg.senderName ?? ''}', style: const TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(msg.message, style: TextStyle(color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary, fontSize: 13)),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: isAgent ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.5),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isAgent
                ? AppColors.primary.withValues(alpha: 0.15)
                : (isDark ? AppColors.surfaceLight : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    msg.senderName ?? (isAgent ? 'Agent' : 'Müşteri'),
                    style: TextStyle(
                      color: isAgent ? AppColors.primary : textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('HH:mm').format(msg.createdAt),
                    style: TextStyle(color: textMuted, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(msg.message, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      await ref.read(ticketServiceProvider).sendMessage(
        ticketId: widget.ticketId,
        message: text,
      );
      _messageCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mesaj gönderilemedi: $e'), backgroundColor: AppColors.error),
        );
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  void _showCannedResponsesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => CannedResponsesPopup(
        onSelect: (content) {
          _messageCtrl.text = content;
          Navigator.pop(ctx);
        },
      ),
    );
  }
}
