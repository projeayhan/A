import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/emlak_models.dart';
import '../../services/realtor_service.dart';

class RealtorLoginScreen extends ConsumerStatefulWidget {
  const RealtorLoginScreen({super.key});

  @override
  ConsumerState<RealtorLoginScreen> createState() =>
      _RealtorLoginScreenState();
}

class _RealtorLoginScreenState extends ConsumerState<RealtorLoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _realtorService = RealtorService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _showForgotPassword = false;
  bool _showRegister = false;

  late AnimationController _entranceController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;
  late AnimationController _glowController;

  static const _accent = Color(0xFF0EA5E9);
  static const _accentSecondary = Color(0xFF14B8A6);

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _entranceController.forward();
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _glowController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  InputDecoration _inputDeco({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF6B7280), size: 20),
      suffixIcon: suffix,
      labelStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
      hintStyle: const TextStyle(color: Color(0xFF4B5563), fontSize: 14),
      filled: true,
      fillColor: const Color(0xFF0A0F1C),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1F2937)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1F2937)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
      errorStyle: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      body: Stack(
        children: [
          // Background glows
          Positioned(
            top: -250,
            right: -200,
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _accent.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -300,
            left: -200,
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _accentSecondary.withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Content
          FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideUp,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo
                        AnimatedBuilder(
                          animation: _glowController,
                          builder: (context, _) {
                            final glow =
                                0.15 + _glowController.value * 0.15;
                            return Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [_accent, _accentSecondary],
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        _accent.withValues(alpha: glow),
                                    blurRadius: 30,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.real_estate_agent_rounded,
                                size: 32,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 28),
                        // Title
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              const LinearGradient(
                            colors: [
                              Color(0xFFF9FAFB),
                              _accentSecondary,
                            ],
                          ).createShader(bounds),
                          child: Text(
                            _showForgotPassword
                                ? 'Şifre Sıfırlama'
                                : _showRegister
                                    ? 'Yeni Hesap'
                                    : 'Emlakçı Paneli',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _showForgotPassword
                              ? 'E-posta adresinize sıfırlama linki gönderilecek'
                              : _showRegister
                                  ? 'Emlakçı olmak için hesap oluşturun'
                                  : 'Profesyonel emlak yönetim paneli',
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 15,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 36),
                        // Card
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111827),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Colors.black.withValues(alpha: 0.3),
                                blurRadius: 32,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: _showForgotPassword
                              ? _buildForgotPasswordForm()
                              : _showRegister
                                  ? _buildRegisterForm()
                                  : _buildLoginForm(),
                        ),
                        const SizedBox(height: 20),
                        // Toggle buttons
                        if (!_showForgotPassword) ...[
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: const Color(0xFF1F2937),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16),
                                child: Text(
                                  'veya',
                                  style: TextStyle(
                                    color: const Color(0xFF6B7280)
                                        .withValues(alpha: 0.7),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: const Color(0xFF1F2937),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _showRegister = !_showRegister;
                                  _emailController.clear();
                                  _passwordController.clear();
                                  _confirmPasswordController.clear();
                                });
                              },
                              icon: Icon(
                                _showRegister
                                    ? Icons.login
                                    : Icons.person_add_outlined,
                                size: 18,
                              ),
                              label: Text(
                                _showRegister
                                    ? 'Zaten Hesabım Var'
                                    : 'Yeni Hesap Oluştur',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _accent,
                                side: BorderSide(
                                    color:
                                        _accent.withValues(alpha: 0.3)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (_showForgotPassword) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => setState(
                                () => _showForgotPassword = false),
                            icon: const Icon(Icons.arrow_back, size: 16),
                            label: const Text('Giriş Ekranına Dön'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        // Security
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shield_outlined,
                                color: const Color(0xFF22C55E)
                                    .withValues(alpha: 0.6),
                                size: 14),
                            const SizedBox(width: 6),
                            const Text(
                              'Güvenli bağlantı ile korunuyor',
                              style: TextStyle(
                                color: Color(0xFF4B5563),
                                fontSize: 12,
                              ),
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
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style:
                const TextStyle(color: Color(0xFFF9FAFB), fontSize: 14),
            decoration: _inputDeco(
              label: 'E-posta',
              hint: 'ornek@email.com',
              icon: Icons.email_outlined,
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'E-posta gerekli';
              if (!v.contains('@')) return 'Geçerli bir e-posta girin';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style:
                const TextStyle(color: Color(0xFFF9FAFB), fontSize: 14),
            decoration: _inputDeco(
              label: 'Şifre',
              hint: '••••••••',
              icon: Icons.lock_outlined,
              suffix: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: const Color(0xFF6B7280),
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Şifre gerekli';
              if (v.length < 6) return 'Şifre en az 6 karakter olmalı';
              return null;
            },
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () =>
                  setState(() => _showForgotPassword = true),
              style: TextButton.styleFrom(
                foregroundColor: _accent,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                textStyle: const TextStyle(fontSize: 13),
              ),
              child: const Text('Şifremi Unuttum'),
            ),
          ),
          const SizedBox(height: 16),
          _buildGradientButton(
            onPressed: _isLoading ? null : _handleLogin,
            label: 'Giriş Yap',
          ),
        ],
      ),
    );
  }

  Widget _buildForgotPasswordForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _accent.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: _accent.withValues(alpha: 0.7), size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'E-posta adresinize şifre sıfırlama linki göndereceğiz.',
                    style:
                        TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style:
                const TextStyle(color: Color(0xFFF9FAFB), fontSize: 14),
            decoration: _inputDeco(
              label: 'E-posta',
              hint: 'ornek@email.com',
              icon: Icons.email_outlined,
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'E-posta gerekli';
              if (!v.contains('@')) return 'Geçerli bir e-posta girin';
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildGradientButton(
            onPressed: _isLoading ? null : _handleForgotPassword,
            label: 'Sıfırlama Linki Gönder',
            icon: Icons.send,
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style:
                const TextStyle(color: Color(0xFFF9FAFB), fontSize: 14),
            decoration: _inputDeco(
              label: 'E-posta',
              hint: 'ornek@email.com',
              icon: Icons.email_outlined,
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'E-posta gerekli';
              if (!v.contains('@')) return 'Geçerli bir e-posta girin';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style:
                const TextStyle(color: Color(0xFFF9FAFB), fontSize: 14),
            decoration: _inputDeco(
              label: 'Şifre',
              hint: 'En az 6 karakter',
              icon: Icons.lock_outlined,
              suffix: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: const Color(0xFF6B7280),
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Şifre gerekli';
              if (v.length < 6) return 'Şifre en az 6 karakter olmalı';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: true,
            style:
                const TextStyle(color: Color(0xFFF9FAFB), fontSize: 14),
            decoration: _inputDeco(
              label: 'Şifre Tekrar',
              hint: 'Şifrenizi tekrar girin',
              icon: Icons.lock_outlined,
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Şifre tekrarı gerekli';
              if (v != _passwordController.text) {
                return 'Şifreler eşleşmiyor';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildGradientButton(
            onPressed: _isLoading ? null : _handleRegister,
            label: 'Kayıt Ol',
          ),
        ],
      ),
    );
  }

  Widget _buildGradientButton({
    VoidCallback? onPressed,
    required String label,
    IconData? icon,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(colors: [_accent, _accentSecondary]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response =
          await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (response.user == null) throw Exception('Giriş başarısız');

      final isRealtor = await _realtorService.isRealtor();
      if (!mounted) return;

      if (isRealtor) {
        HapticFeedback.mediumImpact();
        context.go('/panel');
      } else {
        final application = await _realtorService.getApplicationStatus();
        if (!mounted) return;

        if (application != null) {
          if (application['status'] == 'pending' ||
              application['status'] == 'under_review') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                    'Başvurunuz henüz onaylanmadı. Lütfen bekleyin.'),
                backgroundColor: EmlakColors.accent,
              ),
            );
            context.push('/application');
          } else if (application['status'] == 'rejected') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                    'Başvurunuz reddedildi. Yeniden başvurabilirsiniz.'),
                backgroundColor: EmlakColors.error,
              ),
            );
            context.push('/application');
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  const Text('Emlakçı başvurusu yapmanız gerekiyor.'),
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
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: ${e.toString()}'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _realtorService
          .sendPasswordResetEmail(_emailController.text.trim());
      if (!mounted) return;

      HapticFeedback.mediumImpact();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF111827),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_email_read,
                    size: 36, color: Color(0xFF22C55E)),
              ),
              const SizedBox(height: 16),
              const Text(
                'E-posta Gönderildi!',
                style: TextStyle(
                  color: Color(0xFFF9FAFB),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Şifre sıfırlama linki ${_emailController.text} adresine gönderildi.',
                style: const TextStyle(color: Color(0xFF9CA3AF)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _showForgotPassword = false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Tamam'),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: ${e.toString()}'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (response.user == null) throw Exception('Kayıt başarısız');
      if (!mounted) return;

      HapticFeedback.mediumImpact();

      if (response.session == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Kayıt başarılı! E-posta doğrulama linkine tıklayın.'),
            backgroundColor: Color(0xFF22C55E),
            duration: Duration(seconds: 5),
          ),
        );
        setState(() {
          _showRegister = false;
          _emailController.clear();
          _passwordController.clear();
          _confirmPasswordController.clear();
        });
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Kayıt başarılı! Şimdi emlakçı başvurusu yapabilirsiniz.'),
          backgroundColor: Color(0xFF22C55E),
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
        default:
          message = e.message;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: ${e.toString()}'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
