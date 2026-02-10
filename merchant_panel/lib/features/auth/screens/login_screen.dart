import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/services/security_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  late AnimationController _entranceController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;
  late AnimationController _glowController;

  static const _accent = Color(0xFF6366F1);
  static const _accentLight = Color(0xFF818CF8);

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
      final blockStatus = await SecurityService.checkLoginBlocked(email);
      if (blockStatus['is_blocked'] == true) {
        final blockedUntil = blockStatus['blocked_until'];
        String message =
            'Çok fazla başarısız deneme. Hesabınız geçici olarak engellendi.';
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
        final roleCheck =
            await _checkUserRole(supabase, response.user!.id);
        final roles = List<String>.from(roleCheck['roles'] ?? []);

        if (roles.isNotEmpty &&
            !roles.contains('merchant') &&
            !roles.contains('admin')) {
          await supabase.auth.signOut();
          setState(() {
            _errorMessage =
                'Bu hesapla işletme paneline giriş yapamazsınız.';
            _isLoading = false;
          });
          return;
        }

        await SecurityService.clearLoginBlocks(email);
        if (mounted) context.go('/');
      }
    } on AuthException catch (e) {
      await SecurityService.trackFailedLogin(
          email: email, errorMessage: _getAuthErrorMessage(e.message));
      setState(() => _errorMessage = _getAuthErrorMessage(e.message));
    } catch (e) {
      await SecurityService.trackFailedLogin(
          email: email, errorMessage: 'Bir hata oluştu');
      setState(() => _errorMessage = 'Bir hata olustu. Lutfen tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Map<String, dynamic>> _checkUserRole(
      SupabaseClient supabase, String userId) async {
    try {
      final response = await supabase.rpc(
        'get_user_role',
        params: {'check_user_id': userId},
      );
      if (response != null) return Map<String, dynamic>.from(response);
      return {'role': 'none', 'message': 'Rol bulunamadı'};
    } catch (e) {
      return {'role': 'none', 'message': 'Rol kontrolü başarısız'};
    }
  }

  String _getAuthErrorMessage(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'E-posta veya şifre hatalı.';
    } else if (message.contains('Email not confirmed')) {
      return 'E-posta adresiniz doğrulanmamış.';
    } else if (message.contains('Too many requests')) {
      return 'Çok fazla deneme yaptınız. Lütfen bekleyin.';
    } else if (message.contains('User not found')) {
      return 'Bu e-posta ile kayıtlı kullanıcı bulunamadı.';
    } else if (message.contains('network')) {
      return 'Bağlantı hatası. İnternet bağlantınızı kontrol edin.';
    }
    return 'Giriş başarısız: $message';
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
          // Subtle background glow
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
                    _accentLight.withValues(alpha: 0.03),
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
                            final glow = 0.15 + _glowController.value * 0.15;
                            return Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [_accent, _accentLight],
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: _accent.withValues(alpha: glow),
                                    blurRadius: 30,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.storefront_rounded,
                                size: 32,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 28),
                        // Title
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFFF9FAFB), _accentLight],
                          ).createShader(bounds),
                          child: const Text(
                            'İşletme Paneli',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'İşletmenizi tek panelden yönetin',
                          style: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 15,
                          ),
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
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 32,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444)
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFFEF4444)
                                            .withValues(alpha: 0.2),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline,
                                            color: Color(0xFFEF4444),
                                            size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            style: const TextStyle(
                                              color: Color(0xFFEF4444),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  style: const TextStyle(
                                      color: Color(0xFFF9FAFB), fontSize: 14),
                                  decoration: _inputDeco(
                                    label: 'E-posta',
                                    hint: 'ornek@email.com',
                                    icon: Icons.email_outlined,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty)
                                      return 'E-posta giriniz';
                                    if (!v.contains('@'))
                                      return 'Geçerli bir e-posta giriniz';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  style: const TextStyle(
                                      color: Color(0xFFF9FAFB), fontSize: 14),
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
                                      onPressed: () => setState(
                                          () => _obscurePassword =
                                              !_obscurePassword),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty)
                                      return 'Şifre giriniz';
                                    if (v.length < 6)
                                      return 'Şifre en az 6 karakter olmalı';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () =>
                                        context.push('/auth/forgot-password'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: _accent,
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(0, 32),
                                      textStyle:
                                          const TextStyle(fontSize: 13),
                                    ),
                                    child: const Text('Şifremi Unuttum'),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Button
                                Container(
                                  height: 50,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [_accent, _accentLight],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            _accent.withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _login,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child:
                                                CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Giriş Yap',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Hesabınız yok mu?',
                                      style: TextStyle(
                                        color: Color(0xFF6B7280),
                                        fontSize: 14,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          context.push('/auth/register'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: _accent,
                                        padding:
                                            const EdgeInsets.only(left: 4),
                                      ),
                                      child: const Text(
                                        'Kayıt Olun',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
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
}
