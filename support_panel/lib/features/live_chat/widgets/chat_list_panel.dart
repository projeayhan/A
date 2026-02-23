import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/support_auth_service.dart';
import '../../../core/providers/chat_providers.dart';
import '../../../core/models/support_models.dart';
import '../../../shared/widgets/status_badge.dart';

class ChatListPanel extends ConsumerStatefulWidget {
  const ChatListPanel({super.key});

  @override
  ConsumerState<ChatListPanel> createState() => _ChatListPanelState();
}

class _ChatListPanelState extends ConsumerState<ChatListPanel> {
  String _filter = 'all'; // all, mine, unassigned

  @override
  Widget build(BuildContext context) {
    final chatsAsync = ref.watch(activeChatsProvider);
    final selectedId = ref.watch(selectedChatTicketProvider);
    final agent = ref.watch(currentAgentProvider).value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    return Column(
      children: [
        // Header with filter
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Canlı Sohbetler', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildFilterChip('Tümü', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Bana Atanan', 'mine'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Atanmamış', 'unassigned'),
                ],
              ),
            ],
          ),
        ),

        // Chat list
        Expanded(
          child: chatsAsync.when(
            data: (chats) {
              var filtered = chats;
              if (_filter == 'mine' && agent != null) {
                filtered = chats.where((c) => c['assigned_agent_id'] == agent.id).toList();
              } else if (_filter == 'unassigned') {
                filtered = chats.where((c) => c['assigned_agent_id'] == null).toList();
              }

              if (filtered.isEmpty) {
                return Center(
                  child: Text('Aktif sohbet yok', style: TextStyle(color: textMuted)),
                );
              }

              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final chat = filtered[index];
                  final ticket = SupportTicket.fromJson(chat);
                  final isSelected = selectedId == ticket.id;

                  return _buildChatItem(ticket, isSelected, isDark, borderColor, textMuted);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Hata: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isActive = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AppColors.primary : null,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildChatItem(SupportTicket ticket, bool isSelected, bool isDark, Color borderColor, Color textMuted) {
    final selectedBg = isDark
        ? AppColors.primary.withValues(alpha: 0.15)
        : AppColors.primary.withValues(alpha: 0.08);

    return Material(
      color: isSelected ? selectedBg : Colors.transparent,
      child: InkWell(
        onTap: () => ref.read(selectedChatTicketProvider.notifier).state = ticket.id,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: borderColor.withValues(alpha: 0.5))),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Service type icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _serviceColor(ticket.serviceType).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_serviceIcon(ticket.serviceType), color: _serviceColor(ticket.serviceType), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ticket.customerName ?? 'Anonim',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatTime(ticket.updatedAt),
                          style: TextStyle(color: textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ticket.subject,
                      style: TextStyle(color: textMuted, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        StatusBadge.priority(ticket.priority),
                        const SizedBox(width: 6),
                        StatusBadge.serviceType(ticket.serviceType),
                        if (ticket.isSlaBreached) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('SLA', style: TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.w600)),
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
      ),
    );
  }

  IconData _serviceIcon(String type) {
    switch (type) {
      case 'food': return Icons.restaurant;
      case 'market': return Icons.shopping_cart;
      case 'store': return Icons.store;
      case 'taxi': return Icons.local_taxi;
      case 'rental': return Icons.car_rental;
      case 'emlak': return Icons.home_work;
      case 'car_sales': return Icons.directions_car;
      default: return Icons.help_outline;
    }
  }

  Color _serviceColor(String type) {
    switch (type) {
      case 'food': return AppColors.warning;
      case 'market': return AppColors.success;
      case 'store': return AppColors.info;
      case 'taxi': return const Color(0xFF8B5CF6);
      case 'rental': return AppColors.primary;
      case 'emlak': return const Color(0xFFEC4899);
      case 'car_sales': return const Color(0xFFF97316);
      default: return AppColors.textMuted;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes}dk';
    if (diff.inHours < 24) return '${diff.inHours}sa';
    return DateFormat('dd/MM').format(dt);
  }
}
