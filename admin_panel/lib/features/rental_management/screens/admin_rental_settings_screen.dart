import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

// Provider to fetch rental company details
final _rentalCompanyDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((
      ref,
      companyId,
    ) async {
      final client = ref.watch(supabaseProvider);
      final response = await client
          .from('rental_companies')
          .select('*')
          .eq('id', companyId)
          .maybeSingle();
      return response;
    });

class AdminRentalSettingsScreen extends ConsumerStatefulWidget {
  final String companyId;

  const AdminRentalSettingsScreen({super.key, required this.companyId});

  @override
  ConsumerState<AdminRentalSettingsScreen> createState() =>
      _AdminRentalSettingsScreenState();
}

class _AdminRentalSettingsScreenState
    extends ConsumerState<AdminRentalSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isLoaded = false;

  // Tab 1: Company Info
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  String? _logoUrl;

  // Tab 2: Tax & Commission (commission_rate exists on rental_companies)
  final _taxNumberController = TextEditingController();
  final _taxOfficeController = TextEditingController();
  final _commissionController = TextEditingController();

  // Tab 3: Status & Admin (is_approved, is_active exist on rental_companies)
  bool _isApproved = false;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _taxNumberController.dispose();
    _taxOfficeController.dispose();
    _commissionController.dispose();
    super.dispose();
  }

  void _populateFields(Map<String, dynamic> data) {
    if (_isLoaded) return;
    _isLoaded = true;

    _nameController.text = data['company_name'] as String? ?? '';
    _emailController.text = data['email'] as String? ?? '';
    _phoneController.text = data['phone'] as String? ?? '';
    _addressController.text = data['address'] as String? ?? '';
    _cityController.text = data['city'] as String? ?? '';
    _logoUrl = data['logo_url'] as String?;

    _taxNumberController.text = data['tax_number'] as String? ?? '';
    _taxOfficeController.text = data['tax_office'] as String? ?? '';
    _commissionController.text =
        (data['commission_rate'] as num?)?.toString() ?? '15';

    _isApproved = data['is_approved'] as bool? ?? false;
    _isActive = data['is_active'] as bool? ?? true;
  }

  Future<void> _pickAndUploadLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      setState(() => _isSaving = true);
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() => _isSaving = false);
        return;
      }

      final client = ref.read(supabaseProvider);
      final safeFileName = file.name.replaceAll(
        RegExp(r'[^a-zA-Z0-9._-]'),
        '_',
      );
      final fileName =
          'rental_logo_${widget.companyId}_${DateTime.now().millisecondsSinceEpoch}_$safeFileName';

      await client.storage
          .from('images')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(
              cacheControl: '31536000',
              upsert: true,
            ),
          );

      final imageUrl = client.storage.from('images').getPublicUrl(fileName);
      await client
          .from('rental_companies')
          .update({'logo_url': imageUrl})
          .eq('id', widget.companyId);

      setState(() {
        _logoUrl = imageUrl;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo başarıyla yüklendi'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logo yükleme hatası: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _saveAll() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final client = ref.read(supabaseProvider);

      await client
          .from('rental_companies')
          .update({
            'company_name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'address': _addressController.text.trim(),
            'city': _cityController.text.trim(),
            'tax_number': _taxNumberController.text.trim(),
            'tax_office': _taxOfficeController.text.trim(),
            'commission_rate':
                double.tryParse(_commissionController.text.trim()) ?? 15,
            'is_approved': _isApproved,
            'is_active': _isActive,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.companyId);

      ref.invalidate(_rentalCompanyDetailProvider(widget.companyId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tüm ayarlar başarıyla kaydedildi'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kaydetme hatası: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(
      _rentalCompanyDetailProvider(widget.companyId),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: companyAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                'Hata: $e',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        data: (data) {
          if (data == null) {
            return const Center(
              child: Text(
                'Kiralama şirketi bulunamadı',
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
                    indicatorColor: AppColors.primary,
                    tabs: const [
                      Tab(
                        text: 'Şirket Bilgileri',
                        icon: Icon(Icons.business, size: 18),
                      ),
                      Tab(
                        text: 'Vergi & Komisyon',
                        icon: Icon(Icons.receipt_long, size: 18),
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
                      _buildCompanyInfoTab(),
                      _buildTaxCommissionTab(),
                      _buildStatusAdminTab(),
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
                      label: Text(
                        _isSaving ? 'Kaydediliyor...' : 'Tüm Ayarları Kaydet',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
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

  // ==================== TAB 1: ŞİRKET BİLGİLERİ ====================
  Widget _buildCompanyInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          _buildSectionCard(
            title: 'Şirket Logosu',
            icon: Icons.image_outlined,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: _pickAndUploadLogo,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.surfaceLight),
                      ),
                      child: _logoUrl != null && _logoUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _logoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.business,
                                  size: 40,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.add_a_photo,
                              size: 32,
                              color: AppColors.textMuted,
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Logo Yükle',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'PNG, JPG formatında, max 2MB',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _pickAndUploadLogo,
                          icon: const Icon(Icons.upload, size: 16),
                          label: const Text('Yükle'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Company Details
          _buildSectionCard(
            title: 'Temel Bilgiler',
            icon: Icons.business_outlined,
            children: [
              _buildTextField(
                controller: _nameController,
                label: 'Şirket Adı',
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
        ],
      ),
    );
  }

  // ==================== TAB 2: VERGİ & KOMİSYON ====================
  Widget _buildTaxCommissionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildSectionCard(
            title: 'Vergi Bilgileri',
            icon: Icons.account_balance_outlined,
            children: [
              _buildTextField(
                controller: _taxNumberController,
                label: 'Vergi No',
                icon: Icons.badge_outlined,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _taxOfficeController,
                label: 'Vergi Dairesi',
                icon: Icons.account_balance_outlined,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionCard(
            title: 'Komisyon Ayarları',
            icon: Icons.percent_outlined,
            children: [
              _buildTextField(
                controller: _commissionController,
                label: 'Platform Komisyon Oranı (%)',
                icon: Icons.percent_outlined,
                keyboardType: TextInputType.number,
                hint: 'Varsayılan: 15',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppColors.info,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Komisyon oranı, şirketin her kiralama işleminden platforma ödeyeceği yüzdeyi belirler.',
                        style: TextStyle(
                          color: AppColors.info.withValues(alpha: 0.9),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== TAB 3: DURUM & ADMİN ====================
  Widget _buildStatusAdminTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Approval Status
          _buildSectionCard(
            title: 'Onay Durumu',
            icon: Icons.verified_outlined,
            children: [_buildApprovalSelector()],
          ),
          const SizedBox(height: 24),

          // Active/Inactive
          _buildSectionCard(
            title: 'Şirket Durumu',
            icon: Icons.toggle_on_outlined,
            children: [
              SwitchListTile(
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                title: Text(
                  _isActive ? 'Aktif' : 'Pasif',
                  style: TextStyle(
                    color: _isActive ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                subtitle: Text(
                  _isActive
                      ? 'Şirket platformda aktif olarak görünüyor'
                      : 'Şirket platformda görünmüyor',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.success,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalSelector() {
    final options = [
      {
        'value': true,
        'label': 'Onaylı',
        'color': AppColors.success,
        'icon': Icons.check_circle_outline,
        'description': 'Şirket onaylanmış, platformda aktif.',
      },
      {
        'value': false,
        'label': 'Onay Bekliyor',
        'color': AppColors.warning,
        'icon': Icons.hourglass_empty_outlined,
        'description': 'Şirket henüz onaylanmamış.',
      },
    ];

    return Row(
      children: options.map((option) {
        final isSelected = _isApproved == option['value'];
        final color = option['color'] as Color;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: option != options.last ? 12 : 0),
            child: InkWell(
              onTap: () =>
                  setState(() => _isApproved = option['value'] as bool),
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
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      option['description'] as String,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
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
