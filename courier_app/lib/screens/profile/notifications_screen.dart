import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/courier_service.dart';
import '../../core/theme/app_theme.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _newOrders = true;
  bool _orderUpdates = true;
  bool _promotions = false;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await CourierService.getCourierProfile();
    if (profile != null && mounted) {
      setState(() {
        _newOrders = profile['notification_new_orders'] ?? true;
        _orderUpdates = profile['notification_order_updates'] ?? true;
        _promotions = profile['notification_promotions'] ?? false;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    try {
      final success = await CourierService.updateNotificationSettings(
        newOrders: _newOrders,
        orderUpdates: _orderUpdates,
        promotions: _promotions,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bildirim ayarları güncellendi'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Güncelleme başarısız'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bildirimler'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Push Notifications Section
                  Text(
                    'Anlık Bildirimler',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),

                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _buildSwitchTile(
                          icon: Icons.notifications_active,
                          iconColor: AppColors.primary,
                          title: 'Yeni Siparişler',
                          subtitle: 'Yeni sipariş geldiğinde bildirim al',
                          value: _newOrders,
                          onChanged: (value) {
                            setState(() => _newOrders = value);
                            _saveSettings();
                          },
                        ),
                        const Divider(height: 1),
                        _buildSwitchTile(
                          icon: Icons.update,
                          iconColor: AppColors.info,
                          title: 'Sipariş Güncellemeleri',
                          subtitle: 'Sipariş durumu değiştiğinde bildirim al',
                          value: _orderUpdates,
                          onChanged: (value) {
                            setState(() => _orderUpdates = value);
                            _saveSettings();
                          },
                        ),
                        const Divider(height: 1),
                        _buildSwitchTile(
                          icon: Icons.local_offer,
                          iconColor: AppColors.warning,
                          title: 'Kampanyalar',
                          subtitle: 'Promosyon ve kampanya bildirimleri',
                          value: _promotions,
                          onChanged: (value) {
                            setState(() => _promotions = value);
                            _saveSettings();
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Sound Settings
                  Text(
                    'Ses Ayarları',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),

                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _buildSwitchTile(
                          icon: Icons.volume_up,
                          iconColor: AppColors.success,
                          title: 'Bildirim Sesi',
                          subtitle: 'Yeni sipariş için sesli uyarı',
                          value: true,
                          onChanged: (value) {
                            // TODO: Implement
                          },
                        ),
                        const Divider(height: 1),
                        _buildSwitchTile(
                          icon: Icons.vibration,
                          iconColor: AppColors.secondary,
                          title: 'Titreşim',
                          subtitle: 'Bildirimler için titreşim',
                          value: true,
                          onChanged: (value) {
                            // TODO: Implement
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Info Note
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.info),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Online olduğunuzda yeni sipariş bildirimlerini almak için bildirimleri açık tutun.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.info,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: _isSaving ? null : onChanged,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return AppColors.primary;
              }
              return Colors.grey.shade400;
            }),
          ),
        ],
      ),
    );
  }
}
