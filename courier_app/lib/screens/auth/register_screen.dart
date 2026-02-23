import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/app_dialogs.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // Controllers
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _tcNoController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _ibanController = TextEditingController();
  final _merchantEmailController = TextEditingController();

  String _selectedVehicleType = 'motorcycle';
  String _selectedWorkMode = 'platform'; // platform, restaurant, both
  bool _obscurePassword = true;
  bool _isSearchingMerchant = false;
  bool _isExistingUser = false; // E-posta ile giriş yapmış ama profili yok
  bool _phoneVerified = false;
  Map<String, dynamic>? _selectedMerchant;

  List<Map<String, String>> _vehicleTypes = [];
  bool _isLoadingVehicleTypes = true;

  // OTP doğrulama
  final _otpController = TextEditingController();
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  int _otpCountdown = 0;
  Timer? _otpTimer;

  @override
  void initState() {
    super.initState();
    _loadVehicleTypes();
    final authState = ref.read(authProvider);
    if (authState.status == AuthStatus.needsRegistration) {
      _isExistingUser = true;
      // E-posta ile giriş yapmış kullanıcının telefonunu al (varsa)
      final phone = Supabase.instance.client.auth.currentUser?.phone ?? '';
      if (phone.isNotEmpty) {
        String stripped = phone;
        if (stripped.startsWith('+')) stripped = stripped.substring(1);
        if (stripped.startsWith('90') && stripped.length > 10) stripped = stripped.substring(2);
        if (stripped.startsWith('0')) stripped = stripped.substring(1);
        _phoneController.text = stripped;
      }
    }
  }

  Future<void> _loadVehicleTypes() async {
    try {
      final response = await Supabase.instance.client
          .from('courier_vehicle_types')
          .select('id, name')
          .eq('is_active', true)
          .order('sort_order');
      final list = (response as List).map<Map<String, String>>((e) => {
        'value': e['id'] as String,
        'label': e['name'] as String,
      }).toList();
      if (mounted) {
        setState(() {
          _vehicleTypes = list;
          if (list.isNotEmpty && !list.any((t) => t['value'] == _selectedVehicleType)) {
            _selectedVehicleType = list.first['value']!;
          }
          _isLoadingVehicleTypes = false;
        });
      }
    } catch (_) {
      // Fallback: hardcoded defaults
      if (mounted) {
        setState(() {
          _vehicleTypes = [
            {'value': 'motorcycle', 'label': 'Motosiklet'},
            {'value': 'moto_taxi', 'label': 'Moto Taksi'},
            {'value': 'bicycle', 'label': 'Bisiklet'},
            {'value': 'car', 'label': 'Araba'},
          ];
          _isLoadingVehicleTypes = false;
        });
      }
    }
  }

  // _vehicleTypes DB'den yüklenir (initState → _loadVehicleTypes)

  final List<Map<String, String>> _workModes = [
    {
      'value': 'platform',
      'label': 'Platform Kuryesi',
      'description': 'Tüm restoran, market ve mağazalardan sipariş alırsınız',
      'icon': 'public',
    },
    {
      'value': 'restaurant',
      'label': 'İşletme Kuryesi',
      'description': 'Sadece belirli bir işletmeye (restoran, market veya mağaza) çalışırsınız',
      'icon': 'store',
    },
    {
      'value': 'both',
      'label': 'Her İkisi',
      'description': 'Hem platform hem de belirli bir işletmeye çalışırsınız',
      'icon': 'all_inclusive',
    },
  ];

  @override
  void dispose() {
    _otpTimer?.cancel();
    _pageController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _tcNoController.dispose();
    _vehiclePlateController.dispose();
    _bankNameController.dispose();
    _ibanController.dispose();
    _merchantEmailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage == 0) {
      if (_fullNameController.text.isEmpty || _phoneController.text.isEmpty) {
        _showError('Lütfen tüm alanları doldurun');
        return;
      }
      if (!_isExistingUser) {
        if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
          _showError('Lütfen tüm alanları doldurun');
          return;
        }
        if (_passwordController.text.length < 6) {
          _showError('Şifre en az 6 karakter olmalı');
          return;
        }
      }
      // Telefon zaten doğrulanmışsa OTP sayfasını atla
      if (_phoneVerified) {
        _pageController.animateToPage(2,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        return;
      }
      // Telefon OTP gönder
      _sendOtp();
      return;
    } else if (_currentPage == 2) {
      // Araç bilgileri validasyonu
      if (_tcNoController.text.isEmpty) {
        _showError('Kimlik Numarası gerekli');
        return;
      }
      if (_vehiclePlateController.text.isEmpty) {
        _showError('Plaka bilgisi gerekli');
        return;
      }
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _previousPage() {
    // Telefon doğrulanmışsa araç bilgileri sayfasından geriye gidince OTP'yi atlayıp page 0'a atla
    if (_phoneVerified && _currentPage == 2) {
      _pageController.animateToPage(0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _sendOtp() async {
    final phone = '+90${_phoneController.text.trim()}';
    setState(() => _isSendingOtp = true);
    try {
      await SupabaseService.sendPhoneOtp(phone: phone);
      if (mounted) {
        _startOtpCountdown();
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } catch (e) {
      if (mounted) _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      _showError('Lütfen 6 haneli kodu girin');
      return;
    }
    final phone = '+90${_phoneController.text.trim()}';
    setState(() => _isVerifyingOtp = true);
    try {
      await SupabaseService.verifyPhoneOnly(phone: phone, code: code);
      if (mounted) {
        _otpTimer?.cancel();
        setState(() => _phoneVerified = true);
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } catch (e) {
      if (mounted) _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isVerifyingOtp = false);
    }
  }

  void _startOtpCountdown() {
    _otpTimer?.cancel();
    setState(() => _otpCountdown = 60);
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _otpCountdown--;
        if (_otpCountdown <= 0) timer.cancel();
      });
    });
  }

  Future<void> _searchMerchant() async {
    final email = _merchantEmailController.text.trim();
    if (email.isEmpty) {
      _showError('İşletme e-posta adresi girin');
      return;
    }

    setState(() => _isSearchingMerchant = true);

    try {
      final response = await SupabaseService.client
          .from('merchants')
          .select('id, business_name, type, address, logo_url')
          .eq('email', email)
          .maybeSingle();

      if (response == null) {
        _showError('Bu e-posta adresine ait işletme bulunamadı');
        setState(() => _selectedMerchant = null);
      } else {
        setState(() => _selectedMerchant = response);
      }
    } catch (e) {
      _showError('Arama hatası: $e');
    } finally {
      setState(() => _isSearchingMerchant = false);
    }
  }

  Future<void> _handleRegister() async {
    // Çalışma modu validasyonu
    if (_selectedWorkMode == 'restaurant' || _selectedWorkMode == 'both') {
      if (_selectedMerchant == null) {
        _showError('Lütfen bir işletme seçin');
        return;
      }
    }

    if (_isExistingUser) {
      // Mevcut kullanıcı (e-posta ile giriş yapmış, profili yok): sadece kurye profili oluştur
      await ref.read(authProvider.notifier).completeRegistration(
        fullName: _fullNameController.text.trim(),
        phone: '+90${_phoneController.text.trim()}',
        tcNo: _tcNoController.text.trim(),
        vehicleType: _selectedVehicleType,
        vehiclePlate: _vehiclePlateController.text.trim().toUpperCase(),
        bankName: _bankNameController.text.trim(),
        bankIban: _ibanController.text.replaceAll(' ', '').toUpperCase(),
        workMode: _selectedWorkMode,
        merchantId: _selectedMerchant?['id'],
      );
    } else {
      // Yeni kullanıcı: e-posta + şifre ile hesap oluştur + kurye profili oluştur
      await ref.read(authProvider.notifier).registerWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        phone: '+90${_phoneController.text.trim()}',
        tcNo: _tcNoController.text.trim(),
        vehicleType: _selectedVehicleType,
        vehiclePlate: _vehiclePlateController.text.trim().toUpperCase(),
        bankName: _bankNameController.text.trim(),
        bankIban: _ibanController.text.replaceAll(' ', '').toUpperCase(),
        workMode: _selectedWorkMode,
        merchantId: _selectedMerchant?['id'],
      );
    }
    // Router otomatik pending'e yönlendirir
  }

  void _showError(String message) {
    AppDialogs.showError(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.errorMessage != null) {
        _showError(next.errorMessage!);
        ref.read(authProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentPage > 0) {
              _previousPage();
            } else if (_isExistingUser) {
              ref.read(authProvider.notifier).signOut();
            } else {
              context.go('/login');
            }
          },
        ),
        title: Text(_isExistingUser && _currentPage == 0 ? 'Bilgilerinizi Tamamlayın' : _getPageTitle()),
      ),
      body: Column(
        children: [
          // Progress indicator - her zaman 4 adım
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: List.generate(4, (i) {
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(left: i > 0 ? 8 : 0),
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= _currentPage ? AppColors.primary : AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),

          // Pages
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (page) => setState(() => _currentPage = page),
              children: [
                _buildPersonalInfoPage(isLoading),
                _buildOtpPage(),        // page 1
                _buildVehicleInfoPage(isLoading), // page 2
                _buildWorkModePage(isLoading),    // page 3
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getPageTitle() {
    switch (_currentPage) {
      case 0:
        return 'Kişisel Bilgiler';
      case 1:
        return 'Telefon Doğrulama';
      case 2:
        return 'Araç Bilgileri';
      case 3:
        return 'Çalışma Modu';
      default:
        return 'Kayıt Ol';
    }
  }

  Widget _buildPersonalInfoPage(bool isLoading) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ad Soyad
          TextFormField(
            controller: _fullNameController,
            enabled: !isLoading,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Ad Soyad',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),

          const SizedBox(height: 16),

          if (!_isExistingUser) ...[
            // E-posta (sadece yeni kayıt)
            TextFormField(
              controller: _emailController,
              enabled: !isLoading,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-posta',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),

            const SizedBox(height: 16),
          ],

          // Telefon
          TextFormField(
            controller: _phoneController,
            enabled: !isLoading && !_phoneVerified,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: InputDecoration(
              labelText: 'Telefon',
              prefixIcon: const Icon(Icons.phone_outlined),
              prefixText: '+90 ',
              suffixIcon: _phoneVerified
                  ? const Icon(Icons.verified, color: Colors.green, size: 20)
                  : null,
            ),
          ),

          const SizedBox(height: 16),

          if (!_isExistingUser) ...[
            // Şifre (sadece yeni kayıt)
            TextFormField(
              controller: _passwordController,
              enabled: !isLoading,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Şifre',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
            ),

            const SizedBox(height: 32),
          ] else ...[
            const SizedBox(height: 16),
          ],

          // Devam butonu
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: (isLoading || _isSendingOtp) ? null : _nextPage,
              child: _isSendingOtp
                  ? const SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Devam Et'),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 20),
                      ],
                    ),
            ),
          ),

          if (!_isExistingUser) ...[
            const SizedBox(height: 16),

            // Giriş linki
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Zaten hesabınız var mı? ',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                TextButton(
                  onPressed: isLoading ? null : () => context.go('/login'),
                  child: const Text('Giriş Yap'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOtpPage() {
    final phone = _phoneController.text.trim();
    final maskedPhone = phone.length >= 10
        ? '${phone.substring(0, 3)} *** ** ${phone.substring(phone.length - 2)}'
        : phone;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),

          // İkon
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sms_outlined, size: 40, color: AppColors.primary),
          ),

          const SizedBox(height: 24),

          Text(
            'Doğrulama Kodu',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '+90 $maskedPhone numarasına gönderilen\n6 haneli kodu girin',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // OTP input
          TextFormField(
            controller: _otpController,
            enabled: !_isVerifyingOtp,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              counterText: '',
              hintText: '------',
              hintStyle: TextStyle(letterSpacing: 8, color: AppColors.textHint),
            ),
            onChanged: (value) {
              if (value.length == 6) _verifyOtp();
            },
          ),

          const SizedBox(height: 24),

          // Doğrula butonu
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _isVerifyingOtp ? null : _verifyOtp,
              child: _isVerifyingOtp
                  ? const SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Doğrula'),
            ),
          ),

          const SizedBox(height: 16),

          // Tekrar gönder
          Center(
            child: _otpCountdown > 0
                ? Text(
                    'Tekrar gönder ($_otpCountdown sn)',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  )
                : TextButton(
                    onPressed: _isSendingOtp ? null : () async {
                      _otpController.clear();
                      await _sendOtp();
                    },
                    child: const Text('Kodu Tekrar Gönder'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleInfoPage(bool isLoading) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kimlik Numarası
          TextFormField(
            controller: _tcNoController,
            enabled: !isLoading,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              labelText: 'Kimlik Numarası',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),

          const SizedBox(height: 16),

          // Araç tipi
          if (_isLoadingVehicleTypes)
            const InputDecorator(
              decoration: InputDecoration(
                labelText: 'Araç Tipi',
                prefixIcon: Icon(Icons.two_wheeler_outlined),
              ),
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            DropdownButtonFormField<String>(
              value: _selectedVehicleType,
              decoration: const InputDecoration(
                labelText: 'Araç Tipi',
                prefixIcon: Icon(Icons.two_wheeler_outlined),
              ),
              items: _vehicleTypes.map((type) {
                return DropdownMenuItem(
                  value: type['value'],
                  child: Text(type['label']!),
                );
              }).toList(),
              onChanged: isLoading
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _selectedVehicleType = value);
                      }
                    },
            ),

          const SizedBox(height: 16),

          // Plaka
          TextFormField(
            controller: _vehiclePlateController,
            enabled: !isLoading,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Plaka',
              prefixIcon: Icon(Icons.confirmation_number_outlined),
              hintText: '34 ABC 123',
            ),
          ),

          const SizedBox(height: 32),

          // Devam butonu
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: isLoading ? null : _nextPage,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Devam Et'),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkModePage(bool isLoading) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Nasıl çalışmak istiyorsunuz?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Çalışma modunuzu seçin',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),

          // Çalışma modu seçenekleri
          ..._workModes.map((mode) => _buildWorkModeOption(mode)),

          // Restoran seçimi (restaurant veya both modunda göster)
          if (_selectedWorkMode == 'restaurant' ||
              _selectedWorkMode == 'both') ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            Text(
              'Hangi işletmeye çalışacaksınız?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'İşletmenin kayıtlı e-posta adresini girin',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),

            // Restoran arama
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _merchantEmailController,
                    enabled: !isLoading && !_isSearchingMerchant,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'İşletme E-posta',
                      prefixIcon: Icon(Icons.store_outlined),
                      hintText: 'isletme@email.com',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSearchingMerchant ? null : _searchMerchant,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                    ),
                    child: _isSearchingMerchant
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.search),
                  ),
                ),
              ],
            ),

            // Seçilen restoran
            if (_selectedMerchant != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _selectedMerchant!['logo_url'] != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _selectedMerchant!['logo_url'],
                                fit: BoxFit.cover,
                              ),
                            )
                          : Icon(Icons.store, color: AppColors.success),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedMerchant!['business_name'] ?? 'İşletme',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _getMerchantTypeLabel(_selectedMerchant!['type']),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedMerchant!['address'] ?? '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.check_circle, color: AppColors.success),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Kayıt sonrası bu işletmeye bağlantı isteği gönderilecek. İşletme onayladığında bağlantınız tamamlanır.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],

          const SizedBox(height: 24),

          // Bilgi kartı
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.info),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Başvurunuz onaylandıktan sonra çalışmaya başlayabilirsiniz.',
                    style: TextStyle(fontSize: 13, color: AppColors.info),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Kayıt ol butonu
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: isLoading ? null : _handleRegister,
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Başvuruyu Tamamla'),
            ),
          ),
        ],
      ),
    );
  }

  String _getMerchantTypeLabel(String? type) {
    switch (type) {
      case 'restaurant':
        return 'Restoran';
      case 'market':
        return 'Market';
      case 'store':
        return 'Mağaza';
      default:
        return 'İşletme';
    }
  }

  Widget _buildWorkModeOption(Map<String, String> mode) {
    final isSelected = _selectedWorkMode == mode['value'];
    IconData icon;
    switch (mode['icon']) {
      case 'public':
        icon = Icons.public;
        break;
      case 'store':
        icon = Icons.store;
        break;
      case 'all_inclusive':
        icon = Icons.all_inclusive;
        break;
      default:
        icon = Icons.help_outline;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedWorkMode = mode['value']!;
          if (_selectedWorkMode == 'platform') {
            _selectedMerchant = null;
            _merchantEmailController.clear();
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode['label']!,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mode['description']!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: mode['value']!,
              groupValue: _selectedWorkMode,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedWorkMode = value;
                    if (_selectedWorkMode == 'platform') {
                      _selectedMerchant = null;
                      _merchantEmailController.clear();
                    }
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
