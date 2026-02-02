import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/car_models.dart';
import '../../services/dealer_service.dart';

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

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      // Satıcı mı kontrol et
      final dealerService = DealerService();
      final isDealer = await dealerService.isDealer();

      if (!mounted) return;

      if (isDealer) {
        context.go('/panel');
      } else {
        // Başvuru durumunu kontrol et
        final application = await dealerService.getApplicationStatus();

        if (!mounted) return;

        if (application != null) {
          if (application['status'] == 'pending') {
            _showPendingDialog();
          } else if (application['status'] == 'rejected') {
            _showRejectedDialog(application['rejection_reason'] as String?);
          } else {
            context.go('/application');
          }
        } else {
          context.go('/application');
        }
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = _getAuthErrorMessage(e.message);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Giriş yapılırken bir hata oluştu';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getAuthErrorMessage(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'E-posta veya şifre hatalı';
    } else if (message.contains('Email not confirmed')) {
      return 'E-posta adresinizi doğrulayın';
    }
    return 'Giriş yapılırken bir hata oluştu';
  }

  void _showPendingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: CarSalesColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.hourglass_empty, color: CarSalesColors.secondary),
            ),
            const SizedBox(width: 12),
            const Text('Başvuru Beklemede'),
          ],
        ),
        content: const Text(
          'Başvurunuz inceleme aşamasındadır. Onaylandığında size bildirim göndereceğiz.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Supabase.instance.client.auth.signOut();
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void _showRejectedDialog(String? reason) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: CarSalesColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.cancel, color: CarSalesColors.accent),
            ),
            const SizedBox(width: 12),
            const Text('Başvuru Reddedildi'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Başvurunuz reddedilmiştir.'),
            if (reason != null) ...[
              const SizedBox(height: 12),
              Text('Sebep: $reason', style: const TextStyle(color: Colors.grey)),
            ],
            const SizedBox(height: 12),
            const Text('Yeni başvuru yapabilirsiniz.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Supabase.instance.client.auth.signOut();
            },
            child: const Text('Kapat'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/application');
            },
            child: const Text('Yeni Başvuru'),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CarSalesColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lock_reset, color: CarSalesColors.primary),
              ),
              const SizedBox(width: 12),
              const Text('Şifre Sıfırlama'),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'E-posta adresinize şifre sıfırlama linki gönderilecektir.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: resetEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-posta',
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
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      setDialogState(() => isLoading = true);

                      try {
                        final dealerService = DealerService();
                        await dealerService.sendPasswordResetEmail(
                          resetEmailController.text.trim(),
                        );

                        if (!context.mounted) return;
                        Navigator.pop(context);

                        // Başarı mesajı göster
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Şifre sıfırlama linki e-posta adresinize gönderildi.',
                            ),
                            backgroundColor: CarSalesColors.success,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => isLoading = false);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Hata: ${e.toString()}'),
                            backgroundColor: CarSalesColors.accent,
                          ),
                        );
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Gönder'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CarSalesColors.backgroundLight,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
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
                  child: const Icon(Icons.directions_car, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 24),

                // Başlık
                const Text(
                  'Araç Satış Paneli',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: CarSalesColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hesabınıza giriş yapın',
                  style: TextStyle(
                    fontSize: 16,
                    color: CarSalesColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 40),

                // Form
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // E-posta
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'E-posta',
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
                          labelText: 'Şifre',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() => _obscurePassword = !_obscurePassword);
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Şifre gerekli';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),

                      // Şifremi unuttum
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showForgotPasswordDialog,
                          child: const Text('Şifremi unuttum'),
                        ),
                      ),
                      const SizedBox(height: 16),

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
                              const Icon(Icons.error_outline, color: CarSalesColors.accent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: CarSalesColors.accent),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Giriş butonu
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('Giriş Yap'),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Kayıt ol
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Hesabınız yok mu?',
                            style: TextStyle(color: CarSalesColors.textSecondaryLight),
                          ),
                          TextButton(
                            onPressed: () => context.go('/register'),
                            child: const Text('Kayıt Olun'),
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
