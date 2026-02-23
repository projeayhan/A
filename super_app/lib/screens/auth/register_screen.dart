import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/app_dialogs.dart';

String _normalizePhone(String phone) {
  String cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
  if (cleaned.startsWith('+90')) return cleaned;
  if (cleaned.startsWith('90') && cleaned.length == 12) return '+$cleaned';
  if (cleaned.startsWith('0')) return '+90${cleaned.substring(1)}';
  if (cleaned.length == 10 && cleaned.startsWith('5')) return '+90$cleaned';
  if (cleaned.startsWith('+')) return cleaned;
  return '+90$cleaned';
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();

  final _phoneFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _nameFormKey = GlobalKey<FormState>();

  int _currentStep = 0; // 0: phone, 1: OTP, 2: name
  bool _isLoading = false;
  bool _acceptedTerms = false;

  // Countdown timer for resend
  Timer? _resendTimer;
  int _resendCountdown = 0;

  String get _normalizedPhone => _normalizePhone(_phoneController.text);

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _surnameController.dispose();
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
    if (!_phoneFormKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      AppDialogs.showError(context, 'Kullanım koşullarını kabul etmelisiniz');
      return;
    }

    setState(() => _isLoading = true);

    final success = await ref.read(authProvider.notifier).sendOtp(
      phone: _normalizedPhone,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      setState(() {
        _currentStep = 1;
      });
      _startResendTimer();
    }
  }

  Future<void> _handleResendOtp() async {
    if (_resendCountdown > 0) return;

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

  Future<void> _handleVerifyOtp() async {
    if (!_otpFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await ref.read(authProvider.notifier).verifyOtp(
      phone: _normalizedPhone,
      code: _otpController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      final user = ref.read(authProvider).user;
      final metadata = user?.userMetadata;
      final existingName = metadata?['full_name'] ?? metadata?['first_name'] ?? '';

      if (existingName.toString().trim().isNotEmpty) {
        // Returning user with name - go home
        if (mounted) context.go(AppRoutes.home);
      } else {
        // New user or no name - go to personal info to complete profile
        if (mounted) context.go(AppRoutes.personalInfo);
      }
    }
  }

  Future<void> _handleCompleteName() async {
    if (!_nameFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final success = await ref.read(authProvider.notifier).updateProfile(
      firstName: _nameController.text.trim(),
      lastName: _surnameController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      context.go(AppRoutes.home);
    } else {
      // Even if profile update fails, user is authenticated, go home
      context.go(AppRoutes.home);
    }
  }

  Future<void> _handleGoogleRegister() async {
    await ref.read(authProvider.notifier).signInWithGoogle();
  }

  Future<void> _handleAppleRegister() async {
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
      body: Stack(
        children: [
          // Background decorations
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withValues(alpha: 0.05),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 32),

                  // Logo
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.layers_outlined,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Title
                  Text(
                    _currentStep == 0
                        ? 'Hesap Oluştur'
                        : _currentStep == 1
                            ? 'Doğrulama Kodu'
                            : 'Bilgileriniz',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Subtitle
                  Text(
                    _currentStep == 0
                        ? 'Telefon numaranızla kayıt olun'
                        : _currentStep == 1
                            ? '$_normalizedPhone numarasına gönderilen kodu girin'
                            : 'Adınızı ve soyadınızı girin',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Step indicators
                  _buildStepIndicator(isDark),

                  const SizedBox(height: 32),

                  // Step content
                  if (_currentStep == 0) _buildPhoneStep(isDark),
                  if (_currentStep == 1) _buildOtpStep(isDark),
                  if (_currentStep == 2) _buildNameStep(isDark),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < 3; i++) ...[
          if (i > 0) Container(
            width: 32,
            height: 2,
            color: i <= _currentStep
                ? AppColors.primary
                : (isDark ? AppColors.borderDark : AppColors.borderLight),
          ),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i <= _currentStep
                  ? AppColors.primary
                  : (isDark ? AppColors.surfaceDark : const Color(0xFFF0F0F0)),
              border: i == _currentStep
                  ? Border.all(color: AppColors.primary, width: 2)
                  : null,
            ),
            child: Center(
              child: i < _currentStep
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: i == _currentStep
                            ? Colors.white
                            : (isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight),
                      ),
                    ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPhoneStep(bool isDark) {
    return Form(
      key: _phoneFormKey,
      child: Column(
        children: [
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
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Telefon numarası gerekli';
              }
              final cleaned = value.replaceAll(RegExp(r'\D'), '');
              if (cleaned.length < 10) {
                return 'Geçerli bir telefon numarası girin';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // Terms Checkbox
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: _acceptedTerms,
                  onChanged: _isLoading
                      ? null
                      : (value) {
                          setState(() => _acceptedTerms = value ?? false);
                        },
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _isLoading
                      ? null
                      : () {
                          setState(() => _acceptedTerms = !_acceptedTerms);
                        },
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(
                          text: 'Kullanım Koşulları',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const TextSpan(text: ' ve '),
                        TextSpan(
                          text: 'Gizlilik Politikası',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const TextSpan(
                          text: '\'nı okudum ve kabul ediyorum.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Send OTP Button
          SizedBox(
            width: double.infinity,
            height: 48,
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
                  : const Text(
                      'Doğrulama Kodu Gönder',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 24),

          // Divider
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'VEYA ŞUNUNLA KAYIT OL',
                  style: TextStyle(
                    fontSize: 10,
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
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Social Buttons
          Row(
            children: [
              Expanded(
                child: _buildSocialButton(
                  label: 'Google',
                  isDark: isDark,
                  onPressed: _isLoading ? null : _handleGoogleRegister,
                  child: CachedNetworkImage(
                    imageUrl: 'https://www.google.com/favicon.ico',
                    width: 20,
                    height: 20,
                    placeholder: (_, _) => const SizedBox(
                      width: 20,
                      height: 20,
                      child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (_, _, _) => const Text(
                      'G',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSocialButton(
                  label: 'Apple',
                  isDark: isDark,
                  onPressed: _isLoading ? null : _handleAppleRegister,
                  child: Icon(
                    Icons.apple,
                    size: 20,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Login Link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Zaten hesabınız var mı?',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              TextButton(
                onPressed: _isLoading ? null : () => context.go(AppRoutes.login),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.only(left: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Giriş Yap',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep(bool isDark) {
    return Form(
      key: _otpFormKey,
      child: Column(
        children: [
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
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Doğrulama kodu gerekli';
              }
              if (value.length != 6) {
                return '6 haneli kodu girin';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

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
            height: 48,
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
                  : const Text(
                      'Doğrula',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // Back button
          TextButton.icon(
            onPressed: _isLoading
                ? null
                : () {
                    setState(() {
                      _currentStep = 0;
                      _otpController.clear();
                    });
                  },
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Numarayı Değiştir'),
            style: TextButton.styleFrom(
              foregroundColor: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameStep(bool isDark) {
    return Form(
      key: _nameFormKey,
      child: Column(
        children: [
          // Name & Surname
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  label: 'Ad',
                  hint: 'Adınız',
                  controller: _nameController,
                  isDark: isDark,
                  enabled: !_isLoading,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ad gerekli';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInputField(
                  label: 'Soyad',
                  hint: 'Soyadınız',
                  controller: _surnameController,
                  isDark: isDark,
                  enabled: !_isLoading,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Soyad gerekli';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Complete Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleCompleteName,
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
                  : const Text(
                      'Tamamla',
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

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool isDark,
    IconData? icon,
    bool enabled = true,
    TextInputType? keyboardType,
    String? prefixText,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              fontSize: 14,
            ),
            prefixIcon: icon != null
                ? Icon(
                    icon,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    size: 20,
                  )
                : null,
            prefixText: prefixText,
            prefixStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
            filled: true,
            fillColor: isDark ? AppColors.surfaceDark : const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required String label,
    required bool isDark,
    required Widget child,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
          side: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            child,
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
