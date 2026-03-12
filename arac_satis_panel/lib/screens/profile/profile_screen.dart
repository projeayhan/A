import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/car_models.dart';
import '../../providers/dealer_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _ownerNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _businessNameController;
  late TextEditingController _taxNumberController;
  late TextEditingController _addressController;
  String? _selectedCity;
  bool _isSaving = false;
  bool _isInitialized = false;

  static const List<String> _kktcCities = [
    'Lefkosa',
    'Gazimagusa',
    'Girne',
    'Guzelyurt',
    'Iskele',
    'Lefke',
    'Yenibogazici',
    'Mehmetcik',
    'Dipkarpaz',
    'Gecitkale',
    'Alsancak',
    'Lapta',
    'Catalkoy',
    'Karakum',
  ];

  @override
  void initState() {
    super.initState();
    _ownerNameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _businessNameController = TextEditingController();
    _taxNumberController = TextEditingController();
    _addressController = TextEditingController();
  }

  @override
  void dispose() {
    _ownerNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _businessNameController.dispose();
    _taxNumberController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _initFromProfile(CarDealer profile) {
    if (_isInitialized) return;
    _isInitialized = true;
    _ownerNameController.text = profile.ownerName;
    _phoneController.text = profile.phone;
    _emailController.text = profile.email ?? '';
    _businessNameController.text = profile.businessName ?? '';
    _taxNumberController.text = profile.taxNumber ?? '';
    _addressController.text = profile.address ?? '';
    _selectedCity = profile.city;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileAsync = ref.watch(dealerProfileProvider);

    return profileAsync.when(
      data: (profile) {
        if (profile == null) {
          return Center(
            child: Text(
              'Profil bulunamadi.',
              style: TextStyle(color: CarSalesColors.textSecondary(isDark)),
            ),
          );
        }

        _initFromProfile(profile);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Header
                _buildProfileHeader(isDark, profile),
                const SizedBox(height: 24),

                // Stats Row
                _buildStatsRow(isDark, profile),
                const SizedBox(height: 32),

                // Kisisel Bilgiler
                _buildSectionTitle('Kisisel Bilgiler', isDark),
                const SizedBox(height: 16),
                _buildCard(isDark, [
                  _buildTextField(
                    controller: _ownerNameController,
                    label: 'Ad Soyad',
                    icon: Icons.person_outline,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Telefon',
                    icon: Icons.phone_outlined,
                    isDark: isDark,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _emailController,
                    label: 'E-posta',
                    icon: Icons.email_outlined,
                    isDark: isDark,
                    readOnly: true,
                    keyboardType: TextInputType.emailAddress,
                  ),
                ]),
                const SizedBox(height: 24),

                // Isletme Bilgileri
                _buildSectionTitle('Isletme Bilgileri', isDark),
                const SizedBox(height: 16),
                _buildCard(isDark, [
                  _buildTextField(
                    controller: _businessNameController,
                    label: 'Isletme Adi',
                    icon: Icons.business_outlined,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _taxNumberController,
                    label: 'Vergi Numarasi',
                    icon: Icons.receipt_long_outlined,
                    isDark: isDark,
                    keyboardType: TextInputType.number,
                  ),
                ]),
                const SizedBox(height: 24),

                // Konum
                _buildSectionTitle('Konum', isDark),
                const SizedBox(height: 16),
                _buildCard(isDark, [
                  // City dropdown
                  DropdownButtonFormField<String>(
                    value: _kktcCities.contains(_selectedCity)
                        ? _selectedCity
                        : null,
                    decoration: InputDecoration(
                      labelText: 'Sehir',
                      prefixIcon: const Icon(Icons.location_city_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    dropdownColor: CarSalesColors.card(isDark),
                    items: _kktcCities.map((city) {
                      return DropdownMenuItem(
                        value: city,
                        child: Text(city),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedCity = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _addressController,
                    label: 'Adres',
                    icon: Icons.location_on_outlined,
                    isDark: isDark,
                    maxLines: 3,
                  ),
                ]),
                const SizedBox(height: 32),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Kaydet', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: CarSalesColors.textTertiary(isDark)),
            const SizedBox(height: 12),
            Text(
              'Profil yuklenirken hata olustu',
              style: TextStyle(color: CarSalesColors.textSecondary(isDark)),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref.invalidate(dealerProfileProvider),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(bool isDark, CarDealer profile) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: CarSalesColors.card(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CarSalesColors.border(isDark)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: CarSalesColors.primaryGradient,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: profile.logoUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(
                      profile.logoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _buildInitials(profile.displayName),
                    ),
                  )
                : _buildInitials(profile.displayName),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: CarSalesColors.textPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: CarSalesColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        profile.dealerType.label,
                        style: const TextStyle(
                          color: CarSalesColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (profile.isVerified) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: CarSalesColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified,
                                size: 14, color: CarSalesColors.success),
                            SizedBox(width: 4),
                            Text(
                              'Onaylanmis',
                              style: TextStyle(
                                color: CarSalesColors.success,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitials(String name) {
    final parts = name.split(' ');
    String initials;
    if (parts.length >= 2) {
      initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (name.isNotEmpty) {
      initials = name[0].toUpperCase();
    } else {
      initials = '?';
    }

    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatsRow(bool isDark, CarDealer profile) {
    return Row(
      children: [
        _buildMiniStat(isDark, '${profile.totalListings}', 'Toplam Ilan'),
        const SizedBox(width: 12),
        _buildMiniStat(isDark, '${profile.totalSold}', 'Satilan'),
        const SizedBox(width: 12),
        _buildMiniStat(
            isDark,
            profile.averageRating > 0
                ? profile.averageRating.toStringAsFixed(1)
                : '-',
            'Ortalama Puan'),
        const SizedBox(width: 12),
        _buildMiniStat(isDark, '${profile.totalReviews}', 'Degerlendirme'),
      ],
    );
  }

  Widget _buildMiniStat(bool isDark, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: CarSalesColors.card(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CarSalesColors.border(isDark)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: CarSalesColors.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: CarSalesColors.textTertiary(isDark),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: CarSalesColors.textPrimary(isDark),
      ),
    );
  }

  Widget _buildCard(bool isDark, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CarSalesColors.card(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CarSalesColors.border(isDark)),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    bool readOnly = false,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: CarSalesColors.textPrimary(isDark)),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        suffixIcon: readOnly
            ? Icon(Icons.lock_outline,
                size: 18, color: CarSalesColors.textTertiary(isDark))
            : null,
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final updates = <String, dynamic>{
        'owner_name': _ownerNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'business_name': _businessNameController.text.trim().isNotEmpty
            ? _businessNameController.text.trim()
            : null,
        'tax_number': _taxNumberController.text.trim().isNotEmpty
            ? _taxNumberController.text.trim()
            : null,
        'city': _selectedCity,
        'address': _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : null,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await ref.read(dealerServiceProvider).updateDealerProfile(updates);
      ref.invalidate(dealerProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil basariyla guncellendi!'),
            backgroundColor: CarSalesColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: CarSalesColors.accent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
