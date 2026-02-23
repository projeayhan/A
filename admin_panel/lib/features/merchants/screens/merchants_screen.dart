import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

// Merchants provider
final merchantsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase
      .from('merchants')
      .select()
      .order('created_at', ascending: false)
      .limit(100);
  return List<Map<String, dynamic>>.from(response);
});

class MerchantsScreen extends ConsumerStatefulWidget {
  const MerchantsScreen({super.key});

  @override
  ConsumerState<MerchantsScreen> createState() => _MerchantsScreenState();
}

class _MerchantsScreenState extends ConsumerState<MerchantsScreen> {
  String _searchQuery = '';
  String _statusFilter = 'all';
  String _typeFilter = 'all';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final merchantsAsync = ref.watch(merchantsProvider);

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
                      'İşletmeler',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Restoran, mağaza ve marketleri yönetin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ref.refresh(merchantsProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _showAddMerchantInfo,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('İşletme Ekle'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Stats Cards
            _buildStatsRow(merchantsAsync),

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
                  // Search
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
                        hintText: 'İşletme ara...',
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
                  // Type Filter
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _typeFilter,
                        dropdownColor: AppColors.surface,
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Tüm Tipler')),
                          DropdownMenuItem(value: 'restaurant', child: Text('Restoran')),
                          DropdownMenuItem(value: 'store', child: Text('Mağaza')),
                          DropdownMenuItem(value: 'market', child: Text('Market')),
                          DropdownMenuItem(value: 'pharmacy', child: Text('Eczane')),
                        ],
                        onChanged: (value) => setState(() => _typeFilter = value!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Status Filter
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
                    onPressed: _showExportSnackbar,
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
                child: merchantsAsync.when(
                  data: (merchants) => _buildDataTable(merchants),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.store, size: 64, color: AppColors.textMuted),
                        const SizedBox(height: 16),
                        const Text(
                          'Henüz işletme yok',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Hata: $e',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
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

  void _showAddMerchantInfo() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('İşletmeler uygulama üzerinden başvuru yapar'),
        backgroundColor: AppColors.info,
      ),
    );
  }

  void _showExportSnackbar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dışa aktarma hazırlanıyor...'),
        backgroundColor: AppColors.info,
      ),
    );
  }

  void _showViewDialog(Map<String, dynamic> merchant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'İşletme Detayları',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('İşletme Adı', merchant['business_name'] ?? '-'),
                _buildDetailRow('Sahip Adı', merchant['owner_name'] ?? '-'),
                _buildDetailRow('Telefon', merchant['phone'] ?? '-'),
                _buildDetailRow('E-posta', merchant['email'] ?? '-'),
                _buildDetailRow(
                  'Adres',
                  merchant['address'] != null
                    ? '${merchant['address']}, ${merchant['district'] ?? ''}, ${merchant['city'] ?? ''}'
                    : '-',
                ),
                _buildDetailRow('Tip', _getTypeText(merchant['type'])),
                _buildDetailRow(
                  'Komisyon',
                  merchant['commission_rate'] != null
                      ? '%${merchant['commission_rate']}'
                      : 'Platform varsayılanı',
                ),
                _buildDetailRow(
                  'Durum',
                  merchant['is_approved'] == true ? 'Onaylı' : 'Onay Bekliyor',
                ),
                _buildDetailRow(
                  'Oluşturulma',
                  merchant['created_at'] != null
                    ? DateTime.parse(merchant['created_at']).toString().split('.')[0]
                    : '-',
                ),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
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

  void _showEditDialog(Map<String, dynamic> merchant) {
    final businessNameController = TextEditingController(text: merchant['business_name']);
    final phoneController = TextEditingController(text: merchant['phone']);
    final emailController = TextEditingController(text: merchant['email']);
    final commissionController = TextEditingController(
      text: merchant['commission_rate']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'İşletme Düzenle',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: businessNameController,
                  decoration: const InputDecoration(
                    labelText: 'İşletme Adı',
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
                  controller: commissionController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Komisyon Oranı (%)',
                    hintText: 'Boş bırakılırsa platform varsayılanı uygulanır',
                    border: const OutlineInputBorder(),
                    suffixText: '%',
                    helperText: 'İşletmeye özel oran. Boş = Fiyatlandırma ekranındaki varsayılan.',
                    helperStyle: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ),
              ],
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
              await _updateMerchant(
                merchant['id'],
                businessNameController.text.trim(),
                phoneController.text.trim(),
                emailController.text.trim(),
                commissionRate: commissionController.text.trim().isEmpty
                    ? null
                    : double.tryParse(commissionController.text.trim()),
              );
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateMerchant(
    String merchantId,
    String businessName,
    String phone,
    String email, {
    double? commissionRate,
  }) async {
    try {
      final supabase = ref.read(supabaseProvider);
      final updates = <String, dynamic>{
        'business_name': businessName,
        'phone': phone,
        'email': email,
        'updated_at': DateTime.now().toIso8601String(),
      };
      // null = kullanıcı boş bıraktı → DB'de null olsun (platform varsayılanı uygulansın)
      updates['commission_rate'] = commissionRate;
      await supabase.from('merchants').update(updates).eq('id', merchantId);

      ref.invalidate(merchantsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('İşletme başarıyla güncellendi'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildStatsRow(AsyncValue<List<Map<String, dynamic>>> merchantsAsync) {
    return merchantsAsync.when(
      data: (merchants) {
        final pending = merchants.where((m) => m['is_approved'] == false).length;
        final approved = merchants.where((m) => m['is_approved'] == true).length;
        final closed = merchants.where((m) => m['is_open'] == false).length;

        return Row(
          children: [
            _buildStatCard('Toplam İşletme', merchants.length.toString(), Icons.store, AppColors.primary),
            const SizedBox(width: 16),
            _buildStatCard('Onay Bekleyen', pending.toString(), Icons.pending, AppColors.warning),
            const SizedBox(width: 16),
            _buildStatCard('Onaylı', approved.toString(), Icons.check_circle, AppColors.success),
            const SizedBox(width: 16),
            _buildStatCard('Kapalı', closed.toString(), Icons.pause_circle, AppColors.error),
          ],
        );
      },
      loading: () => Row(
        children: List.generate(4, (_) => Expanded(child: _buildStatCardLoading())),
      ),
      error: (_, __) => const SizedBox(),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
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
              child: Icon(icon, color: color, size: 24),
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
                Text(
                  title,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
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

  Widget _buildDataTable(List<Map<String, dynamic>> merchants) {
    // Filter merchants
    var filteredMerchants = merchants.where((merchant) {
      final name = (merchant['business_name'] ?? '').toString().toLowerCase();
      final matchesSearch = name.contains(_searchQuery.toLowerCase());

      bool matchesStatus = true;
      if (_statusFilter == 'pending') {
        matchesStatus = merchant['is_approved'] == false;
      } else if (_statusFilter == 'approved') {
        matchesStatus = merchant['is_approved'] == true;
      } else if (_statusFilter == 'suspended') {
        matchesStatus = merchant['is_open'] == false;
      }

      final matchesType = _typeFilter == 'all' || merchant['type'] == _typeFilter;

      return matchesSearch && matchesStatus && matchesType;
    }).toList();

    if (filteredMerchants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.store, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text(
              'İşletme bulunamadı',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            if (_searchQuery.isNotEmpty || _statusFilter != 'all' || _typeFilter != 'all')
              TextButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _statusFilter = 'all';
                    _typeFilter = 'all';
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
      headingTextStyle: const TextStyle(
        color: AppColors.textMuted,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      dataTextStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
      ),
      columns: const [
        DataColumn2(label: Text('İŞLETME'), size: ColumnSize.L),
        DataColumn2(label: Text('TİP'), size: ColumnSize.S),
        DataColumn2(label: Text('KONUM'), size: ColumnSize.M),
        DataColumn2(label: Text('SİPARİŞ'), size: ColumnSize.S),
        DataColumn2(label: Text('PUAN'), size: ColumnSize.S),
        DataColumn2(label: Text('DURUM'), size: ColumnSize.S),
        DataColumn2(label: Text('İŞLEMLER'), size: ColumnSize.M),
      ],
      rows: filteredMerchants.map((merchant) {
        return DataRow2(
          cells: [
            DataCell(
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: _getTypeColor(merchant['type']).withValues(alpha: 0.2),
                    backgroundImage: merchant['logo_url'] != null
                        ? NetworkImage(merchant['logo_url'])
                        : null,
                    child: merchant['logo_url'] == null
                        ? Icon(
                            _getTypeIcon(merchant['type']),
                            color: _getTypeColor(merchant['type']),
                            size: 18,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          merchant['business_name'] ?? 'İsimsiz',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          merchant['phone'] ?? '-',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            DataCell(_buildTypeBadge(merchant['type'] ?? '-')),
            DataCell(
              Text(
                '${merchant['district'] ?? ''}, ${merchant['city'] ?? ''}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DataCell(Text('${merchant['total_orders'] ?? 0}')),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: AppColors.warning, size: 16),
                  const SizedBox(width: 4),
                  Text('${(merchant['rating'] ?? 0).toStringAsFixed(1)}'),
                ],
              ),
            ),
            DataCell(_buildStatusBadge(merchant['is_approved'] == true ? 'approved' : 'pending')),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _showViewDialog(merchant),
                    icon: const Icon(Icons.visibility, size: 18),
                    color: AppColors.textMuted,
                    tooltip: 'Görüntüle',
                  ),
                  if (merchant['is_approved'] != true)
                    IconButton(
                      onPressed: () => _approveMerchant(merchant['id']),
                      icon: const Icon(Icons.check_circle, size: 18),
                      color: AppColors.success,
                      tooltip: 'Onayla',
                    ),
                  if (merchant['is_approved'] == true)
                    IconButton(
                      onPressed: () => _rejectMerchant(merchant['id']),
                      icon: const Icon(Icons.cancel, size: 18),
                      color: AppColors.error,
                      tooltip: 'Onayı Kaldır',
                    ),
                  IconButton(
                    onPressed: () => _showEditDialog(merchant),
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

  Future<void> _approveMerchant(String merchantId) async {
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.from('merchants').update({
        'is_approved': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', merchantId);

      ref.invalidate(merchantsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('İşletme başarıyla onaylandı'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _rejectMerchant(String merchantId) async {
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.from('merchants').update({
        'is_approved': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', merchantId);

      ref.invalidate(merchantsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('İşletme onayı kaldırıldı'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildTypeBadge(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getTypeColor(type).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _getTypeText(type),
        style: TextStyle(color: _getTypeColor(type), fontSize: 12, fontWeight: FontWeight.w500),
      ),
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
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  Color _getTypeColor(String? type) {
    switch (type) {
      case 'restaurant':
        return AppColors.primary;
      case 'store':
        return AppColors.success;
      case 'market':
        return AppColors.warning;
      case 'pharmacy':
        return AppColors.info;
      default:
        return AppColors.textMuted;
    }
  }

  IconData _getTypeIcon(String? type) {
    switch (type) {
      case 'restaurant':
        return Icons.restaurant;
      case 'store':
        return Icons.store;
      case 'market':
        return Icons.shopping_cart;
      case 'pharmacy':
        return Icons.local_pharmacy;
      default:
        return Icons.store;
    }
  }

  String _getTypeText(String? type) {
    switch (type) {
      case 'restaurant':
        return 'Restoran';
      case 'store':
        return 'Mağaza';
      case 'market':
        return 'Market';
      case 'pharmacy':
        return 'Eczane';
      default:
        return type ?? '-';
    }
  }
}
