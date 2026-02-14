import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

  // Account fields
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Company fields
  final _companyNameController = TextEditingController();
  final _companyPhoneController = TextEditingController();
  final _companyEmailController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _companyCityController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _taxOfficeController = TextEditingController();

  // Owner fields
  final _ownerNameController = TextEditingController();
  final _ownerPhoneController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _error;
  bool _registrationComplete = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _companyNameController.dispose();
    _companyPhoneController.dispose();
    _companyEmailController.dispose();
    _companyAddressController.dispose();
    _companyCityController.dispose();
    _taxNumberController.dispose();
    _taxOfficeController.dispose();
    _ownerNameController.dispose();
    _ownerPhoneController.dispose();
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

      // 2. Create rental company (pending approval)
      await Supabase.instance.client.from('rental_companies').insert({
        'owner_user_id': authResponse.user!.id,
        'company_name': _companyNameController.text.trim(),
        'phone': _companyPhoneController.text.trim(),
        'email': _companyEmailController.text.trim(),
        'address': _companyAddressController.text.trim(),
        'city': _companyCityController.text.trim(),
        'tax_number': _taxNumberController.text.trim(),
        'tax_office': _taxOfficeController.text.trim(),
        'owner_name': _ownerNameController.text.trim(),
        'owner_phone': _ownerPhoneController.text.trim(),
        'is_approved': false,
        'is_active': false,
        'commission_rate': 15.0,
        'rating': 0.0,
        'total_reviews': 0,
      });

      // Sign out until approved and send verification email
      await Supabase.instance.client.auth.signOut();
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: _emailController.text.trim(),
      );

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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.background,
              AppColors.surface,
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
                              colors: [AppColors.primary, AppColors.secondary],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.car_rental,
                            size: 36,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Title
                        const Text(
                          'Şirket Başvurusu',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Kiralama şirketinizi kaydedin',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Error message
                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: AppColors.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: AppColors.error,
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
                        if (_currentStep == 1) _buildCompanyStep(),
                        if (_currentStep == 2) _buildOwnerStep(),

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
                            const Text(
                              'Zaten hesabınız var mı? ',
                              style: TextStyle(color: AppColors.textSecondary),
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
        _buildStepDot(1, 'Şirket'),
        Expanded(child: _buildStepLine(1)),
        _buildStepDot(2, 'İletişim'),
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
            color: isActive ? AppColors.primary : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(18),
            border: isCurrent
                ? Border.all(color: AppColors.primary, width: 2)
                : null,
          ),
          child: Center(
            child: isActive && !isCurrent
                ? const Icon(Icons.check, size: 18, color: Colors.white)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : AppColors.textMuted,
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
            color: isActive ? AppColors.primary : AppColors.textMuted,
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
      color: isActive ? AppColors.primary : AppColors.surfaceLight,
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
            hintText: 'ornek@sirket.com',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'E-posta giriniz';
            }
            if (!value.contains('@')) {
              return 'Geçerli bir e-posta giriniz';
            }
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
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            hintText: 'En az 6 karakter',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Şifre giriniz';
            }
            if (value.length < 6) {
              return 'Şifre en az 6 karakter olmalı';
            }
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
                _obscureConfirmPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Şifreyi tekrar giriniz';
            }
            if (value != _passwordController.text) {
              return 'Şifreler eşleşmiyor';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCompanyStep() {
    return Column(
      children: [
        TextFormField(
          controller: _companyNameController,
          decoration: const InputDecoration(
            labelText: 'Şirket Adı *',
            prefixIcon: Icon(Icons.business),
            hintText: 'ABC Rent a Car',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Şirket adı giriniz';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _taxNumberController,
                decoration: const InputDecoration(
                  labelText: 'Vergi No *',
                  prefixIcon: Icon(Icons.badge),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vergi no giriniz';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _taxOfficeController,
                decoration: const InputDecoration(
                  labelText: 'Vergi Dairesi *',
                  prefixIcon: Icon(Icons.account_balance),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vergi dairesi giriniz';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _companyAddressController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Adres *',
            prefixIcon: Icon(Icons.location_on),
            hintText: 'Şirket adresi',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Adres giriniz';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _companyCityController,
          decoration: const InputDecoration(
            labelText: 'Şehir *',
            prefixIcon: Icon(Icons.location_city),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Şehir giriniz';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildOwnerStep() {
    return Column(
      children: [
        TextFormField(
          controller: _ownerNameController,
          decoration: const InputDecoration(
            labelText: 'Yetkili Adı Soyadı *',
            prefixIcon: Icon(Icons.person),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Yetkili adı giriniz';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _ownerPhoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Yetkili Telefon *',
            prefixIcon: Icon(Icons.phone),
            hintText: '05XX XXX XX XX',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Telefon numarası giriniz';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _companyPhoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Şirket Telefon',
            prefixIcon: Icon(Icons.business_center),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _companyEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Şirket E-posta',
            prefixIcon: Icon(Icons.email),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.info.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.info),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Başvurunuz admin onayından sonra aktif olacaktır. '
                  'Onay durumu e-posta ile bildirilecektir.',
                  style: TextStyle(
                    color: AppColors.info,
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
    // Validate current step
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
      if (_companyNameController.text.isEmpty ||
          _taxNumberController.text.isEmpty ||
          _taxOfficeController.text.isEmpty ||
          _companyAddressController.text.isEmpty ||
          _companyCityController.text.isEmpty) {
        isValid = false;
        _formKey.currentState!.validate();
      }
    } else if (_currentStep == 2) {
      if (_ownerNameController.text.isEmpty ||
          _ownerPhoneController.text.isEmpty) {
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.background,
              AppColors.surface,
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
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        size: 48,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Başvurunuz Alındı!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Şirket başvurunuz başarıyla alınmıştır. '
                      'Admin onayından sonra hesabınız aktif olacak ve '
                      'giriş yapabileceksiniz.\n\n'
                      'Onay durumu ${_emailController.text} adresine e-posta ile bildirilecektir.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
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
