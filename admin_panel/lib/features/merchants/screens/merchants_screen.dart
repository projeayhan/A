import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/pagination_controls.dart';

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

  // Pagination
  int _currentPage = 0;
  final int _pageSize = 25;
  int _totalCount = 0;

  // Data
  List<Map<String, dynamic>> _merchants = [];
  bool _isLoading = true;

  // Bulk operations
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _fetchMerchants();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchMerchants() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final supabase = ref.read(supabaseProvider);

      // Build query with server-side filters
      var countQuery = supabase.from('merchants').select('id');
      var dataQuery = supabase.from('merchants').select();

      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        countQuery = countQuery.ilike('business_name', '%$_searchQuery%');
        dataQuery = dataQuery.ilike('business_name', '%$_searchQuery%');
      }

      // Apply type filter
      if (_typeFilter != 'all') {
        countQuery = countQuery.eq('type', _typeFilter);
        dataQuery = dataQuery.eq('type', _typeFilter);
      }

      // Apply status filter
      if (_statusFilter != 'all') {
        switch (_statusFilter) {
          case 'pending':
            countQuery = countQuery.eq('is_approved', false);
            dataQuery = dataQuery.eq('is_approved', false);
            break;
          case 'active':
            countQuery = countQuery.eq('is_approved', true);
            dataQuery = dataQuery.eq('is_approved', true);
            break;
          case 'rejected':
            countQuery = countQuery.eq('is_approved', false);
            dataQuery = dataQuery.eq('is_approved', false);
            break;
          case 'suspended':
            countQuery = countQuery.eq('is_approved', false);
            dataQuery = dataQuery.eq('is_approved', false);
            break;
        }
      }

      final countResponse = await countQuery.count();
      _totalCount = countResponse.count;

      final from = _currentPage * _pageSize;
      final to = from + _pageSize - 1;

      final response = await dataQuery
          .order('created_at', ascending: false)
          .range(from, to);

      if (!mounted) return;
      setState(() {
        _merchants = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  int get _totalPages => (_totalCount / _pageSize).ceil().clamp(1, 999999);

  @override
  Widget build(BuildContext context) {
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
                    if (_isSelectionMode && _selectedIds.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_selectedIds.length} öğe seçildi',
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _bulkUpdateStatus('active'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('Toplu Onayla'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _bulkUpdateStatus('rejected'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text('Toplu Reddet'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _bulkUpdateStatus('suspended'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
                        icon: const Icon(Icons.pause_circle, size: 18),
                        label: const Text('Toplu Askıya Al'),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => setState(() {
                          _isSelectionMode = false;
                          _selectedIds.clear();
                        }),
                        icon: const Icon(Icons.close),
                        tooltip: 'Seçimi İptal Et',
                      ),
                    ] else ...[
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _isSelectionMode = !_isSelectionMode),
                        icon: Icon(_isSelectionMode ? Icons.close : Icons.checklist, size: 18),
                        label: Text(_isSelectionMode ? 'Seçimi Kapat' : 'Toplu İşlem'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _fetchMerchants,
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
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Stats Cards
            _buildStatsRow(),

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
                          if (mounted) {
                            setState(() {
                              _searchQuery = value;
                              _currentPage = 0;
                            });
                            _fetchMerchants();
                          }
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
                        onChanged: (value) {
                          setState(() {
                            _typeFilter = value!;
                            _currentPage = 0;
                          });
                          _fetchMerchants();
                        },
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
                          DropdownMenuItem(value: 'active', child: Text('Onaylı')),
                          DropdownMenuItem(value: 'rejected', child: Text('Reddedildi')),
                          DropdownMenuItem(value: 'suspended', child: Text('Askıda')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _statusFilter = value!;
                            _currentPage = 0;
                          });
                          _fetchMerchants();
                        },
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
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        children: [
                          Expanded(child: _buildDataTable()),
                          PaginationControls(
                            currentPage: _currentPage,
                            totalPages: _totalPages,
                            totalCount: _totalCount,
                            pageSize: _pageSize,
                            onPrevious: () {
                              setState(() => _currentPage--);
                              _fetchMerchants();
                            },
                            onNext: () {
                              setState(() => _currentPage++);
                              _fetchMerchants();
                            },
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    if (_isLoading) {
      return Row(children: List.generate(4, (_) => Expanded(child: _buildStatCardLoading())));
    }

    final pending = _merchants.where((m) => m['is_approved'] == false).length;
    final approved = _merchants.where((m) => m['is_approved'] == true).length;
    final closed = _merchants.where((m) => m['is_open'] == false).length;

    return Row(
      children: [
        _buildStatCard('Toplam İşletme', _totalCount.toString(), Icons.store, AppColors.primary),
        const SizedBox(width: 16),
        _buildStatCard('Onay Bekleyen', pending.toString(), Icons.pending, AppColors.warning),
        const SizedBox(width: 16),
        _buildStatCard('Onaylı', approved.toString(), Icons.check_circle, AppColors.success),
        const SizedBox(width: 16),
        _buildStatCard('Kapalı', closed.toString(), Icons.pause_circle, AppColors.error),
      ],
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

  Widget _buildDataTable() {
    final filteredMerchants = _merchants;

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

    final allPageIds = filteredMerchants.map((m) => m['id'].toString()).toSet();
    final allSelected = allPageIds.isNotEmpty && allPageIds.every((id) => _selectedIds.contains(id));

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
      columns: [
        if (_isSelectionMode)
          DataColumn2(
            label: Checkbox(
              value: allSelected,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selectedIds.addAll(allPageIds);
                  } else {
                    _selectedIds.removeAll(allPageIds);
                  }
                });
              },
            ),
            fixedWidth: 50,
          ),
        const DataColumn2(label: Text('İŞLETME'), size: ColumnSize.L),
        const DataColumn2(label: Text('TİP'), size: ColumnSize.S),
        const DataColumn2(label: Text('KONUM'), size: ColumnSize.M),
        const DataColumn2(label: Text('SİPARİŞ'), size: ColumnSize.S),
        const DataColumn2(label: Text('PUAN'), size: ColumnSize.S),
        const DataColumn2(label: Text('DURUM'), size: ColumnSize.S),
        const DataColumn2(label: Text('İŞLEMLER'), size: ColumnSize.M),
      ],
      rows: filteredMerchants.map((merchant) {
        final merchantId = merchant['id'].toString();
        return DataRow2(
          selected: _selectedIds.contains(merchantId),
          onSelectChanged: _isSelectionMode
              ? (selected) {
                  setState(() {
                    if (selected == true) {
                      _selectedIds.add(merchantId);
                    } else {
                      _selectedIds.remove(merchantId);
                    }
                  });
                }
              : null,
          cells: [
            if (_isSelectionMode)
              DataCell(
                Checkbox(
                  value: _selectedIds.contains(merchantId),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedIds.add(merchantId);
                      } else {
                        _selectedIds.remove(merchantId);
                      }
                    });
                  },
                ),
              ),
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

  Future<void> _bulkUpdateStatus(String newStatus) async {
    if (_selectedIds.isEmpty) return;

    final count = _selectedIds.length;
    String actionLabel;
    Color actionColor;
    switch (newStatus) {
      case 'active':
        actionLabel = 'onayla';
        actionColor = AppColors.success;
        break;
      case 'rejected':
        actionLabel = 'reddet';
        actionColor = AppColors.error;
        break;
      case 'suspended':
        actionLabel = 'askıya al';
        actionColor = AppColors.warning;
        break;
      default:
        actionLabel = 'güncelle';
        actionColor = AppColors.primary;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Toplu İşlem'),
        content: Text('$count işletmeyi $actionLabel istediğinizden emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: actionColor),
            child: Text(actionLabel[0].toUpperCase() + actionLabel.substring(1)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = ref.read(supabaseProvider);
      final Map<String, dynamic> updates = {
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (newStatus == 'active') {
        updates['is_approved'] = true;
      } else {
        updates['is_approved'] = false;
      }

      // Store previous states for undo
      final previousStates = <String, Map<String, dynamic>>{};
      for (final id in _selectedIds) {
        final merchant = _merchants.firstWhere(
          (m) => m['id'].toString() == id,
          orElse: () => {},
        );
        if (merchant.isNotEmpty) {
          previousStates[id] = {
            'is_approved': merchant['is_approved'],
          };
        }
        await supabase.from('merchants').update(updates).eq('id', id);
      }

      if (!mounted) return;
      final updatedCount = _selectedIds.length;
      setState(() {
        _selectedIds.clear();
        _isSelectionMode = false;
      });

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$updatedCount işletme güncellendi'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Geri Al',
            textColor: Colors.white,
            onPressed: () async {
              for (final entry in previousStates.entries) {
                await supabase.from('merchants').update({
                  'is_approved': entry.value['is_approved'],
                  'updated_at': DateTime.now().toIso8601String(),
                }).eq('id', entry.key);
              }
              _fetchMerchants();
            },
          ),
        ),
      );

      _fetchMerchants();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
      );
    }
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
      updates['commission_rate'] = commissionRate;
      await supabase.from('merchants').update(updates).eq('id', merchantId);

      _fetchMerchants();

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

  Future<void> _approveMerchant(String merchantId) async {
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.from('merchants').update({
        'is_approved': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', merchantId);

      _fetchMerchants();

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

      _fetchMerchants();

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
