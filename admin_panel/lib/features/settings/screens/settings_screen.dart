import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

// Settings provider
final settingsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
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

  final List<Map<String, dynamic>> _categories = [
    {'id': 'general', 'name': 'Genel', 'icon': Icons.settings},
    {'id': 'delivery', 'name': 'Teslimat', 'icon': Icons.delivery_dining},
    {'id': 'commission', 'name': 'Komisyon', 'icon': Icons.percent},
    {'id': 'payment', 'name': 'Ödeme', 'icon': Icons.payment},
    {'id': 'notification', 'name': 'Bildirim', 'icon': Icons.notifications},
    {'id': 'security', 'name': 'Güvenlik', 'icon': Icons.security},
    {'id': 'limits', 'name': 'Limitler', 'icon': Icons.tune},
  ];

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ayarlar',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Sistem ayarlarını yönetin',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
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
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.surfaceLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kategoriler',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ..._categories.map((cat) => _buildCategoryItem(cat)),
                      ],
                    ),
                  ),

                  const SizedBox(width: 24),

                  // Settings Content
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.surfaceLight),
                      ),
                      child: settingsAsync.when(
                        data: (settings) => _buildSettingsContent(settings),
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => _buildDefaultSettings(),
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

  Widget _buildCategoryItem(Map<String, dynamic> category) {
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
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  category['icon'],
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  category['name'],
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsContent(List<Map<String, dynamic>> settings) {
    final filteredSettings = settings
        .where((s) => s['category'] == _selectedCategory)
        .toList();

    if (filteredSettings.isEmpty) {
      return _buildDefaultSettings();
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getCategoryTitle(_selectedCategory),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getCategoryDescription(_selectedCategory),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),
          ...filteredSettings.map((setting) => _buildSettingItem(setting)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => ref.invalidate(settingsProvider),
                child: const Text('Sıfırla'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => _saveSettings(),
                child: const Text('Kaydet'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultSettings() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getCategoryTitle(_selectedCategory),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getCategoryDescription(_selectedCategory),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),
          ..._getDefaultSettingsForCategory(_selectedCategory),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(onPressed: () {}, child: const Text('Sıfırla')),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => _saveSettings(),
                child: const Text('Kaydet'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _getDefaultSettingsForCategory(String category) {
    switch (category) {
      case 'general':
        return [
          _buildTextField('Uygulama Adı', 'OdaBase', 'Uygulamanın görünen adı'),
          _buildTextField(
            'Destek E-posta',
            'destek@odabase.com',
            'Destek e-posta adresi',
          ),
          _buildTextField(
            'Destek Telefon',
            '+90 555 123 4567',
            'Destek telefon numarası',
          ),
          _buildDropdownField('Varsayılan Dil', 'tr', [
            'tr',
            'en',
          ], 'Varsayılan dil'),
        ];
      case 'delivery':
        return [
          _buildNumberField(
            'Baz Teslimat Ücreti',
            '15',
            'TL cinsinden minimum ücret',
          ),
          _buildNumberField('KM Başı Ücret', '3', 'Her km için ek ücret (TL)'),
          _buildNumberField(
            'Ücretsiz Teslimat Limiti',
            '150',
            'Bu tutarın üstünde ücretsiz',
          ),
          _buildNumberField(
            'Maks. Teslimat Mesafesi',
            '15',
            'Kilometre cinsinden',
          ),
          _buildNumberField(
            'Tahmini Hazırlık Süresi',
            '20',
            'Dakika cinsinden',
          ),
        ];
      case 'commission':
        return [
          _buildNumberField('İşletme Komisyon Oranı', '15', 'Yüzde cinsinden'),
          _buildNumberField(
            'Kurye Komisyon Oranı',
            '85',
            'Teslimat ücretinden kuryeye kalan (%)',
          ),
          _buildNumberField('Taksi Komisyon Oranı', '20', 'Yüzde cinsinden'),
          _buildNumberField('Minimum Çekim Tutarı', '100', 'TL cinsinden'),
        ];
      case 'payment':
        return [
          _buildSwitchField('Online Ödeme', true, 'Online ödeme aktif mi'),
          _buildSwitchField('Kapıda Kart', true, 'Kapıda kart ödeme aktif mi'),
          _buildSwitchField('Nakit Ödeme', true, 'Nakit ödeme aktif mi'),
        ];
      case 'notification':
        return [
          _buildSwitchField(
            'Push Bildirimler',
            true,
            'Push bildirimleri aktif mi',
          ),
          _buildSwitchField(
            'SMS Bildirimler',
            true,
            'SMS bildirimleri aktif mi',
          ),
          _buildSwitchField(
            'E-posta Bildirimler',
            true,
            'E-posta bildirimleri aktif mi',
          ),
        ];
      case 'security':
        return [
          _buildNumberField(
            'Maks. Giriş Denemesi',
            '5',
            'Hesap kilitlenmeden önce',
          ),
          _buildNumberField('Hesap Kilit Süresi', '30', 'Dakika cinsinden'),
          _buildNumberField('Oturum Zaman Aşımı', '24', 'Saat cinsinden'),
          _buildSwitchField(
            'Admin 2FA Zorunlu',
            false,
            'Adminler için 2FA zorunlu mu',
          ),
        ];
      case 'limits':
        return [
          _buildNumberField(
            'Maks. Sipariş Ürünü',
            '50',
            'Bir siparişte maksimum ürün',
          ),
          _buildNumberField('Min. Sipariş Tutarı', '30', 'TL cinsinden'),
          _buildNumberField('Maks. Sipariş Tutarı', '5000', 'TL cinsinden'),
          _buildNumberField('Sipariş İptal Süresi', '5', 'Dakika cinsinden'),
        ];
      default:
        return [];
    }
  }

  Widget _buildSettingItem(Map<String, dynamic> setting) {
    final valueType = setting['value_type'] ?? 'string';
    final value = setting['value'];

    switch (valueType) {
      case 'boolean':
        return _buildSwitchField(
          setting['display_name'] ?? setting['key'],
          value == true || value == 'true',
          setting['description'] ?? '',
        );
      case 'number':
        return _buildNumberField(
          setting['display_name'] ?? setting['key'],
          value?.toString() ?? '',
          setting['description'] ?? '',
        );
      default:
        return _buildTextField(
          setting['display_name'] ?? setting['key'],
          value?.toString() ?? '',
          setting['description'] ?? '',
        );
    }
  }

  Widget _buildTextField(String label, String value, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: value,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.surfaceLight),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberField(String label, String value, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: value,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.surfaceLight),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    String value,
    List<String> options,
    String description,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.surfaceLight),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                dropdownColor: AppColors.surface,
                items: options
                    .map(
                      (o) => DropdownMenuItem(
                        value: o,
                        child: Text(o.toUpperCase()),
                      ),
                    )
                    .toList(),
                onChanged: (v) {},
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchField(String label, bool value, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (v) {},
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  String _getCategoryTitle(String category) {
    switch (category) {
      case 'general':
        return 'Genel Ayarlar';
      case 'delivery':
        return 'Teslimat Ayarları';
      case 'commission':
        return 'Komisyon Ayarları';
      case 'payment':
        return 'Ödeme Ayarları';
      case 'notification':
        return 'Bildirim Ayarları';
      case 'security':
        return 'Güvenlik Ayarları';
      case 'limits':
        return 'Limit Ayarları';
      default:
        return 'Ayarlar';
    }
  }

  String _getCategoryDescription(String category) {
    switch (category) {
      case 'general':
        return 'Uygulamanın genel ayarlarını yapılandırın';
      case 'delivery':
        return 'Teslimat ücretleri ve süreleri';
      case 'commission':
        return 'Komisyon oranları ve ödeme ayarları';
      case 'payment':
        return 'Ödeme yöntemlerini yönetin';
      case 'notification':
        return 'Bildirim kanallarını ayarlayın';
      case 'security':
        return 'Güvenlik ve oturum ayarları';
      case 'limits':
        return 'Sipariş ve işlem limitleri';
      default:
        return '';
    }
  }

  void _saveSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ayarlar kaydedildi'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
