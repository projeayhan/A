import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/emlak_models.dart';
import '../../services/realtor_service.dart';

/// Emlakçı Giriş Ekranı
class RealtorLoginScreen extends ConsumerStatefulWidget {
  const RealtorLoginScreen({super.key});

  @override
  ConsumerState<RealtorLoginScreen> createState() => _RealtorLoginScreenState();
}

class _RealtorLoginScreenState extends ConsumerState<RealtorLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _realtorService = RealtorService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _showForgotPassword = false;
  bool _showRegister = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: EmlakColors.background(isDark),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),

              // Header
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [EmlakColors.primary, EmlakColors.secondary],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: EmlakColors.primary.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.real_estate_agent,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _showForgotPassword
                          ? 'Şifre Sıfırlama'
                          : _showRegister
                              ? 'Yeni Hesap Oluştur'
                              : 'Emlakçı Girişi',
                      style: TextStyle(
                        color: EmlakColors.textPrimary(isDark),
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _showForgotPassword
                          ? 'E-posta adresinize şifre sıfırlama linki gönderilecek'
                          : _showRegister
                              ? 'Emlakçı olmak için önce hesap oluşturun'
                              : 'Profesyonel emlak yönetim paneline hoş geldiniz',
                      style: TextStyle(
                        color: EmlakColors.textSecondary(isDark),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // Form
              _showForgotPassword
                  ? _buildForgotPasswordForm(isDark)
                  : _showRegister
                      ? _buildRegisterForm(isDark)
                      : _buildLoginForm(isDark),

              const SizedBox(height: 32),

              // Divider & Toggle
              if (!_showForgotPassword) ...[
                Row(
                  children: [
                    Expanded(child: Divider(color: EmlakColors.border(isDark))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'veya',
                        style: TextStyle(
                          color: EmlakColors.textTertiary(isDark),
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: EmlakColors.border(isDark))),
                  ],
                ),
                const SizedBox(height: 32),

                // Toggle Login/Register Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _showRegister = !_showRegister;
                        _emailController.clear();
                        _passwordController.clear();
                        _confirmPasswordController.clear();
                      });
                    },
                    icon: Icon(_showRegister ? Icons.login : Icons.person_add_outlined),
                    label: Text(_showRegister ? 'Zaten Hesabım Var' : 'Yeni Hesap Oluştur'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: EmlakColors.primary,
                      side: BorderSide(color: EmlakColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Footer
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _showForgotPassword = !_showForgotPassword;
                    });
                  },
                  child: Text(
                    _showForgotPassword ? 'Giriş Ekranına Dön' : '',
                    style: TextStyle(color: EmlakColors.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Email Field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: EmlakColors.textPrimary(isDark)),
            decoration: InputDecoration(
              labelText: 'E-posta',
              hintText: 'ornek@email.com',
              prefixIcon: Icon(Icons.email_outlined, color: EmlakColors.primary),
              labelStyle: TextStyle(color: EmlakColors.textSecondary(isDark)),
              hintStyle: TextStyle(color: EmlakColors.textTertiary(isDark)),
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

          // Password Field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: TextStyle(color: EmlakColors.textPrimary(isDark)),
            decoration: InputDecoration(
              labelText: 'Şifre',
              hintText: '••••••••',
              prefixIcon: Icon(Icons.lock_outline, color: EmlakColors.primary),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: EmlakColors.textSecondary(isDark),
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
              labelStyle: TextStyle(color: EmlakColors.textSecondary(isDark)),
              hintStyle: TextStyle(color: EmlakColors.textTertiary(isDark)),
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
          const SizedBox(height: 12),

          // Forgot Password Link
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                setState(() => _showForgotPassword = true);
              },
              child: Text(
                'Şifremi Unuttum',
                style: TextStyle(
                  color: EmlakColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Login Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: EmlakColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Giriş Yap',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForgotPasswordForm(bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: EmlakColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: EmlakColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: EmlakColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'E-posta adresinize şifre sıfırlama linki göndereceğiz.',
                    style: TextStyle(
                      color: EmlakColors.primary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Email Field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: EmlakColors.textPrimary(isDark)),
            decoration: InputDecoration(
              labelText: 'E-posta',
              hintText: 'ornek@email.com',
              prefixIcon: Icon(Icons.email_outlined, color: EmlakColors.primary),
              labelStyle: TextStyle(color: EmlakColors.textSecondary(isDark)),
              hintStyle: TextStyle(color: EmlakColors.textTertiary(isDark)),
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
          const SizedBox(height: 24),

          // Send Reset Link Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _handleForgotPassword,
              icon: _isLoading
                  ? const SizedBox.shrink()
                  : const Icon(Icons.send),
              label: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Şifre Sıfırlama Linki Gönder',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: EmlakColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Back to Login
          TextButton.icon(
            onPressed: () {
              setState(() => _showForgotPassword = false);
            },
            icon: Icon(Icons.arrow_back, color: EmlakColors.textSecondary(isDark)),
            label: Text(
              'Giriş Ekranına Dön',
              style: TextStyle(color: EmlakColors.textSecondary(isDark)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Supabase ile giriş yap
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (response.user == null) {
        throw Exception('Giriş başarısız');
      }

      // Emlakçı profili var mı kontrol et
      final isRealtor = await _realtorService.isRealtor();

      if (!mounted) return;

      if (isRealtor) {
        HapticFeedback.mediumImpact();
        context.go('/panel');
      } else {
        // Başvuru durumunu kontrol et
        final application = await _realtorService.getApplicationStatus();

        if (!mounted) return;

        if (application != null) {
          if (application['status'] == 'pending' || application['status'] == 'under_review') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Başvurunuz henüz onaylanmadı. Lütfen bekleyin.'),
                backgroundColor: EmlakColors.accent,
              ),
            );
            context.push('/application');
          } else if (application['status'] == 'rejected') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Başvurunuz reddedildi. Yeniden başvurabilirsiniz.'),
                backgroundColor: EmlakColors.error,
              ),
            );
            context.push('/application');
          }
        } else {
          // Henüz başvuru yok
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Emlakçı başvurusu yapmanız gerekiyor.'),
              backgroundColor: EmlakColors.accent,
            ),
          );
          context.push('/application');
        }
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      String message;
      switch (e.message) {
        case 'Invalid login credentials':
          message = 'E-posta veya şifre hatalı';
          break;
        case 'Email not confirmed':
          message = 'E-posta adresiniz doğrulanmamış';
          break;
        default:
          message = e.message;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: EmlakColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: ${e.toString()}'),
          backgroundColor: EmlakColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _realtorService.sendPasswordResetEmail(_emailController.text.trim());

      if (!mounted) return;

      HapticFeedback.mediumImpact();

      // Success dialog
      showDialog(
        context: context,
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: EmlakColors.card(isDark),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: EmlakColors.success.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mark_email_read,
                    size: 40,
                    color: EmlakColors.success,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'E-posta Gönderildi!',
                  style: TextStyle(
                    color: EmlakColors.textPrimary(isDark),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Şifre sıfırlama linki ${_emailController.text} adresine gönderildi.',
                  style: TextStyle(
                    color: EmlakColors.textSecondary(isDark),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'E-posta gelmezse spam klasörünüzü kontrol edin.',
                  style: TextStyle(
                    color: EmlakColors.textTertiary(isDark),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() => _showForgotPassword = false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EmlakColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Tamam'),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: ${e.toString()}'),
          backgroundColor: EmlakColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildRegisterForm(bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Email Field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: EmlakColors.textPrimary(isDark)),
            decoration: InputDecoration(
              labelText: 'E-posta',
              hintText: 'ornek@email.com',
              prefixIcon: Icon(Icons.email_outlined, color: EmlakColors.primary),
              labelStyle: TextStyle(color: EmlakColors.textSecondary(isDark)),
              hintStyle: TextStyle(color: EmlakColors.textTertiary(isDark)),
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

          // Password Field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: TextStyle(color: EmlakColors.textPrimary(isDark)),
            decoration: InputDecoration(
              labelText: 'Şifre',
              hintText: 'En az 6 karakter',
              prefixIcon: Icon(Icons.lock_outline, color: EmlakColors.primary),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: EmlakColors.textSecondary(isDark),
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
              labelStyle: TextStyle(color: EmlakColors.textSecondary(isDark)),
              hintStyle: TextStyle(color: EmlakColors.textTertiary(isDark)),
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

          // Confirm Password Field
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: true,
            style: TextStyle(color: EmlakColors.textPrimary(isDark)),
            decoration: InputDecoration(
              labelText: 'Şifre Tekrar',
              hintText: 'Şifrenizi tekrar girin',
              prefixIcon: Icon(Icons.lock_outline, color: EmlakColors.primary),
              labelStyle: TextStyle(color: EmlakColors.textSecondary(isDark)),
              hintStyle: TextStyle(color: EmlakColors.textTertiary(isDark)),
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

          // Register Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: EmlakColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Kayıt Ol',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Supabase ile kayıt ol
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      debugPrint('SignUp response: user=${response.user?.id}, session=${response.session?.accessToken != null}');

      if (response.user == null) {
        throw Exception('Kayıt başarısız');
      }

      if (!mounted) return;

      HapticFeedback.mediumImpact();

      // E-posta doğrulaması gerekiyorsa (session null ise)
      if (response.session == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Kayıt başarılı! E-posta adresinize gelen doğrulama linkine tıklayın.'),
            backgroundColor: EmlakColors.success,
            duration: const Duration(seconds: 5),
          ),
        );
        // Giriş ekranına dön
        setState(() {
          _showRegister = false;
          _emailController.clear();
          _passwordController.clear();
          _confirmPasswordController.clear();
        });
        return;
      }

      // Session varsa direkt başvuruya yönlendir
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Kayıt başarılı! Şimdi emlakçı başvurusu yapabilirsiniz.'),
          backgroundColor: EmlakColors.success,
        ),
      );

      context.go('/application');

    } on AuthException catch (e) {
      if (!mounted) return;
      String message;
      switch (e.message) {
        case 'User already registered':
          message = 'Bu e-posta adresi zaten kayıtlı';
          break;
        case 'Password should be at least 6 characters':
          message = 'Şifre en az 6 karakter olmalı';
          break;
        default:
          message = e.message;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: EmlakColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: ${e.toString()}'),
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
