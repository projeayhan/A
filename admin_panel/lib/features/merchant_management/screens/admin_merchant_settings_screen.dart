import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../providers/merchant_management_providers.dart';

class AdminMerchantSettingsScreen extends ConsumerStatefulWidget {
  final String merchantId;

  const AdminMerchantSettingsScreen({
    super.key,
    required this.merchantId,
  });

  @override
  ConsumerState<AdminMerchantSettingsScreen> createState() =>
      _AdminMerchantSettingsScreenState();
}

class _AdminMerchantSettingsScreenState
    extends ConsumerState<AdminMerchantSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isLoaded = false;

  // Profile fields
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Delivery settings
  double _deliveryRadius = 5.0;
  final _minOrderAmountController = TextEditingController();

  // Status
  String _status = 'active';

  // Working hours: 7 days, each with open/close times and closed toggle
  static const List<String> _dayNames = [
    'Pazartesi',
    'Sali',
    'Carsamba',
    'Persembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];

  late List<TimeOfDay> _openingTimes;
  late List<TimeOfDay> _closingTimes;
  late List<bool> _dayClosed;

  @override
  void initState() {
    super.initState();
    _openingTimes = List.generate(7, (_) => const TimeOfDay(hour: 9, minute: 0));
    _closingTimes =
        List.generate(7, (_) => const TimeOfDay(hour: 22, minute: 0));
    _dayClosed = List.generate(7, (_) => false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _minOrderAmountController.dispose();
    super.dispose();
  }

  void _populateFields(Map<String, dynamic> data) {
    if (_isLoaded) return;
    _isLoaded = true;

    _nameController.text = data['name'] as String? ?? '';
    _emailController.text = data['email'] as String? ?? '';
    _phoneController.text = data['phone'] as String? ?? '';
    _addressController.text = data['address'] as String? ?? '';
    _descriptionController.text = data['description'] as String? ?? '';
    _deliveryRadius =
        (data['delivery_radius'] as num?)?.toDouble() ?? 5.0;
    _minOrderAmountController.text =
        (data['min_order_amount'] as num?)?.toString() ?? '0';
    _status = data['status'] as String? ?? 'active';

    // Parse working hours if available
    final workingHours = data['working_hours'];
    if (workingHours is Map<String, dynamic>) {
      for (int i = 0; i < 7; i++) {
        final dayKey = i.toString();
        final dayData = workingHours[dayKey];
        if (dayData is Map<String, dynamic>) {
          _dayClosed[i] = dayData['closed'] == true;
          if (dayData['open'] is String) {
            _openingTimes[i] = _parseTime(dayData['open'] as String);
          }
          if (dayData['close'] is String) {
            _closingTimes[i] = _parseTime(dayData['close'] as String);
          }
        }
      }
    }
  }

  TimeOfDay _parseTime(String time) {
    try {
      final parts = time.split(':');
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    } catch (_) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> _buildWorkingHoursJson() {
    final Map<String, dynamic> result = {};
    for (int i = 0; i < 7; i++) {
      result[i.toString()] = {
        'closed': _dayClosed[i],
        'open': _formatTime(_openingTimes[i]),
        'close': _formatTime(_closingTimes[i]),
      };
    }
    return result;
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final client = ref.read(supabaseProvider);
      await client.from('merchants').update({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'description': _descriptionController.text.trim(),
        'delivery_radius': _deliveryRadius,
        'min_order_amount':
            double.tryParse(_minOrderAmountController.text) ?? 0,
        'status': _status,
        'working_hours': _buildWorkingHoursJson(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.merchantId);

      ref.invalidate(merchantSettingsProvider(widget.merchantId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Ayarlar basariyla kaydedildi'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmStatusChange(String newStatus) async {
    final statusLabels = {
      'active': 'Aktif',
      'inactive': 'Pasif',
      'suspended': 'Askiya Alinmis',
    };

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Durum Degisikligi',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Isletme durumu "${statusLabels[newStatus]}" olarak degistirilecek. Onayliyor musunuz?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _status = newStatus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync =
        ref.watch(merchantSettingsProvider(widget.merchantId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Isletme Ayarlari',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
      ),
      body: settingsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 12),
              Text(
                'Ayarlar yuklenemedi',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(
                    merchantSettingsProvider(widget.merchantId)),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
        data: (data) {
          if (data == null) {
            return const Center(
              child: Text(
                'Isletme bulunamadi',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
            );
          }

          _populateFields(data);

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section 1: Profil Bilgileri
                  _buildSectionCard(
                    title: 'Profil Bilgileri',
                    icon: Icons.store_outlined,
                    children: [
                      _buildTextField(
                        controller: _nameController,
                        label: 'Isletme Adi',
                        icon: Icons.badge_outlined,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Zorunlu alan' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _emailController,
                        label: 'E-posta',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Telefon',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _addressController,
                        label: 'Adres',
                        icon: Icons.location_on_outlined,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'Aciklama',
                        icon: Icons.description_outlined,
                        maxLines: 3,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Section 2: Calisma Saatleri
                  _buildSectionCard(
                    title: 'Calisma Saatleri',
                    icon: Icons.schedule_outlined,
                    children: [
                      _buildWorkingHoursGrid(),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Section 3: Teslimat Bolgesi
                  _buildSectionCard(
                    title: 'Teslimat Bolgesi',
                    icon: Icons.delivery_dining_outlined,
                    children: [
                      // Delivery radius slider
                      Row(
                        children: [
                          const Icon(Icons.radar_outlined,
                              color: AppColors.textSecondary, size: 20),
                          const SizedBox(width: 12),
                          const Text(
                            'Teslimat Yaricapi',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_deliveryRadius.toStringAsFixed(1)} km',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppColors.primary,
                          inactiveTrackColor: AppColors.surfaceLight,
                          thumbColor: AppColors.primary,
                          overlayColor: AppColors.primary.withValues(alpha:0.1),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: _deliveryRadius,
                          min: 1.0,
                          max: 50.0,
                          divisions: 98,
                          onChanged: (v) =>
                              setState(() => _deliveryRadius = v),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _minOrderAmountController,
                        label: 'Minimum Siparis Tutari (TL)',
                        icon: Icons.payments_outlined,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (v) {
                          if (v != null && v.isNotEmpty) {
                            final val = double.tryParse(v);
                            if (val == null || val < 0) {
                              return 'Gecerli bir tutar girin';
                            }
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Section 4: Durum
                  _buildSectionCard(
                    title: 'Durum',
                    icon: Icons.toggle_on_outlined,
                    children: [
                      _buildStatusSelector(),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor:
                            AppColors.primary.withValues(alpha:0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save_outlined, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Kaydet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.surfaceLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.surfaceLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildWorkingHoursGrid() {
    return Column(
      children: List.generate(7, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index < 6 ? 12 : 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceLight, width: 1),
            ),
            child: Row(
              children: [
                // Day name
                SizedBox(
                  width: 100,
                  child: Text(
                    _dayNames[index],
                    style: TextStyle(
                      color: _dayClosed[index]
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Closed toggle
                GestureDetector(
                  onTap: () {
                    setState(() => _dayClosed[index] = !_dayClosed[index]);
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _dayClosed[index]
                          ? AppColors.error.withValues(alpha:0.15)
                          : AppColors.success.withValues(alpha:0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _dayClosed[index]
                            ? AppColors.error.withValues(alpha:0.3)
                            : AppColors.success.withValues(alpha:0.3),
                      ),
                    ),
                    child: Text(
                      _dayClosed[index] ? 'Kapali' : 'Acik',
                      style: TextStyle(
                        color: _dayClosed[index]
                            ? AppColors.error
                            : AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Time pickers
                if (!_dayClosed[index]) ...[
                  _buildTimePicker(
                    time: _openingTimes[index],
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _openingTimes[index],
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppColors.primary,
                                surface: AppColors.surface,
                                onSurface: AppColors.textPrimary,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() => _openingTimes[index] = picked);
                      }
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '-',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 16),
                    ),
                  ),
                  _buildTimePicker(
                    time: _closingTimes[index],
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _closingTimes[index],
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppColors.primary,
                                surface: AppColors.surface,
                                onSurface: AppColors.textPrimary,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() => _closingTimes[index] = picked);
                      }
                    },
                  ),
                ] else
                  const Expanded(
                    child: Text(
                      'Gun kapali',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTimePicker({
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.access_time,
                color: AppColors.textMuted, size: 16),
            const SizedBox(width: 6),
            Text(
              _formatTime(time),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSelector() {
    final statusOptions = [
      {
        'value': 'active',
        'label': 'Aktif',
        'color': AppColors.success,
        'icon': Icons.check_circle_outline,
      },
      {
        'value': 'inactive',
        'label': 'Pasif',
        'color': AppColors.warning,
        'icon': Icons.pause_circle_outline,
      },
      {
        'value': 'suspended',
        'label': 'Askiya Alinmis',
        'color': AppColors.error,
        'icon': Icons.block_outlined,
      },
    ];

    return Row(
      children: statusOptions.map((option) {
        final isSelected = _status == option['value'];
        final color = option['color'] as Color;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: option != statusOptions.last ? 12 : 0,
            ),
            child: InkWell(
              onTap: () {
                if (!isSelected) {
                  _confirmStatusChange(option['value'] as String);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha:0.15)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? color.withValues(alpha:0.5)
                        : AppColors.surfaceLight,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      option['icon'] as IconData,
                      color: isSelected ? color : AppColors.textMuted,
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      option['label'] as String,
                      style: TextStyle(
                        color: isSelected ? color : AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
