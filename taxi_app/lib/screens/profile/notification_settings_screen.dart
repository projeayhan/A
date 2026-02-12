import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/communication_service.dart';
import '../../core/theme/app_theme.dart';

final _notificationPrefsProvider = FutureProvider<CommunicationPreferences?>((ref) async {
  return await CommunicationService.getPreferences();
});

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  bool _notifyNewRides = true;
  bool _notifyRideUpdates = true;
  bool _notifyEarnings = true;
  bool _notifyCampaigns = true;
  bool _notifySystemUpdates = true;
  bool _initialized = false;

  void _initFromPrefs(CommunicationPreferences prefs) {
    if (_initialized) return;
    _notifyNewRides = prefs.notifyNewRides;
    _notifyRideUpdates = prefs.notifyRideUpdates;
    _notifyEarnings = prefs.notifyEarnings;
    _notifyCampaigns = prefs.notifyCampaigns;
    _notifySystemUpdates = prefs.notifySystemUpdates;
    _initialized = true;
  }

  Future<void> _savePreferences() async {
    final currentPrefs = ref.read(_notificationPrefsProvider).value;
    final updated = (currentPrefs ?? const CommunicationPreferences()).copyWith(
      notifyNewRides: _notifyNewRides,
      notifyRideUpdates: _notifyRideUpdates,
      notifyEarnings: _notifyEarnings,
      notifyCampaigns: _notifyCampaigns,
      notifySystemUpdates: _notifySystemUpdates,
    );
    await CommunicationService.updatePreferences(updated);
  }

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(_notificationPrefsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bildirim Ayarlari'),
      ),
      body: prefsAsync.when(
        data: (prefs) {
          if (prefs != null) _initFromPrefs(prefs);
          return _buildContent(context);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.notifications_active, color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Bildirim tercihlerinizi yonetin. Kapattiginiz bildirimler size gonderilmeyecektir.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Ride notifications
          _buildSection(
            context,
            title: 'Yolculuk Bildirimleri',
            icon: Icons.local_taxi,
            iconColor: AppColors.secondary,
            children: [
              _buildSwitch(
                'Yeni Surus Talepleri',
                'Yeni musteri talepleri geldiginde bildirim al',
                _notifyNewRides,
                (v) {
                  setState(() => _notifyNewRides = v);
                  _savePreferences();
                },
              ),
              const Divider(height: 1),
              _buildSwitch(
                'Yolculuk Guncellemeleri',
                'Musteri mesajlari ve durum degisiklikleri',
                _notifyRideUpdates,
                (v) {
                  setState(() => _notifyRideUpdates = v);
                  _savePreferences();
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Financial notifications
          _buildSection(
            context,
            title: 'Finansal Bildirimler',
            icon: Icons.account_balance_wallet,
            iconColor: AppColors.success,
            children: [
              _buildSwitch(
                'Kazanc Bildirimleri',
                'Yolculuk tamamlandiginda kazanc bildirimi',
                _notifyEarnings,
                (v) {
                  setState(() => _notifyEarnings = v);
                  _savePreferences();
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // General notifications
          _buildSection(
            context,
            title: 'Genel Bildirimler',
            icon: Icons.campaign_outlined,
            iconColor: AppColors.info,
            children: [
              _buildSwitch(
                'Kampanya ve Promosyonlar',
                'Firsatlar ve ozel teklifler',
                _notifyCampaigns,
                (v) {
                  setState(() => _notifyCampaigns = v);
                  _savePreferences();
                },
              ),
              const Divider(height: 1),
              _buildSwitch(
                'Sistem Guncellemeleri',
                'Uygulama guncellemeleri ve duyurular',
                _notifySystemUpdates,
                (v) {
                  setState(() => _notifySystemUpdates = v);
                  _savePreferences();
                },
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitch(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      value: value,
      onChanged: onChanged,
      activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
      thumbColor: WidgetStatePropertyAll(value ? AppColors.primary : null),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
