import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/security_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();

    try {
      // Brute force kontrolü
      final blockStatus = await SecurityService.checkLoginBlocked(email);
      if (blockStatus['is_blocked'] == true) {
        final blockedUntil = blockStatus['blocked_until'];
        String message = 'Çok fazla başarısız deneme. Hesabınız geçici olarak engellendi.';
        if (blockedUntil != null) {
          final until = DateTime.tryParse(blockedUntil.toString());
          if (until != null) {
            final minutes = until.difference(DateTime.now()).inMinutes;
            if (minutes > 0) {
              message = 'Hesabınız $minutes dakika süreyle engellendi.';
            }
          }
        }
        setState(() {
          _errorMessage = message;
          _isLoading = false;
        });
        return;
      }

      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: _passwordController.text,
      );

      if (response.user != null) {
        // Kullanıcının rollerini kontrol et
        final roleCheck = await _checkUserRole(supabase, response.user!.id);
        final roles = List<String>.from(roleCheck['roles'] ?? []);

        // Kullanıcının rolleri var ama merchant veya admin değilse engelle
        if (roles.isNotEmpty && !roles.contains('merchant') && !roles.contains('admin')) {
          await supabase.auth.signOut();
          setState(() {
            _errorMessage = 'Bu hesapla işletme paneline giriş yapamazsınız.';
            _isLoading = false;
          });
          return;
        }

        await SecurityService.clearLoginBlocks(email);
        if (mounted) {
          context.go('/');
        }
      }
    } on AuthException catch (e) {
      await SecurityService.trackFailedLogin(email: email, errorMessage: _getAuthErrorMessage(e.message));
      setState(() {
        _errorMessage = _getAuthErrorMessage(e.message);
      });
    } catch (e) {
      await SecurityService.trackFailedLogin(email: email, errorMessage: 'Bir hata oluştu');
      setState(() {
        _errorMessage = 'Bir hata olustu. Lutfen tekrar deneyin.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _checkUserRole(SupabaseClient supabase, String userId) async {
    try {
      final response = await supabase.rpc(
        'get_user_role',
        params: {'check_user_id': userId},
      );
      if (response != null) {
        return Map<String, dynamic>.from(response);
      }
      return {'role': 'none', 'message': 'Rol bulunamadı'};
    } catch (e) {
      debugPrint('_checkUserRole error: $e');
      return {'role': 'none', 'message': 'Rol kontrolü başarısız'};
    }
  }

  String _getAuthErrorMessage(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'E-posta veya sifre hatali.';
    } else if (message.contains('Email not confirmed')) {
      return 'E-posta adresiniz dogrulanmamis. Lutfen e-postanizi kontrol edin.';
    } else if (message.contains('Too many requests')) {
      return 'Cok fazla deneme yaptiniz. Lutfen biraz bekleyin.';
    } else if (message.contains('User not found')) {
      return 'Bu e-posta ile kayitli kullanici bulunamadi.';
    } else if (message.contains('network')) {
      return 'Baglanti hatasi. Internet baglantinizi kontrol edin.';
    }
    return 'Giris basarisiz: $message';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo & Title
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.storefront,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Merchant Panel',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Isletmenizi yonetin',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

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

                // Form
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Email Field
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

                      // Password Field
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
                      const SizedBox(height: 8),

                      // Forgot Password
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.push('/auth/forgot-password'),
                          child: const Text('Sifremi Unuttum'),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Login Button
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Giris Yap'),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Register Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Hesabiniz yok mu?',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          TextButton(
                            onPressed: () => context.push('/auth/register'),
                            child: const Text('Kayit Olun'),
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
