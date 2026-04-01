import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

// ==================== PROVIDER ====================

final realtorDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>(
  (ref, realtorId) async {
    final client = ref.watch(supabaseProvider);
    final response = await client
        .from('realtors')
        .select()
        .eq('id', realtorId)
        .maybeSingle();
    return response;
  },
);

// ==================== SCREEN ====================

class AdminRealtorSettingsScreen extends ConsumerStatefulWidget {
  final String realtorId;

  const AdminRealtorSettingsScreen({
    super.key,
    required this.realtorId,
  });

  @override
  ConsumerState<AdminRealtorSettingsScreen> createState() =>
      _AdminRealtorSettingsScreenState();
}

class _AdminRealtorSettingsScreenState
    extends ConsumerState<AdminRealtorSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isLoaded = false;

  // Profile fields (all valid DB columns on realtors table)
  final _companyNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _bioController = TextEditingController();

  // Notifications (notifications_enabled is valid DB column)
  bool _notificationsEnabled = true;

  // Status & Admin (status is valid DB column)
  String _approvalStatus = 'pending';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _companyNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _licenseNumberController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _populateFields(Map<String, dynamic> data) {
    if (_isLoaded) return;
    _isLoaded = true;

    _companyNameController.text = data['company_name'] as String? ?? '';
    _emailController.text = data['email'] as String? ?? '';
    _phoneController.text = data['phone'] as String? ?? '';
    _cityController.text = data['city'] as String? ?? '';
    _licenseNumberController.text = data['license_number'] as String? ?? '';
    _bioController.text = data['bio'] as String? ?? '';

    // Notifications
    _notificationsEnabled = data['notifications_enabled'] as bool? ?? true;

    // Status
    _approvalStatus = data['status'] as String? ?? 'pending';
  }

  Future<void> _saveAll() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final client = ref.read(supabaseProvider);

      await client.from('realtors').update({
        'company_name': _companyNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'city': _cityController.text.trim(),
        'license_number': _licenseNumberController.text.trim(),
        'bio': _bioController.text.trim(),
        'notifications_enabled': _notificationsEnabled,
        'status': _approvalStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.realtorId);

      // Reset loaded flag so next watch refresh picks up new data
      _isLoaded = false;
      ref.invalidate(realtorDetailProvider(widget.realtorId));

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
    final realtorAsync = ref.watch(realtorDetailProvider(widget.realtorId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: realtorAsync.when(
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
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () =>
                    ref.invalidate(realtorDetailProvider(widget.realtorId)),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Tekrar Dene'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        data: (data) {
          if (data == null) {
            return const Center(
              child: Text(
                'Emlakci bulunamadi',
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
                        bottom: BorderSide(color: AppColors.surfaceLight)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.textMuted,
                    indicatorColor: AppColors.primary,
                    tabs: const [
                      Tab(
                        text: 'Profil Bilgileri',
                        icon: Icon(Icons.person_outlined, size: 18),
                      ),
                      Tab(
                        text: 'Bildirimler',
                        icon: Icon(Icons.notifications_outlined, size: 18),
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
                      _buildProfileTab(),
                      _buildNotificationsTab(),
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
                        top: BorderSide(color: AppColors.surfaceLight)),
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
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save, size: 20),
                      label: Text(
                        _isSaving
                            ? 'Kaydediliyor...'
                            : 'Tüm Ayarları Kaydet',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
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

  // ==================== TAB 1: PROFİL BİLGİLERİ ====================

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            title: 'Temel Bilgiler',
            icon: Icons.business_outlined,
            children: [
              _buildTextField(
                controller: _companyNameController,
                label: 'Firma Adi',
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
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _cityController,
                      label: 'Sehir',
                      icon: Icons.location_city_outlined,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _licenseNumberController,
                      label: 'Lisans No',
                      icon: Icons.verified_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _bioController,
                label: 'Hakkinda / Bio',
                icon: Icons.info_outline,
                maxLines: 4,
                hint: 'Emlakci hakkinda kisa bilgi...',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== TAB 2: BİLDİRİMLER ====================

  Widget _buildNotificationsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _buildSectionCard(
        title: 'Bildirim Ayarlari',
        icon: Icons.notifications_outlined,
        children: [
          _buildNotificationTile(
            'Bildirimler',
            'Bildirimleri etkinlestir/devre disi birak',
            _notificationsEnabled,
            (v) => setState(() => _notificationsEnabled = v),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: Text(title,
            style: const TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle,
            style:
                const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        contentPadding: EdgeInsets.zero,
        activeThumbColor: AppColors.success,
      ),
    );
  }

  // ==================== TAB 3: DURUM & ADMİN ====================

  Widget _buildStatusTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Approval Status
          _buildSectionCard(
            title: 'Onay Durumu',
            icon: Icons.verified_outlined,
            children: [
              _buildApprovalSelector(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalSelector() {
    final options = [
      {
        'value': 'approved',
        'label': 'Onayli',
        'color': AppColors.success,
        'icon': Icons.check_circle_outline,
        'description': 'Emlakci onayli, ilan verebilir.',
      },
      {
        'value': 'pending',
        'label': 'Onay Bekliyor',
        'color': AppColors.warning,
        'icon': Icons.hourglass_empty_outlined,
        'description': 'Basvuru henuz degerlendirilmedi.',
      },
      {
        'value': 'under_review',
        'label': 'Inceleniyor',
        'color': AppColors.info,
        'icon': Icons.search_outlined,
        'description': 'Basvuru inceleme asamasinda.',
      },
      {
        'value': 'rejected',
        'label': 'Reddedildi',
        'color': AppColors.error,
        'icon': Icons.cancel_outlined,
        'description': 'Basvuru reddedildi.',
      },
      {
        'value': 'suspended',
        'label': 'Askiya Alindi',
        'color': AppColors.error,
        'icon': Icons.block_outlined,
        'description': 'Hesap askiya alindi.',
      },
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: options.map((option) {
        final isSelected = _approvalStatus == option['value'];
        final color = option['color'] as Color;

        return InkWell(
          onTap: () => setState(() => _approvalStatus = option['value'] as String),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 180,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
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
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  option['description'] as String,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (isSelected) ...[
                  const SizedBox(height: 6),
                  Icon(Icons.check, color: color, size: 16),
                ],
              ],
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
