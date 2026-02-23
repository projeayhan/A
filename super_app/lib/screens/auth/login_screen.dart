import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_dialogs.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/supabase_service.dart';
import '../../core/router/app_router.dart';

String _normalizePhone(String phone) {
  String cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
  if (cleaned.startsWith('+90')) return cleaned;
  if (cleaned.startsWith('90') && cleaned.length == 12) return '+$cleaned';
  if (cleaned.startsWith('0')) return '+90${cleaned.substring(1)}';
  if (cleaned.length == 10 && cleaned.startsWith('5')) return '+90$cleaned';
  if (cleaned.startsWith('+')) return cleaned;
  return '+90$cleaned';
}

class LoginScreen extends ConsumerStatefulWidget {
  final VoidCallback? onLoginSuccess;

  const LoginScreen({super.key, this.onLoginSuccess});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _showEmailLogin = false;
  bool _otpSent = false;
  bool _isLoading = false;

  // Countdown timer for resend
  Timer? _resendTimer;
  int _resendCountdown = 0;

  late AnimationController _logoEntrance;

  String get _normalizedPhone => _normalizePhone(_phoneController.text);

  @override
  void initState() {
    super.initState();
    _logoEntrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _logoEntrance.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _handleSendOtp() async {
    final phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (phone.length < 10) {
      AppDialogs.showError(context, 'Geçerli bir telefon numarası girin');
      return;
    }

    setState(() => _isLoading = true);

    final success = await ref.read(authProvider.notifier).sendOtp(
      phone: _normalizedPhone,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      setState(() => _otpSent = true);
      _startResendTimer();
    }
  }

  Future<void> _handleVerifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      AppDialogs.showError(context, '6 haneli doğrulama kodunu girin');
      return;
    }

    setState(() => _isLoading = true);

    final result = await ref.read(authProvider.notifier).verifyOtp(
      phone: _normalizedPhone,
      code: code,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true && mounted) {
      if (widget.onLoginSuccess != null) {
        widget.onLoginSuccess!();
      } else {
        // Check if user has a name - first check users table, then metadata
        final user = ref.read(authProvider).user;
        String existingName = '';

        // Önce users tablosundan kontrol et (asıl veri kaynağı)
        if (user != null) {
          try {
            final profile = await SupabaseService.client
                .from('users')
                .select('first_name, last_name')
                .eq('id', user.id)
                .maybeSingle();
            if (profile != null) {
              final firstName = (profile['first_name'] as String?) ?? '';
              final lastName = (profile['last_name'] as String?) ?? '';
              existingName = '$firstName $lastName'.trim();
            }
          } catch (_) {}
        }

        // users tablosunda yoksa metadata'ya bak
        if (existingName.isEmpty) {
          final metadata = user?.userMetadata;
          existingName = (metadata?['full_name'] ?? metadata?['first_name'] ?? '').toString().trim();
        }

        if (!mounted) return;
        if (existingName.isEmpty) {
          context.go(AppRoutes.personalInfo);
        } else {
          context.go(AppRoutes.home);
        }
      }
    }
  }

  Future<void> _handleResendOtp() async {
    if (_resendCountdown > 0) return;
    _otpController.clear();

    setState(() => _isLoading = true);

    final success = await ref.read(authProvider.notifier).sendOtp(
      phone: _normalizedPhone,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      _startResendTimer();
      AppDialogs.showSuccess(context, 'Yeni doğrulama kodu gönderildi');
    }
  }

  Future<void> _handleEmailLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      AppDialogs.showError(context, 'Lütfen tüm alanları doldurun');
      return;
    }

    setState(() => _isLoading = true);

    final success = await ref.read(authProvider.notifier).signIn(
      email: email,
      password: password,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success && mounted) {
      if (widget.onLoginSuccess != null) {
        widget.onLoginSuccess!();
      } else {
        context.go(AppRoutes.home);
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    await ref.read(authProvider.notifier).signInWithGoogle();
  }

  Future<void> _handleAppleLogin() async {
    await ref.read(authProvider.notifier).signInWithApple();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.status == AuthStatus.error && next.errorMessage != null) {
        AppDialogs.showError(context, next.errorMessage!);
        ref.read(authProvider.notifier).clearError();
      }
    });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 48),

                // Logo
                AnimatedBuilder(
                  animation: _logoEntrance,
                  builder: (context, child) {
                    final scale = Curves.elasticOut
                        .transform(_logoEntrance.value.clamp(0.0, 1.0));
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: Image.asset(
                    'assets/images/supercyp_logo.png',
                    width: 280,
                  ),
                ),

                const SizedBox(height: 16),

                // Subtitle
                Text(
                  'Yemekten alışverişe, 8 farklı hizmet dünyasına tek bir hesaptan erişin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 40),

                // Phone OTP or Email login
                if (_showEmailLogin)
                  _buildEmailLoginSection(isDark)
                else
                  _buildPhoneOtpSection(isDark),

                const SizedBox(height: 32),

                // Divider
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'VEYA',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Social Login Buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildSocialButton(
                        label: 'Google',
                        icon: 'G',
                        isDark: isDark,
                        onPressed: _isLoading ? null : _handleGoogleLogin,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSocialButton(
                        label: 'Apple',
                        icon: '',
                        isApple: true,
                        isDark: isDark,
                        onPressed: _isLoading ? null : _handleAppleLogin,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Toggle email/phone login
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _showEmailLogin = !_showEmailLogin;
                            _otpSent = false;
                            _otpController.clear();
                          });
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  child: Text(
                    _showEmailLogin
                        ? 'Telefon ile giriş yap'
                        : 'E-posta ile giriş yap',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),

                const SizedBox(height: 16),

                // Sign Up Prompt
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Hesabınız yok mu?',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => context.push(AppRoutes.register),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.only(left: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Kayıt Ol',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneOtpSection(bool isDark) {
    return Column(
      children: [
        if (!_otpSent) ...[
          // Phone input
          _buildInputField(
            label: 'Telefon Numarası',
            hint: '5XX XXX XX XX',
            controller: _phoneController,
            icon: Icons.phone_outlined,
            isDark: isDark,
            enabled: !_isLoading,
            keyboardType: TextInputType.phone,
            prefixText: '+90 ',
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
          ),

          const SizedBox(height: 24),

          // Send OTP Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSendOtp,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Doğrulama Kodu Gönder'),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 20),
                      ],
                    ),
            ),
          ),
        ] else ...[
          // Show phone number being verified
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.phone_outlined,
                    size: 20, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _normalizedPhone,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _otpSent = false;
                            _otpController.clear();
                          });
                        },
                  child: Text(
                    'Değiştir',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // OTP input
          _buildInputField(
            label: 'Doğrulama Kodu',
            hint: '6 haneli kodu girin',
            controller: _otpController,
            icon: Icons.lock_outline,
            isDark: isDark,
            enabled: !_isLoading,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
          ),

          const SizedBox(height: 12),

          // Resend row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Kod gelmedi mi?',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(width: 4),
              if (_resendCountdown > 0)
                Text(
                  '${_resendCountdown}s',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                )
              else
                TextButton(
                  onPressed: _isLoading ? null : _handleResendOtp,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Tekrar Gönder',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 24),

          // Verify Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleVerifyOtp,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Giriş Yap'),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 20),
                      ],
                    ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmailLoginSection(bool isDark) {
    return Column(
      children: [
        // Email Input
        _buildInputField(
          label: 'E-posta',
          hint: 'ornek@mail.com',
          controller: _emailController,
          icon: Icons.mail_outline,
          isDark: isDark,
          enabled: !_isLoading,
        ),

        const SizedBox(height: 20),

        // Password Input
        _buildInputField(
          label: 'Şifre',
          hint: '••••••••',
          controller: _passwordController,
          icon: Icons.lock_outline,
          isPassword: true,
          isDark: isDark,
          enabled: !_isLoading,
        ),

        const SizedBox(height: 12),

        // Forgot Password
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed:
                _isLoading ? null : () => context.push(AppRoutes.forgotPassword),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Şifremi Unuttum?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Login Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleEmailLogin,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Giriş Yap'),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    required bool isDark,
    bool isPassword = false,
    bool enabled = true,
    TextInputType? keyboardType,
    String? prefixText,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: isPassword ? _obscurePassword : false,
          enabled: enabled,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            prefixIcon: Icon(
              icon,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              size: 20,
            ),
            prefixText: prefixText,
            prefixStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required String label,
    required String icon,
    required bool isDark,
    VoidCallback? onPressed,
    bool isApple = false,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isApple)
            Icon(
              Icons.apple,
              size: 20,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            )
          else
            Text(
              icon,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
