import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  bool _isGridView = true;
  Timer? _debounce;
  final _currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 0);
  final _numberFormat = NumberFormat('#,###', 'tr_TR');

  List<Map<String, dynamic>> _listings = [];
  bool _isLoading = true;

  late TabController _tabController;

  final List<Map<String, String>> _statusTabs = [
    {'key': 'all', 'label': 'Tümü'},
    {'key': 'active', 'label': 'Aktif'},
    {'key': 'pending', 'label': 'Beklemede'},
    {'key': 'inactive', 'label': 'Pasif'},
    {'key': 'sold', 'label': 'Satıldı'},
    {'key': 'reserved', 'label': 'Rezerve'},
    {'key': 'expired', 'label': 'Süresi Dolmuş'},
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
    if (!mounted) {
      return;
    }
    setState(() => _isLoading = true);

    try {
      final supabase = ref.read(supabaseProvider);
      final response = await supabase
          .from('car_listings')
          .select()
          .eq('dealer_id', widget.dealerId)
          .order('created_at', ascending: false);

      if (!mounted) {
        return;
      }
      setState(() {
        _listings = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('fetchListings error: $e');
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Araç ilanları yüklenemedi: $e'), backgroundColor: Colors.red),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredListings {
    return _listings.where((listing) {
      final brand = (listing['brand'] ?? listing['brand_name'] ?? '').toString().toLowerCase();
      final model = (listing['model'] ?? listing['model_name'] ?? '').toString().toLowerCase();
      final title = (listing['title'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      final matchesSearch = _searchQuery.isEmpty ||
          brand.contains(query) ||
          model.contains(query) ||
          title.contains(query);

      final matchesStatus = _statusFilter == 'all' ||
          listing['status'] == _statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  String _getListingTitle(Map<String, dynamic> listing) {
    final brand = listing['brand'] ?? listing['brand_name'] ?? '';
    final model = listing['model'] ?? listing['model_name'] ?? '';
    final year = listing['year']?.toString() ?? '';
    final composed = '$brand $model $year'.trim();
    return composed.isNotEmpty ? composed : (listing['title'] ?? 'İsimsiz');
  }

  String? _getFirstImage(Map<String, dynamic> listing) {
    final images = listing['images'];
    if (images is List && images.isNotEmpty) {
      return images[0] as String?;
    }
    return null;
  }

  String _formatPrice(dynamic price) {
    if (price == null) {
      return '-';
    }
    return _currencyFormat.format(price);
  }

  String _formatMileage(dynamic mileage) {
    if (mileage == null) {
      return '-';
    }
    return '${_numberFormat.format(mileage)} km';
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

  String _translateBodyType(String? bodyType) {
    switch (bodyType) {
      case 'sedan':
        return 'Sedan';
      case 'hatchback':
        return 'Hatchback';
      case 'suv':
        return 'SUV';
      case 'coupe':
        return 'Coupe';
      case 'convertible':
        return 'Cabrio';
      case 'pickup':
        return 'Pickup';
      case 'van':
        return 'Van';
      case 'minivan':
        return 'Minivan';
      case 'wagon':
        return 'Station Wagon';
      default:
        return bodyType ?? '-';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'sold':
        return AppColors.info;
      case 'reserved':
        return AppColors.primary;
      case 'expired':
        return AppColors.textMuted;
      case 'rejected':
        return AppColors.error;
      case 'inactive':
        return AppColors.textMuted;
      default:
        return AppColors.textMuted;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Aktif';
      case 'pending':
        return 'Beklemede';
      case 'inactive':
        return 'Pasif';
      case 'sold':
        return 'Satıldı';
      case 'reserved':
        return 'Rezerve';
      case 'expired':
        return 'Süresi Dolmuş';
      case 'rejected':
        return 'Reddedildi';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredListings;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
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
                    // Grid/List toggle
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.surfaceLight),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildViewToggleButton(
                            icon: Icons.grid_view_rounded,
                            isActive: _isGridView,
                            onTap: () => setState(() => _isGridView = true),
                          ),
                          _buildViewToggleButton(
                            icon: Icons.view_list_rounded,
                            isActive: !_isGridView,
                            onTap: () => setState(() => _isGridView = false),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
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
              child: TabBar(
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
              child: TextField(
                onChanged: (value) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 300), () {
                    if (mounted) {
                      setState(() => _searchQuery = value);
                    }
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Marka, model veya başlık ara...',
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

            const SizedBox(height: 16),

            // Listings content
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filtered.isEmpty)
              _buildEmptyState()
            else if (_isGridView)
              _buildGridView(filtered)
            else
              _buildListView(filtered),
          ],
        ),
      ),
    );
  }

  Widget _buildViewToggleButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isActive ? AppColors.primary : AppColors.textMuted,
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

  // ==================== GRID VIEW ====================

  Widget _buildGridView(List<Map<String, dynamic>> listings) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 420,
        mainAxisExtent: 340,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: listings.length,
      itemBuilder: (context, index) {
        return _buildListingCard(listings[index]);
      },
    );
  }

  Widget _buildListingCard(Map<String, dynamic> listing) {
    final imageUrl = _getFirstImage(listing);
    final title = _getListingTitle(listing);
    final status = (listing['status'] ?? 'pending') as String;
    final isPending = status == 'pending';

    return InkWell(
      onTap: () => _showDetailDialog(listing),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            SizedBox(
              height: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                    ),
                    child: imageUrl != null
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _buildImagePlaceholder(),
                          )
                        : _buildImagePlaceholder(),
                  ),
                  // Status badge
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _buildStatusBadge(status),
                  ),
                  // Premium / Featured badges
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (listing['is_premium'] == true)
                          _buildGradientBadge('Premium', [AppColors.primary, AppColors.primaryLight]),
                        if (listing['is_premium'] == true && listing['is_featured'] == true)
                          const SizedBox(width: 4),
                        if (listing['is_featured'] == true)
                          _buildGradientBadge('Öne Çıkan', [AppColors.warning, const Color(0xFFFBBF24)]),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Info section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Spec chips
                    Row(
                      children: [
                        _buildSpecChip(_formatMileage(listing['mileage'])),
                        const SizedBox(width: 6),
                        _buildSpecChip(_translateFuelType(listing['fuel_type'])),
                        const SizedBox(width: 6),
                        _buildSpecChip(_translateTransmission(listing['transmission'])),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Price
                    Text(
                      _formatPrice(listing['price']),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),

                    const Spacer(),

                    // Bottom row: stats + actions
                    Row(
                      children: [
                        // View count
                        Icon(Icons.visibility_outlined, size: 14, color: AppColors.textMuted.withValues(alpha: 0.8)),
                        const SizedBox(width: 3),
                        Text(
                          '${listing['view_count'] ?? 0}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                        const SizedBox(width: 10),
                        // Favorite count
                        Icon(Icons.favorite_outline, size: 14, color: AppColors.textMuted.withValues(alpha: 0.8)),
                        const SizedBox(width: 3),
                        Text(
                          '${listing['favorite_count'] ?? 0}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                        const SizedBox(width: 10),
                        // Contact count
                        Icon(Icons.phone_outlined, size: 14, color: AppColors.textMuted.withValues(alpha: 0.8)),
                        const SizedBox(width: 3),
                        Text(
                          '${listing['contact_count'] ?? 0}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                        const Spacer(),
                        // Pending actions
                        if (isPending) ...[
                          _buildMiniActionButton(
                            icon: Icons.check_circle,
                            color: AppColors.success,
                            tooltip: 'Onayla',
                            onTap: () => _updateListingStatus(listing['id'], 'active'),
                          ),
                          const SizedBox(width: 4),
                          _buildMiniActionButton(
                            icon: Icons.cancel,
                            color: AppColors.error,
                            tooltip: 'Reddet',
                            onTap: () => _showRejectDialog(listing['id']),
                          ),
                        ],
                        if (status == 'active' || status == 'inactive') ...[
                          _buildMiniActionButton(
                            icon: status == 'active' ? Icons.pause_circle_filled : Icons.play_circle_filled,
                            color: status == 'active' ? AppColors.warning : AppColors.success,
                            tooltip: status == 'active' ? 'Pasife Al' : 'Aktif Et',
                            onTap: () => _updateListingStatus(
                              listing['id'],
                              status == 'active' ? 'inactive' : 'active',
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (!isPending)
                          _buildMiniActionButton(
                            icon: Icons.more_vert,
                            color: AppColors.textMuted,
                            tooltip: 'İşlemler',
                            onTap: () => _showActionsMenu(listing),
                          ),
                      ],
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

  // ==================== LIST VIEW ====================

  Widget _buildListView(List<Map<String, dynamic>> listings) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: listings.length,
      itemBuilder: (context, index) {
        return _buildListingRow(listings[index]);
      },
    );
  }

  Widget _buildListingRow(Map<String, dynamic> listing) {
    final imageUrl = _getFirstImage(listing);
    final title = _getListingTitle(listing);
    final status = (listing['status'] ?? 'pending') as String;
    final isPending = status == 'pending';

    return InkWell(
      onTap: () => _showDetailDialog(listing),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 120,
                height: 80,
                child: imageUrl != null
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _buildImagePlaceholder(),
                      )
                    : _buildImagePlaceholder(),
              ),
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + badges
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (listing['is_premium'] == true)
                        _buildMiniTag('Premium', AppColors.primary),
                      if (listing['is_featured'] == true)
                        _buildMiniTag('Öne Çıkan', AppColors.warning),
                      const SizedBox(width: 8),
                      _buildStatusBadge(status),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Spec chips
                  Row(
                    children: [
                      _buildSpecChip(_formatMileage(listing['mileage'])),
                      const SizedBox(width: 6),
                      _buildSpecChip(_translateFuelType(listing['fuel_type'])),
                      const SizedBox(width: 6),
                      _buildSpecChip(_translateTransmission(listing['transmission'])),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Price + stats + actions
                  Row(
                    children: [
                      Text(
                        _formatPrice(listing['price']),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Icon(Icons.visibility_outlined, size: 14, color: AppColors.textMuted.withValues(alpha: 0.8)),
                      const SizedBox(width: 3),
                      Text('${listing['view_count'] ?? 0}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      const SizedBox(width: 10),
                      Icon(Icons.favorite_outline, size: 14, color: AppColors.textMuted.withValues(alpha: 0.8)),
                      const SizedBox(width: 3),
                      Text('${listing['favorite_count'] ?? 0}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      const SizedBox(width: 10),
                      Icon(Icons.phone_outlined, size: 14, color: AppColors.textMuted.withValues(alpha: 0.8)),
                      const SizedBox(width: 3),
                      Text('${listing['contact_count'] ?? 0}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      const Spacer(),
                      if (isPending) ...[
                        _buildMiniActionButton(
                          icon: Icons.check_circle,
                          color: AppColors.success,
                          tooltip: 'Onayla',
                          onTap: () => _updateListingStatus(listing['id'], 'active'),
                        ),
                        const SizedBox(width: 4),
                        _buildMiniActionButton(
                          icon: Icons.cancel,
                          color: AppColors.error,
                          tooltip: 'Reddet',
                          onTap: () => _showRejectDialog(listing['id']),
                        ),
                      ],
                      if (status == 'active' || status == 'inactive') ...[
                        _buildMiniActionButton(
                          icon: status == 'active' ? Icons.pause_circle_filled : Icons.play_circle_filled,
                          color: status == 'active' ? AppColors.warning : AppColors.success,
                          tooltip: status == 'active' ? 'Pasife Al' : 'Aktif Et',
                          onTap: () => _updateListingStatus(
                            listing['id'],
                            status == 'active' ? 'inactive' : 'active',
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      _buildMiniActionButton(
                        icon: Icons.star,
                        color: listing['is_featured'] == true ? AppColors.warning : AppColors.textMuted,
                        tooltip: listing['is_featured'] == true ? 'Öne Çıkarmayı Kaldır' : 'Öne Çıkar',
                        onTap: () => _toggleFeatured(listing),
                      ),
                      const SizedBox(width: 4),
                      _buildMiniActionButton(
                        icon: Icons.workspace_premium,
                        color: listing['is_premium'] == true ? AppColors.primary : AppColors.textMuted,
                        tooltip: listing['is_premium'] == true ? 'Premium Kaldır' : 'Premium Yap',
                        onTap: () => _togglePremium(listing),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== SHARED WIDGETS ====================

  Widget _buildImagePlaceholder() {
    return Container(
      color: AppColors.surfaceLight,
      child: const Center(
        child: Icon(Icons.directions_car, color: AppColors.textMuted, size: 32),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildGradientBadge(String label, List<Color> gradient) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildMiniTag(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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

  Widget _buildSpecChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildMiniActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  void _showActionsMenu(Map<String, dynamic> listing) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        button.size.width - 200,
        button.size.height / 2,
        0,
        0,
      ),
      color: AppColors.surface,
      items: [
        const PopupMenuItem(
          value: 'detail',
          child: Row(
            children: [
              Icon(Icons.visibility, size: 18, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Text('Detay Görüntüle', style: TextStyle(color: AppColors.textPrimary)),
            ],
          ),
        ),
        if (listing['status'] == 'active' || listing['status'] == 'inactive')
          PopupMenuItem(
            value: 'toggle_status',
            child: Row(
              children: [
                Icon(
                  listing['status'] == 'active' ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  size: 18,
                  color: listing['status'] == 'active' ? AppColors.warning : AppColors.success,
                ),
                const SizedBox(width: 8),
                Text(
                  listing['status'] == 'active' ? 'Pasife Al' : 'Aktif Et',
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'featured',
          child: Row(
            children: [
              Icon(
                listing['is_featured'] == true ? Icons.star : Icons.star_border,
                size: 18,
                color: AppColors.warning,
              ),
              const SizedBox(width: 8),
              Text(
                listing['is_featured'] == true ? 'Öne Çıkarmayı Kaldır' : 'Öne Çıkar',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'premium',
          child: Row(
            children: [
              Icon(
                listing['is_premium'] == true ? Icons.workspace_premium : Icons.workspace_premium_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                listing['is_premium'] == true ? 'Premium Kaldır' : 'Premium Yap',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'detail') {
        _showDetailDialog(listing);
      } else if (value == 'toggle_status') {
        _updateListingStatus(
          listing['id'],
          listing['status'] == 'active' ? 'inactive' : 'active',
        );
      } else if (value == 'featured') {
        _toggleFeatured(listing);
      } else if (value == 'premium') {
        _togglePremium(listing);
      }
    });
  }

  // ==================== DETAIL DIALOG ====================

  void _showDetailDialog(Map<String, dynamic> listing) {
    final images = (listing['images'] is List) ? List<String>.from(listing['images']) : <String>[];
    final features = (listing['features'] is List) ? List<String>.from(listing['features']) : <String>[];
    int currentImageIndex = 0;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dialog header
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppColors.surfaceLight)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getListingTitle(listing),
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _buildStatusBadge((listing['status'] ?? 'pending') as String),
                                    if (listing['is_premium'] == true) ...[
                                      const SizedBox(width: 8),
                                      _buildMiniTag('Premium', AppColors.primary),
                                    ],
                                    if (listing['is_featured'] == true) ...[
                                      const SizedBox(width: 8),
                                      _buildMiniTag('Öne Çıkan', AppColors.warning),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),

                    // Dialog body
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Image gallery
                            if (images.isNotEmpty) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  height: 250,
                                  width: double.infinity,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      PageView.builder(
                                        itemCount: images.length,
                                        onPageChanged: (index) {
                                          setDialogState(() => currentImageIndex = index);
                                        },
                                        itemBuilder: (context, index) {
                                          return Image.network(
                                            images[index],
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) => _buildImagePlaceholder(),
                                          );
                                        },
                                      ),
                                      if (images.length > 1)
                                        Positioned(
                                          bottom: 12,
                                          right: 12,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: Text(
                                              '${currentImageIndex + 1} / ${images.length}',
                                              style: const TextStyle(color: Colors.white, fontSize: 12),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              // Thumbnail strip
                              if (images.length > 1) ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 56,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: images.length,
                                    itemBuilder: (context, index) {
                                      final isActive = index == currentImageIndex;
                                      return GestureDetector(
                                        onTap: () => setDialogState(() => currentImageIndex = index),
                                        child: Container(
                                          width: 72,
                                          margin: const EdgeInsets.only(right: 8),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isActive ? AppColors.primary : AppColors.surfaceLight,
                                              width: isActive ? 2 : 1,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(7),
                                            child: Image.network(
                                              images[index],
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 16, color: AppColors.textMuted),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                            ] else ...[
                              Container(
                                height: 150,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.directions_car, size: 48, color: AppColors.textMuted),
                                      SizedBox(height: 8),
                                      Text('Fotoğraf yok', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Price card
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.sell, color: AppColors.primary, size: 24),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Fiyat', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                      Text(
                                        _formatPrice(listing['price']),
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (listing['currency'] != null && listing['currency'] != 'TRY') ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      listing['currency'],
                                      style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Full specs
                            const Text(
                              'Araç Bilgileri',
                              style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),
                            _buildSpecsGrid(listing),
                            const SizedBox(height: 20),

                            // Features
                            if (features.isNotEmpty) ...[
                              const Text(
                                'Donanım & Özellikler',
                                style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: features.map((f) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.surfaceLight),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.check_circle, size: 14, color: AppColors.success),
                                        const SizedBox(width: 6),
                                        Text(f, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Description
                            if (listing['description'] != null && (listing['description'] as String).isNotEmpty) ...[
                              const Text(
                                'Açıklama',
                                style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  listing['description'],
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Statistics
                            const Text(
                              'İstatistikler',
                              style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildDetailStatCard('Görüntülenme', '${listing['view_count'] ?? 0}', Icons.visibility, AppColors.info),
                                const SizedBox(width: 12),
                                _buildDetailStatCard('Favoriler', '${listing['favorite_count'] ?? 0}', Icons.favorite, AppColors.error),
                                const SizedBox(width: 12),
                                _buildDetailStatCard('İletişim', '${listing['contact_count'] ?? 0}', Icons.phone, AppColors.success),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Dialog footer with actions
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: AppColors.surfaceLight)),
                      ),
                      child: Row(
                        children: [
                          if (listing['status'] == 'pending') ...[
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _updateListingStatus(listing['id'], 'active');
                              },
                              icon: const Icon(Icons.check_circle, size: 18),
                              label: const Text('Onayla'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showRejectDialog(listing['id']);
                              },
                              icon: const Icon(Icons.cancel, size: 18),
                              label: const Text('Reddet'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                          if (listing['status'] == 'active' || listing['status'] == 'inactive') ...[
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _updateListingStatus(
                                  listing['id'],
                                  listing['status'] == 'active' ? 'inactive' : 'active',
                                );
                              },
                              icon: Icon(
                                listing['status'] == 'active'
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_filled,
                                size: 18,
                              ),
                              label: Text(listing['status'] == 'active' ? 'Pasife Al' : 'Aktif Et'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: listing['status'] == 'active'
                                    ? AppColors.warning
                                    : AppColors.success,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          const Spacer(),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _toggleFeatured(listing);
                            },
                            icon: Icon(
                              listing['is_featured'] == true ? Icons.star : Icons.star_border,
                              size: 18,
                              color: AppColors.warning,
                            ),
                            label: Text(listing['is_featured'] == true ? 'Öne Çıkarmayı Kaldır' : 'Öne Çıkar'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _togglePremium(listing);
                            },
                            icon: Icon(
                              listing['is_premium'] == true ? Icons.workspace_premium : Icons.workspace_premium_outlined,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            label: Text(listing['is_premium'] == true ? 'Premium Kaldır' : 'Premium Yap'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSpecsGrid(Map<String, dynamic> listing) {
    final specs = <MapEntry<String, String>>[
      MapEntry('Marka', (listing['brand'] ?? listing['brand_name'] ?? '-').toString()),
      MapEntry('Model', (listing['model'] ?? listing['model_name'] ?? '-').toString()),
      MapEntry('Yıl', listing['year']?.toString() ?? '-'),
      MapEntry('Renk', (listing['color'] ?? '-').toString()),
      MapEntry('Yakıt', _translateFuelType(listing['fuel_type'])),
      MapEntry('Vites', _translateTransmission(listing['transmission'])),
      MapEntry('Kilometre', _formatMileage(listing['mileage'])),
      MapEntry('Motor', listing['engine_size'] != null ? '${listing['engine_size']} cc' : '-'),
      MapEntry('Beygir', listing['horsepower'] != null ? '${listing['horsepower']} HP' : '-'),
      MapEntry('Kasa Tipi', _translateBodyType(listing['body_type'])),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 10,
      children: specs.map((spec) {
        return SizedBox(
          width: 170,
          child: Row(
            children: [
              SizedBox(
                width: 70,
                child: Text(
                  spec.key,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
              Expanded(
                child: Text(
                  spec.value,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDetailStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ==================== ACTIONS ====================

  Future<void> _updateListingStatus(String listingId, String newStatus) async {
    String actionLabel;
    String successMsg;
    Color btnColor;
    String btnLabel;

    switch (newStatus) {
      case 'active':
        actionLabel = 'onaylamak/aktif etmek';
        successMsg = 'İlan aktif edildi';
        btnColor = AppColors.success;
        btnLabel = 'Onayla';
      case 'inactive':
        actionLabel = 'pasife almak';
        successMsg = 'İlan pasife alındı';
        btnColor = AppColors.warning;
        btnLabel = 'Pasife Al';
      case 'rejected':
        actionLabel = 'reddetmek';
        successMsg = 'İlan reddedildi';
        btnColor = AppColors.error;
        btnLabel = 'Reddet';
      default:
        actionLabel = 'değiştirmek';
        successMsg = 'İlan güncellendi';
        btnColor = AppColors.primary;
        btnLabel = 'Onayla';
    }

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
            style: ElevatedButton.styleFrom(backgroundColor: btnColor),
            child: Text(btnLabel),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

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
          SnackBar(content: Text(successMsg), backgroundColor: btnColor),
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

  void _showRejectDialog(String listingId) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('İlanı Reddet', style: TextStyle(color: AppColors.textPrimary)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Red gerekçesini yazınız:',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Örn: Eksik fotoğraf, uygunsuz fiyat, eksik bilgi...',
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final supabase = ref.read(supabaseProvider);
                  await supabase.from('car_listings').update({
                    'status': 'rejected',
                    'rejection_reason': reasonController.text.trim(),
                    'updated_at': DateTime.now().toIso8601String(),
                  }).eq('id', listingId);

                  _fetchListings();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('İlan reddedildi'),
                        backgroundColor: AppColors.warning,
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
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Reddet'),
            ),
          ],
        );
      },
    );
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
}
