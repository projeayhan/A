import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/providers/chat_providers.dart';
import '../../../core/models/support_models.dart';

class WhisperPanel extends ConsumerStatefulWidget {
  final String ticketId;
  const WhisperPanel({super.key, required this.ticketId});

  @override
  ConsumerState<WhisperPanel> createState() => _WhisperPanelState();
}

class _WhisperPanelState extends ConsumerState<WhisperPanel> {
  final _whisperCtrl = TextEditingController();

  @override
  void dispose() {
    _whisperCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(liveChatMessagesProvider(widget.ticketId));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);
    final bgColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(left: BorderSide(color: borderColor)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: const Row(
              children: [
                Icon(Icons.visibility_off, size: 16, color: AppColors.warning),
                SizedBox(width: 8),
                Text('Whisper (İç Notlar)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text('Müşteri bu mesajları göremez', style: TextStyle(color: textMuted, fontSize: 11)),
          const SizedBox(height: 4),

          // Whisper messages
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                final whispers = messages.where((m) => m.isWhisper || m.messageType == 'internal_note').toList();
                if (whispers.isEmpty) {
                  return Center(child: Text('Henüz iç not yok', style: TextStyle(color: textMuted, fontSize: 12)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: whispers.length,
                  itemBuilder: (context, index) {
                    final msg = whispers[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                msg.senderName ?? 'Agent',
                                style: const TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                              const Spacer(),
                              Text(
                                DateFormat('HH:mm').format(msg.createdAt),
                                style: TextStyle(color: textMuted, fontSize: 10),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(msg.message, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

          // Whisper input
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _whisperCtrl,
                    decoration: InputDecoration(
                      hintText: 'İç not yazın...',
                      hintStyle: TextStyle(fontSize: 12, color: textMuted),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: isDark ? AppColors.background : AppColors.lightBackground,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    minLines: 1,
                    onSubmitted: (_) => _sendWhisper(),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.send, size: 16, color: AppColors.warning),
                  onPressed: _sendWhisper,
                  tooltip: 'Whisper gönder',
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendWhisper() async {
    final text = _whisperCtrl.text.trim();
    if (text.isEmpty) return;

    await ref.read(chatServiceProvider).sendWhisper(
      ticketId: widget.ticketId,
      message: text,
    );
    _whisperCtrl.clear();
  }
}
