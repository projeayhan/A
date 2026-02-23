import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

/// Quick actions card with navigation shortcuts
class QuickActionsCard extends StatelessWidget {
  const QuickActionsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hizli Islemler',
            style: TextStyle(
              color: AppColors.textPrimary(isDark),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _QuickActionItem(
            icon: Icons.add_home_rounded,
            label: 'Yeni Ilan Ekle',
            color: const Color(0xFF3B82F6),
            onTap: () => context.push('/listings/add'),
          ),
          _QuickActionItem(
            icon: Icons.person_add_rounded,
            label: 'Musteri Ekle',
            color: const Color(0xFF14B8A6),
            onTap: () => context.go('/clients?action=add'),
          ),
          _QuickActionItem(
            icon: Icons.calendar_month_rounded,
            label: 'Randevu Olustur',
            color: const Color(0xFFF59E0B),
            onTap: () => context.go('/appointments?action=add'),
          ),
          _QuickActionItem(
            icon: Icons.message_rounded,
            label: 'Mesajlar',
            color: const Color(0xFF10B981),
            onTap: () => context.go('/chat'),
          ),
        ],
      ),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: color.withValues(alpha: 0.5),
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
