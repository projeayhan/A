import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/taxi_service.dart';
import '../../core/theme/app_theme.dart';
import 'profile_screen.dart';

class VehicleInfoScreen extends ConsumerStatefulWidget {
  const VehicleInfoScreen({super.key});

  @override
  ConsumerState<VehicleInfoScreen> createState() => _VehicleInfoScreenState();
}

class _VehicleInfoScreenState extends ConsumerState<VehicleInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  final _plateController = TextEditingController();

  String _selectedType = 'standard';
  bool _isEditing = false;
  bool _isSaving = false;

  final Map<String, Map<String, String>> _vehicleTypes = {
    'standard': {
      'label': 'Standart',
      'description': '4 kisilik sedan araclar',
      'icon': '\u{1F697}',
    },
    'comfort': {
      'label': 'Konfor',
      'description': 'Premium markalar',
      'icon': '\u{1F698}',
    },
    'xl': {
      'label': 'XL',
      'description': '6+ kisilik araclar',
      'icon': '\u{1F690}',
    },
  };

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  void _populateFields(Map<String, dynamic> profile) {
    _brandController.text = profile['vehicle_brand'] ?? '';
    _modelController.text = profile['vehicle_model'] ?? '';
    _yearController.text = (profile['vehicle_year'] ?? '').toString();
    _colorController.text = profile['vehicle_color'] ?? '';
    _plateController.text = profile['vehicle_plate'] ?? '';
    _selectedType = profile['vehicle_type'] ?? 'standard';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final success = await TaxiService.updateDriverProfile({
      'vehicle_brand': _brandController.text.trim(),
      'vehicle_model': _modelController.text.trim(),
      'vehicle_year': int.tryParse(_yearController.text.trim()) ?? 2020,
      'vehicle_color': _colorController.text.trim(),
      'vehicle_plate': _plateController.text.trim().toUpperCase(),
      'vehicle_type': _selectedType,
    });

    setState(() {
      _isSaving = false;
      if (success) _isEditing = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Arac bilgileri guncellendi' : 'Guncelleme basarisiz'),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
      if (success) ref.invalidate(profileProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Arac Bilgileri'),
        actions: [
          IconButton(
            onPressed: () {
              if (_isEditing) {
                _save();
              } else {
                setState(() => _isEditing = true);
              }
            },
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_isEditing ? Icons.check : Icons.edit_outlined),
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profil bulunamadi'));
          }
          if (!_isEditing && _brandController.text.isEmpty) {
            _populateFields(profile);
          }
          return _buildContent(context, profile);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vehicle header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.directions_car, color: AppColors.secondary, size: 32),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${profile['vehicle_brand'] ?? ''} ${profile['vehicle_model'] ?? ''}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile['vehicle_plate'] ?? '',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Vehicle type selector
            Text(
              'Arac Kategorisi',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ..._vehicleTypes.entries.map((entry) => _buildVehicleTypeOption(
                  entry.key,
                  entry.value['label']!,
                  entry.value['description']!,
                  entry.value['icon']!,
                )),

            const SizedBox(height: 24),

            // Form fields
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildField(
                    controller: _brandController,
                    label: 'Marka',
                    icon: Icons.directions_car_outlined,
                    enabled: _isEditing,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Marka gerekli' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    controller: _modelController,
                    label: 'Model',
                    icon: Icons.car_rental_outlined,
                    enabled: _isEditing,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Model gerekli' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildField(
                          controller: _yearController,
                          label: 'Model Yili',
                          icon: Icons.calendar_today_outlined,
                          enabled: _isEditing,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Yil gerekli';
                            final year = int.tryParse(v);
                            if (year == null || year < 2000 || year > DateTime.now().year + 1) {
                              return 'Gecerli yil girin';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildField(
                          controller: _colorController,
                          label: 'Renk',
                          icon: Icons.palette_outlined,
                          enabled: _isEditing,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Renk gerekli' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    controller: _plateController,
                    label: 'Plaka',
                    icon: Icons.pin_outlined,
                    enabled: _isEditing,
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Plaka gerekli' : null,
                  ),
                ],
              ),
            ),

            if (_isEditing) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.secondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Kaydet',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleTypeOption(String key, String label, String description, String icon) {
    final isSelected = _selectedType == key;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: _isEditing
            ? () => setState(() => _selectedType = key)
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? AppColors.secondary : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool enabled,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        filled: true,
        fillColor: enabled ? AppColors.surface : AppColors.background,
      ),
    );
  }
}
