import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/services/courier_service.dart';
import '../../core/theme/app_theme.dart';

class VehicleInfoScreen extends ConsumerStatefulWidget {
  const VehicleInfoScreen({super.key});

  @override
  ConsumerState<VehicleInfoScreen> createState() => _VehicleInfoScreenState();
}

class _VehicleInfoScreenState extends ConsumerState<VehicleInfoScreen> {
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
        title: const Text('Araç Bilgileri'),
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
    final vehicleType = _profile!['vehicle_type'] as String? ?? 'motorcycle';
    final vehiclePlate = _profile!['vehicle_plate'] as String? ?? '';
    final vehicleBrand = _profile!['vehicle_brand'] as String?;
    final vehicleModel = _profile!['vehicle_model'] as String?;
    final vehicleYear = _profile!['vehicle_year'];
    final vehicleColor = _profile!['vehicle_color'] as String?;
    final licenseExpiry = _profile!['license_expiry'];
    final insuranceExpiry = _profile!['insurance_expiry'];

    // Vehicle type info
    IconData vehicleIcon;
    String vehicleTypeName;
    Color vehicleColor2;

    switch (vehicleType) {
      case 'bicycle':
        vehicleIcon = Icons.pedal_bike;
        vehicleTypeName = 'Bisiklet';
        vehicleColor2 = AppColors.success;
        break;
      case 'car':
        vehicleIcon = Icons.directions_car;
        vehicleTypeName = 'Otomobil';
        vehicleColor2 = AppColors.info;
        break;
      default:
        vehicleIcon = Icons.two_wheeler;
        vehicleTypeName = 'Motosiklet';
        vehicleColor2 = AppColors.primary;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vehicle Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [vehicleColor2, vehicleColor2.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: vehicleColor2.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(vehicleIcon, size: 44, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  vehicleTypeName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (vehiclePlate.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      vehiclePlate.toUpperCase(),
                      style: TextStyle(
                        color: vehicleColor2,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
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
                    'Araç bilgilerinizi değiştirmek için destek ekibiyle iletişime geçin.',
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

          // Vehicle Details
          Text(
            'Araç Detayları',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          _buildInfoCard([
            _buildInfoRow(
              icon: Icons.category_outlined,
              label: 'Araç Tipi',
              value: vehicleTypeName,
            ),
            _buildInfoRow(
              icon: Icons.confirmation_number_outlined,
              label: 'Plaka',
              value: vehiclePlate.toUpperCase(),
              onCopy: vehiclePlate,
            ),
            if (vehicleBrand != null && vehicleBrand.isNotEmpty)
              _buildInfoRow(
                icon: Icons.branding_watermark_outlined,
                label: 'Marka',
                value: vehicleBrand,
              ),
            if (vehicleModel != null && vehicleModel.isNotEmpty)
              _buildInfoRow(
                icon: Icons.directions_car_outlined,
                label: 'Model',
                value: vehicleModel,
              ),
            if (vehicleYear != null)
              _buildInfoRow(
                icon: Icons.calendar_today_outlined,
                label: 'Model Yılı',
                value: vehicleYear.toString(),
              ),
            if (vehicleColor != null && vehicleColor.isNotEmpty)
              _buildInfoRow(
                icon: Icons.palette_outlined,
                label: 'Renk',
                value: vehicleColor,
              ),
          ]),

          const SizedBox(height: 24),

          // Documents
          Text(
            'Belgeler',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          _buildInfoCard([
            _buildDocumentRow(
              icon: Icons.badge_outlined,
              label: 'Ehliyet',
              expiry: licenseExpiry,
            ),
            _buildDocumentRow(
              icon: Icons.security_outlined,
              label: 'Sigorta',
              expiry: insuranceExpiry,
            ),
          ]),

          const SizedBox(height: 24),

          // Vehicle Status
          Text(
            'Araç Durumu',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.check_circle, color: AppColors.success, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aktif',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Aracınız teslimat için onaylıdır',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
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
          Icon(Icons.lock_outline, size: 18, color: AppColors.textHint),
        ],
      ),
    );
  }

  Widget _buildDocumentRow({
    required IconData icon,
    required String label,
    String? expiry,
  }) {
    final isExpired = _isExpired(expiry);
    final isExpiringSoon = _isExpiringSoon(expiry);

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (expiry == null) {
      statusColor = AppColors.textHint;
      statusText = 'Bilgi yok';
      statusIcon = Icons.help_outline;
    } else if (isExpired) {
      statusColor = AppColors.error;
      statusText = 'Süresi dolmuş';
      statusIcon = Icons.error_outline;
    } else if (isExpiringSoon) {
      statusColor = AppColors.warning;
      statusText = 'Yakında dolacak';
      statusIcon = Icons.warning_amber_outlined;
    } else {
      statusColor = AppColors.success;
      statusText = 'Geçerli';
      statusIcon = Icons.check_circle_outline;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: statusColor, size: 22),
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
                  expiry != null ? _formatDate(expiry) : '-',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 14, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isExpired(String? dateStr) {
    if (dateStr == null) return false;
    try {
      final date = DateTime.parse(dateStr);
      return date.isBefore(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  bool _isExpiringSoon(String? dateStr) {
    if (dateStr == null) return false;
    try {
      final date = DateTime.parse(dateStr);
      final thirtyDaysFromNow = DateTime.now().add(const Duration(days: 30));
      return date.isAfter(DateTime.now()) && date.isBefore(thirtyDaysFromNow);
    } catch (e) {
      return false;
    }
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
