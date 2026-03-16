import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/merchant_management_providers.dart';

class AdminMessagesScreen extends ConsumerStatefulWidget {
  final String entityType;
  final String entityId;

  const AdminMessagesScreen({
    super.key,
    required this.entityType,
    required this.entityId,
  });

  @override
  ConsumerState<AdminMessagesScreen> createState() =>
      _AdminMessagesScreenState();
}

class _AdminMessagesScreenState extends ConsumerState<AdminMessagesScreen> {
  String? _selectedConversationId;
  List<Map<String, dynamic>> _selectedMessages = [];

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(
      entityConversationsProvider((
        entityType: widget.entityType,
        entityId: widget.entityId,
      )),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Mesajlar',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
      ),
      body: conversationsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 12),
              Text(
                'Mesajlar yuklenemedi',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(entityConversationsProvider((
                  entityType: widget.entityType,
                  entityId: widget.entityId,
                ))),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
        data: (conversations) {
          if (conversations.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.forum_outlined,
                      color: AppColors.textMuted, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'Mesaj yok',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Henuz bir konusma baslatilmamis.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          return Row(
            children: [
              // Left panel - Conversation list
              SizedBox(
                width: 360,
                child: _buildConversationList(conversations),
              ),
              // Divider
              Container(
                width: 1,
                color: AppColors.surfaceLight,
              ),
              // Right panel - Message detail
              Expanded(
                child: _selectedConversationId != null
                    ? _buildMessageDetail()
                    : const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                color: AppColors.textMuted, size: 56),
                            SizedBox(height: 16),
                            Text(
                              'Bir konusma secin',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildConversationList(List<Map<String, dynamic>> conversations) {
    return Container(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Konusmalar',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Divider(color: AppColors.surfaceLight, height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: conversations.length,
              separatorBuilder: (_, _) =>
                  const Divider(color: AppColors.surfaceLight, height: 1),
              itemBuilder: (context, index) {
                final conversation = conversations[index];
                final messages = List<Map<String, dynamic>>.from(
                    conversation['messages'] ?? []);
                final lastMessage =
                    messages.isNotEmpty ? messages.first : null;
                final unreadCount = messages
                    .where((m) => m['is_read'] == false)
                    .length;
                final isSelected =
                    _selectedConversationId == conversation['id'];

                return _buildConversationTile(
                  conversation: conversation,
                  lastMessage: lastMessage,
                  unreadCount: unreadCount,
                  isSelected: isSelected,
                  messages: messages,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTile({
    required Map<String, dynamic> conversation,
    required Map<String, dynamic>? lastMessage,
    required int unreadCount,
    required bool isSelected,
    required List<Map<String, dynamic>> messages,
  }) {
    final customerName =
        conversation['customer_name'] as String? ?? 'Musteri';
    final lastText =
        lastMessage?['message'] as String? ?? 'Mesaj yok';
    final lastTime = lastMessage?['created_at'] as String?;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedConversationId = conversation['id'] as String?;
          _selectedMessages = List<Map<String, dynamic>>.from(messages);
          // Sort messages chronologically
          _selectedMessages.sort((a, b) {
            final aTime = a['created_at'] as String? ?? '';
            final bTime = b['created_at'] as String? ?? '';
            return aTime.compareTo(bTime);
          });
        });
      },
      child: Container(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.15)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor:
                  isSelected ? AppColors.primary : AppColors.surfaceLight,
              child: Text(
                customerName.isNotEmpty
                    ? customerName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
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
                          customerName,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: unreadCount > 0
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (lastTime != null)
                        Text(
                          _formatTimestamp(lastTime),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastText,
                          style: TextStyle(
                            color: unreadCount > 0
                                ? AppColors.textSecondary
                                : AppColors.textMuted,
                            fontSize: 13,
                            fontWeight: unreadCount > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildMessageDetail() {
    if (_selectedMessages.isEmpty) {
      return const Center(
        child: Text(
          'Bu konusmada mesaj yok',
          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
      );
    }

    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                bottom: BorderSide(color: AppColors.surfaceLight, width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.visibility_outlined,
                    color: AppColors.textMuted, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Salt okunur gorunum',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_selectedMessages.length} mesaj',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // Messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: _selectedMessages.length,
              itemBuilder: (context, index) {
                final message = _selectedMessages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          // Read-only footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.surfaceLight, width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline,
                    color: AppColors.textMuted, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'Admin gorunumu - mesaj gonderilemez',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final senderType = message['sender_type'] as String? ?? 'customer';
    final senderName = message['sender_name'] as String? ?? '';
    final text = message['message'] as String? ?? '';
    final createdAt = message['created_at'] as String?;
    final isRead = message['is_read'] as bool? ?? false;

    final isCustomer = senderType == 'customer';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isCustomer ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isCustomer) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.info.withValues(alpha: 0.2),
              child: Text(
                senderName.isNotEmpty ? senderName[0].toUpperCase() : 'M',
                style: const TextStyle(
                    color: AppColors.info,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isCustomer
                    ? AppColors.surfaceLight
                    : AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isCustomer ? 4 : 16),
                  bottomRight: Radius.circular(isCustomer ? 16 : 4),
                ),
                border: isCustomer
                    ? null
                    : Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (senderName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        senderName,
                        style: TextStyle(
                          color: isCustomer
                              ? AppColors.info
                              : AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Text(
                    text,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (createdAt != null)
                        Text(
                          _formatTimestamp(createdAt),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      if (!isCustomer) ...[
                        const SizedBox(width: 6),
                        Icon(
                          isRead ? Icons.done_all : Icons.done,
                          size: 14,
                          color: isRead
                              ? AppColors.success
                              : AppColors.textMuted,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (!isCustomer) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              child: const Icon(Icons.store,
                  color: AppColors.primary, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dateTime);

      if (diff.inMinutes < 1) return 'Simdi';
      if (diff.inMinutes < 60) return '${diff.inMinutes}dk';
      if (diff.inHours < 24) return '${diff.inHours}sa';
      if (diff.inDays < 7) return '${diff.inDays}g';

      return '${dateTime.day.toString().padLeft(2, '0')}.'
          '${dateTime.month.toString().padLeft(2, '0')}.'
          '${dateTime.year}';
    } catch (_) {
      return '';
    }
  }
}
