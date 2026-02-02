import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../services/job_listings_admin_service.dart';

class JobSettingsScreen extends ConsumerWidget {
  const JobSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(jobSettingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'İş İlanları Ayarları',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'İş ilanları modülü için genel ayarları düzenleyin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(jobSettingsProvider),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Yenile'),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Settings List
            Expanded(
              child: settingsAsync.when(
                data: (settings) => _buildSettingsList(context, ref, settings),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Hata: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsList(BuildContext context, WidgetRef ref, List<JobSetting> settings) {
    if (settings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.settings_outlined, size: 64, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text('Ayar bulunamadı', style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    // Group settings by category (if key contains underscore, group by first part)
    final groupedSettings = <String, List<JobSetting>>{};
    for (final setting in settings) {
      final parts = setting.key.split('_');
      final category = parts.length > 1 ? parts.first : 'genel';
      groupedSettings.putIfAbsent(category, () => []).add(setting);
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: groupedSettings.entries.map((entry) {
          return Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getCategoryTitle(entry.key),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ...entry.value.map((setting) => _buildSettingItem(context, ref, setting)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getCategoryTitle(String category) {
    const titles = {
      'genel': 'Genel Ayarlar',
      'listing': 'İlan Ayarları',
      'company': 'Şirket Ayarları',
      'application': 'Başvuru Ayarları',
      'notification': 'Bildirim Ayarları',
      'limit': 'Limit Ayarları',
    };
    return titles[category] ?? category.toUpperCase();
  }

  Widget _buildSettingItem(BuildContext context, WidgetRef ref, JobSetting setting) {
    final isBoolSetting = setting.value == 'true' || setting.value == 'false';
    final isNumberSetting = int.tryParse(setting.value) != null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.surfaceLight)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getSettingLabel(setting.key),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (setting.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    setting.description!,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (isBoolSetting)
            Switch(
              value: setting.value == 'true',
              onChanged: (v) => _updateSetting(ref, setting, v.toString()),
            )
          else
            SizedBox(
              width: 200,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isNumberSetting ? setting.value : setting.value,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => _showEditDialog(context, ref, setting),
                    color: AppColors.info,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _getSettingLabel(String key) {
    // Convert snake_case to readable label
    return key
        .split('_')
        .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
        .join(' ');
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, JobSetting setting) {
    final controller = TextEditingController(text: setting.value);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_getSettingLabel(setting.key)),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (setting.description != null) ...[
                Text(
                  setting.description!,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Değer',
                ),
                keyboardType: int.tryParse(setting.value) != null
                    ? TextInputType.number
                    : TextInputType.text,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _updateSetting(ref, setting, controller.text);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateSetting(WidgetRef ref, JobSetting setting, String value) async {
    final service = ref.read(jobListingsAdminServiceProvider);
    try {
      await service.updateSetting(setting.id, value);
      ref.invalidate(jobSettingsProvider);
    } catch (e) {
      debugPrint('Error updating setting: $e');
    }
  }
}
