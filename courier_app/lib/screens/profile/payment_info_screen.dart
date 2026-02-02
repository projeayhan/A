import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/courier_service.dart';
import '../../core/theme/app_theme.dart';

class PaymentInfoScreen extends ConsumerStatefulWidget {
  const PaymentInfoScreen({super.key});

  @override
  ConsumerState<PaymentInfoScreen> createState() => _PaymentInfoScreenState();
}

class _PaymentInfoScreenState extends ConsumerState<PaymentInfoScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await CourierService.getCourierProfile();
    if (mounted) {
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ödeme Bilgileri'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() => _isLoading = true);
              _loadProfile();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text(
            'Bilgiler yüklenemedi',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              setState(() => _isLoading = true);
              _loadProfile();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final bankName = _profile!['bank_name'] as String? ?? '';
    final bankIban = _profile!['bank_iban'] as String? ?? '';
    final accountHolder = _profile!['full_name'] as String? ?? '';
    final totalEarnings = (_profile!['total_earnings'] as num?)?.toDouble() ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Payment Info Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.account_balance,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            'Doğrulanmış',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Toplam Kazanç',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₺${totalEarnings.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Haftalık ödemeler her Pazartesi',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Info Notice
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.info.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.info, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Banka bilgilerinizi değiştirmek için destek ekibiyle iletişime geçin.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.info,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Bank Details
          Text(
            'Banka Bilgileri',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          _buildInfoCard([
            _buildInfoRow(
              icon: Icons.account_balance_outlined,
              label: 'Banka',
              value: bankName.isEmpty ? 'Belirtilmemiş' : bankName,
            ),
            _buildInfoRow(
              icon: Icons.person_outline,
              label: 'Hesap Sahibi',
              value: accountHolder.isEmpty ? 'Belirtilmemiş' : accountHolder,
            ),
            _buildIbanRow(bankIban),
          ]),

          const SizedBox(height: 24),

          // Payment Schedule
          Text(
            'Ödeme Takvimi',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _buildScheduleRow(
                  icon: Icons.calendar_today,
                  title: 'Ödeme Günü',
                  value: 'Her Pazartesi',
                  color: AppColors.primary,
                ),
                const Divider(height: 1),
                _buildScheduleRow(
                  icon: Icons.payments_outlined,
                  title: 'Minimum Ödeme',
                  value: '₺100',
                  color: AppColors.success,
                ),
                const Divider(height: 1),
                _buildScheduleRow(
                  icon: Icons.speed,
                  title: 'Transfer Süresi',
                  value: '1-2 İş Günü',
                  color: AppColors.info,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Security Note
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.security, color: AppColors.warning, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Güvenli Ödeme',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.warning,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Banka bilgileriniz güvenli şekilde saklanır ve sadece ödeme işlemleri için kullanılır.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: children.asMap().entries.map((entry) {
          final index = entry.key;
          final child = entry.value;
          return Column(
            children: [
              child,
              if (index < children.length - 1) const Divider(height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.lock_outline, size: 18, color: AppColors.textHint),
        ],
      ),
    );
  }

  Widget _buildIbanRow(String iban) {
    final formattedIban = _formatIban(iban);
    final maskedIban = _maskIban(iban);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.credit_card_outlined, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IBAN',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  iban.isEmpty ? 'Belirtilmemiş' : maskedIban,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    fontFamily: 'monospace',
                    color: iban.isEmpty ? AppColors.textHint : null,
                  ),
                ),
              ],
            ),
          ),
          if (iban.isNotEmpty)
            IconButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: formattedIban));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('IBAN kopyalandı'),
                    backgroundColor: AppColors.success,
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              icon: Icon(Icons.copy, size: 18, color: AppColors.textHint),
              tooltip: 'Kopyala',
            ),
          Icon(Icons.lock_outline, size: 18, color: AppColors.textHint),
        ],
      ),
    );
  }

  Widget _buildScheduleRow({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatIban(String iban) {
    iban = iban.replaceAll(' ', '').toUpperCase();
    final buffer = StringBuffer();
    for (int i = 0; i < iban.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(iban[i]);
    }
    return buffer.toString();
  }

  String _maskIban(String iban) {
    if (iban.isEmpty) return '';
    iban = iban.replaceAll(' ', '').toUpperCase();
    if (iban.length < 10) return iban;
    // TR12 **** **** **** **** **** 5678
    final first4 = iban.substring(0, 4);
    final last4 = iban.substring(iban.length - 4);
    return '$first4 **** **** **** **** **** $last4';
  }
}
