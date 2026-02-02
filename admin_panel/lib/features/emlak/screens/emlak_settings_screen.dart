import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../services/emlak_admin_service.dart';

class EmlakSettingsScreen extends ConsumerStatefulWidget {
  const EmlakSettingsScreen({super.key});

  @override
  ConsumerState<EmlakSettingsScreen> createState() => _EmlakSettingsScreenState();
}

class _EmlakSettingsScreenState extends ConsumerState<EmlakSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(emlakSettingsProvider);

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
                      'Emlak Ayarları',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Emlak modülü genel ayarlarını yapılandırın',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(emlakSettingsProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showAddSettingDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Yeni Ayar Ekle'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Settings Content
            Expanded(
              child: settingsAsync.when(
                data: (settings) => _buildSettingsContent(settings),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text('Hata: $e', style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsContent(List<EmlakSetting> settings) {
    if (settings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.settings, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text('Henüz ayar bulunmuyor', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showAddSettingDialog(),
              icon: const Icon(Icons.add),
              label: const Text('İlk Ayarı Ekle'),
            ),
          ],
        ),
      );
    }

    // Ayarları kategorilere göre grupla
    final limitSettings = settings.where((s) => s.key.contains('max_') || s.key.contains('limit')).toList();
    final priceSettings = settings.where((s) => s.key.contains('price') || s.key.contains('fee')).toList();
    final otherSettings = settings.where((s) =>
        !s.key.contains('max_') &&
        !s.key.contains('limit') &&
        !s.key.contains('price') &&
        !s.key.contains('fee')
    ).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (limitSettings.isNotEmpty) ...[
            _buildSettingsSection('Limitler', limitSettings, Icons.tune, AppColors.info),
            const SizedBox(height: 24),
          ],
          if (priceSettings.isNotEmpty) ...[
            _buildSettingsSection('Fiyatlandırma', priceSettings, Icons.attach_money, AppColors.success),
            const SizedBox(height: 24),
          ],
          if (otherSettings.isNotEmpty) ...[
            _buildSettingsSection('Diğer Ayarlar', otherSettings, Icons.settings, AppColors.primary),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<EmlakSetting> settings, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.surfaceLight)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${settings.length} ayar',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          // Settings List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: settings.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.surfaceLight),
            itemBuilder: (context, index) => _buildSettingRow(settings[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(EmlakSetting setting) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getSettingDisplayName(setting.key),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (setting.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    setting.description!,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: _buildSettingValueWidget(setting),
          ),
          const SizedBox(width: 16),
          Row(
            children: [
              IconButton(
                onPressed: () => _showEditSettingDialog(setting),
                icon: const Icon(Icons.edit, size: 18),
                tooltip: 'Düzenle',
                color: AppColors.textMuted,
              ),
              IconButton(
                onPressed: () => _showDeleteConfirmDialog(setting),
                icon: const Icon(Icons.delete, size: 18),
                tooltip: 'Sil',
                color: AppColors.error,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingValueWidget(EmlakSetting setting) {
    final value = setting.value;

    if (value is bool) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: value
                  ? AppColors.success.withValues(alpha: 0.15)
                  : AppColors.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              value ? 'Aktif' : 'Pasif',
              style: TextStyle(
                color: value ? AppColors.success : AppColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    } else if (value is num) {
      final isPrice = setting.key.contains('price') || setting.key.contains('fee');
      return Text(
        isPrice ? '${value.toStringAsFixed(0)} ₺' : value.toString(),
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        textAlign: TextAlign.end,
      );
    } else {
      return Text(
        value?.toString() ?? '-',
        style: const TextStyle(color: AppColors.textPrimary),
        textAlign: TextAlign.end,
      );
    }
  }

  String _getSettingDisplayName(String key) {
    final names = {
      'max_images_per_listing': 'İlan Başına Maksimum Fotoğraf',
      'max_free_listings_per_user': 'Kullanıcı Başına Ücretsiz İlan',
      'featured_listing_price': 'Öne Çıkan İlan Ücreti',
      'premium_listing_price': 'Premium İlan Ücreti',
      'spotlight_listing_price': 'Vitrin İlan Ücreti',
      'listing_expiry_days': 'İlan Geçerlilik Süresi (Gün)',
      'auto_approve_listings': 'Otomatik İlan Onayı',
      'require_phone_verification': 'Telefon Doğrulama Zorunlu',
      'allow_agent_accounts': 'Emlakçı Hesaplarına İzin Ver',
    };
    return names[key] ?? key.replaceAll('_', ' ').toUpperCase();
  }

  void _showAddSettingDialog() {
    final keyController = TextEditingController();
    final valueController = TextEditingController();
    final descController = TextEditingController();
    String valueType = 'number';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Yeni Ayar Ekle'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: keyController,
                  decoration: const InputDecoration(
                    labelText: 'Ayar Anahtarı',
                    hintText: 'Örn: max_images_per_listing',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: valueType,
                  decoration: const InputDecoration(
                    labelText: 'Değer Tipi',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'number', child: Text('Sayı')),
                    DropdownMenuItem(value: 'text', child: Text('Metin')),
                    DropdownMenuItem(value: 'boolean', child: Text('Evet/Hayır')),
                  ],
                  onChanged: (value) => setDialogState(() => valueType = value!),
                ),
                const SizedBox(height: 16),
                if (valueType == 'boolean')
                  SwitchListTile(
                    title: const Text('Değer'),
                    value: valueController.text == 'true',
                    onChanged: (value) => setDialogState(() {
                      valueController.text = value.toString();
                    }),
                  )
                else
                  TextField(
                    controller: valueController,
                    keyboardType: valueType == 'number' ? TextInputType.number : TextInputType.text,
                    decoration: InputDecoration(
                      labelText: 'Değer',
                      hintText: valueType == 'number' ? 'Örn: 10' : 'Değer girin',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama (Opsiyonel)',
                    hintText: 'Bu ayarın ne işe yaradığını açıklayın',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () async {
                if (keyController.text.isEmpty || valueController.text.isEmpty) return;

                dynamic value;
                if (valueType == 'number') {
                  value = num.tryParse(valueController.text) ?? 0;
                } else if (valueType == 'boolean') {
                  value = valueController.text == 'true';
                } else {
                  value = valueController.text;
                }

                final service = ref.read(emlakAdminServiceProvider);
                try {
                  await service.addSetting(
                    keyController.text,
                    value,
                    descController.text.isNotEmpty ? descController.text : null,
                  );
                  ref.invalidate(emlakSettingsProvider);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ayar eklendi'), backgroundColor: AppColors.success),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSettingDialog(EmlakSetting setting) {
    final valueController = TextEditingController(text: setting.value.toString());
    bool boolValue = setting.value is bool ? setting.value as bool : false;
    final isBoolean = setting.value is bool;
    final isNumber = setting.value is num;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_getSettingDisplayName(setting.key)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (setting.description != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.info, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            setting.description!,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (isBoolean)
                  SwitchListTile(
                    title: const Text('Değer'),
                    subtitle: Text(boolValue ? 'Aktif' : 'Pasif'),
                    value: boolValue,
                    onChanged: (value) => setDialogState(() => boolValue = value),
                  )
                else
                  TextField(
                    controller: valueController,
                    keyboardType: isNumber ? TextInputType.number : TextInputType.text,
                    decoration: InputDecoration(
                      labelText: 'Değer',
                      border: const OutlineInputBorder(),
                      suffixText: setting.key.contains('price') || setting.key.contains('fee') ? '₺' : null,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () async {
                dynamic value;
                if (isBoolean) {
                  value = boolValue;
                } else if (isNumber) {
                  value = num.tryParse(valueController.text) ?? 0;
                } else {
                  value = valueController.text;
                }

                final service = ref.read(emlakAdminServiceProvider);
                try {
                  await service.updateSetting(setting.id, value);
                  ref.invalidate(emlakSettingsProvider);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ayar güncellendi'), backgroundColor: AppColors.success),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(EmlakSetting setting) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ayarı Sil'),
        content: Text('"${_getSettingDisplayName(setting.key)}" ayarını silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              final service = ref.read(emlakAdminServiceProvider);
              try {
                await service.deleteSetting(setting.id);
                ref.invalidate(emlakSettingsProvider);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ayar silindi')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}
