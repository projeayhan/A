import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/support_auth_service.dart';
import '../../../core/providers/theme_provider.dart';

class SupportSettingsScreen extends ConsumerStatefulWidget {
  const SupportSettingsScreen({super.key});

  @override
  ConsumerState<SupportSettingsScreen> createState() =>
      _SupportSettingsScreenState();
}

class _SupportSettingsScreenState extends ConsumerState<SupportSettingsScreen> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final agent = ref.watch(currentAgentProvider).value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark
        ? AppColors.surfaceLight
        : const Color(0xFFE2E8F0);
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    if (agent == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ayarlar',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),

          // Profil Kartı
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profil Bilgileri',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                      child: Text(
                        agent.fullName.isNotEmpty
                            ? agent.fullName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            agent.fullName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            agent.email,
                            style: TextStyle(color: textMuted, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _buildInfoChip(
                                agent.permissionLevelDisplay,
                                AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              _buildInfoChip(
                                agent.statusDisplay,
                                _statusColor(agent.status),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (agent.phone != null && agent.phone!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.phone, size: 16, color: textMuted),
                      const SizedBox(width: 8),
                      Text(agent.phone!, style: TextStyle(color: textMuted)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Vardiya Ayarları
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vardiya Bilgileri',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  'Maks Eşzamanlı Chat',
                  '${agent.maxConcurrentChats}',
                  textMuted,
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  'Aktif Chat Sayısı',
                  '${agent.activeChatCount}',
                  textMuted,
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  'Vardiya Başlangıç',
                  agent.shiftStart != null
                      ? _formatTime(agent.shiftStart!)
                      : 'Belirlenmedi',
                  textMuted,
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  'Vardiya Bitiş',
                  agent.shiftEnd != null
                      ? _formatTime(agent.shiftEnd!)
                      : 'Belirlenmedi',
                  textMuted,
                ),
                if (agent.specializations.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Uzmanlık Alanları',
                    style: TextStyle(color: textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: agent.specializations
                        .map((s) => _buildInfoChip(s, AppColors.info))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tema Ayarları
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Görünüm',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Koyu Tema'),
                  subtitle: Text(
                    'Koyu tema kullanarak göz yorgunluğunu azaltın',
                    style: TextStyle(color: textMuted, fontSize: 13),
                  ),
                  value: isDark,
                  activeThumbColor: AppColors.primary,
                  onChanged: (_) =>
                      ref.read(themeModeProvider.notifier).toggle(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Durum Değiştir
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Durum',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildStatusButton(
                      'online',
                      'Çevrimiçi',
                      AppColors.success,
                      agent.status,
                    ),
                    _buildStatusButton(
                      'busy',
                      'Meşgul',
                      AppColors.warning,
                      agent.status,
                    ),
                    _buildStatusButton(
                      'break',
                      'Mola',
                      AppColors.info,
                      agent.status,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color mutedColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: mutedColor, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildStatusButton(
    String status,
    String label,
    Color color,
    String currentStatus,
  ) {
    final isActive = status == currentStatus;
    return OutlinedButton.icon(
      onPressed: _saving
          ? null
          : () async {
              setState(() => _saving = true);
              await ref
                  .read(currentAgentProvider.notifier)
                  .updateStatus(status);
              if (mounted) setState(() => _saving = false);
            },
      icon: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: isActive ? color : null,
        side: BorderSide(
          color: isActive ? color : Colors.grey.withValues(alpha: 0.3),
          width: isActive ? 2 : 1,
        ),
        backgroundColor: isActive ? color.withValues(alpha: 0.1) : null,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'online':
        return AppColors.success;
      case 'busy':
        return AppColors.warning;
      case 'break':
        return AppColors.info;
      default:
        return AppColors.textMuted;
    }
  }
}
