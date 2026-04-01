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

// Company settings provider
final companySettingsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase.from('company_settings').select().limit(1).maybeSingle();
  return response;
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
    {'id': 'company', 'name': 'Şirket Bilgileri', 'icon': Icons.business},
    {'id': 'invoice', 'name': 'Fatura', 'icon': Icons.receipt_long},
    {'id': 'general', 'name': 'Genel', 'icon': Icons.settings},
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
                      child: _selectedCategory == 'company'
                          ? _buildCompanySettingsPanel(textPrimary, textSecondary, textMuted, bgColor)
                          : _selectedCategory == 'invoice'
                          ? _buildInvoiceSettingsPanel(textPrimary, textSecondary, textMuted, bgColor)
                          : settingsAsync.when(
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

  Widget _buildCompanySettingsPanel(Color textPrimary, Color textSecondary, Color textMuted, Color bgColor) {
    final companyAsync = ref.watch(companySettingsProvider);
    return companyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e', style: TextStyle(color: textMuted))),
      data: (data) => _CompanySettingsForm(
        initialData: data,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        textMuted: textMuted,
        bgColor: bgColor,
        onSaved: () => ref.invalidate(companySettingsProvider),
      ),
    );
  }

  Widget _buildInvoiceSettingsPanel(Color textPrimary, Color textSecondary, Color textMuted, Color bgColor) {
    final companyAsync = ref.watch(companySettingsProvider);
    return companyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e', style: TextStyle(color: textMuted))),
      data: (data) => _InvoiceSettingsForm(
        initialData: data,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        bgColor: bgColor,
        onSaved: () => ref.invalidate(companySettingsProvider),
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
      'general': {'app_name': 'SuperCyp', 'support_email': '', 'support_phone': ''},

      'payment': {'cash_payment_enabled': 'true', 'online_payment_enabled': 'true', 'card_on_delivery_enabled': 'true'},
      'notification': {'push_notifications_enabled': 'true', 'sms_notifications_enabled': 'true', 'email_notifications_enabled': 'true'},
      'security': {'max_login_attempts': '5', 'account_lock_duration': '30', 'session_timeout_hours': '24', 'admin_2fa_required': 'false'},
      'limits': {'max_order_items': '50', 'min_order_amount': '30', 'max_order_amount': '5000', 'order_cancel_time': '5'},
    };
    final defaults = allDefaults[category] ?? <String, String>{};

    return defaults.entries.map((e) {
      final isBoolean = e.value == 'true' || e.value == 'false';
      final isNumber = num.tryParse(e.value) != null;
      final currentValue = _changedValues.containsKey(e.key) ? _changedValues[e.key] : e.value;

      final desc = _keyDescriptions[e.key] ?? '';
      if (isBoolean) {
        return _buildSwitchField(
          _humanizeKey(e.key), desc, currentValue == true || currentValue == 'true',
          textPrimary, textMuted,
          (v) => setState(() => _changedValues[e.key] = v),
        );
      } else if (isNumber) {
        return _buildNumberField(
          _humanizeKey(e.key), desc, currentValue?.toString() ?? e.value,
          textPrimary, textMuted, bgColor,
          (v) => setState(() => _changedValues[e.key] = num.tryParse(v) ?? v),
        );
      } else {
        return _buildTextField(
          _humanizeKey(e.key), desc, currentValue?.toString() ?? e.value,
          textPrimary, textMuted, bgColor,
          (v) => setState(() => _changedValues[e.key] = v),
        );
      }
    }).toList();
  }

  static const _keyLabels = {
    'cash_payment_enabled': 'Nakit Ödeme',
    'online_payment_enabled': 'Online Ödeme',
    'card_on_delivery_enabled': 'Kapıda Kart',
  };

  static const _keyDescriptions = {
    'cash_payment_enabled': 'Nakit ödeme aktif mi',
    'online_payment_enabled': 'Online ödeme aktif mi',
    'card_on_delivery_enabled': 'Kapıda kart ödeme aktif mi',
  };

  String _humanizeKey(String key) {
    if (_keyLabels.containsKey(key)) return _keyLabels[key]!;
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
      case 'delivery': return 'Teslimat Ayarları'; // unused
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
      case 'delivery': return 'Teslimat ücretleri ve süreleri'; // unused
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

class _CompanySettingsForm extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialData;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color bgColor;
  final VoidCallback onSaved;

  const _CompanySettingsForm({
    required this.initialData,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.bgColor,
    required this.onSaved,
  });

  @override
  ConsumerState<_CompanySettingsForm> createState() => _CompanySettingsFormState();
}

class _CompanySettingsFormState extends ConsumerState<_CompanySettingsForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _taxOffice;
  late final TextEditingController _taxNumber;
  late final TextEditingController _website;
  late final TextEditingController _invoicePrefix;
  late final TextEditingController _kdvRate;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData ?? {};
    _name = TextEditingController(text: d['name'] ?? '');
    _address = TextEditingController(text: d['address'] ?? '');
    _phone = TextEditingController(text: d['phone'] ?? '');
    _email = TextEditingController(text: d['email'] ?? '');
    _taxOffice = TextEditingController(text: d['tax_office'] ?? '');
    _taxNumber = TextEditingController(text: d['tax_number'] ?? '');
    _website = TextEditingController(text: d['website'] ?? '');
    _invoicePrefix = TextEditingController(text: d['invoice_prefix'] ?? 'ODB');
    _kdvRate = TextEditingController(text: (d['kdv_rate'] ?? 10.0).toString());
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _email.dispose();
    _taxOffice.dispose();
    _taxNumber.dispose();
    _website.dispose();
    _invoicePrefix.dispose();
    _kdvRate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final supabase = ref.read(supabaseProvider);
      final payload = {
        'name': _name.text.trim(),
        'address': _address.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'tax_office': _taxOffice.text.trim(),
        'tax_number': _taxNumber.text.trim(),
        'website': _website.text.trim(),
        'invoice_prefix': _invoicePrefix.text.trim(),
        'kdv_rate': double.tryParse(_kdvRate.text.trim()) ?? 10.0,
        'updated_at': DateTime.now().toIso8601String(),
      };
      final existing = widget.initialData;
      if (existing != null && existing['id'] != null) {
        await supabase.from('company_settings').update(payload).eq('id', existing['id']);
      } else {
        await supabase.from('company_settings').insert(payload);
      }
      if (!mounted) return;
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şirket bilgileri kaydedildi'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kaydetme hatası: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Şirket Bilgileri', style: TextStyle(color: widget.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Faturalarda görünecek şirket ve vergi bilgilerini girin', style: TextStyle(color: widget.textSecondary, fontSize: 14)),
            const SizedBox(height: 32),
            _field('Şirket Adı', _name, required: true),
            _field('Adres', _address, required: true, maxLines: 3),
            Row(
              children: [
                Expanded(child: _field('Telefon', _phone)),
                const SizedBox(width: 16),
                Expanded(child: _field('E-posta', _email)),
              ],
            ),
            Row(
              children: [
                Expanded(child: _field('Vergi Dairesi', _taxOffice, required: true)),
                const SizedBox(width: 16),
                Expanded(child: _field('Vergi Numarası', _taxNumber, required: true)),
              ],
            ),
            Row(
              children: [
                Expanded(child: _field('Web Sitesi', _website)),
                const SizedBox(width: 16),
                Expanded(
                  child: _field(
                    'Fatura Prefix',
                    _invoicePrefix,
                    required: true,
                    hint: 'Örn: ODB → ODB202603-000001',
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _field(
                    'Platform KDV Oranı (%)',
                    _kdvRate,
                    required: true,
                    hint: 'Komisyon üzerinden uygulanacak KDV oranı',
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(child: SizedBox()),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Kaydet'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {bool required = false, int maxLines = 1, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: widget.textPrimary, fontWeight: FontWeight.w500, fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: ctrl,
            maxLines: maxLines,
            style: TextStyle(color: widget.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: widget.textMuted, fontSize: 12),
              filled: true,
              fillColor: widget.bgColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.surfaceLight)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
              errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.error)),
              focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.error)),
            ),
            validator: required ? (v) => (v == null || v.trim().isEmpty) ? '$label zorunludur' : null : null,
          ),
        ],
      ),
    );
  }
}

// ── Fatura Ayarları Formu ──────────────────────────────────────

class _InvoiceSettingsForm extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialData;
  final Color textPrimary;
  final Color textSecondary;
  final Color bgColor;
  final VoidCallback onSaved;

  const _InvoiceSettingsForm({
    required this.initialData,
    required this.textPrimary,
    required this.textSecondary,
    required this.bgColor,
    required this.onSaved,
  });

  @override
  ConsumerState<_InvoiceSettingsForm> createState() => _InvoiceSettingsFormState();
}

class _InvoiceSettingsFormState extends ConsumerState<_InvoiceSettingsForm> {
  bool _isSaving = false;
  bool _autoEnabled = false;
  int _autoDay = 1;
  String? _lastDate;
  late TextEditingController _kdvCtrl;
  late TextEditingController _prefixCtrl;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData ?? {};
    _autoEnabled = d['auto_invoice_enabled'] == true;
    final rawDay = (d['auto_invoice_day'] as int?) ?? 1;
    _autoDay = rawDay.clamp(1, 28);
    _lastDate = d['last_auto_invoice_date']?.toString();
    _kdvCtrl = TextEditingController(text: (d['kdv_rate'] ?? 16).toString());
    _prefixCtrl = TextEditingController(text: d['invoice_prefix'] ?? 'ODB');
  }

  @override
  void dispose() {
    _kdvCtrl.dispose();
    _prefixCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final supabase = ref.read(supabaseProvider);
      final existing = widget.initialData;
      final payload = {
        'auto_invoice_enabled': _autoEnabled,
        'auto_invoice_day': _autoDay,
        'kdv_rate': double.tryParse(_kdvCtrl.text.trim()) ?? 16,
        'invoice_prefix': _prefixCtrl.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (existing != null && existing['id'] != null) {
        await supabase.from('company_settings').update(payload).eq('id', existing['id']);
      }
      if (!mounted) return;
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fatura ayarları kaydedildi'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Fatura Ayarları', style: TextStyle(color: widget.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('KDV oranı, fatura numaralama ve otomatik fatura oluşturma ayarları', style: TextStyle(color: widget.textSecondary, fontSize: 14)),
          const SizedBox(height: 32),

          // KDV ve Prefix
          Row(
            children: [
              SizedBox(
                width: 200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Platform KDV Oranı (%)', style: TextStyle(color: widget.textPrimary, fontWeight: FontWeight.w500, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _kdvCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: widget.textPrimary),
                      decoration: InputDecoration(
                        filled: true, fillColor: widget.bgColor,
                        hintText: 'Örn: 16',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: 200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fatura Numarası Prefix', style: TextStyle(color: widget.textPrimary, fontWeight: FontWeight.w500, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _prefixCtrl,
                      style: TextStyle(color: widget.textPrimary),
                      decoration: InputDecoration(
                        filled: true, fillColor: widget.bgColor,
                        hintText: 'Örn: ODB',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 24),

          // Otomatik Fatura
          Text('Otomatik Fatura Oluşturma', style: TextStyle(color: widget.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Aktif olduğunda, her ay belirlediğiniz günde önceki ayın tüm komisyon faturaları otomatik oluşturulur.', style: TextStyle(color: widget.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Toggle
              SizedBox(
                width: 250,
                child: SwitchListTile(
                  title: Text('Otomatik Fatura', style: TextStyle(color: widget.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    _autoEnabled ? 'Aktif — Her ayın ${_autoDay}\'inde çalışır' : 'Kapalı',
                    style: TextStyle(color: _autoEnabled ? AppColors.success : widget.textSecondary, fontSize: 12),
                  ),
                  value: _autoEnabled,
                  onChanged: (v) => setState(() => _autoEnabled = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ),

              if (_autoEnabled) ...[
                const SizedBox(width: 32),
                // Gün seçimi
                SizedBox(
                  width: 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fatura Günü', style: TextStyle(color: widget.textPrimary, fontWeight: FontWeight.w500, fontSize: 13)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: widget.bgColor, borderRadius: BorderRadius.circular(10)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _autoDay,
                            isExpanded: true,
                            style: TextStyle(color: widget.textPrimary, fontSize: 14),
                            items: List.generate(28, (i) => DropdownMenuItem(value: i + 1, child: Text('Her ayın ${i + 1}\'i'))),
                            onChanged: (v) => setState(() => _autoDay = v ?? 1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 32),
                // Son oluşturma tarihi
                if (_lastDate != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.success.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Son Otomatik Fatura', style: TextStyle(color: widget.textSecondary, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(_lastDate!, style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                  ),
              ],
            ],
          ),

          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
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
}
