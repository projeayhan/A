import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/chat_providers.dart';
import '../widgets/chat_list_panel.dart';
import '../widgets/chat_conversation.dart';

class LiveChatScreen extends ConsumerStatefulWidget {
  const LiveChatScreen({super.key});

  @override
  ConsumerState<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends ConsumerState<LiveChatScreen> {
  @override
  Widget build(BuildContext context) {
    final selectedTicketId = ref.watch(selectedChatTicketProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? AppColors.surfaceLight
        : const Color(0xFFE2E8F0);

    return Row(
      children: [
        // Left panel: chat list
        Container(
          width: 380,
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: borderColor)),
          ),
          child: const ChatListPanel(),
        ),
        // Right panel: conversation
        Expanded(
          child: selectedTicketId != null
              ? ChatConversation(ticketId: selectedTicketId)
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 64,
                        color: isDark
                            ? AppColors.textMuted
                            : AppColors.lightTextMuted,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Bir sohbet seçin',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textMuted
                              : AppColors.lightTextMuted,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
