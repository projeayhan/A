import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/taxi_service.dart';
import '../../core/theme/app_theme.dart';
import 'profile_screen.dart';

final _earningsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return await TaxiService.getEarningsSummary();
});

class PaymentInfoScreen extends ConsumerStatefulWidget {
  const PaymentInfoScreen({super.key});

  @override
  ConsumerState<PaymentInfoScreen> createState() => _PaymentInfoScreenState();
}

class _PaymentInfoScreenState extends ConsumerState<PaymentInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bankNameController = TextEditingController();
  final _ibanController = TextEditingController();
  final _accountHolderController = TextEditingController();

  bool _isEditingBank = false;
  bool _isSaving = false;
  bool _bankPopulated = false;

  @override
  void dispose() {
    _bankNameController.dispose();
    _ibanController.dispose();
    _accountHolderController.dispose();
    super.dispose();
  }

  void _populateBankFields(Map<String, dynamic> profile) {
    if (_bankPopulated) return;
    _bankNameController.text = profile['bank_name'] ?? '';
    _ibanController.text = profile['bank_iban'] ?? '';
    _accountHolderController.text = profile['bank_account_holder'] ?? '';
    _bankPopulated = true;
  }

  Future<void> _saveBankInfo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final success = await TaxiService.updateDriverProfile({
      'bank_name': _bankNameController.text.trim(),
      'bank_iban': _ibanController.text.trim().toUpperCase(),
      'bank_account_holder': _accountHolderController.text.trim(),
    });

    setState(() {
      _isSaving = false;
      if (success) _isEditingBank = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Banka bilgileri kaydedildi' : 'Kayit basarisiz'),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
      if (success) ref.invalidate(profileProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final earningsAsync = ref.watch(_earningsProvider);
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Odeme Bilgileri'),
        actions: [
          IconButton(
            onPressed: () {
              ref.invalidate(_earningsProvider);
              ref.invalidate(profileProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Earnings summary
            earningsAsync.when(
              data: (earnings) => _buildEarningsSummary(context, earnings),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 24),

            // Commission info
            _buildCommissionCard(context, earningsAsync),

            const SizedBox(height: 24),

            // Bank info
            profileAsync.when(
              data: (profile) {
                if (profile != null) _populateBankFields(profile);
                return _buildBankSection(context);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => _buildBankSection(context),
            ),

            const SizedBox(height: 24),

            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.info, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Kazanclariniz her hafta Pazartesi gunu banka hesabiniza aktarilir.',
                      style: TextStyle(
                        color: AppColors.info,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsSummary(BuildContext context, Map<String, dynamic> earnings) {
    final total = (earnings['total'] as num?)?.toDouble() ?? 0;
    final commissionRate = (earnings['commission_rate'] as num?)?.toDouble() ?? 20;
    final netTotal = total * (1 - commissionRate / 100);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.secondary, AppColors.secondary.withValues(alpha: 0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            'Toplam Net Kazanc',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\u20BA${netTotal.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildMiniStat(
                'Bugun',
                '\u20BA${((earnings['today'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
              ),
              _buildMiniStat(
                'Bu Hafta',
                '\u20BA${((earnings['week'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
              ),
              _buildMiniStat(
                'Bu Ay',
                '\u20BA${((earnings['month'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommissionCard(BuildContext context, AsyncValue<Map<String, dynamic>> earningsAsync) {
    final rate = earningsAsync.whenOrNull(
      data: (e) => (e['commission_rate'] as num?)?.toDouble() ?? 20,
    ) ?? 20.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.percent, color: AppColors.warning, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Komisyon Orani',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Platform Komisyonu', style: Theme.of(context).textTheme.bodyMedium),
              Text(
                '%${rate.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Her yolculuktan %${rate.toStringAsFixed(0)} platform komisyonu kesilir.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.account_balance, color: AppColors.info, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Banka Hesap Bilgileri',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    if (_isEditingBank) {
                      _saveBankInfo();
                    } else {
                      setState(() => _isEditingBank = true);
                    }
                  },
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _isEditingBank ? Icons.check : Icons.edit_outlined,
                          size: 20,
                        ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildBankField(
              controller: _bankNameController,
              label: 'Banka Adi',
              hint: 'Ornegin: Ziraat Bankasi',
              icon: Icons.business_outlined,
              enabled: _isEditingBank,
              validator: (v) => v == null || v.trim().isEmpty ? 'Banka adi gerekli' : null,
            ),
            const SizedBox(height: 16),
            _buildBankField(
              controller: _ibanController,
              label: 'IBAN',
              hint: 'TR00 0000 0000 0000 0000 0000 00',
              icon: Icons.credit_card_outlined,
              enabled: _isEditingBank,
              textCapitalization: TextCapitalization.characters,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'IBAN gerekli';
                final clean = v.replaceAll(' ', '').toUpperCase();
                if (!clean.startsWith('TR')) return 'IBAN "TR" ile baslamali';
                if (clean.length != 26) return 'IBAN 26 karakter olmali';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildBankField(
              controller: _accountHolderController,
              label: 'Hesap Sahibi',
              hint: 'Ad Soyad',
              icon: Icons.person_outline,
              enabled: _isEditingBank,
              validator: (v) => v == null || v.trim().isEmpty ? 'Hesap sahibi gerekli' : null,
            ),
            if (_isEditingBank) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _isSaving ? null : _saveBankInfo,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.secondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Banka Bilgilerini Kaydet',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBankField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool enabled,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      validator: validator,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        filled: true,
        fillColor: enabled ? AppColors.surface : AppColors.background,
      ),
    );
  }
}
