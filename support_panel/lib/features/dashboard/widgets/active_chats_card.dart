import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/chat_providers.dart';

class ActiveChatsCard extends ConsumerWidget {
  const ActiveChatsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    final activeChats = ref.watch(activeChatCountProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.info),
              const SizedBox(width: 8),
              Text('Aktif Chatler', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Text(
                  '$activeChats',
                  style: TextStyle(color: AppColors.info, fontSize: 36, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text('aktif konusma', style: TextStyle(color: textMuted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
