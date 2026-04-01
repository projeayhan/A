import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

/// Provider to fetch dealer data from car_dealers table
final _dealerSettingsProvider =
    FutureProvider.family<Map<String, dynamic>?, String>(
  (ref, dealerId) async {
    final client = ref.watch(supabaseProvider);
    final response = await client
        .from('car_dealers')
        .select()
        .eq('id', dealerId)
        .maybeSingle();
    return response;
  },
);

class AdminDealerSettingsScreen extends ConsumerStatefulWidget {
  final String dealerId;

  const AdminDealerSettingsScreen({
    super.key,
    required this.dealerId,
  });

  @override
  ConsumerState<AdminDealerSettingsScreen> createState() =>
      _AdminDealerSettingsScreenState();
}

class _AdminDealerSettingsScreenState
    extends ConsumerState<AdminDealerSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isLoaded = false;

  // Tab 1: Bayi Bilgileri
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();

  // Location (latitude/longitude exist on car_dealers)
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  // Tab 2: Durum & Admin
  // is_verified and status are valid DB columns
  bool _isVerified = false;
  String _status = 'active';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  void _populateFields(Map<String, dynamic> data) {
    if (_isLoaded) return;
    _isLoaded = true;

    _nameController.text = data['business_name'] as String? ?? '';
    _emailController.text = data['email'] as String? ?? '';
    _phoneController.text = data['phone'] as String? ?? '';
    _addressController.text = data['address'] as String? ?? '';
    _cityController.text = data['city'] as String? ?? '';

    _isVerified = data['is_verified'] as bool? ?? false;
    _status = data['status'] as String? ?? 'active';

    _latitudeController.text = data['latitude']?.toString() ?? '';
    _longitudeController.text = data['longitude']?.toString() ?? '';
  }

  Future<void> _saveAll() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final client = ref.read(supabaseProvider);

      await client.from('car_dealers').update({
        'business_name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'is_verified': _isVerified,
        'status': _status,
        'latitude': double.tryParse(_latitudeController.text.trim()),
        'longitude': double.tryParse(_longitudeController.text.trim()),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.dealerId);

      ref.invalidate(_dealerSettingsProvider(widget.dealerId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Tüm ayarlar başarıyla kaydedildi'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dealerAsync = ref.watch(_dealerSettingsProvider(widget.dealerId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: dealerAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Hata: $e',
                  style: const TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
        data: (data) {
          if (data == null) {
            return const Center(
              child: Text(
                'Bayi bulunamadı',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }
          _populateFields(data);

          return Form(
            key: _formKey,
            child: Column(
              children: [
                // Tab bar
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      bottom: BorderSide(color: AppColors.surfaceLight),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.textMuted,
                    tabs: const [
                      Tab(
                        text: 'Bayi Bilgileri',
                        icon: Icon(Icons.store, size: 18),
                      ),
                      Tab(
                        text: 'Durum & Admin',
                        icon: Icon(Icons.admin_panel_settings, size: 18),
                      ),
                    ],
                  ),
                ),
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDealerInfoTab(),
                      _buildStatusTab(),
                    ],
                  ),
                ),
                // Save button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      top: BorderSide(color: AppColors.surfaceLight),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveAll,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save, size: 20),
                      label: const Text(
                        'Tüm Ayarları Kaydet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==================== TAB 1: BAYİ BİLGİLERİ ====================
  Widget _buildDealerInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: 'Temel Bilgiler',
            icon: Icons.store_outlined,
            children: [
              _buildTextField(
                controller: _nameController,
                label: 'İşletme Adı',
                icon: Icons.badge_outlined,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Zorunlu alan' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _emailController,
                      label: 'E-posta',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _phoneController,
                      label: 'Telefon',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
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
                controller: _cityController,
                label: 'Şehir',
                icon: Icons.location_city_outlined,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Location
          _buildLocationSection(),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    final lat = double.tryParse(_latitudeController.text) ?? 0;
    final lng = double.tryParse(_longitudeController.text) ?? 0;
    final hasValidCoords = lat != 0 && lng != 0;

    return _buildSectionCard(
      title: 'Konum',
      icon: Icons.location_on,
      children: [
        if (hasValidCoords) ...[
          SizedBox(
            height: 250,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(lat, lng),
                  zoom: 16,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('business'),
                    position: LatLng(lat, lng),
                  ),
                },
                zoomControlsEnabled: true,
                mapToolbarEnabled: false,
                myLocationButtonEnabled: false,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _latitudeController,
                label: 'Enlem',
                icon: Icons.explore,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: _longitudeController,
                label: 'Boylam',
                icon: Icons.explore,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==================== TAB 2: DURUM & ADMİN ====================
  Widget _buildStatusTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Verification Status
          _buildSectionCard(
            title: 'Doğrulama Durumu',
            icon: Icons.verified_outlined,
            children: [
              _buildVerificationSelector(),
            ],
          ),
          const SizedBox(height: 24),

          // Status selector
          _buildSectionCard(
            title: 'Bayi Durumu',
            icon: Icons.toggle_on_outlined,
            children: [
              _buildStatusSelector(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationSelector() {
    final options = [
      {
        'value': true,
        'label': 'Doğrulanmış',
        'color': AppColors.success,
        'icon': Icons.check_circle_outline,
      },
      {
        'value': false,
        'label': 'Doğrulanmamış',
        'color': AppColors.warning,
        'icon': Icons.hourglass_empty_outlined,
      },
    ];

    return Row(
      children: options.map((option) {
        final isSelected = _isVerified == option['value'];
        final color = option['color'] as Color;

        return Expanded(
          child: Padding(
            padding:
                EdgeInsets.only(right: option != options.last ? 12 : 0),
            child: InkWell(
              onTap: () =>
                  setState(() => _isVerified = option['value'] as bool),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.15)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? color.withValues(alpha: 0.5)
                        : AppColors.surfaceLight,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      option['icon'] as IconData,
                      color: isSelected ? color : AppColors.textMuted,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      option['label'] as String,
                      style: TextStyle(
                        color: isSelected ? color : AppColors.textSecondary,
                        fontSize: 14,
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

  Widget _buildStatusSelector() {
    final statusOptions = [
      {'value': 'active', 'label': 'Aktif', 'color': AppColors.success},
      {'value': 'inactive', 'label': 'Pasif', 'color': AppColors.warning},
      {'value': 'suspended', 'label': 'Askıda', 'color': AppColors.error},
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: statusOptions.map((option) {
        final isSelected = _status == option['value'];
        final color = option['color'] as Color;

        return InkWell(
          onTap: () => setState(() => _status = option['value'] as String),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.15)
                  : AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? color.withValues(alpha: 0.5)
                    : AppColors.surfaceLight,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Text(
              option['label'] as String,
              style: TextStyle(
                color: isSelected ? color : AppColors.textSecondary,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ==================== SHARED WIDGETS ====================
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
        border: Border.all(color: AppColors.surfaceLight),
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
    String? hint,
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
        hintText: hint,
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
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textMuted),
      ),
    );
  }
}
