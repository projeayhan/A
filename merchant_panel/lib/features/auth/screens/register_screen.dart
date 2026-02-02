import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/models/merchant_models.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  MerchantType _selectedType = MerchantType.restaurant;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _businessNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = ref.read(supabaseClientProvider);

      // Create auth user
      final authResponse = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {
          'full_name': _businessNameController.text.trim(),
          'phone': _phoneController.text.trim(),
        },
      );

      if (authResponse.user != null) {
        // Create merchant record
        await supabase.from('merchants').insert({
          'user_id': authResponse.user!.id,
          'type': _selectedType.name,
          'business_name': _businessNameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'is_approved': false,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kayit basarili! Hesabiniz onay bekliyor.'),
              backgroundColor: AppColors.success,
            ),
          );
          context.go('/auth/login');
        }
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = _getAuthErrorMessage(e.message);
      });
    } on PostgrestException catch (e) {
      setState(() {
        _errorMessage = 'Veritabani hatasi: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Kayit sirasinda bir hata olustu: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getAuthErrorMessage(String message) {
    if (message.contains('already registered') || message.contains('already exists')) {
      return 'Bu e-posta adresi zaten kayitli.';
    } else if (message.contains('Invalid email')) {
      return 'Gecersiz e-posta adresi.';
    } else if (message.contains('Password')) {
      return 'Sifre en az 6 karakter olmali.';
    } else if (message.contains('network')) {
      return 'Baglanti hatasi. Internet baglantinizi kontrol edin.';
    }
    return 'Kayit hatasi: $message';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title
                Text(
                  'Isletme Kaydi',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Isletmenizi kaydedin ve siparisleri almaya baslayin',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Error Message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withValues(alpha:0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Business Type Selection
                Text(
                  'Isletme Tipi',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _TypeCard(
                        type: MerchantType.restaurant,
                        isSelected: _selectedType == MerchantType.restaurant,
                        onTap: () => setState(() => _selectedType = MerchantType.restaurant),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TypeCard(
                        type: MerchantType.store,
                        isSelected: _selectedType == MerchantType.store,
                        onTap: () => setState(() => _selectedType = MerchantType.store),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Form
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Business Name
                      TextFormField(
                        controller: _businessNameController,
                        decoration: InputDecoration(
                          labelText: 'Isletme Adi',
                          hintText: _selectedType == MerchantType.restaurant
                              ? 'Restoran adiniz'
                              : 'Magaza adiniz',
                          prefixIcon: Icon(_selectedType.icon),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Isletme adi giriniz';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Email
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'E-posta',
                          hintText: 'ornek@email.com',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'E-posta giriniz';
                          }
                          if (!value.contains('@')) {
                            return 'Gecerli bir e-posta giriniz';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Phone
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Telefon',
                          hintText: '+90 5XX XXX XX XX',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Telefon giriniz';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Sifre',
                          hintText: '********',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Sifre giriniz';
                          }
                          if (value.length < 6) {
                            return 'Sifre en az 6 karakter olmali';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Confirm Password
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: 'Sifre Tekrar',
                          hintText: '********',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
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
                            return 'Sifre tekrar giriniz';
                          }
                          if (value != _passwordController.text) {
                            return 'Sifreler eslesmeli';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      // Register Button
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _register,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Kayit Ol'),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Login Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Zaten hesabiniz var mi?',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          TextButton(
                            onPressed: () => context.go('/auth/login'),
                            child: const Text('Giris Yapin'),
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

class _TypeCard extends StatelessWidget {
  final MerchantType type;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeCard({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? (type == MerchantType.restaurant
                  ? AppColors.restaurant.withValues(alpha:0.1)
                  : AppColors.store.withValues(alpha:0.1))
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (type == MerchantType.restaurant
                    ? AppColors.restaurant
                    : AppColors.store)
                : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              type.icon,
              size: 40,
              color: isSelected
                  ? (type == MerchantType.restaurant
                      ? AppColors.restaurant
                      : AppColors.store)
                  : AppColors.textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              type.displayName,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? (type == MerchantType.restaurant
                        ? AppColors.restaurant
                        : AppColors.store)
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
