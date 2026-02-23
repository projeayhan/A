import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/supabase_service.dart';
import '../../core/providers/user_provider.dart';
import '../../core/utils/app_dialogs.dart';

class PersonalInfoScreen extends ConsumerStatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  ConsumerState<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends ConsumerState<PersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _birthDateController;
  String _selectedGender = 'Erkek';
  bool _isEditing = false;
  bool _isFirstTimeSetup = false;
  bool _isPhoneVerified = false;
  bool _isVerifyingPhone = false;
  int _actualOrderCount = 0;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _birthDateController = TextEditingController();

    // Attempt to load existing data if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProfile = ref.read(userProfileProvider);
      if (userProfile != null) {
        _populateControllers(userProfile);
      }
      // Auth user'dan telefon ve e-posta doldur (profil henüz yüklenmemişse)
      final authUser = SupabaseService.currentUser;
      if (authUser != null) {
        if (_phoneController.text.trim().isEmpty && (authUser.phone ?? '').isNotEmpty) {
          _phoneController.text = authUser.phone!;
        }
        if (_emailController.text.trim().isEmpty && (authUser.email ?? '').isNotEmpty) {
          _emailController.text = authUser.email!;
        }
      }
      _loadActualOrderCount();
      _checkPhoneVerification();
      // Auto-enable editing if name is empty (first-time setup after OTP)
      final firstName = _firstNameController.text.trim();
      if (firstName.isEmpty) {
        setState(() {
          _isEditing = true;
          _isFirstTimeSetup = true;
        });
      }
    });
  }

  Future<void> _loadActualOrderCount() async {
    final user = SupabaseService.currentUser;
    if (user == null) return;
    try {
      final response = await SupabaseService.client
          .from('orders')
          .select('id')
          .eq('user_id', user.id);
      if (mounted) {
        setState(() => _actualOrderCount = (response as List).length);
      }
    } catch (_) {}
  }

  void _populateControllers(UserProfile profile) {
    if (_isEditing) return;
    _firstNameController.text = profile.firstName ?? '';
    _lastNameController.text = profile.lastName ?? '';
    _emailController.text = profile.email ?? '';
    _phoneController.text = profile.phone ?? '';
    if (profile.dateOfBirth != null) {
      _birthDateController.text =
          '${profile.dateOfBirth!.day.toString().padLeft(2, '0')}/${profile.dateOfBirth!.month.toString().padLeft(2, '0')}/${profile.dateOfBirth!.year}';
    }
    if (profile.gender != null) {
      setState(() {
        _selectedGender = _mapGenderFromDb(profile.gender!);
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen<UserProfile?>(userProfileProvider, (previous, next) {
      if (next != null) {
        _populateControllers(next);
      }
    });

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _isFirstTimeSetup ? const SizedBox.shrink() : IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
              ),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              size: 16,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),
          onPressed: () => context.pop(),
        ),
        automaticallyImplyLeading: false,
        title: Text(
          _isFirstTimeSetup ? 'Hoş Geldiniz!' : 'Kişisel Bilgiler',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              if (_isEditing) {
                _saveChanges();
              } else {
                setState(() => _isEditing = true);
              }
            },
            child: Text(
              _isEditing ? 'Kaydet' : 'Düzenle',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Photo Section
              _buildProfilePhotoSection(isDark),

              const SizedBox(height: 32),

              // Personal Information
              _buildSectionTitle('Temel Bilgiler', isDark),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _firstNameController,
                label: 'Ad',
                icon: Icons.person_outline,
                enabled: _isEditing,
                isDark: isDark,
              ),

              const SizedBox(height: 16),

              _buildTextField(
                controller: _lastNameController,
                label: 'Soyad',
                icon: Icons.person_outline,
                enabled: _isEditing,
                isDark: isDark,
              ),

              const SizedBox(height: 16),

              _buildGenderSelector(isDark),

              const SizedBox(height: 16),

              _buildDateField(isDark),

              const SizedBox(height: 32),

              // Contact Information
              _buildSectionTitle('İletişim Bilgileri', isDark),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _emailController,
                label: 'E-posta',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                enabled: false,
                isDark: isDark,
                suffix: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.verified, size: 14, color: Colors.green),
                ),
              ),

              const SizedBox(height: 16),

              _buildTextField(
                controller: _phoneController,
                label: 'Telefon',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                enabled: _isEditing && !_isFirstTimeSetup,
                isDark: isDark,
                suffix: _phoneController.text.trim().isNotEmpty && (!_isEditing || _isFirstTimeSetup)
                    ? _isPhoneVerified
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.verified,
                              size: 14,
                              color: Colors.green,
                            ),
                          )
                        : GestureDetector(
                            onTap: _isVerifyingPhone
                                ? null
                                : _startPhoneVerification,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: _isVerifyingPhone
                                  ? const SizedBox(
                                      height: 14,
                                      width: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Doğrula',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                            ),
                          )
                    : null,
              ),

              const SizedBox(height: 32),

              // Account Information
              _buildSectionTitle('Hesap Bilgileri', isDark),
              const SizedBox(height: 16),

              Consumer(
                builder: (context, ref, child) {
                  final profile = ref.watch(userProfileProvider);
                  final createdAt = profile?.createdAt;
                  final formattedDate = createdAt != null
                      ? '${createdAt.day} ${_getMonthName(createdAt.month)} ${createdAt.year}'
                      : '-';
                  final totalOrders = _actualOrderCount;
                  final memberId = profile?.id.substring(0, 8).toUpperCase() ?? '-';

                  return _buildInfoCard(isDark, [
                    _buildInfoRow(
                      'Üyelik Tarihi',
                      formattedDate,
                      Icons.calendar_today_outlined,
                      isDark,
                    ),
                    _buildInfoRow(
                      'Toplam Sipariş',
                      '$totalOrders sipariş',
                      Icons.shopping_bag_outlined,
                      isDark,
                    ),
                    _buildInfoRow('Hesap ID', '#$memberId', Icons.tag, isDark),
                  ]);
                },
              ),

              const SizedBox(height: 32),

              // Danger Zone
              if (_isEditing) ...[
                _buildSectionTitle('Tehlikeli Bölge', isDark),
                const SizedBox(height: 16),
                _buildDangerZone(isDark),
              ],

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePhotoSection(bool isDark) {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 60),
              ),
              if (_isEditing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => _showPhotoOptions(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${_firstNameController.text} ${_lastNameController.text}'.trim().isEmpty
                ? 'İsim Belirtilmemiş'
                : '${_firstNameController.text} ${_lastNameController.text}',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.grey[400] : Colors.grey[600],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        style: TextStyle(
          fontSize: 16,
          color: isDark ? Colors.white : const Color(0xFF1F2937),
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          suffixIcon: suffix != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: suffix,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: isDark ? AppColors.surfaceDark : Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildGenderSelector(bool isDark) {
    final genders = ['Erkek', 'Kadın', 'Belirtmek İstemiyorum'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEC4899).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.wc_outlined,
                  color: Color(0xFFEC4899),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Cinsiyet',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            children: genders.map((gender) {
              final isSelected = _selectedGender == gender;
              return GestureDetector(
                onTap: _isEditing
                    ? () => setState(() => _selectedGender = gender)
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? Colors.grey[800] : Colors.grey[100]),
                    borderRadius: BorderRadius.circular(10),
                    border: isSelected
                        ? null
                        : Border.all(
                            color: isDark
                                ? Colors.grey[700]!
                                : Colors.grey[200]!,
                          ),
                  ),
                  child: Text(
                    gender,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.grey[300] : Colors.grey[700]),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(bool isDark) {
    // Doğum tarihi daha önce girilmişse değiştirilemez, boşsa her zaman düzenlenebilir
    final hasDateOfBirth = _birthDateController.text.isNotEmpty;
    final canEdit = !hasDateOfBirth;

    return GestureDetector(
      onTap: canEdit ? () => _selectDate() : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.cake_outlined,
                color: Color(0xFF10B981),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Doğum Tarihi',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _birthDateController.text.isEmpty
                        ? (canEdit ? 'Tarih seçin' : 'Belirtilmemiş')
                        : _birthDateController.text,
                    style: TextStyle(
                      fontSize: 16,
                      color: _birthDateController.text.isEmpty
                          ? Colors.grey[400]
                          : (isDark ? Colors.white : const Color(0xFF1F2937)),
                    ),
                  ),
                ],
              ),
            ),
            if (canEdit)
              Icon(
                Icons.calendar_today_outlined,
                color: Colors.grey[400],
                size: 20,
              )
            else if (hasDateOfBirth)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 12, color: Colors.orange),
                    SizedBox(width: 4),
                    Text(
                      'Kilitli',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
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

  Widget _buildInfoCard(bool isDark, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon,
    bool isDark, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.grey[500], size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color:
                  valueColor ??
                  (isDark ? Colors.white : const Color(0xFF1F2937)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.no_accounts_outlined,
                color: Colors.red,
                size: 20,
              ),
            ),
            title: const Text(
              'Hesabı Devre Dışı Bırak',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Geçici olarak hesabınızı askıya alın',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.red),
            onTap: () => _showDeactivateDialog(),
          ),
        ],
      ),
    );
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.surfaceDark
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Profil Fotoğrafı',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt, color: Color(0xFF3B82F6)),
              ),
              title: const Text('Kamera ile Çek'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Kamera özelliği yakında eklenecek'),
                  ),
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.photo_library,
                  color: Color(0xFF10B981),
                ),
              ),
              title: const Text('Galeriden Seç'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Galeri özelliği yakında eklenecek'),
                  ),
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete_outline, color: Colors.red),
              ),
              title: const Text(
                'Fotoğrafı Kaldır',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fotoğraf kaldırıldı')),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(1990, 3, 15),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        _birthDateController.text =
            '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      });
    }
  }

  void _showDeactivateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 12),
            Text('Hesabı Askıya Al'),
          ],
        ),
        content: const Text(
          'Hesabınız geçici olarak devre dışı bırakılacak. Tekrar giriş yaptığınızda aktif olacaktır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Vazgeç', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await AppDialogs.showWarning(context, 'Hesabınız askıya alındı');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Askıya Al',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      setState(
        () => _isEditing = false,
      ); // Optimistic UI update or show loading

      final success = await ref
          .read(userProfileProvider.notifier)
          .updateProfile(
            firstName: _firstNameController.text,
            lastName: _lastNameController.text,
            email: _emailController.text,
            phone: _phoneController.text,
            dateOfBirth: _birthDateController.text.isNotEmpty
                ? DateTime.tryParse(
                    _birthDateController.text.split('/').reversed.join('-'),
                  )
                : null,
            gender: _mapGenderToDb(_selectedGender),
          );

      // Auth metadata'yı da güncelle (router redirect isim kontrolü için)
      if (success) {
        try {
          await SupabaseService.updateUserProfile(
            firstName: _firstNameController.text,
            lastName: _lastNameController.text,
          );
        } catch (_) {}
      }

      if (mounted) {
        if (success) {
          _checkPhoneVerification();
          if (_isFirstTimeSetup) {
            // İlk kurulum tamamlandı, ana sayfaya yönlendir
            context.go('/');
          } else {
            await AppDialogs.showSuccess(context, 'Bilgileriniz başarıyla güncellendi');
          }
        } else {
          setState(() => _isEditing = true); // Revert editing state on failure
          await AppDialogs.showError(context, 'Güncelleme başarısız oldu');
        }
      }
    }
  }

  void _checkPhoneVerification() {
    final user = SupabaseService.currentUser;
    if (user == null) return;
    final authPhone = user.phone ?? '';
    final profilePhone = _phoneController.text.trim();
    // Normalize both to +90XXXXXXXXXX format for comparison
    final normalizedAuth = authPhone.isNotEmpty ? _normalizePhoneNumber(authPhone) : '';
    final normalizedProfile = profilePhone.isNotEmpty ? _normalizePhoneNumber(profilePhone) : '';
    setState(() {
      _isPhoneVerified = normalizedAuth.isNotEmpty &&
          normalizedAuth == normalizedProfile &&
          user.phoneConfirmedAt != null;
    });
  }

  String _normalizePhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.startsWith('+90')) return cleaned;
    if (cleaned.startsWith('90') && cleaned.length == 12) return '+$cleaned';
    if (cleaned.startsWith('0')) return '+90${cleaned.substring(1)}';
    if (cleaned.length == 10 && cleaned.startsWith('5')) return '+90$cleaned';
    if (cleaned.startsWith('+')) return cleaned;
    return '+90$cleaned';
  }

  Future<void> _startPhoneVerification() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      await AppDialogs.showError(context, 'Lütfen önce telefon numarası girin');
      return;
    }

    final normalizedPhone = _normalizePhoneNumber(phone);
    if (normalizedPhone.length < 12) {
      await AppDialogs.showError(context, 'Geçersiz telefon numarası');
      return;
    }

    setState(() => _isVerifyingPhone = true);

    try {
      // Use Twilio Verify via edge function (Supabase built-in doesn't work for Turkey)
      await SupabaseService.sendPhoneOtp(phone: normalizedPhone);

      if (mounted) {
        setState(() => _isVerifyingPhone = false);
        _showOtpDialog(normalizedPhone);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifyingPhone = false);
        await AppDialogs.showError(
          context,
          'SMS gönderilemedi: ${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    }
  }

  void _showOtpDialog(String normalizedPhone) {
    final otpController = TextEditingController();
    bool isVerifying = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.sms_outlined, color: AppColors.primary),
              SizedBox(width: 12),
              Text('Telefon Doğrulama'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$normalizedPhone numarasına gönderilen 6 haneli kodu girin',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  hintText: '000000',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isVerifying
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: Text(
                'İptal',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            FilledButton(
              onPressed: isVerifying
                  ? null
                  : () async {
                      final otp = otpController.text.trim();
                      if (otp.length != 6) return;

                      setDialogState(() => isVerifying = true);

                      try {
                        // Use Twilio Verify via edge function
                        await SupabaseService.verifyPhoneOtp(
                          phone: normalizedPhone,
                          code: otp,
                        );

                        if (mounted) {
                          Navigator.pop(dialogContext);
                          setState(() => _isPhoneVerified = true);
                          await AppDialogs.showSuccess(
                            context,
                            'Telefon numaranız doğrulandı',
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isVerifying = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Doğrulama hatası: ${e.toString().replaceAll('Exception: ', '')}',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isVerifying
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Doğrula'),
            ),
          ],
        ),
      ),
    );
  }

  String _mapGenderToDb(String uiGender) {
    switch (uiGender) {
      case 'Erkek':
        return 'male';
      case 'Kadın':
        return 'female';
      default:
        return 'other';
    }
  }

  String _mapGenderFromDb(String? dbGender) {
    switch (dbGender) {
      case 'male':
        return 'Erkek';
      case 'female':
        return 'Kadın';
      default:
        return 'Belirtmek İstemiyorum';
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    return months[month - 1];
  }

}
