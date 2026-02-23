import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

// Settings provider
final settingsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase
      .from('system_settings')
      .select()
      .order('category');
  return List<Map<String, dynamic>>.from(response);
});

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _selectedCategory = 'general';
  bool _isSaving = false;

  // Track changed values: key -> new value
  final Map<String, dynamic> _changedValues = {};

  final List<Map<String, dynamic>> _categories = [
    {'id': 'general', 'name': 'Genel', 'icon': Icons.settings},
    {'id': 'delivery', 'name': 'Teslimat', 'icon': Icons.delivery_dining},
    {'id': 'payment', 'name': 'Ödeme', 'icon': Icons.payment},
    {'id': 'notification', 'name': 'Bildirim', 'icon': Icons.notifications},
    {'id': 'security', 'name': 'Güvenlik', 'icon': Icons.security},
    {'id': 'limits', 'name': 'Limitler', 'icon': Icons.tune},
  ];

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.background : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? AppColors.surface : const Color(0xFFFFFFFF);
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? AppColors.textPrimary : const Color(0xFF0F172A);
    final textSecondary = isDark ? AppColors.textSecondary : const Color(0xFF475569);
    final textMuted = isDark ? AppColors.textMuted : const Color(0xFF94A3B8);

    return Scaffold(
      backgroundColor: bgColor,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ayarlar', style: TextStyle(color: textPrimary, fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Sistem ayarlarını yönetin', style: TextStyle(color: textSecondary, fontSize: 14)),
                  ],
                ),
                if (_changedValues.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_changedValues.length} değişiklik kaydedilmedi',
                      style: const TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 32),

            // Content
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sidebar
                  Container(
                    width: 250,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kategoriler', style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 16),
                        ..._categories.map((cat) => _buildCategoryItem(cat, textSecondary)),
                      ],
                    ),
                  ),

                  const SizedBox(width: 24),

                  // Settings Content
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: settingsAsync.when(
                        data: (settings) => _buildSettingsContent(settings, textPrimary, textSecondary, textMuted, bgColor),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => _buildSettingsContent([], textPrimary, textSecondary, textMuted, bgColor),
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

  Widget _buildCategoryItem(Map<String, dynamic> category, Color textSecondary) {
    final isSelected = _selectedCategory == category['id'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedCategory = category['id']),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(category['icon'], color: isSelected ? AppColors.primary : textSecondary, size: 20),
                const SizedBox(width: 12),
                Text(
                  category['name'],
                  style: TextStyle(
                    color: isSelected ? AppColors.primary : textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsContent(
    List<Map<String, dynamic>> settings,
    Color textPrimary,
    Color textSecondary,
    Color textMuted,
    Color bgColor,
  ) {
    final filteredSettings = settings.where((s) => s['category'] == _selectedCategory).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_getCategoryTitle(_selectedCategory), style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(_getCategoryDescription(_selectedCategory), style: TextStyle(color: textSecondary, fontSize: 14)),
          const SizedBox(height: 32),
          if (filteredSettings.isNotEmpty)
            ...filteredSettings.map((s) => _buildSettingItem(s, textPrimary, textMuted, bgColor))
          else
            ..._getDefaultSettingsForCategory(_selectedCategory, textPrimary, textMuted, bgColor),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () {
                  setState(() => _changedValues.clear());
                  ref.invalidate(settingsProvider);
                },
                child: const Text('Sıfırla'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isSaving ? null : () => _saveSettings(),
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Kaydet'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(Map<String, dynamic> setting, Color textPrimary, Color textMuted, Color bgColor) {
    final key = setting['key'] as String;
    final valueType = setting['value_type'] ?? 'string';
    final currentValue = _changedValues.containsKey(key) ? _changedValues[key] : setting['value'];
    final label = setting['display_name'] ?? key;
    final description = setting['description'] ?? '';

    switch (valueType) {
      case 'boolean':
        return _buildSwitchField(label, description, currentValue == true || currentValue == 'true', textPrimary, textMuted, (v) {
          setState(() => _changedValues[key] = v);
        });
      case 'number':
        return _buildNumberField(label, description, currentValue?.toString() ?? '', textPrimary, textMuted, bgColor, (v) {
          setState(() => _changedValues[key] = num.tryParse(v) ?? v);
        });
      default:
        final strValue = currentValue?.toString() ?? '';
        // Strip surrounding quotes from jsonb string values
        final cleanValue = strValue.startsWith('"') && strValue.endsWith('"')
            ? strValue.substring(1, strValue.length - 1)
            : strValue;
        return _buildTextField(label, description, cleanValue, textPrimary, textMuted, bgColor, (v) {
          setState(() => _changedValues[key] = v);
        });
    }
  }

  List<Widget> _getDefaultSettingsForCategory(String category, Color textPrimary, Color textMuted, Color bgColor) {
    // Default settings shown when DB has no entries for this category
    final allDefaults = <String, Map<String, String>>{
      'general': {'app_name': 'SuperCyp', 'support_email': 'destek@odabase.com', 'support_phone': '+90 555 123 4567'},
      'delivery': {'base_delivery_fee': '15', 'per_km_fee': '3', 'free_delivery_limit': '150', 'max_delivery_distance': '15', 'estimated_prep_time': '20'},
      'payment': {'online_payment_enabled': 'true', 'card_on_delivery_enabled': 'true', 'cash_payment_enabled': 'true'},
      'notification': {'push_notifications_enabled': 'true', 'sms_notifications_enabled': 'true', 'email_notifications_enabled': 'true'},
      'security': {'max_login_attempts': '5', 'account_lock_duration': '30', 'session_timeout_hours': '24', 'admin_2fa_required': 'false'},
      'limits': {'max_order_items': '50', 'min_order_amount': '30', 'max_order_amount': '5000', 'order_cancel_time': '5'},
    };
    final defaults = allDefaults[category] ?? <String, String>{};

    return defaults.entries.map((e) {
      final isBoolean = e.value == 'true' || e.value == 'false';
      final isNumber = num.tryParse(e.value) != null;
      final currentValue = _changedValues.containsKey(e.key) ? _changedValues[e.key] : e.value;

      if (isBoolean) {
        return _buildSwitchField(
          _humanizeKey(e.key), '', currentValue == true || currentValue == 'true',
          textPrimary, textMuted,
          (v) => setState(() => _changedValues[e.key] = v),
        );
      } else if (isNumber) {
        return _buildNumberField(
          _humanizeKey(e.key), '', currentValue?.toString() ?? e.value,
          textPrimary, textMuted, bgColor,
          (v) => setState(() => _changedValues[e.key] = num.tryParse(v) ?? v),
        );
      } else {
        return _buildTextField(
          _humanizeKey(e.key), '', currentValue?.toString() ?? e.value,
          textPrimary, textMuted, bgColor,
          (v) => setState(() => _changedValues[e.key] = v),
        );
      }
    }).toList();
  }

  String _humanizeKey(String key) {
    return key.replaceAll('_', ' ').split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
  }

  Widget _buildTextField(String label, String description, String value, Color textPrimary, Color textMuted, Color bgColor, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w500)),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(description, style: TextStyle(color: textMuted, fontSize: 12)),
          ],
          const SizedBox(height: 8),
          TextFormField(
            initialValue: value,
            onChanged: onChanged,
            decoration: InputDecoration(
              filled: true,
              fillColor: bgColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.surfaceLight)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberField(String label, String description, String value, Color textPrimary, Color textMuted, Color bgColor, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w500)),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(description, style: TextStyle(color: textMuted, fontSize: 12)),
          ],
          const SizedBox(height: 8),
          TextFormField(
            initialValue: value,
            keyboardType: TextInputType.number,
            onChanged: onChanged,
            decoration: InputDecoration(
              filled: true,
              fillColor: bgColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.surfaceLight)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchField(String label, String description, bool value, Color textPrimary, Color textMuted, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w500)),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(description, style: TextStyle(color: textMuted, fontSize: 12)),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  String _getCategoryTitle(String category) {
    switch (category) {
      case 'general': return 'Genel Ayarlar';
      case 'delivery': return 'Teslimat Ayarları';
      case 'payment': return 'Ödeme Ayarları';
      case 'notification': return 'Bildirim Ayarları';
      case 'security': return 'Güvenlik Ayarları';
      case 'limits': return 'Limit Ayarları';
      default: return 'Ayarlar';
    }
  }

  String _getCategoryDescription(String category) {
    switch (category) {
      case 'general': return 'Uygulamanın genel ayarlarını yapılandırın';
      case 'delivery': return 'Teslimat ücretleri ve süreleri';
      case 'payment': return 'Ödeme yöntemlerini yönetin';
      case 'notification': return 'Bildirim kanallarını ayarlayın';
      case 'security': return 'Güvenlik ve oturum ayarları';
      case 'limits': return 'Sipariş ve işlem limitleri';
      default: return '';
    }
  }

  Future<void> _saveSettings() async {
    if (_changedValues.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Değişiklik yok'), backgroundColor: AppColors.info),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final supabase = ref.read(supabaseProvider);

      for (final entry in _changedValues.entries) {
        final value = entry.value is String ? '"${entry.value}"' : entry.value;
        await supabase.from('system_settings').upsert({
          'key': entry.key,
          'value': value,
          'category': _selectedCategory,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'key');
      }

      if (!mounted) return;

      setState(() {
        _changedValues.clear();
        _isSaving = false;
      });

      ref.invalidate(settingsProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ayarlar başarıyla kaydedildi'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kaydetme hatası: $e'), backgroundColor: AppColors.error),
      );
    }
  }
}
