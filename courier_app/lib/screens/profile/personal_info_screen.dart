import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/services/courier_service.dart';
import '../../core/theme/app_theme.dart';

class PersonalInfoScreen extends ConsumerStatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  ConsumerState<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends ConsumerState<PersonalInfoScreen> {
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
        title: const Text('Kişisel Bilgiler'),
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
    final fullName = _profile!['full_name'] ?? '';
    final email = _profile!['email'] ?? '';
    final phone = _profile!['phone'] ?? '';
    final tcNo = _profile!['tc_no'] ?? '';
    final birthDate = _profile!['birth_date'];
    final address = _profile!['address'] ?? '';
    final createdAt = _profile!['created_at'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Avatar
          Center(
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      fullName.isNotEmpty ? fullName[0].toUpperCase() : 'K',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  fullName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 16, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        'Onaylı Kurye',
                        style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

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
                    'Kişisel bilgilerinizi değiştirmek için destek ekibiyle iletişime geçin.',
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

          // Personal Information
          Text(
            'Kimlik Bilgileri',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          _buildInfoCard([
            _buildInfoRow(
              icon: Icons.person_outline,
              label: 'Ad Soyad',
              value: fullName,
            ),
            _buildInfoRow(
              icon: Icons.badge_outlined,
              label: 'TC Kimlik No',
              value: _maskTcNo(tcNo),
              isSensitive: true,
            ),
            if (birthDate != null)
              _buildInfoRow(
                icon: Icons.cake_outlined,
                label: 'Doğum Tarihi',
                value: _formatDate(birthDate),
              ),
          ]),

          const SizedBox(height: 24),

          // Contact Information
          Text(
            'İletişim Bilgileri',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          _buildInfoCard([
            _buildInfoRow(
              icon: Icons.phone_outlined,
              label: 'Telefon',
              value: _formatPhone(phone),
              onCopy: phone,
            ),
            _buildInfoRow(
              icon: Icons.email_outlined,
              label: 'E-posta',
              value: email,
              onCopy: email,
            ),
            if (address.isNotEmpty)
              _buildInfoRow(
                icon: Icons.location_on_outlined,
                label: 'Adres',
                value: address,
              ),
          ]),

          const SizedBox(height: 24),

          // Account Information
          Text(
            'Hesap Bilgileri',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          _buildInfoCard([
            _buildInfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Kayıt Tarihi',
              value: createdAt != null ? _formatDate(createdAt) : '-',
            ),
            _buildInfoRow(
              icon: Icons.fingerprint,
              label: 'Kurye ID',
              value: _profile!['id']?.toString().substring(0, 8).toUpperCase() ?? '-',
            ),
          ]),

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
    bool isSensitive = false,
    String? onCopy,
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
                  value.isEmpty ? '-' : value,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isSensitive ? AppColors.textSecondary : null,
                  ),
                ),
              ],
            ),
          ),
          if (onCopy != null && onCopy.isNotEmpty)
            IconButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: onCopy));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$label kopyalandı'),
                    backgroundColor: AppColors.success,
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              icon: Icon(Icons.copy, size: 18, color: AppColors.textHint),
              tooltip: 'Kopyala',
            ),
          if (isSensitive)
            Icon(Icons.lock_outline, size: 18, color: AppColors.textHint),
        ],
      ),
    );
  }

  String _maskTcNo(String tcNo) {
    if (tcNo.length < 11) return tcNo;
    return '${tcNo.substring(0, 3)}*****${tcNo.substring(tcNo.length - 3)}';
  }

  String _formatPhone(String phone) {
    if (phone.isEmpty) return '-';
    // +905551234567 -> +90 555 123 45 67
    phone = phone.replaceAll(' ', '');
    if (phone.startsWith('+90') && phone.length == 13) {
      return '+90 ${phone.substring(3, 6)} ${phone.substring(6, 9)} ${phone.substring(9, 11)} ${phone.substring(11)}';
    }
    return phone;
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMMM yyyy', 'tr').format(date);
    } catch (e) {
      return dateStr;
    }
  }
}
