import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

class AdminPropertyListingsScreen extends ConsumerStatefulWidget {
  final String realtorId;
  const AdminPropertyListingsScreen({super.key, required this.realtorId});

  @override
  ConsumerState<AdminPropertyListingsScreen> createState() =>
      _AdminPropertyListingsScreenState();
}

class _AdminPropertyListingsScreenState
    extends ConsumerState<AdminPropertyListingsScreen>
    with SingleTickerProviderStateMixin {
  final _currencyFormat = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '\u20BA',
    decimalDigits: 0,
  );
  final _dateFormat = DateFormat('dd MMM yyyy', 'tr');

  String _searchQuery = '';
  Timer? _debounce;
  late TabController _tabController;

  List<Map<String, dynamic>> _properties = [];
  bool _isLoading = true;

  final List<_StatusTab> _tabs = [
    _StatusTab('all', 'Tümü', Icons.apps),
    _StatusTab('active', 'Aktif', Icons.check_circle_outline),
    _StatusTab('pending', 'Beklemede', Icons.pending_outlined),
    _StatusTab('inactive', 'Pasif', Icons.pause_circle_outline),
    _StatusTab('sold', 'Satıldı', Icons.sell_outlined),
    _StatusTab('rented', 'Kiralandı', Icons.key_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this); // 6 tabs
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _fetchProperties();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  String get _currentStatus => _tabs[_tabController.index].key;

  Future<void> _fetchProperties() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final supabase = ref.read(supabaseProvider);
      final response = await supabase
          .from('properties')
          .select()
          .eq('user_id', widget.realtorId)
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _properties = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('fetchProperties error: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İlanlar yüklenemedi: $e'), backgroundColor: Colors.red),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredProperties {
    return _properties.where((p) {
      final title = (p['title'] ?? '').toString().toLowerCase();
      final address = (p['address'] ?? '').toString().toLowerCase();
      final city = (p['city'] ?? '').toString().toLowerCase();
      final district = (p['district'] ?? '').toString().toLowerCase();
      final propertyType = (p['property_type'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      final matchesSearch = _searchQuery.isEmpty ||
          title.contains(query) ||
          address.contains(query) ||
          city.contains(query) ||
          district.contains(query) ||
          propertyType.contains(query);

      final status = p['status'] as String? ?? '';
      final matchesStatus = _currentStatus == 'all' || status == _currentStatus;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  int _countByStatus(String status) {
    return _properties.where((p) => p['status'] == status).length;
  }

  String _formatPrice(num? price) {
    if (price == null) return '-';
    return _currencyFormat.format(price.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProperties;

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
                      'Emlak İlanları',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Emlakci ilanlari yonetin ve onaylayin',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _fetchProperties,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Stats Cards
            Row(
              children: [
                _buildStatCard(
                  'Toplam İlan',
                  _properties.length.toString(),
                  Icons.home_work,
                  AppColors.primary,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Aktif',
                  _countByStatus('active').toString(),
                  Icons.check_circle,
                  AppColors.success,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Beklemede',
                  _countByStatus('pending').toString(),
                  Icons.pending,
                  AppColors.warning,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Satıldı',
                  _countByStatus('sold').toString(),
                  Icons.sell,
                  AppColors.info,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Kiralandı',
                  _countByStatus('rented').toString(),
                  Icons.key,
                  AppColors.primaryLight,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Search + Status Tabs
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: Column(
                children: [
                  // Search Bar
                  TextField(
                    onChanged: (value) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 300), () {
                        if (mounted) {
                          setState(() => _searchQuery = value);
                        }
                      });
                    },
                    decoration: InputDecoration(
                      hintText:
                          'İlan ara (başlık, adres, şehir, ilan tipi)...',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.textMuted,
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Status Tabs
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicatorColor: AppColors.primary,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textMuted,
                    dividerColor: Colors.transparent,
                    tabs: _tabs.map((tab) {
                      final count = tab.key == 'all'
                          ? _properties.length
                          : _countByStatus(tab.key);
                      return Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(tab.icon, size: 16),
                            const SizedBox(width: 6),
                            Text(tab.label),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
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

            const SizedBox(height: 24),

            // Property List
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
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.home_work,
                                  size: 64,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'İlan bulunamadı',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 16,
                                  ),
                                ),
                                if (_searchQuery.isNotEmpty ||
                                    _currentStatus != 'all')
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _searchQuery = '';
                                        _tabController.animateTo(0);
                                      });
                                    },
                                    child: const Text('Filtreleri Temizle'),
                                  ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(8),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) =>
                                _buildPropertyCard(filtered[index]),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyCard(Map<String, dynamic> property) {
    final images = property['images'] as List?;
    final imageUrl =
        images != null && images.isNotEmpty ? images[0] as String? : null;
    final status = property['status'] as String? ?? 'pending';
    final isFeatured = property['is_featured'] == true;
    final area = property['square_meters'];
    final rooms = property['rooms'];
    final bathrooms = property['bathrooms'];
    final price = property['price'] as num?;
    final viewCount = property['view_count'] ?? 0;
    final favoriteCount = property['favorite_count'] ?? 0;
    final createdAt = property['created_at'] != null
        ? DateTime.tryParse(property['created_at'].toString())
        : null;

    return InkWell(
      onTap: () => _showPropertyDetailDialog(property),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: status == 'pending'
                ? AppColors.warning.withValues(alpha: 0.3)
                : AppColors.surfaceLight.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 100,
                height: 80,
                color: AppColors.surfaceLight,
                child: imageUrl != null
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.broken_image,
                          color: AppColors.textMuted,
                          size: 28,
                        ),
                      )
                    : const Icon(
                        Icons.home,
                        color: AppColors.textMuted,
                        size: 28,
                      ),
              ),
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                property['title'] ?? 'İsimsiz',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isFeatured) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.warning.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.star,
                                      color: AppColors.warning,
                                      size: 12,
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      'One Cikan',
                                      style: TextStyle(
                                        color: AppColors.warning,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusBadge(status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Property type + listing type
                  Row(
                    children: [
                      _buildPropertyTypeBadge(
                        property['property_type'] as String?,
                        property['listing_type'] as String?,
                      ),
                      const SizedBox(width: 12),
                      if (property['district'] != null ||
                          property['city'] != null)
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 13,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${property['district'] ?? ''}, ${property['city'] ?? ''}',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Quick stats row
                  Row(
                    children: [
                      // Price
                      Text(
                        _formatPrice(price),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Area
                      if (area != null) ...[
                        _buildQuickStat(Icons.square_foot, '$area m\u00B2'),
                        const SizedBox(width: 12),
                      ],
                      // Rooms
                      if (rooms != null) ...[
                        _buildQuickStat(Icons.meeting_room, '$rooms Oda'),
                        const SizedBox(width: 12),
                      ],
                      // Bathrooms
                      if (bathrooms != null) ...[
                        _buildQuickStat(Icons.bathtub, '$bathrooms'),
                        const SizedBox(width: 12),
                      ],
                      const Spacer(),
                      // Views
                      _buildQuickStat(Icons.visibility, '$viewCount'),
                      const SizedBox(width: 12),
                      // Favorites
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.favorite,
                            size: 13,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$favoriteCount',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // Date
                      if (createdAt != null)
                        Text(
                          _dateFormat.format(createdAt),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Actions
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                if (status == 'pending') ...[
                  _buildIconAction(
                    Icons.check_circle,
                    AppColors.success,
                    'Onayla',
                    () => _updatePropertyStatus(property['id'], 'active'),
                  ),
                  const SizedBox(height: 4),
                  _buildIconAction(
                    Icons.cancel,
                    AppColors.error,
                    'Reddet',
                    () => _updatePropertyStatus(property['id'], 'rejected'),
                  ),
                  const SizedBox(height: 4),
                ],
                if (status == 'active' || status == 'inactive') ...[
                  _buildIconAction(
                    status == 'active' ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    status == 'active' ? AppColors.warning : AppColors.success,
                    status == 'active' ? 'Pasife Al' : 'Aktif Et',
                    () => _updatePropertyStatus(
                      property['id'],
                      status == 'active' ? 'inactive' : 'active',
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                _buildIconAction(
                  isFeatured ? Icons.star : Icons.star_border,
                  isFeatured ? AppColors.warning : AppColors.textMuted,
                  isFeatured ? 'Öne Çıkarmayı Kaldır' : 'Öne Çıkar',
                  () => _toggleFeatured(property['id'], isFeatured),
                ),
                const SizedBox(height: 4),
                // Quick status dropdown
                PopupMenuButton<String>(
                  onSelected: (newStatus) =>
                      _updatePropertyStatus(property['id'], newStatus),
                  tooltip: 'Durum Değiştir',
                  icon: const Icon(
                    Icons.swap_horiz,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'active',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 16, color: AppColors.success),
                          SizedBox(width: 8),
                          Text('Aktif'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'pending',
                      child: Row(
                        children: [
                          Icon(Icons.pending, size: 16, color: AppColors.warning),
                          SizedBox(width: 8),
                          Text('Beklemede'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'inactive',
                      child: Row(
                        children: [
                          Icon(Icons.pause_circle_filled, size: 16, color: AppColors.textMuted),
                          SizedBox(width: 8),
                          Text('Pasif'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'sold',
                      child: Row(
                        children: [
                          Icon(Icons.sell, size: 16, color: AppColors.info),
                          SizedBox(width: 8),
                          Text('Satıldı'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'rented',
                      child: Row(
                        children: [
                          Icon(Icons.key, size: 16, color: AppColors.primaryLight),
                          SizedBox(width: 8),
                          Text('Kiralandı'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconAction(
    IconData icon,
    Color color,
    String tooltip,
    VoidCallback onPressed,
  ) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      color: color,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }

  Widget _buildQuickStat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
    );
  }

  void _showPropertyDetailDialog(Map<String, dynamic> property) {
    final images = property['images'] as List? ?? [];
    final features = <String>[
      if (property['has_parking'] == true) 'Otopark',
      if (property['has_balcony'] == true) 'Balkon',
      if (property['has_elevator'] == true) 'Asansör',
      if (property['has_garden'] == true) 'Bahçe',
      if (property['has_pool'] == true) 'Havuz',
      if (property['has_security'] == true) 'Güvenlik',
      if (property['has_gym'] == true) 'Spor Salonu',
      if (property['has_furnished'] == true) 'Eşyalı',
    ];
    final status = property['status'] as String? ?? 'pending';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.surfaceLight),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        property['title'] ?? 'İlan Detayı',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildStatusBadge(status),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Images
                      if (images.isNotEmpty) ...[
                        SizedBox(
                          height: 180,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: images.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (_, i) => ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                images[i].toString(),
                                width: 240,
                                height: 180,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  width: 240,
                                  height: 180,
                                  color: AppColors.surfaceLight,
                                  child: const Icon(
                                    Icons.broken_image,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      // Price
                      Text(
                        _formatPrice(
                            (property['price'] as num?)?.toDouble()),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Quick info grid
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          if (property['square_meters'] != null)
                            _buildDetailChip(
                              Icons.square_foot,
                              '${property['square_meters']} m\u00B2',
                            ),
                          if (property['rooms'] != null)
                            _buildDetailChip(
                              Icons.meeting_room,
                              '${property['rooms']} Oda',
                            ),
                          if (property['bathrooms'] != null)
                            _buildDetailChip(
                              Icons.bathtub,
                              '${property['bathrooms']} Banyo',
                            ),
                          if (property['floor'] != null)
                            _buildDetailChip(
                              Icons.layers,
                              'Kat: ${property['floor']}/${property['total_floors'] ?? '?'}',
                            ),
                          if (property['heating_type'] != null)
                            _buildDetailChip(
                              Icons.thermostat,
                              '${property['heating_type']}',
                            ),
                          if (property['facing_direction'] != null)
                            _buildDetailChip(
                              Icons.compass_calibration,
                              '${property['facing_direction']}',
                            ),
                          if (property['deed_type'] != null)
                            _buildDetailChip(
                              Icons.description,
                              '${property['deed_type']}',
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Location
                      if (property['address'] != null ||
                          property['city'] != null) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 16,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                [
                                  property['address'],
                                  property['district'],
                                  property['city'],
                                ]
                                    .where((e) => e != null && e.toString().isNotEmpty)
                                    .join(', '),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Description
                      if (property['description'] != null &&
                          (property['description'] as String).isNotEmpty) ...[
                        const Text(
                          'Açıklama',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          property['description'],
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Features
                      if (features.isNotEmpty) ...[
                        const Text(
                          'Özellikler',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: features.map((f) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                f.toString(),
                                style: const TextStyle(
                                  color: AppColors.primaryLight,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Stats
                      const Divider(color: AppColors.surfaceLight),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildStatItem(
                            Icons.visibility,
                            '${property['view_count'] ?? 0}',
                            'Görüntülenme',
                          ),
                          const SizedBox(width: 24),
                          _buildStatItem(
                            Icons.favorite,
                            '${property['favorite_count'] ?? 0}',
                            'Favori',
                          ),
                          const SizedBox(width: 24),
                          if (property['created_at'] != null)
                            _buildStatItem(
                              Icons.calendar_today,
                              _dateFormat.format(
                                DateTime.parse(property['created_at']),
                              ),
                              'İlan Tarihi',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Footer Actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.surfaceLight),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (status == 'pending') ...[
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _updatePropertyStatus(property['id'], 'active');
                        },
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Onayla'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _updatePropertyStatus(property['id'], 'rejected');
                        },
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Reddet'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                    if (status == 'active' || status == 'inactive') ...[
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _updatePropertyStatus(
                            property['id'],
                            status == 'active' ? 'inactive' : 'active',
                          );
                        },
                        icon: Icon(
                          status == 'active' ? Icons.pause_circle_filled : Icons.play_circle_filled,
                          size: 18,
                        ),
                        label: Text(status == 'active' ? 'Pasife Al' : 'Aktif Et'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: status == 'active' ? AppColors.warning : AppColors.success,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (status != 'pending') ...[
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Kapat'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String text) {
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
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
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
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
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
      case 'rented':
        color = AppColors.primaryLight;
        text = 'Kiralandı';
        break;
      case 'rejected':
        color = AppColors.error;
        text = 'Reddedildi';
        break;
      case 'inactive':
        color = AppColors.textMuted;
        text = 'Pasif';
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
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPropertyTypeBadge(String? propertyType, String? listingType) {
    final type = propertyType ?? '-';
    final listing = listingType ?? '';

    String typeText;
    switch (type) {
      case 'apartment':
        typeText = 'Daire';
        break;
      case 'house':
        typeText = 'Müstakil';
        break;
      case 'villa':
        typeText = 'Villa';
        break;
      case 'land':
        typeText = 'Arsa';
        break;
      case 'commercial':
        typeText = 'Ticari';
        break;
      case 'office':
        typeText = 'Ofis';
        break;
      default:
        typeText = type;
    }

    String listingText = '';
    if (listing == 'sale') {
      listingText = 'Satılık';
    } else if (listing == 'rent') {
      listingText = 'Kiralık';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        listingText.isNotEmpty ? '$typeText / $listingText' : typeText,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
        ),
      ),
    );
  }

  Future<void> _updatePropertyStatus(
      String propertyId, String newStatus) async {
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.from('properties').update({
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', propertyId);

      _fetchProperties();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'active'
                ? 'İlan aktif edildi'
                : newStatus == 'inactive'
                    ? 'İlan pasife alındı'
                    : newStatus == 'rejected'
                        ? 'İlan reddedildi'
                        : 'İlan durumu güncellendi',
          ),
          backgroundColor: newStatus == 'active'
              ? AppColors.success
              : newStatus == 'inactive'
                  ? AppColors.warning
                  : AppColors.info,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _toggleFeatured(
      String propertyId, bool currentlyFeatured) async {
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.from('properties').update({
        'is_featured': !currentlyFeatured,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', propertyId);

      _fetchProperties();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!currentlyFeatured
              ? 'İlan öne çıkarıldı'
              : 'Öne çıkarma kaldırıldı'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
      );
    }
  }
}

class _StatusTab {
  final String key;
  final String label;
  final IconData icon;
  const _StatusTab(this.key, this.label, this.icon);
}
