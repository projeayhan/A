import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/admin_auth_service.dart';
import '../../../core/services/admin_log_service.dart';
import '../../../core/services/security_service.dart';
import '../../../core/router/app_router.dart';

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

  late AnimationController _entranceController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;
  late AnimationController _glowController;
  late AnimationController _shimmerController;

  static const _accent = Color(0xFF06B6D4);
  static const _accentLight = Color(0xFF22D3EE);
  static const _accentSecondary = Color(0xFF6366F1);

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
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _entranceController.forward();
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _glowController.dispose();
    _shimmerController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    final logService = ref.read(adminLogServiceProvider);
    final securityService = ref.read(securityServiceProvider);

    try {
      final blockStatus = await securityService.checkLoginBlocked(email);
      if (blockStatus['is_blocked'] == true) {
        final blockedUntil = blockStatus['blocked_until'];
        String message =
            'Çok fazla başarısız deneme. Hesabınız geçici olarak engellendi.';
        if (blockedUntil != null) {
          final until = DateTime.tryParse(blockedUntil);
          if (until != null) {
            final minutes = until.difference(DateTime.now()).inMinutes;
            if (minutes > 0) {
              message = 'Hesabınız $minutes dakika süreyle engellendi.';
            }
          }
        }
        _showError(message);
        setState(() => _isLoading = false);
        return;
      }

      final authService = ref.read(adminAuthServiceProvider);
      final result = await authService.signIn(
        email: email,
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (result.isSuccess) {
        await securityService.clearLoginBlocks(email);
        await logService.logLogin(
          email: email,
          success: true,
          adminUserId: result.admin!.id,
          adminName: result.admin!.fullName,
        );
        ref
            .read(currentAdminProvider.notifier)
            .loadAdmin(result.admin!.userId!);
        context.go(AppRoutes.dashboard);
      } else {
        final trackResult = await securityService.trackFailedLogin(
          email: email,
          errorMessage: result.error,
        );
        await logService.logLogin(
          email: email,
          success: false,
          errorMessage: result.error,
        );

        final attemptCount = trackResult['attempt_count'] ?? 0;
        final isBlocked = trackResult['is_blocked'] == true;

        if (isBlocked) {
          final blockMinutes = trackResult['block_minutes'] ?? 15;
          _showError(
              'Çok fazla başarısız deneme. Hesabınız $blockMinutes dakika süreyle engellendi.');
        } else if (attemptCount >= 3) {
          final remaining = 5 - attemptCount;
          _showError(
              '${result.error ?? 'Giriş başarısız'}. $remaining deneme hakkınız kaldı.');
        } else {
          _showError(result.error ?? 'Giriş başarısız oldu');
        }
      }
    } catch (e) {
      await logService.logLogin(
        email: email,
        success: false,
        errorMessage: e.toString(),
      );
      if (mounted) _showError('Beklenmeyen bir hata oluştu');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
    final isWide = MediaQuery.of(context).size.width > 900;
    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      body: isWide ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left - Branding
        Expanded(
          flex: 5,
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF030712), Color(0xFF0A0F1C)],
                  ),
                ),
              ),

              // Subtle glow
              Positioned(
                top: -150,
                left: -100,
                child: AnimatedBuilder(
                  animation: _glowController,
                  builder: (context, _) {
                    final scale = 1.0 + _glowController.value * 0.1;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 500,
                        height: 500,
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
                    );
                  },
                ),
              ),
              Positioned(
                bottom: -200,
                right: -100,
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _accentSecondary.withValues(alpha: 0.04),
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
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo with effects
                          AnimatedBuilder(
                            animation: Listenable.merge([_entranceController, _shimmerController]),
                            builder: (context, child) {
                              final scale = Curves.elasticOut.transform(_entranceController.value.clamp(0.0, 1.0));
                              final sv = _shimmerController.value;
                              final showShimmer = sv <= 0.3;
                              final sp = showShimmer ? sv / 0.3 : 0.0;
                              Widget logo = child!;
                              if (showShimmer) {
                                logo = ShaderMask(
                                  shaderCallback: (bounds) => LinearGradient(
                                    begin: Alignment(sp * 4 - 2, -0.3),
                                    end: Alignment(sp * 4 - 1, 0.3),
                                    colors: const [
                                      Color(0x00FFFFFF),
                                      Color(0x40FFFFFF),
                                      Color(0x00FFFFFF),
                                    ],
                                  ).createShader(bounds),
                                  blendMode: BlendMode.srcATop,
                                  child: logo,
                                );
                              }
                              return Transform.scale(
                                scale: scale,
                                child: logo,
                              );
                            },
                            child: Image.asset(
                              'assets/images/supercyp_logo.png',
                              width: 320,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'ADMIN KONTROL MERKEZİ',
                            style: TextStyle(
                              color: _accent.withValues(alpha: 0.7),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(height: 48),
                          ..._buildFeatures(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 24,
                left: 24,
                child: Text(
                  'v1.0.0',
                  style: TextStyle(
                    color: const Color(0xFF6B7280).withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(width: 1, color: const Color(0xFF1F2937)),
        // Right - Form
        Expanded(flex: 4, child: _buildFormSection()),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Stack(
      children: [
        Positioned(
          top: -200,
          right: -150,
          child: Container(
            width: 500,
            height: 500,
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
        FadeTransition(
          opacity: _fadeIn,
          child: SlideTransition(
            position: _slideUp,
            child: _buildFormSection(showLogo: true),
          ),
        ),
      ],
    );
  }

  Widget _buildFormSection({bool showLogo = false}) {
    return Container(
      color: const Color(0xFF030712),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showLogo) ...[
                  Center(
                    // Logo with effects
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_entranceController, _shimmerController]),
                      builder: (context, child) {
                        final scale = Curves.elasticOut.transform(_entranceController.value.clamp(0.0, 1.0));
                        final sv = _shimmerController.value;
                        final showShimmer = sv <= 0.3;
                        final sp = showShimmer ? sv / 0.3 : 0.0;
                        Widget logo = child!;
                        if (showShimmer) {
                          logo = ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              begin: Alignment(sp * 4 - 2, -0.3),
                              end: Alignment(sp * 4 - 1, 0.3),
                              colors: const [
                                Color(0x00FFFFFF),
                                Color(0x40FFFFFF),
                                Color(0x00FFFFFF),
                              ],
                            ).createShader(bounds),
                            blendMode: BlendMode.srcATop,
                            child: logo,
                          );
                        }
                        return Transform.scale(
                          scale: scale,
                          child: logo,
                        );
                      },
                      child: Image.asset(
                        'assets/images/supercyp_logo.png',
                        width: 280,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'Devam etmek için giriş yapın',
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 36),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(
                            color: Color(0xFFF9FAFB), fontSize: 14),
                        decoration: _inputDeco(
                          label: 'E-posta',
                          hint: 'admin@supercyp.com',
                          icon: Icons.email_outlined,
                        ),
                        validator: (v) {
                          if (v?.isEmpty ?? true) return 'E-posta gerekli';
                          if (!v!.contains('@')) {
                            return 'Geçerli bir e-posta girin';
                          }
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
                          icon: Icons.lock_outline,
                          suffix: IconButton(
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: const Color(0xFF6B7280),
                              size: 20,
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v?.isEmpty ?? true) return 'Şifre gerekli';
                          if (v!.length < 6) {
                            return 'Şifre en az 6 karakter olmalı';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.push('/forgot-password'),
                          child: const Text(
                            'Şifremi Unuttum',
                            style: TextStyle(
                              color: _accentLight,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Button
                      Container(
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_accent, _accentSecondary],
                          ),
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
                          onPressed: _isLoading ? null : _handleLogin,
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
                              : const Text(
                                  'Giriş Yap',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Security
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.shield_outlined,
                                color: const Color(0xFF22C55E)
                                    .withValues(alpha: 0.6),
                                size: 16),
                            const SizedBox(width: 8),
                            const Text(
                              'Güvenli bağlantı ile korunuyor',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
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

  List<Widget> _buildFeatures() {
    final features = [
      (Icons.analytics_rounded, 'Gerçek Zamanlı Analitik'),
      (Icons.people_rounded, 'Kullanıcı Yönetimi'),
      (Icons.store_rounded, 'İşletme Kontrolü'),
      (Icons.local_shipping_rounded, 'Kurye Takibi'),
    ];

    return features
        .map((f) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _accent.withValues(alpha: 0.1)),
                    ),
                    child: Icon(f.$1, color: _accent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    f.$2,
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ))
        .toList();
  }
}