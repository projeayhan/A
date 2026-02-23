import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

// Partners provider
final partnersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase
      .from('partners')
      .select()
      .order('created_at', ascending: false)
      .limit(100);
  return List<Map<String, dynamic>>.from(response);
});

class PartnersScreen extends ConsumerStatefulWidget {
  const PartnersScreen({super.key});

  @override
  ConsumerState<PartnersScreen> createState() => _PartnersScreenState();
}

class _PartnersScreenState extends ConsumerState<PartnersScreen> {
  String _searchQuery = '';
  String _statusFilter = 'all';
  String _roleFilter = 'all';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final partnersAsync = ref.watch(partnersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Partnerler',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Kurye ve taksi sürücülerini yönetin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(partnersProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _showAddPartnerInfo,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Partner Ekle'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Stats Cards
            _buildStatsRow(partnersAsync),

            const SizedBox(height: 24),

            // Filters
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      onChanged: (value) {
                        _debounce?.cancel();
                        _debounce = Timer(const Duration(milliseconds: 300), () {
                          if (mounted) setState(() => _searchQuery = value);
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Partner ara...',
                        prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _roleFilter,
                        dropdownColor: AppColors.surface,
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Tüm Roller')),
                          DropdownMenuItem(value: 'courier', child: Text('Kurye')),
                          DropdownMenuItem(value: 'taxi', child: Text('Taksi')),
                        ],
                        onChanged: (value) => setState(() => _roleFilter = value!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _statusFilter,
                        dropdownColor: AppColors.surface,
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Tüm Durumlar')),
                          DropdownMenuItem(value: 'pending', child: Text('Bekleyen')),
                          DropdownMenuItem(value: 'approved', child: Text('Onaylı')),
                          DropdownMenuItem(value: 'rejected', child: Text('Reddedildi')),
                          DropdownMenuItem(value: 'suspended', child: Text('Askıda')),
                        ],
                        onChanged: (value) => setState(() => _statusFilter = value!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: _showExportSnackBar,
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Dışa Aktar'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceLight),
                ),
                child: partnersAsync.when(
                  data: (partners) => _buildDataTable(partners),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.delivery_dining, size: 64, color: AppColors.textMuted),
                        const SizedBox(height: 16),
                        const Text(
                          'Henüz partner yok',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text('Hata: $e', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPartnerInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Partnerler uygulama üzerinden başvuru yapar'),
        backgroundColor: AppColors.info,
      ),
    );
  }

  void _showExportSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dışa aktarma hazırlanıyor...'),
        backgroundColor: AppColors.info,
      ),
    );
  }

  void _showPartnerDetails(Map<String, dynamic> partner) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Partner Detayları', style: TextStyle(color: AppColors.textPrimary)),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Ad Soyad', partner['full_name'] ?? '-'),
                _buildDetailRow('Telefon', partner['phone'] ?? '-'),
                _buildDetailRow('E-posta', partner['email'] ?? '-'),
                _buildDetailRow('Roller', partner['roles'] is List ? (partner['roles'] as List).join(', ') : '-'),
                _buildDetailRow('Durum', partner['status'] ?? '-'),
                _buildDetailRow('Onay Durumu', partner['is_approved'] == true ? 'Onaylı' : 'Bekliyor'),
                _buildDetailRow('Toplam Teslimat', '${partner['total_deliveries'] ?? 0}'),
                _buildDetailRow('Puan', '${(partner['rating'] ?? 0).toStringAsFixed(1)}'),
                _buildDetailRow('Toplam Kazanç', '₺${(partner['total_earnings'] ?? 0).toStringAsFixed(2)}'),
                _buildDetailRow('Şirket Adı', partner['company_name'] ?? '-'),
                _buildDetailRow('Vergi No', partner['tax_number'] ?? '-'),
                _buildDetailRow('IBAN', partner['iban'] ?? '-'),
                _buildDetailRow('Oluşturma Tarihi', partner['created_at'] != null
                    ? DateTime.parse(partner['created_at']).toString().substring(0, 16)
                    : '-'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approvePartner(String partnerId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Partneri Onayla', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Bu partneri onaylamak istediğinizden emin misiniz?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = ref.read(supabaseProvider);
      await supabase
          .from('partners')
          .update({
            'status': 'approved',
            'is_approved': true,
          })
          .eq('id', partnerId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Partner başarıyla onaylandı'),
          backgroundColor: AppColors.success,
        ),
      );

      ref.invalidate(partnersProvider);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showEditPartnerDialog(Map<String, dynamic> partner) {
    final fullNameController = TextEditingController(text: partner['full_name']);
    final phoneController = TextEditingController(text: partner['phone']);
    final emailController = TextEditingController(text: partner['email']);
    final companyNameController = TextEditingController(text: partner['company_name']);
    final taxNumberController = TextEditingController(text: partner['tax_number']);
    final ibanController = TextEditingController(text: partner['iban']);
    String selectedStatus = partner['status'] ?? 'pending';
    bool isApproved = partner['is_approved'] ?? false;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Partner Düzenle', style: TextStyle(color: AppColors.textPrimary)),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Ad Soyad',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Telefon',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'E-posta',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: companyNameController,
                    decoration: const InputDecoration(
                      labelText: 'Şirket Adı',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: taxNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Vergi No',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: ibanController,
                    decoration: const InputDecoration(
                      labelText: 'IBAN',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Durum',
                      border: OutlineInputBorder(),
                    ),
                    dropdownColor: AppColors.surface,
                    items: const [
                      DropdownMenuItem(value: 'pending', child: Text('Bekleyen')),
                      DropdownMenuItem(value: 'approved', child: Text('Onaylı')),
                      DropdownMenuItem(value: 'rejected', child: Text('Reddedildi')),
                      DropdownMenuItem(value: 'suspended', child: Text('Askıda')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedStatus = value!;
                        if (value == 'approved') {
                          isApproved = true;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Onaylı', style: TextStyle(color: AppColors.textPrimary)),
                    value: isApproved,
                    onChanged: (value) {
                      setState(() {
                        isApproved = value ?? false;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _updatePartner(
                partner['id'],
                fullNameController.text,
                phoneController.text,
                emailController.text,
                companyNameController.text,
                taxNumberController.text,
                ibanController.text,
                selectedStatus,
                isApproved,
              );
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _updatePartner(
    String partnerId,
    String fullName,
    String phone,
    String email,
    String companyName,
    String taxNumber,
    String iban,
    String status,
    bool isApproved,
  ) async {
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase
          .from('partners')
          .update({
            'full_name': fullName,
            'phone': phone,
            'email': email,
            'company_name': companyName,
            'tax_number': taxNumber,
            'iban': iban,
            'status': status,
            'is_approved': isApproved,
          })
          .eq('id', partnerId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Partner başarıyla güncellendi'),
          backgroundColor: AppColors.success,
        ),
      );

      ref.invalidate(partnersProvider);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildStatsRow(AsyncValue<List<Map<String, dynamic>>> partnersAsync) {
    return partnersAsync.when(
      data: (partners) {
        final couriers = partners.where((p) {
          final roles = p['roles'];
          if (roles is List) return roles.contains('courier');
          return false;
        }).length;
        final taxis = partners.where((p) {
          final roles = p['roles'];
          if (roles is List) return roles.contains('taxi');
          return false;
        }).length;
        final online = partners.where((p) => p['is_online'] == true).length;
        final pending = partners.where((p) => p['status'] == 'pending').length;

        return Row(
          children: [
            _buildStatCard('Toplam Partner', partners.length.toString(), Icons.people, AppColors.primary),
            const SizedBox(width: 16),
            _buildStatCard('Kurye', couriers.toString(), Icons.delivery_dining, AppColors.success),
            const SizedBox(width: 16),
            _buildStatCard('Taksi', taxis.toString(), Icons.local_taxi, AppColors.warning),
            const SizedBox(width: 16),
            _buildStatCard('Online', online.toString(), Icons.circle, AppColors.info, showDot: true),
            const SizedBox(width: 16),
            _buildStatCard('Onay Bekleyen', pending.toString(), Icons.pending, AppColors.error),
          ],
        );
      },
      loading: () => Row(children: List.generate(5, (_) => Expanded(child: _buildStatCardLoading()))),
      error: (_, __) => const SizedBox(),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {bool showDot = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: showDot
                  ? Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    )
                  : Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCardLoading() {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  Widget _buildDataTable(List<Map<String, dynamic>> partners) {
    var filteredPartners = partners.where((partner) {
      final matchesSearch = _searchQuery.isEmpty;
      final matchesStatus = _statusFilter == 'all' || partner['status'] == _statusFilter;
      final roles = partner['roles'];
      final matchesRole = _roleFilter == 'all' ||
          (roles is List && roles.contains(_roleFilter));

      return matchesSearch && matchesStatus && matchesRole;
    }).toList();

    if (filteredPartners.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delivery_dining, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text('Partner bulunamadı', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            if (_searchQuery.isNotEmpty || _statusFilter != 'all' || _roleFilter != 'all')
              TextButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _statusFilter = 'all';
                    _roleFilter = 'all';
                  });
                },
                child: const Text('Filtreleri Temizle'),
              ),
          ],
        ),
      );
    }

    return DataTable2(
      columnSpacing: 12,
      horizontalMargin: 16,
      minWidth: 1000,
      headingRowColor: WidgetStateProperty.all(AppColors.background),
      headingTextStyle: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 12),
      dataTextStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      columns: const [
        DataColumn2(label: Text('PARTNER'), size: ColumnSize.L),
        DataColumn2(label: Text('ROL'), size: ColumnSize.S),
        DataColumn2(label: Text('TESLİMAT'), size: ColumnSize.S),
        DataColumn2(label: Text('PUAN'), size: ColumnSize.S),
        DataColumn2(label: Text('KAZANÇ'), size: ColumnSize.S),
        DataColumn2(label: Text('DURUM'), size: ColumnSize.S),
        DataColumn2(label: Text('İŞLEMLER'), size: ColumnSize.M),
      ],
      rows: filteredPartners.map((partner) {
        final roles = partner['roles'] is List ? (partner['roles'] as List).join(', ') : '-';

        return DataRow2(
          cells: [
            DataCell(
              Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                        child: const Icon(Icons.person, color: AppColors.primary, size: 18),
                      ),
                      if (partner['is_online'] == true)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.surface, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(partner['full_name'] ?? 'Partner', style: const TextStyle(fontWeight: FontWeight.w500)),
                        Text(partner['phone'] ?? '-', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            DataCell(_buildRoleBadge(roles)),
            DataCell(Text('${partner['total_deliveries'] ?? 0}')),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: AppColors.warning, size: 16),
                  const SizedBox(width: 4),
                  Text('${(partner['rating'] ?? 0).toStringAsFixed(1)}'),
                ],
              ),
            ),
            DataCell(Text('₺${(partner['total_earnings'] ?? 0).toStringAsFixed(0)}')),
            DataCell(_buildStatusBadge(partner['status'] ?? 'pending')),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _showPartnerDetails(partner),
                    icon: const Icon(Icons.visibility, size: 18),
                    color: AppColors.textMuted,
                    tooltip: 'Görüntüle',
                  ),
                  if (partner['status'] == 'pending')
                    IconButton(
                      onPressed: () => _approvePartner(partner['id']),
                      icon: const Icon(Icons.check_circle, size: 18),
                      color: AppColors.success,
                      tooltip: 'Onayla',
                    ),
                  IconButton(
                    onPressed: () => _showEditPartnerDialog(partner),
                    icon: const Icon(Icons.edit, size: 18),
                    color: AppColors.info,
                    tooltip: 'Düzenle',
                  ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildRoleBadge(String roles) {
    final isCourier = roles.contains('courier');
    final isTaxi = roles.contains('taxi');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isCourier)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Kurye', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w500)),
          ),
        if (isTaxi)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Taksi', style: TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w500)),
          ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;

    switch (status) {
      case 'approved':
        color = AppColors.success;
        text = 'Onaylı';
        break;
      case 'pending':
        color = AppColors.warning;
        text = 'Bekliyor';
        break;
      case 'rejected':
        color = AppColors.error;
        text = 'Reddedildi';
        break;
      case 'suspended':
        color = AppColors.error;
        text = 'Askıda';
        break;
      default:
        color = AppColors.textMuted;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }
}
