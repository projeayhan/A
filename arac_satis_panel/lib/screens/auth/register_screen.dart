import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/car_models.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _businessNameController = TextEditingController();

  DealerType _selectedDealerType = DealerType.individual;
  String? _selectedCity;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  static const List<String> _cities = [
    'Lefkoşa',
    'Gazimağusa',
    'Girne',
    'Güzelyurt',
    'İskele',
    'Lefke',
    'Akıncılar',
    'Alayköy',
    'Değirmenlik',
    'Demirhan',
    'Gönyeli',
    'Hamitköy',
    'Haspolat',
    'Minareliköy',
    'Yeniceköy',
    'Yılmazköy',
    'Akdoğan',
    'Beyarmudu',
    'Geçitkale',
    'Mutluyaka',
    'Pile',
    'Serdarlı',
    'Tatlısu',
    'Yeniboğaziçi',
    'Alsancak',
    'Çatalköy',
    'Esentepe',
    'Karşıyaka',
    'Lapta',
    'Ozanköy',
    'Çamlıbel',
    'Karaman',
    'Kayalar',
    'Aydınköy',
    'Kalkanlı',
    'Serhatköy',
    'Yayla',
    'Zümrütköy',
    'Bafra',
    'Boğaziçi',
    'Büyükkonuk',
    'Dipkarpaz',
    'Kaplıca',
    'Mehmetçik',
    'Yeni Erenköy',
    'Ziyamet',
    'Gaziveren',
    'Yeşilırmak',
    'Yeşilyurt',
    'Cengizköy',
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _businessNameController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCity == null) {
      setState(() => _errorMessage = 'Lütfen şehir seçin');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Auth kullanıcısı oluştur
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final userId = response.user?.id;

      // 2. Başvuruyu car_dealer_applications tablosuna ekle
      await Supabase.instance.client.from('car_dealer_applications').insert({
        if (userId != null) 'user_id': userId,
        'dealer_type': _selectedDealerType.name,
        'owner_name': _ownerNameController.text.trim(),
        'business_name': _businessNameController.text.trim().isEmpty
            ? null
            : _businessNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'city': _selectedCity,
        'status': 'pending',
      });

      // 3. Oturumu kapat ve doğrulama maili gönder
      if (response.session != null) {
        await Supabase.instance.client.auth.signOut();
      }
      if (response.user != null) {
        await Supabase.instance.client.auth.resend(
          type: OtpType.signup,
          email: _emailController.text.trim(),
        );
      }

      if (!mounted) return;
      _showSuccessDialog();
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = _getAuthErrorMessage(e.message);
      });
    } catch (e) {
      setState(() {
        _errorMessage =
            'Kayıt olurken bir hata oluştu: ${e.toString().replaceAll('Exception: ', '')}';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getAuthErrorMessage(String message) {
    if (message.contains('already registered')) {
      return 'Bu e-posta zaten kayıtlı';
    } else if (message.contains('Password')) {
      return 'Şifre en az 6 karakter olmalı';
    }
    return 'Kayıt olurken bir hata oluştu';
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle, color: Colors.green, size: 32),
        ),
        title: const Text('Başvurunuz Alındı'),
        content: const Text(
          'Kaydınız ve başvurunuz başarıyla oluşturuldu.\n\n'
          'Başvurunuz admin tarafından incelendikten sonra onaylanacaktır. '
          'Onay durumu e-posta ile bildirilecektir.',
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/login');
              },
              child: const Text('Tamam'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CarSalesColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Galerici Başvurusu'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: CarSalesColors.primaryGradient,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: CarSalesColors.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.directions_car,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Galerici Başvurusu',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: CarSalesColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Araç satışına başlamak için bilgilerinizi doldurun',
                  style: TextStyle(
                    fontSize: 16,
                    color: CarSalesColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 32),

                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // === SATICI BİLGİLERİ ===
                      const Text(
                        'Satıcı Bilgileri',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Satıcı Tipi
                      const Text(
                        'Satıcı Tipi',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: DealerType.values.map((type) {
                          final isSelected = _selectedDealerType == type;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedDealerType = type),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? CarSalesColors.primary
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? CarSalesColors.primary
                                      : CarSalesColors.borderLight,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    type == DealerType.individual
                                        ? Icons.person
                                        : type == DealerType.dealer
                                        ? Icons.store
                                        : Icons.verified,
                                    color: isSelected
                                        ? Colors.white
                                        : CarSalesColors.textSecondaryLight,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    type.label,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : CarSalesColors.textPrimaryLight,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Ad Soyad
                      TextFormField(
                        controller: _ownerNameController,
                        decoration: const InputDecoration(
                          labelText: 'Ad Soyad *',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ad soyad gerekli';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // İşletme Adı
                      if (_selectedDealerType != DealerType.individual) ...[
                        TextFormField(
                          controller: _businessNameController,
                          decoration: const InputDecoration(
                            labelText: 'İşletme / Galeri Adı',
                            prefixIcon: Icon(Icons.business_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Telefon
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(11),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Telefon *',
                          prefixIcon: Icon(Icons.phone_outlined),
                          hintText: '05XX XXX XX XX',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Telefon gerekli';
                          }
                          if (value.length < 7) {
                            return 'Geçerli bir telefon numarası girin';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Şehir
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCity,
                        menuMaxHeight: 300,
                        decoration: const InputDecoration(
                          labelText: 'Şehir *',
                          prefixIcon: Icon(Icons.location_city_outlined),
                        ),
                        items: _cities
                            .map(
                              (city) => DropdownMenuItem(
                                value: city,
                                child: Text(city),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedCity = value),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Lütfen şehir seçin';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // === HESAP BİLGİLERİ ===
                      const Text(
                        'Hesap Bilgileri',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // E-posta
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'E-posta *',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'E-posta gerekli';
                          }
                          if (!value.contains('@')) {
                            return 'Geçerli bir e-posta girin';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Şifre
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Şifre *',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Şifre gerekli';
                          }
                          if (value.length < 6) {
                            return 'Şifre en az 6 karakter olmalı';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Şifre tekrar
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: 'Şifre Tekrar *',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () => setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Şifre tekrarı gerekli';
                          }
                          if (value != _passwordController.text) {
                            return 'Şifreler eşleşmiyor';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Hata mesajı
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: CarSalesColors.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: CarSalesColors.accent,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: CarSalesColors.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Başvuru butonu
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleRegister,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text('Başvuruyu Gönder'),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Giriş yap
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Zaten hesabınız var mı?',
                            style: TextStyle(
                              color: CarSalesColors.textSecondaryLight,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go('/login'),
                            child: const Text('Giriş Yapın'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
