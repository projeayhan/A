import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

class AdminCarListingsScreen extends ConsumerStatefulWidget {
  final String dealerId;
  final String? dealerName;

  const AdminCarListingsScreen({
    super.key,
    required this.dealerId,
    this.dealerName,
  });

  @override
  ConsumerState<AdminCarListingsScreen> createState() => _AdminCarListingsScreenState();
}

class _AdminCarListingsScreenState extends ConsumerState<AdminCarListingsScreen>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  String _statusFilter = 'all';
  Timer? _debounce;
  final _currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 0);
  final _dateFormat = DateFormat('dd MMM yyyy', 'tr');

  List<Map<String, dynamic>> _listings = [];
  bool _isLoading = true;

  late TabController _tabController;

  final List<Map<String, String>> _statusTabs = [
    {'key': 'all', 'label': 'Tümü'},
    {'key': 'active', 'label': 'Aktif'},
    {'key': 'pending', 'label': 'Beklemede'},
    {'key': 'sold', 'label': 'Satıldı'},
    {'key': 'reserved', 'label': 'Rezerve'},
    {'key': 'expired', 'label': 'Süresi Doldu'},
    {'key': 'rejected', 'label': 'Reddedildi'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusTabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _statusFilter = _statusTabs[_tabController.index]['key']!);
      }
    });
    _fetchListings();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchListings() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final supabase = ref.read(supabaseProvider);
      final response = await supabase
          .from('car_listings')
          .select()
          .eq('dealer_id', widget.dealerId)
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _listings = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredListings {
    return _listings.where((listing) {
      final title = (listing['title'] ?? '').toString().toLowerCase();
      final brand = (listing['brand_name'] ?? '').toString().toLowerCase();
      final model = (listing['model_name'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      final matchesSearch = _searchQuery.isEmpty ||
          title.contains(query) ||
          brand.contains(query) ||
          model.contains(query);

      final matchesStatus = _statusFilter == 'all' ||
          listing['status'] == _statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredListings;

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
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                      tooltip: 'Geri',
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.dealerName != null
                              ? '${widget.dealerName} - İlanlar'
                              : 'Araç İlanları',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_listings.length} ilan listeleniyor',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _fetchListings,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Stats Cards
            _buildStatsRow(),

            const SizedBox(height: 24),

            // Status Tabs
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicatorColor: AppColors.primary,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textMuted,
                    indicatorSize: TabBarIndicatorSize.label,
                    tabAlignment: TabAlignment.start,
                    tabs: _statusTabs.map((tab) {
                      final count = tab['key'] == 'all'
                          ? _listings.length
                          : _listings.where((l) => l['status'] == tab['key']).length;
                      return Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(tab['label']!),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Search
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
                    child: TextField(
                      onChanged: (value) {
                        _debounce?.cancel();
                        _debounce = Timer(const Duration(milliseconds: 300), () {
                          if (mounted) setState(() => _searchQuery = value);
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Başlık, marka veya model ara...',
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
                ],
              ),
            ),

            const SizedBox(height: 16),

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
                    : filtered.isEmpty
                        ? _buildEmptyState()
                        : _buildDataTable(filtered),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    if (_isLoading) {
      return Row(
        children: List.generate(4, (_) => Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceLight),
            ),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        )),
      );
    }

    final active = _listings.where((l) => l['status'] == 'active').length;
    final pending = _listings.where((l) => l['status'] == 'pending').length;
    final sold = _listings.where((l) => l['status'] == 'sold').length;

    return Row(
      children: [
        _buildStatCard('Toplam İlan', _listings.length.toString(), Icons.directions_car, AppColors.primary),
        const SizedBox(width: 16),
        _buildStatCard('Aktif', active.toString(), Icons.check_circle, AppColors.success),
        const SizedBox(width: 16),
        _buildStatCard('Beklemede', pending.toString(), Icons.pending, AppColors.warning),
        const SizedBox(width: 16),
        _buildStatCard('Satıldı', sold.toString(), Icons.sell, AppColors.info),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.directions_car, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          const Text(
            'İlan bulunamadı',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
          if (_searchQuery.isNotEmpty || _statusFilter != 'all')
            TextButton(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _statusFilter = 'all';
                  _tabController.animateTo(0);
                });
              },
              child: const Text('Filtreleri Temizle'),
            ),
        ],
      ),
    );
  }

  Widget _buildDataTable(List<Map<String, dynamic>> listings) {
    return DataTable2(
      columnSpacing: 12,
      horizontalMargin: 16,
      minWidth: 1400,
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
        DataColumn2(label: Text('ARAÇ'), size: ColumnSize.L),
        DataColumn2(label: Text('FİYAT'), size: ColumnSize.S),
        DataColumn2(label: Text('YAKIT'), size: ColumnSize.S),
        DataColumn2(label: Text('VİTES'), size: ColumnSize.S),
        DataColumn2(label: Text('KM'), size: ColumnSize.S),
        DataColumn2(label: Text('ŞEHİR'), size: ColumnSize.S),
        DataColumn2(label: Text('DURUM'), size: ColumnSize.S),
        DataColumn2(label: Text('GÖRÜNTÜLENME'), fixedWidth: 120),
        DataColumn2(label: Text('TARİH'), size: ColumnSize.S),
        DataColumn2(label: Text('İŞLEMLER'), size: ColumnSize.M),
      ],
      rows: listings.map((listing) {
        final images = listing['images'];
        String? imageUrl;
        if (images is List && images.isNotEmpty) {
          imageUrl = images[0] as String?;
        }

        final brandName = listing['brand_name'] ?? '';
        final modelName = listing['model_name'] ?? '';
        final year = listing['year']?.toString() ?? '';
        final title = '$brandName $modelName $year'.trim();

        return DataRow2(
          cells: [
            // Thumbnail + Title
            DataCell(
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(6),
                      image: imageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(imageUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: imageUrl == null
                        ? const Icon(Icons.directions_car, color: AppColors.textMuted, size: 20)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title.isNotEmpty ? title : (listing['title'] ?? 'İsimsiz'),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            if (listing['is_featured'] == true)
                              _buildMiniTag('Öne Çıkan', AppColors.warning),
                            if (listing['is_premium'] == true)
                              _buildMiniTag('Premium', AppColors.primary),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Price
            DataCell(
              Text(
                listing['price'] != null
                    ? _currencyFormat.format(listing['price'])
                    : '-',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            // Fuel type
            DataCell(Text(_translateFuelType(listing['fuel_type']))),
            // Transmission
            DataCell(Text(_translateTransmission(listing['transmission']))),
            // Mileage
            DataCell(
              Text(
                listing['mileage'] != null
                    ? '${NumberFormat('#,###', 'tr_TR').format(listing['mileage'])} km'
                    : '-',
              ),
            ),
            // City
            DataCell(Text(listing['city'] ?? '-')),
            // Status
            DataCell(_buildStatusBadge(listing['status'] ?? 'pending')),
            // View count
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.visibility, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text('${listing['view_count'] ?? 0}'),
                ],
              ),
            ),
            // Created at
            DataCell(
              Text(
                listing['created_at'] != null
                    ? _dateFormat.format(DateTime.parse(listing['created_at']))
                    : '-',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
            // Actions
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (listing['status'] == 'pending') ...[
                    IconButton(
                      onPressed: () => _updateListingStatus(listing['id'], 'active'),
                      icon: const Icon(Icons.check_circle, size: 18),
                      color: AppColors.success,
                      tooltip: 'Onayla',
                    ),
                    IconButton(
                      onPressed: () => _updateListingStatus(listing['id'], 'rejected'),
                      icon: const Icon(Icons.cancel, size: 18),
                      color: AppColors.error,
                      tooltip: 'Reddet',
                    ),
                  ],
                  IconButton(
                    onPressed: () => _toggleFeatured(listing),
                    icon: Icon(
                      listing['is_featured'] == true ? Icons.star : Icons.star_border,
                      size: 18,
                    ),
                    color: listing['is_featured'] == true ? AppColors.warning : AppColors.textMuted,
                    tooltip: listing['is_featured'] == true ? 'Öne Çıkarmayı Kaldır' : 'Öne Çıkar',
                  ),
                  IconButton(
                    onPressed: () => _togglePremium(listing),
                    icon: Icon(
                      listing['is_premium'] == true ? Icons.workspace_premium : Icons.workspace_premium_outlined,
                      size: 18,
                    ),
                    color: listing['is_premium'] == true ? AppColors.primary : AppColors.textMuted,
                    tooltip: listing['is_premium'] == true ? 'Premium Kaldır' : 'Premium Yap',
                  ),
                  IconButton(
                    onPressed: () => _showDetailDialog(listing),
                    icon: const Icon(Icons.visibility, size: 18),
                    color: AppColors.textMuted,
                    tooltip: 'Detay',
                  ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildMiniTag(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4, top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;

    switch (status) {
      case 'active':
        color = AppColors.success;
        text = 'Aktif';
        break;
      case 'pending':
        color = AppColors.warning;
        text = 'Beklemede';
        break;
      case 'sold':
        color = AppColors.info;
        text = 'Satıldı';
        break;
      case 'reserved':
        color = AppColors.primary;
        text = 'Rezerve';
        break;
      case 'expired':
        color = AppColors.textMuted;
        text = 'Süresi Doldu';
        break;
      case 'rejected':
        color = AppColors.error;
        text = 'Reddedildi';
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

  String _translateFuelType(String? fuelType) {
    switch (fuelType) {
      case 'gasoline':
        return 'Benzin';
      case 'diesel':
        return 'Dizel';
      case 'lpg':
        return 'LPG';
      case 'electric':
        return 'Elektrik';
      case 'hybrid':
        return 'Hibrit';
      default:
        return fuelType ?? '-';
    }
  }

  String _translateTransmission(String? transmission) {
    switch (transmission) {
      case 'automatic':
        return 'Otomatik';
      case 'manual':
        return 'Manuel';
      case 'semi_automatic':
        return 'Yarı Otomatik';
      default:
        return transmission ?? '-';
    }
  }

  Future<void> _updateListingStatus(String listingId, String newStatus) async {
    final actionLabel = newStatus == 'active' ? 'onaylamak' : 'reddetmek';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Onay', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Bu ilanı $actionLabel istediğinizden emin misiniz?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == 'active' ? AppColors.success : AppColors.error,
            ),
            child: Text(newStatus == 'active' ? 'Onayla' : 'Reddet'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = ref.read(supabaseProvider);
      final updates = <String, dynamic>{
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (newStatus == 'active') {
        updates['published_at'] = DateTime.now().toIso8601String();
      }

      await supabase.from('car_listings').update(updates).eq('id', listingId);

      _fetchListings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == 'active' ? 'İlan onaylandı' : 'İlan reddedildi'),
            backgroundColor: newStatus == 'active' ? AppColors.success : AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _toggleFeatured(Map<String, dynamic> listing) async {
    try {
      final supabase = ref.read(supabaseProvider);
      final newValue = !(listing['is_featured'] == true);
      await supabase.from('car_listings').update({
        'is_featured': newValue,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', listing['id']);

      _fetchListings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newValue ? 'İlan öne çıkarıldı' : 'Öne çıkarma kaldırıldı'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _togglePremium(Map<String, dynamic> listing) async {
    try {
      final supabase = ref.read(supabaseProvider);
      final newValue = !(listing['is_premium'] == true);
      await supabase.from('car_listings').update({
        'is_premium': newValue,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', listing['id']);

      _fetchListings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newValue ? 'İlan premium yapıldı' : 'Premium kaldırıldı'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showDetailDialog(Map<String, dynamic> listing) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'İlan Detayları',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Başlık', listing['title'] ?? '-'),
                _buildDetailRow('Marka', listing['brand_name'] ?? '-'),
                _buildDetailRow('Model', listing['model_name'] ?? '-'),
                _buildDetailRow('Yıl', listing['year']?.toString() ?? '-'),
                _buildDetailRow(
                  'Fiyat',
                  listing['price'] != null
                      ? '${_currencyFormat.format(listing['price'])} ${listing['currency'] ?? 'TRY'}'
                      : '-',
                ),
                _buildDetailRow('Yakıt', _translateFuelType(listing['fuel_type'])),
                _buildDetailRow('Vites', _translateTransmission(listing['transmission'])),
                _buildDetailRow('Kasa Tipi', listing['body_type'] ?? '-'),
                _buildDetailRow(
                  'Kilometre',
                  listing['mileage'] != null
                      ? '${NumberFormat('#,###', 'tr_TR').format(listing['mileage'])} km'
                      : '-',
                ),
                _buildDetailRow('Şehir', listing['city'] ?? '-'),
                _buildDetailRow('Durum', listing['status'] ?? '-'),
                _buildDetailRow('Görüntülenme', '${listing['view_count'] ?? 0}'),
                _buildDetailRow('Favori', '${listing['favorite_count'] ?? 0}'),
                _buildDetailRow('İletişim', '${listing['contact_count'] ?? 0}'),
                _buildDetailRow('Öne Çıkan', listing['is_featured'] == true ? 'Evet' : 'Hayır'),
                _buildDetailRow('Premium', listing['is_premium'] == true ? 'Evet' : 'Hayır'),
                _buildDetailRow(
                  'Oluşturulma',
                  listing['created_at'] != null
                      ? DateTime.parse(listing['created_at']).toString().split('.')[0]
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
}
