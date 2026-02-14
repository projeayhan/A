import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  final _formKey = GlobalKey<FormState>();
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
  Map<String, dynamic>? _selectedMerchant;

  final List<Map<String, String>> _vehicleTypes = [
    {'value': 'motorcycle', 'label': 'Motosiklet'},
    {'value': 'bicycle', 'label': 'Bisiklet'},
    {'value': 'car', 'label': 'Araba'},
  ];

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
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage == 0) {
      // İlk sayfa validasyonu
      if (_fullNameController.text.isEmpty ||
          _emailController.text.isEmpty ||
          _phoneController.text.isEmpty ||
          _passwordController.text.isEmpty) {
        _showError('Lütfen tüm alanları doldurun');
        return;
      }
      if (_passwordController.text.length < 6) {
        _showError('Şifre en az 6 karakter olmalı');
        return;
      }
    } else if (_currentPage == 1) {
      // İkinci sayfa validasyonu
      if (_tcNoController.text.length != 11) {
        _showError('TC Kimlik No 11 haneli olmalı');
        return;
      }
      if (_vehiclePlateController.text.isEmpty) {
        _showError('Plaka bilgisi gerekli');
        return;
      }
    } else if (_currentPage == 2) {
      // Üçüncü sayfa validasyonu (ödeme bilgileri)
      if (_bankNameController.text.isEmpty) {
        _showError('Banka adı gerekli');
        return;
      }
      final iban = _ibanController.text.replaceAll(' ', '');
      if (iban.length < 26) {
        _showError('Geçerli bir IBAN girin');
        return;
      }
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
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

    final success = await ref
        .read(authProvider.notifier)
        .signUp(
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

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kayıt başarılı! E-posta adresinize gelen doğrulama linkine tıklayın.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );
      context.go('/login');
    }
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
            } else {
              context.go('/login');
            }
          },
        ),
        title: Text(_getPageTitle()),
      ),
      body: Column(
        children: [
          // Progress indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: _currentPage >= 1
                          ? AppColors.primary
                          : AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: _currentPage >= 2
                          ? AppColors.primary
                          : AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
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
                _buildVehicleInfoPage(isLoading),
                _buildWorkModePage(isLoading),
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
        return 'Araç Bilgileri';
      case 2:
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

          // E-posta
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

          // Telefon
          TextFormField(
            controller: _phoneController,
            enabled: !isLoading,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: const InputDecoration(
              labelText: 'Telefon',
              prefixIcon: Icon(Icons.phone_outlined),
              prefixText: '+90 ',
            ),
          ),

          const SizedBox(height: 16),

          // Şifre
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
      ),
    );
  }

  Widget _buildVehicleInfoPage(bool isLoading) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // TC Kimlik No
          TextFormField(
            controller: _tcNoController,
            enabled: !isLoading,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
            ],
            decoration: const InputDecoration(
              labelText: 'TC Kimlik No',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),

          const SizedBox(height: 16),

          // Araç tipi
          DropdownButtonFormField<String>(
            initialValue: _selectedVehicleType,
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
