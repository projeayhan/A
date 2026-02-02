import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/services/supabase_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final VoidCallback? onLoginSuccess;

  const LoginScreen({super.key, this.onLoginSuccess});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('Lütfen tüm alanları doldurun');
      return;
    }

    final success = await ref.read(authProvider.notifier).signIn(
      email: email,
      password: password,
    );

    if (success && mounted) {
      // Debug: Giriş sonrası session kontrolü
      debugPrint('=== LOGIN SUCCESS DEBUG ===');
      debugPrint('User ID: ${SupabaseService.currentUser?.id}');
      debugPrint('Session: ${SupabaseService.currentSession != null}');
      debugPrint('Access Token: ${SupabaseService.currentSession?.accessToken.substring(0, 20)}...');

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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);

    // Show error if any
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.status == AuthStatus.error && next.errorMessage != null) {
        _showError(next.errorMessage!);
        ref.read(authProvider.notifier).clearError();
      }
    });

    final isLoading = authState.status == AuthStatus.loading;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 48),

                // Logo
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.hexagon_outlined,
                    color: Colors.white,
                    size: 40,
                  ),
                ),

                const SizedBox(height: 24),

                // Title
                Text(
                  'Hoş Geldiniz',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),

                const SizedBox(height: 8),

                // Subtitle
                Text(
                  'Yemekten alışverişe, 7 farklı hizmet dünyasına tek bir hesaptan erişin.',
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

                // Email Input
                _buildInputField(
                  label: 'E-posta veya Kullanıcı Adı',
                  hint: 'ornek@mail.com',
                  controller: _emailController,
                  icon: Icons.mail_outline,
                  isDark: isDark,
                  enabled: !isLoading,
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
                  enabled: !isLoading,
                ),

                const SizedBox(height: 12),

                // Forgot Password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: isLoading ? null : () {
                      context.push(AppRoutes.forgotPassword);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Şifremi Unuttum?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Login Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _handleLogin,
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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

                const SizedBox(height: 32),

                // Divider
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
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
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
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
                        onPressed: isLoading ? null : _handleGoogleLogin,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSocialButton(
                        label: 'Apple',
                        icon: '',
                        isApple: true,
                        isDark: isDark,
                        onPressed: isLoading ? null : _handleAppleLogin,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 48),

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
                      onPressed: isLoading ? null : () {
                        context.push(AppRoutes.register);
                      },
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

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    required bool isDark,
    bool isPassword = false,
    bool enabled = true,
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
              color: isDark ? AppColors.textSecondaryDark : AppColors.textPrimaryLight,
            ),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: isPassword ? _obscurePassword : false,
          enabled: enabled,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
            prefixIcon: Icon(
              icon,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              size: 20,
            ),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
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
