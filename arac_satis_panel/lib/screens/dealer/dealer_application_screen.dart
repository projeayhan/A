import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/car_models.dart';

class DealerApplicationScreen extends StatefulWidget {
  const DealerApplicationScreen({super.key});

  @override
  State<DealerApplicationScreen> createState() => _DealerApplicationScreenState();
}

class _DealerApplicationScreenState extends State<DealerApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

  // Account fields
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Dealer fields
  final _businessNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _taxNumberController = TextEditingController();

  // Location fields
  final _addressController = TextEditingController();
  String? _selectedCity;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _error;
  bool _registrationComplete = false;

  static const List<String> _cities = [
    'Lefkoşa', 'Gazimağusa', 'Girne', 'Güzelyurt', 'İskele', 'Lefke',
    'Akıncılar', 'Alayköy', 'Değirmenlik', 'Demirhan', 'Gönyeli',
    'Hamitköy', 'Haspolat', 'Minareliköy', 'Yeniceköy', 'Yılmazköy',
    'Akdoğan', 'Beyarmudu', 'Geçitkale', 'Mutluyaka', 'Pile',
    'Serdarlı', 'Tatlısu', 'Yeniboğaziçi',
    'Alsancak', 'Çatalköy', 'Esentepe', 'Karşıyaka', 'Lapta',
    'Ozanköy', 'Çamlıbel', 'Karaman', 'Kayalar',
    'Aydınköy', 'Kalkanlı', 'Serhatköy', 'Yayla', 'Zümrütköy',
    'Bafra', 'Boğaziçi', 'Büyükkonuk', 'Dipkarpaz', 'Kaplıca',
    'Mehmetçik', 'Yeni Erenköy', 'Ziyamet',
    'Gaziveren', 'Yeşilırmak', 'Yeşilyurt', 'Cengizköy',
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _taxNumberController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Create user account
      final authResponse = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (authResponse.user == null) {
        throw Exception('Kullanıcı oluşturulamadı');
      }

      // 2. Create dealer application (pending approval)
      await Supabase.instance.client.from('car_dealer_applications').insert({
        'user_id': authResponse.user!.id,
        'dealer_type': 'dealer',
        'owner_name': _ownerNameController.text.trim(),
        'business_name': _businessNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'tax_number': _taxNumberController.text.trim().isEmpty
            ? null
            : _taxNumberController.text.trim(),
        'city': _selectedCity,
        'address': _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        'status': 'pending',
      });

      // Sign out until approved
      await Supabase.instance.client.auth.signOut();

      if (mounted) {
        setState(() {
          _registrationComplete = true;
          _isLoading = false;
        });
      }
    } on AuthException catch (e) {
      setState(() {
        _error = _getErrorMessage(e.message);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Bir hata oluştu: $e';
        _isLoading = false;
      });
    }
  }

  String _getErrorMessage(String message) {
    if (message.contains('already registered')) {
      return 'Bu e-posta adresi zaten kayıtlı.';
    }
    if (message.contains('weak password')) {
      return 'Şifre çok zayıf. En az 6 karakter kullanın.';
    }
    if (message.contains('invalid email')) {
      return 'Geçersiz e-posta adresi.';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    if (_registrationComplete) {
      return _buildSuccessScreen();
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              CarSalesColors.backgroundLight,
              CarSalesColors.backgroundLight.withValues(alpha: 0.95),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: CarSalesColors.primaryGradient,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.directions_car,
                            size: 36,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Title
                        const Text(
                          'Galerici Başvurusu',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: CarSalesColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Araç galerinizi kaydedin',
                          style: TextStyle(
                            color: CarSalesColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Error message
                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: CarSalesColors.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: CarSalesColors.accent.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: CarSalesColors.accent,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: CarSalesColors.accent,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Step indicator
                        _buildStepIndicator(),
                        const SizedBox(height: 24),

                        // Step content
                        if (_currentStep == 0) _buildAccountStep(),
                        if (_currentStep == 1) _buildDealerStep(),
                        if (_currentStep == 2) _buildLocationStep(),

                        const SizedBox(height: 24),

                        // Navigation buttons
                        Row(
                          children: [
                            if (_currentStep > 0)
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      _currentStep--;
                                    });
                                  },
                                  child: const Text('Geri'),
                                ),
                              ),
                            if (_currentStep > 0) const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _onNextPressed,
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        _currentStep < 2 ? 'Devam' : 'Başvuru Yap',
                                      ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Login link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Zaten hesabınız var mı? ',
                              style: TextStyle(color: CarSalesColors.textSecondaryLight),
                            ),
                            TextButton(
                              onPressed: () => context.go('/login'),
                              child: const Text('Giriş Yap'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _buildStepDot(0, 'Hesap'),
        Expanded(child: _buildStepLine(0)),
        _buildStepDot(1, 'Galeri'),
        Expanded(child: _buildStepLine(1)),
        _buildStepDot(2, 'Konum'),
      ],
    );
  }

  Widget _buildStepDot(int step, String label) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;

    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isActive ? CarSalesColors.primary : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(18),
            border: isCurrent
                ? Border.all(color: CarSalesColors.primary, width: 2)
                : null,
          ),
          child: Center(
            child: isActive && !isCurrent
                ? const Icon(Icons.check, size: 18, color: Colors.white)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isActive ? CarSalesColors.primary : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int beforeStep) {
    final isActive = _currentStep > beforeStep;
    return Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 20),
      color: isActive ? CarSalesColors.primary : Colors.grey.shade200,
    );
  }

  Widget _buildAccountStep() {
    return Column(
      children: [
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'E-posta *',
            prefixIcon: Icon(Icons.email_outlined),
            hintText: 'ornek@email.com',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'E-posta giriniz';
            if (!value.contains('@')) return 'Geçerli bir e-posta giriniz';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Şifre *',
            prefixIcon: const Icon(Icons.lock_outlined),
            hintText: 'En az 6 karakter',
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Şifre giriniz';
            if (value.length < 6) return 'Şifre en az 6 karakter olmalı';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            labelText: 'Şifre Tekrar *',
            prefixIcon: const Icon(Icons.lock_outlined),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              ),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Şifreyi tekrar giriniz';
            if (value != _passwordController.text) return 'Şifreler eşleşmiyor';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDealerStep() {
    return Column(
      children: [
        TextFormField(
          controller: _businessNameController,
          decoration: const InputDecoration(
            labelText: 'Galeri Adı *',
            prefixIcon: Icon(Icons.store),
            hintText: 'ABC Otomotiv',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Galeri adı giriniz';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _ownerNameController,
          decoration: const InputDecoration(
            labelText: 'Yetkili Adı Soyadı *',
            prefixIcon: Icon(Icons.person),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Yetkili adı giriniz';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          decoration: const InputDecoration(
            labelText: 'Telefon *',
            prefixIcon: Icon(Icons.phone),
            hintText: '05XX XXX XX XX',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Telefon numarası giriniz';
            if (value.length < 7) return 'Geçerli bir telefon numarası giriniz';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _taxNumberController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          decoration: const InputDecoration(
            labelText: 'Vergi Numarası',
            prefixIcon: Icon(Icons.badge),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationStep() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedCity,
          menuMaxHeight: 300,
          decoration: const InputDecoration(
            labelText: 'Şehir *',
            prefixIcon: Icon(Icons.location_city),
          ),
          items: _cities
              .map((city) => DropdownMenuItem(value: city, child: Text(city)))
              .toList(),
          onChanged: (value) => setState(() => _selectedCity = value),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Şehir seçiniz';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _addressController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Galeri Adresi',
            prefixIcon: Icon(Icons.location_on),
            hintText: 'Galeri adresi',
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CarSalesColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: CarSalesColors.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: CarSalesColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Başvurunuz admin onayından sonra aktif olacaktır. '
                  'Onay durumu e-posta ile bildirilecektir.',
                  style: TextStyle(
                    color: CarSalesColors.primary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _onNextPressed() {
    bool isValid = true;

    if (_currentStep == 0) {
      if (_emailController.text.isEmpty ||
          !_emailController.text.contains('@') ||
          _passwordController.text.isEmpty ||
          _passwordController.text.length < 6 ||
          _confirmPasswordController.text != _passwordController.text) {
        isValid = false;
        _formKey.currentState!.validate();
      }
    } else if (_currentStep == 1) {
      if (_businessNameController.text.isEmpty ||
          _ownerNameController.text.isEmpty ||
          _phoneController.text.isEmpty ||
          _phoneController.text.length < 7) {
        isValid = false;
        _formKey.currentState!.validate();
      }
    } else if (_currentStep == 2) {
      if (_selectedCity == null) {
        isValid = false;
        _formKey.currentState!.validate();
      }
    }

    if (!isValid) return;

    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
    } else {
      _register();
    }
  }

  Widget _buildSuccessScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              CarSalesColors.backgroundLight,
              CarSalesColors.backgroundLight.withValues(alpha: 0.95),
            ],
          ),
        ),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: CarSalesColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        size: 48,
                        color: CarSalesColors.success,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Başvurunuz Alındı!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: CarSalesColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Galeri başvurunuz başarıyla alınmıştır. '
                      'Admin onayından sonra hesabınız aktif olacak ve '
                      'giriş yapabileceksiniz.\n\n'
                      'Onay durumu ${_emailController.text} adresine e-posta ile bildirilecektir.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: CarSalesColors.textSecondaryLight,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Giriş Sayfasına Dön'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
