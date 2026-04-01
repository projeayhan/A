import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/app_dialogs.dart';
import '../../l10n/app_localizations.dart';

class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  bool _biometricEnabled = false;
  StreamSubscription? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = SupabaseService.authStateChanges.listen((authState) {
      if (mounted) setState(() {});
    });
    _loadBiometricSetting();
  }

  Future<void> _loadBiometricSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _biometricEnabled = prefs.getBool('biometric_enabled') ?? false);
    }
  }

  Future<void> _saveBiometricSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', value);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  String? get _userEmail =>
      SupabaseService.currentUser?.email?.isNotEmpty == true
          ? SupabaseService.currentUser?.email
          : null;

  String? get _pendingEmail => SupabaseService.currentUser?.newEmail;

  bool get _hasConfirmedEmail => SupabaseService.hasConfirmedEmail;
  bool get _hasPassword => !SupabaseService.isOAuthUser;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[200]!),
            ),
            child: Icon(Icons.arrow_back_ios_new, size: 16, color: isDark ? Colors.white : Colors.grey[800]),
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          S.of(context)!.passwordAndSecurity,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // E-posta bölümü
            _buildSettingsCard(isDark, [
              _buildEmailItem(isDark),
            ]),

            const SizedBox(height: 16),

            // Şifre bölümü
            _buildSettingsCard(isDark, [
              _buildNavigationItem(
                icon: Icons.lock_outline,
                title: _hasPassword ? S.of(context)!.changePassword : S.of(context)!.setPassword,
                subtitle: _hasPassword
                    ? S.of(context)!.changePasswordSubtitle
                    : _hasConfirmedEmail
                        ? S.of(context)!.setPasswordSubtitle
                        : S.of(context)!.addEmailFirst,
                color: _hasConfirmedEmail || _hasPassword
                    ? const Color(0xFF3B82F6)
                    : Colors.grey,
                isDark: isDark,
                onTap: () {
                  if (!_hasConfirmedEmail && !_hasPassword) {
                    AppDialogs.showError(context, S.of(context)!.verifyEmailFirst);
                    return;
                  }
                  _hasPassword ? _showChangePasswordDialog() : _showSetPasswordDialog();
                },
              ),
            ]),

            const SizedBox(height: 16),

            // Biyometrik Giriş
            _buildSettingsCard(isDark, [
              _buildSwitchItem(
                icon: Icons.fingerprint,
                title: S.of(context)!.biometricLogin,
                subtitle: S.of(context)!.biometricLoginSubtitle,
                color: const Color(0xFF10B981),
                isDark: isDark,
                value: _biometricEnabled,
                onChanged: (v) {
                  setState(() => _biometricEnabled = v);
                  _saveBiometricSetting(v);
                },
              ),
            ]),

            const SizedBox(height: 32),

            // Çıkış Yap Butonu
            GestureDetector(
              onTap: () => _showLogoutDialog(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout, color: Colors.red, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      S.of(context)!.signOut,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailItem(bool isDark) {
    final email = _userEmail;
    final pending = _pendingEmail;

    String title;
    String subtitle;
    Color color;
    IconData icon;
    Widget? trailing;

    if (pending != null && pending.isNotEmpty) {
      title = S.of(context)!.awaitingEmailVerification;
      subtitle = pending;
      color = const Color(0xFFF59E0B);
      icon = Icons.mark_email_unread_outlined;
      trailing = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          S.of(context)!.pending,
          style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600),
        ),
      );
    } else if (email == null || email.isEmpty) {
      title = S.of(context)!.addEmail;
      subtitle = S.of(context)!.addEmailSubtitle;
      color = const Color(0xFFF59E0B);
      icon = Icons.email_outlined;
    } else if (!_hasConfirmedEmail) {
      title = S.of(context)!.awaitingEmailVerification;
      subtitle = email;
      color = const Color(0xFFF59E0B);
      icon = Icons.mark_email_unread_outlined;
      trailing = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          S.of(context)!.pending,
          style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600),
        ),
      );
    } else {
      title = 'E-posta';
      subtitle = email;
      color = const Color(0xFF10B981);
      icon = Icons.email_outlined;
      trailing = const Icon(Icons.verified, color: Colors.green, size: 20);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showEmailDialog(isDark),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ?? Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmailDialog(bool isDark) {
    final emailController = TextEditingController(text: _userEmail ?? '');
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.5,
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _userEmail == null ? S.of(context)!.addEmail : S.of(context)!.changeEmail,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  S.of(context)!.emailVerificationMessage,
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: S.of(context)!.emailAddress,
                    labelStyle: TextStyle(color: Colors.grey[500]),
                    filled: true,
                    fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
                    prefixIcon: Icon(Icons.email_outlined, color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[200]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            final email = emailController.text.trim();
                            if (email.isEmpty || !email.contains('@')) {
                              await AppDialogs.showError(context, S.of(context)!.enterValidEmail);
                              return;
                            }
                            setModalState(() => isLoading = true);
                            try {
                              await SupabaseService.updateEmail(email);
                              if (context.mounted) {
                                Navigator.pop(context);
                                setState(() {});
                                await AppDialogs.showSuccess(
                                  context,
                                  S.of(context)!.verificationLinkSent(email),
                                );
                              }
                            } catch (e) {
                              setModalState(() => isLoading = false);
                              if (context.mounted) {
                                await AppDialogs.showError(context, 'Hata: ${e.toString().replaceAll('Exception: ', '')}');
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                          )
                        : Text(S.of(context)!.sendVerificationLink, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      emailController.dispose();
    });
  }

  Widget _buildSettingsCard(bool isDark, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildNavigationItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.9,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: AppColors.primary,
              activeThumbColor: Colors.white,
              inactiveTrackColor: isDark ? Colors.grey[700] : Colors.grey[300],
              inactiveThumbColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                S.of(context)!.changePassword,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 24),
              _buildPasswordField(currentPasswordController, S.of(context)!.currentPassword, isDark),
              const SizedBox(height: 16),
              _buildPasswordField(newPasswordController, S.of(context)!.newPassword, isDark),
              const SizedBox(height: 16),
              _buildPasswordField(confirmPasswordController, S.of(context)!.confirmNewPassword, isDark),
              const SizedBox(height: 12),
              Text(
                S.of(context)!.passwordMinLength,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final current = currentPasswordController.text;
                    final newPass = newPasswordController.text;
                    final confirm = confirmPasswordController.text;
                    if (current.isEmpty || newPass.length < 8) {
                      await AppDialogs.showError(context, S.of(context)!.passwordMinError);
                      return;
                    }
                    if (newPass != confirm) {
                      await AppDialogs.showError(context, S.of(context)!.passwordsDoNotMatch);
                      return;
                    }
                    try {
                      await SupabaseService.changePassword(
                        currentPassword: current,
                        newPassword: newPass,
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        await AppDialogs.showSuccess(context, S.of(context)!.passwordChanged);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        await AppDialogs.showError(context, 'Hata: ${e.toString().replaceAll('Exception: ', '')}');
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    S.of(context)!.changePasswordButton,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      currentPasswordController.dispose();
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    });
  }

  Widget _buildPasswordField(TextEditingController controller, String label, bool isDark) {
    bool obscure = true;
    return StatefulBuilder(
      builder: (context, setFieldState) {
        return TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.grey[500]),
            filled: true,
            fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[400]),
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: Colors.grey[400],
              ),
              onPressed: () => setFieldState(() => obscure = !obscure),
            ),
          ),
        );
      },
    );
  }

  void _showSetPasswordDialog() {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.55,
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  S.of(context)!.setPassword,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  S.of(context)!.setPasswordMessage,
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
                const SizedBox(height: 24),
                _buildPasswordField(newPasswordController, S.of(context)!.newPassword, isDark),
                const SizedBox(height: 16),
                _buildPasswordField(confirmPasswordController, S.of(context)!.confirmPassword, isDark),
                const SizedBox(height: 12),
                Text(
                  S.of(context)!.passwordMinLength,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            final newPass = newPasswordController.text;
                            final confirmPass = confirmPasswordController.text;
                            if (newPass.length < 8) {
                              await AppDialogs.showError(context, S.of(context)!.passwordMinError);
                              return;
                            }
                            if (newPass != confirmPass) {
                              await AppDialogs.showError(context, S.of(context)!.passwordsDoNotMatch);
                              return;
                            }
                            setModalState(() => isLoading = true);
                            try {
                              await SupabaseService.setPassword(newPass);
                              if (context.mounted) {
                                Navigator.pop(context);
                                setState(() {});
                                await AppDialogs.showSuccess(context, S.of(context)!.passwordSet);
                              }
                            } catch (e) {
                              setModalState(() => isLoading = false);
                              if (context.mounted) {
                                await AppDialogs.showError(context, 'Hata: ${e.toString().replaceAll('Exception: ', '')}');
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                          )
                        : Text(
                            S.of(context)!.setPasswordButton,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    });
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.logout, color: Colors.red),
            const SizedBox(width: 12),
            Text(S.of(context)!.signOut),
          ],
        ),
        content: Text(S.of(context)!.signOutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.of(context)!.cancel, style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).signOut();
              context.go('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(S.of(context)!.signOut, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
