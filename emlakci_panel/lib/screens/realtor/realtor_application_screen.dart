import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/emlak_models.dart';
import '../../services/realtor_service.dart';
import '../../services/property_service.dart';

/// Emlakçı Başvuru Ekranı
class RealtorApplicationScreen extends StatefulWidget {
  const RealtorApplicationScreen({super.key});

  @override
  State<RealtorApplicationScreen> createState() => _RealtorApplicationScreenState();
}

class _RealtorApplicationScreenState extends State<RealtorApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _realtorService = RealtorService();
  final _propertyService = PropertyService();

  // Form Controllers
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _experienceYearsController = TextEditingController();
  final _messageController = TextEditingController();

  // State
  bool _isLoading = false;
  bool _isCheckingStatus = true;
  bool _isLoadingCities = true;
  Map<String, dynamic>? _existingApplication;

  // Seçimler
  List<String> _selectedSpecializations = [];
  List<String> _selectedCities = [];

  int _currentStep = 0;

  final List<String> _specializationOptions = [
    'Konut Satış',
    'Konut Kiralama',
    'Ticari Gayrimenkul',
    'Arsa/Arazi',
    'Proje Satış',
    'Lüks Konut',
    'Yatırım Danışmanlığı',
  ];

  // Şehirler veritabanından çekilecek
  List<String> _cityOptions = [];

  @override
  void initState() {
    super.initState();
    _checkExistingApplication();
    _loadUserData();
    _loadCities();
  }

  /// Şehirleri veritabanından yükle
  Future<void> _loadCities() async {
    try {
      final cities = await _propertyService.getCities();
      if (mounted) {
        setState(() {
          _cityOptions = cities;
          _isLoadingCities = false;
        });
      }
    } catch (e) {
      debugPrint('Şehirler yüklenemedi: $e');
      if (mounted) {
        setState(() => _isLoadingCities = false);
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _companyNameController.dispose();
    _licenseNumberController.dispose();
    _taxNumberController.dispose();
    _experienceYearsController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';

      // User profile'dan bilgileri al
      try {
        final profile = await Supabase.instance.client
            .from('user_profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (profile != null && mounted) {
          setState(() {
            _fullNameController.text = profile['full_name'] ?? '';
            _phoneController.text = profile['phone'] ?? '';
          });
        }
      } catch (e) {
        debugPrint('Profil yüklenemedi: $e');
      }
    }
  }

  Future<void> _checkExistingApplication() async {
    try {
      final application = await _realtorService.getApplicationStatus();
      if (mounted) {
        setState(() {
          _existingApplication = application;
          _isCheckingStatus = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCheckingStatus = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = Supabase.instance.client.auth.currentUser;

    // Kullanıcı giriş yapmamışsa login'e yönlendir
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/login');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isCheckingStatus) {
      return Scaffold(
        appBar: AppBar(title: const Text('Emlakçı Başvurusu')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Mevcut başvuru varsa durumu göster
    if (_existingApplication != null) {
      return _buildApplicationStatusScreen(isDark);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emlakçı Başvurusu'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await Supabase.instance.client.auth.signOut();
            if (mounted) context.go('/login');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Çıkış Yap',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: _onStepContinue,
          onStepCancel: _onStepCancel,
          onStepTapped: (step) => setState(() => _currentStep = step),
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Row(
                children: [
                  if (_currentStep < 2)
                    ElevatedButton(
                      onPressed: details.onStepContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EmlakColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      ),
                      child: const Text('Devam'),
                    )
                  else
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitApplication,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EmlakColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Başvuruyu Gönder'),
                    ),
                  const SizedBox(width: 12),
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: const Text('Geri'),
                    ),
                ],
              ),
            );
          },
          steps: [
            // Step 1: Kişisel Bilgiler
            Step(
              title: const Text('Kişisel Bilgiler'),
              subtitle: const Text('Ad, telefon ve e-posta'),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
              content: _buildPersonalInfoStep(isDark),
            ),
            // Step 2: Mesleki Bilgiler
            Step(
              title: const Text('Mesleki Bilgiler'),
              subtitle: const Text('Şirket ve lisans bilgileri'),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
              content: _buildProfessionalInfoStep(isDark),
            ),
            // Step 3: Uzmanlık Alanları
            Step(
              title: const Text('Uzmanlık Alanları'),
              subtitle: const Text('Çalışma alanları ve şehirler'),
              isActive: _currentStep >= 2,
              state: _currentStep > 2 ? StepState.complete : StepState.indexed,
              content: _buildSpecializationStep(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoStep(bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 8),
        // Ad Soyad
        TextFormField(
          controller: _fullNameController,
          style: TextStyle(color: EmlakColors.textPrimary(isDark)),
          decoration: _inputDecoration('Ad Soyad', Icons.person_outline, isDark),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Ad soyad gerekli';
            if (value.length < 3) return 'En az 3 karakter girin';
            return null;
          },
        ),
        const SizedBox(height: 16),
        // Telefon
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: TextStyle(color: EmlakColors.textPrimary(isDark)),
          decoration: _inputDecoration('Telefon', Icons.phone_outlined, isDark),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (value) {
            if (value == null || value.isEmpty) return 'Telefon gerekli';
            if (value.length < 10) return 'Geçerli bir telefon girin';
            return null;
          },
        ),
        const SizedBox(height: 16),
        // E-posta
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: TextStyle(color: EmlakColors.textPrimary(isDark)),
          decoration: _inputDecoration('E-posta', Icons.email_outlined, isDark),
          validator: (value) {
            if (value == null || value.isEmpty) return 'E-posta gerekli';
            if (!value.contains('@')) return 'Geçerli bir e-posta girin';
            return null;
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildProfessionalInfoStep(bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 8),
        // Şirket Adı (Opsiyonel)
        TextFormField(
          controller: _companyNameController,
          style: TextStyle(color: EmlakColors.textPrimary(isDark)),
          decoration: _inputDecoration('Şirket Adı (Opsiyonel)', Icons.business_outlined, isDark),
        ),
        const SizedBox(height: 16),
        // Lisans Numarası (Opsiyonel)
        TextFormField(
          controller: _licenseNumberController,
          style: TextStyle(color: EmlakColors.textPrimary(isDark)),
          decoration: _inputDecoration('Lisans Numarası (Opsiyonel)', Icons.badge_outlined, isDark),
        ),
        const SizedBox(height: 16),
        // Vergi Numarası (Opsiyonel)
        TextFormField(
          controller: _taxNumberController,
          keyboardType: TextInputType.number,
          style: TextStyle(color: EmlakColors.textPrimary(isDark)),
          decoration: _inputDecoration('Vergi Numarası (Opsiyonel)', Icons.receipt_long_outlined, isDark),
        ),
        const SizedBox(height: 16),
        // Deneyim Yılı
        TextFormField(
          controller: _experienceYearsController,
          keyboardType: TextInputType.number,
          style: TextStyle(color: EmlakColors.textPrimary(isDark)),
          decoration: _inputDecoration('Deneyim (Yıl)', Icons.timeline_outlined, isDark),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSpecializationStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // Uzmanlık Alanları
        Text(
          'Uzmanlık Alanları',
          style: TextStyle(
            color: EmlakColors.textPrimary(isDark),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _specializationOptions.map((spec) {
            final isSelected = _selectedSpecializations.contains(spec);
            return FilterChip(
              label: Text(spec),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedSpecializations.add(spec);
                  } else {
                    _selectedSpecializations.remove(spec);
                  }
                });
              },
              selectedColor: EmlakColors.primary.withValues(alpha: 0.2),
              checkmarkColor: EmlakColors.primary,
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        // Çalışma Şehirleri
        Text(
          'Çalışma Şehirleri',
          style: TextStyle(
            color: EmlakColors.textPrimary(isDark),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (_isLoadingCities)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_cityOptions.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Şehir listesi yüklenemedi',
              style: TextStyle(color: EmlakColors.textSecondary(isDark)),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _cityOptions.map((city) {
              final isSelected = _selectedCities.contains(city);
              return FilterChip(
                label: Text(city),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedCities.add(city);
                    } else {
                      _selectedCities.remove(city);
                    }
                  });
                },
                selectedColor: EmlakColors.secondary.withValues(alpha: 0.2),
                checkmarkColor: EmlakColors.secondary,
              );
            }).toList(),
          ),
        const SizedBox(height: 24),
        // Mesaj (Opsiyonel)
        TextFormField(
          controller: _messageController,
          maxLines: 3,
          style: TextStyle(color: EmlakColors.textPrimary(isDark)),
          decoration: _inputDecoration('Eklemek istediğiniz not (Opsiyonel)', Icons.message_outlined, isDark),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildApplicationStatusScreen(bool isDark) {
    final status = _existingApplication!['status'] as String;
    final createdAt = DateTime.parse(_existingApplication!['created_at'] as String);

    IconData statusIcon;
    Color statusColor;
    String statusText;
    String statusDescription;

    switch (status) {
      case 'pending':
        statusIcon = Icons.hourglass_empty;
        statusColor = EmlakColors.accent;
        statusText = 'Başvuru Beklemede';
        statusDescription = 'Başvurunuz inceleme için sıraya alındı. En kısa sürede değerlendirilecektir.';
        break;
      case 'under_review':
        statusIcon = Icons.search;
        statusColor = EmlakColors.primary;
        statusText = 'İnceleniyor';
        statusDescription = 'Başvurunuz şu anda incelenmektedir. Sonuç için lütfen bekleyin.';
        break;
      case 'approved':
        statusIcon = Icons.check_circle;
        statusColor = EmlakColors.success;
        statusText = 'Onaylandı';
        statusDescription = 'Tebrikler! Başvurunuz onaylandı. Panele giriş yapabilirsiniz.';
        break;
      case 'rejected':
        statusIcon = Icons.cancel;
        statusColor = EmlakColors.error;
        statusText = 'Reddedildi';
        statusDescription = _existingApplication!['rejection_reason'] as String? ??
            'Başvurunuz reddedildi. Yeni bir başvuru yapabilirsiniz.';
        break;
      default:
        statusIcon = Icons.info;
        statusColor = EmlakColors.textSecondary(isDark);
        statusText = 'Bilinmeyen Durum';
        statusDescription = 'Başvuru durumu belirlenemiyor.';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Başvuru Durumu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Çıkış Yap',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Status Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, size: 64, color: statusColor),
              ),
              const SizedBox(height: 24),

              // Status Text
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                statusDescription,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: EmlakColors.textSecondary(isDark),
                ),
              ),
              const SizedBox(height: 24),

              // Application Date
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: EmlakColors.surface(isDark),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: EmlakColors.border(isDark)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today, color: EmlakColors.textSecondary(isDark)),
                    const SizedBox(width: 12),
                    Text(
                      'Başvuru Tarihi: ${createdAt.day}.${createdAt.month}.${createdAt.year}',
                      style: TextStyle(color: EmlakColors.textPrimary(isDark)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Action Buttons
              if (status == 'approved') ...[
                ElevatedButton.icon(
                  onPressed: () => context.go('/panel'),
                  icon: const Icon(Icons.dashboard),
                  label: const Text('Panele Git'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EmlakColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
              ] else if (status == 'rejected') ...[
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _existingApplication = null;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Yeni Başvuru Yap'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EmlakColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: _checkExistingApplication,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Durumu Yenile'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: EmlakColors.primary,
                    side: BorderSide(color: EmlakColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              TextButton.icon(
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (mounted) context.go('/login');
                },
                icon: const Icon(Icons.logout),
                label: const Text('Çıkış Yap'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, bool isDark) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: EmlakColors.primary),
      labelStyle: TextStyle(color: EmlakColors.textSecondary(isDark)),
      filled: true,
      fillColor: EmlakColors.surface(isDark),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: EmlakColors.border(isDark)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: EmlakColors.border(isDark)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: EmlakColors.primary, width: 2),
      ),
    );
  }

  void _onStepContinue() {
    if (_currentStep == 0) {
      // Kişisel bilgiler validasyonu
      if (_fullNameController.text.isEmpty ||
          _phoneController.text.isEmpty ||
          _emailController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen tüm zorunlu alanları doldurun')),
        );
        return;
      }
    }

    if (_currentStep < 2) {
      setState(() => _currentStep++);
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _realtorService.submitApplication(
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        companyName: _companyNameController.text.trim().isEmpty
            ? null : _companyNameController.text.trim(),
        licenseNumber: _licenseNumberController.text.trim().isEmpty
            ? null : _licenseNumberController.text.trim(),
        taxNumber: _taxNumberController.text.trim().isEmpty
            ? null : _taxNumberController.text.trim(),
        experienceYears: int.tryParse(_experienceYearsController.text) ?? 0,
        specialization: _selectedSpecializations.isEmpty ? null : _selectedSpecializations,
        workingCities: _selectedCities.isEmpty ? null : _selectedCities,
        applicantMessage: _messageController.text.trim().isEmpty
            ? null : _messageController.text.trim(),
      );

      if (!mounted) return;

      HapticFeedback.mediumImpact();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Başvurunuz başarıyla gönderildi!'),
          backgroundColor: EmlakColors.success,
        ),
      );

      // Durumu yeniden kontrol et
      await _checkExistingApplication();

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: EmlakColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
