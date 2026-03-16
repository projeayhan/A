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
  ConsumerState<AdminPropertyListingsScreen> createState() => _AdminPropertyListingsScreenState();
}

class _AdminPropertyListingsScreenState extends ConsumerState<AdminPropertyListingsScreen> {
  final _currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '\u20BA', decimalDigits: 0);
  final _dateFormat = DateFormat('dd MMM yyyy', 'tr');

  String _searchQuery = '';
  String _statusFilter = 'all';
  Timer? _debounce;

  List<Map<String, dynamic>> _properties = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProperties();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

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
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredProperties {
    return _properties.where((p) {
      final title = (p['title'] ?? '').toString().toLowerCase();
      final city = (p['city'] ?? '').toString().toLowerCase();
      final matchesSearch = _searchQuery.isEmpty ||
          title.contains(_searchQuery.toLowerCase()) ||
          city.contains(_searchQuery.toLowerCase());

      final status = p['status'] as String? ?? '';
      final matchesStatus = _statusFilter == 'all' || status == _statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProperties;

    final activeCount = _properties.where((p) => p['status'] == 'active').length;
    final pendingCount = _properties.where((p) => p['status'] == 'pending').length;
    final soldCount = _properties.where((p) => p['status'] == 'sold').length;
    final rentedCount = _properties.where((p) => p['status'] == 'rented').length;

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
                      'Emlak Ilanlari',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Emlakci ilanlari yonetin ve onaylayin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
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
                _buildStatCard('Toplam Ilan', _properties.length.toString(), Icons.home_work, AppColors.primary),
                const SizedBox(width: 16),
                _buildStatCard('Aktif', activeCount.toString(), Icons.check_circle, AppColors.success),
                const SizedBox(width: 16),
                _buildStatCard('Beklemede', pendingCount.toString(), Icons.pending, AppColors.warning),
                const SizedBox(width: 16),
                _buildStatCard('Satildi', soldCount.toString(), Icons.sell, AppColors.info),
                const SizedBox(width: 16),
                _buildStatCard('Kiralandi', rentedCount.toString(), Icons.key, AppColors.primaryLight),
              ],
            ),

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
                        hintText: 'Ilan ara (baslik, sehir)...',
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
                          DropdownMenuItem(value: 'all', child: Text('Tumu')),
                          DropdownMenuItem(value: 'active', child: Text('Aktif')),
                          DropdownMenuItem(value: 'pending', child: Text('Beklemede')),
                          DropdownMenuItem(value: 'sold', child: Text('Satildi')),
                          DropdownMenuItem(value: 'rented', child: Text('Kiralandi')),
                        ],
                        onChanged: (value) => setState(() => _statusFilter = value!),
                      ),
                    ),
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
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.home_work, size: 64, color: AppColors.textMuted),
                                const SizedBox(height: 16),
                                const Text(
                                  'Ilan bulunamadi',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                                ),
                                if (_searchQuery.isNotEmpty || _statusFilter != 'all')
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _searchQuery = '';
                                        _statusFilter = 'all';
                                      });
                                    },
                                    child: const Text('Filtreleri Temizle'),
                                  ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              // Table header
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    topRight: Radius.circular(12),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    SizedBox(width: 60, child: Text('GORSEL', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                                    SizedBox(width: 16),
                                    Expanded(flex: 3, child: Text('BASLIK', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                                    Expanded(flex: 2, child: Text('TIP', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                                    Expanded(flex: 2, child: Text('FIYAT', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                                    Expanded(flex: 2, child: Text('KONUM', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                                    Expanded(child: Text('DURUM', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                                    SizedBox(width: 60, child: Text('GORUNTULENME', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600))),
                                    SizedBox(width: 16),
                                    SizedBox(width: 50, child: Text('FAVORI', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600))),
                                    SizedBox(width: 16),
                                    Expanded(flex: 2, child: Text('TARIH', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                                    SizedBox(width: 140, child: Text('ISLEMLER', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
                                  ],
                                ),
                              ),
                              const Divider(height: 1, color: AppColors.surfaceLight),
                              // Table body
                              Expanded(
                                child: ListView.separated(
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.surfaceLight),
                                  itemBuilder: (context, index) => _buildPropertyRow(filtered[index]),
                                ),
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

  Widget _buildPropertyRow(Map<String, dynamic> property) {
    final images = property['images'] as List?;
    final imageUrl = images != null && images.isNotEmpty ? images[0] as String? : null;
    final status = property['status'] as String? ?? 'pending';
    final isFeatured = property['is_featured'] == true;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Thumbnail
          Container(
            width: 60,
            height: 45,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: AppColors.surfaceLight,
              image: imageUrl != null
                  ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
                  : null,
            ),
            child: imageUrl == null
                ? const Icon(Icons.home, color: AppColors.textMuted, size: 20)
                : null,
          ),
          const SizedBox(width: 16),
          // Title
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        property['title'] ?? 'Isimsiz',
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isFeatured) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.star, color: AppColors.warning, size: 16),
                    ],
                  ],
                ),
                if (property['rooms'] != null || property['square_meters'] != null)
                  Text(
                    '${property['rooms'] ?? '-'} oda, ${property['square_meters'] ?? '-'} m\u00B2',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
              ],
            ),
          ),
          // Property type
          Expanded(
            flex: 2,
            child: _buildPropertyTypeBadge(property['property_type'] as String?, property['listing_type'] as String?),
          ),
          // Price
          Expanded(
            flex: 2,
            child: Text(
              _currencyFormat.format((property['price'] as num?)?.toDouble() ?? 0),
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          // Location
          Expanded(
            flex: 2,
            child: Text(
              '${property['district'] ?? ''}, ${property['city'] ?? ''}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Status
          Expanded(child: _buildStatusBadge(status)),
          // Views
          SizedBox(
            width: 60,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.visibility, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text('${property['view_count'] ?? 0}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Favorites
          SizedBox(
            width: 50,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.favorite, size: 14, color: AppColors.error),
                const SizedBox(width: 4),
                Text('${property['favorite_count'] ?? 0}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Date
          Expanded(
            flex: 2,
            child: Text(
              property['created_at'] != null ? _dateFormat.format(DateTime.parse(property['created_at'])) : '-',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          // Actions
          SizedBox(
            width: 140,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status == 'pending') ...[
                  IconButton(
                    onPressed: () => _updatePropertyStatus(property['id'], 'active'),
                    icon: const Icon(Icons.check_circle, size: 18),
                    color: AppColors.success,
                    tooltip: 'Onayla',
                  ),
                  IconButton(
                    onPressed: () => _updatePropertyStatus(property['id'], 'rejected'),
                    icon: const Icon(Icons.cancel, size: 18),
                    color: AppColors.error,
                    tooltip: 'Reddet',
                  ),
                ],
                IconButton(
                  onPressed: () => _toggleFeatured(property['id'], isFeatured),
                  icon: Icon(isFeatured ? Icons.star : Icons.star_border, size: 18),
                  color: isFeatured ? AppColors.warning : AppColors.textMuted,
                  tooltip: isFeatured ? 'One Cikarmayi Kaldir' : 'One Cikar',
                ),
              ],
            ),
          ),
        ],
      ),
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
        text = 'Satildi';
        break;
      case 'rented':
        color = AppColors.primaryLight;
        text = 'Kiralandi';
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

  Widget _buildPropertyTypeBadge(String? propertyType, String? listingType) {
    final type = propertyType ?? '-';
    final listing = listingType ?? '';

    String typeText;
    switch (type) {
      case 'apartment':
        typeText = 'Daire';
        break;
      case 'house':
        typeText = 'Mustakil';
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
      listingText = 'Satilik';
    } else if (listing == 'rent') {
      listingText = 'Kiralik';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(typeText, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
        if (listingText.isNotEmpty)
          Text(listingText, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ],
    );
  }

  Future<void> _updatePropertyStatus(String propertyId, String newStatus) async {
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
          content: Text(newStatus == 'active' ? 'Ilan onaylandi' : 'Ilan reddedildi'),
          backgroundColor: newStatus == 'active' ? AppColors.success : AppColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _toggleFeatured(String propertyId, bool currentlyFeatured) async {
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
          content: Text(!currentlyFeatured ? 'Ilan one cikarildi' : 'One cikarma kaldirildi'),
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
