import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';

// Banners Provider
final bannersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase
      .from('banners')
      .select()
      .order('sort_order', ascending: true);
  return List<Map<String, dynamic>>.from(response);
});

class BannersScreen extends ConsumerStatefulWidget {
  const BannersScreen({super.key});

  @override
  ConsumerState<BannersScreen> createState() => _BannersScreenState();
}

class _BannersScreenState extends ConsumerState<BannersScreen> {
  String _selectedCategory = 'all';

  final List<Map<String, String>> _categories = [
    {'value': 'all', 'label': 'Tümü', 'icon': 'apps'},
    {'value': 'home', 'label': 'Ana Sayfa', 'icon': 'home'},
    {'value': 'rental', 'label': 'Araç Kiralama', 'icon': 'car_rental'},
    {'value': 'food', 'label': 'Yemek', 'icon': 'restaurant'},
    {'value': 'store', 'label': 'Market', 'icon': 'store'},
    {'value': 'jobs', 'label': 'İş İlanları', 'icon': 'work'},
    {'value': 'emlak', 'label': 'Emlak', 'icon': 'home_work'},
    {'value': 'car_sales', 'label': 'Araç Satış', 'icon': 'directions_car'},
  ];

  @override
  Widget build(BuildContext context) {
    final bannersAsync = ref.watch(bannersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Banner Yönetimi',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Uygulama bannerlarını yönetin - Reklam alanları',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showBannerDialog(
                    defaultCategory: _selectedCategory == 'all' ? 'home' : _selectedCategory,
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Banner Ekle'),
                ),
              ],
            ),
          ),

          // Category Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Wrap(
              spacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat['value'];
                return FilterChip(
                  selected: isSelected,
                  label: Text(cat['label']!),
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = cat['value']!;
                    });
                  },
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  checkmarkColor: AppColors.primary,
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: bannersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Hata: $err')),
                data: (banners) {
                  // Kategoriye göre filtrele
                  final filteredBanners = _selectedCategory == 'all'
                      ? banners
                      : banners.where((b) => b['category'] == _selectedCategory).toList();

                  if (filteredBanners.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.image, size: 64, color: AppColors.textMuted),
                          const SizedBox(height: 16),
                          Text(
                            _selectedCategory == 'all'
                                ? 'Henüz banner eklenmemiş'
                                : 'Bu kategoride banner yok',
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    );
                  }
                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 2,
                    ),
                    itemCount: filteredBanners.length,
                    itemBuilder: (context, index) {
                      final banner = filteredBanners[index];
                      return _buildBannerCard(banner, index);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCategoryLabel(String? category) {
    switch (category) {
      case 'rental':
        return 'Araç Kiralama';
      case 'food':
        return 'Yemek';
      case 'store':
        return 'Market';
      case 'jobs':
        return 'İş İlanları';
      case 'emlak':
        return 'Emlak';
      case 'car_sales':
        return 'Araç Satış';
      case 'home':
      default:
        return 'Ana Sayfa';
    }
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'rental':
        return Colors.purple;
      case 'food':
        return Colors.orange;
      case 'store':
        return Colors.teal;
      case 'jobs':
        return Colors.indigo;
      case 'emlak':
        return Colors.brown;
      case 'car_sales':
        return Colors.red;
      case 'home':
      default:
        return AppColors.primary;
    }
  }

  /// Banner'ın tarih durumunu kontrol eder
  /// Returns: 'scheduled' (henüz başlamadı), 'active' (aktif), 'expired' (süresi doldu)
  String _getDateStatus(Map<String, dynamic> banner) {
    final now = DateTime.now();
    final startDate = banner['start_date'] != null
        ? DateTime.parse(banner['start_date'])
        : null;
    final endDate = banner['end_date'] != null
        ? DateTime.parse(banner['end_date'])
        : null;

    if (startDate != null && now.isBefore(startDate)) {
      return 'scheduled';
    }
    if (endDate != null && now.isAfter(endDate)) {
      return 'expired';
    }
    return 'active';
  }

  String _getDateStatusLabel(String status) {
    switch (status) {
      case 'scheduled':
        return 'Planlandı';
      case 'expired':
        return 'Süresi Doldu';
      default:
        return 'Yayında';
    }
  }

  Color _getDateStatusColor(String status) {
    switch (status) {
      case 'scheduled':
        return Colors.blue;
      case 'expired':
        return Colors.grey;
      default:
        return AppColors.success;
    }
  }

  String _formatDateRange(Map<String, dynamic> banner) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final startDate = banner['start_date'] != null
        ? DateTime.parse(banner['start_date'])
        : null;
    final endDate = banner['end_date'] != null
        ? DateTime.parse(banner['end_date'])
        : null;

    if (startDate == null && endDate == null) return 'Süresiz';
    if (endDate == null) return '${dateFormat.format(startDate!)} - Süresiz';
    if (startDate == null) return 'Başlangıç yok - ${dateFormat.format(endDate)}';
    return '${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}';
  }

  Widget _buildBannerCard(Map<String, dynamic> banner, int index) {
    final title = banner['title'] ?? 'Banner ${index + 1}';
    final description = banner['description'] ?? '';
    final isActive = banner['is_active'] ?? false;
    final imageUrl = banner['image_url'] as String?;
    final bannerId = banner['id'] as String?;
    final category = banner['category'] as String? ?? 'home';
    final dateStatus = _getDateStatus(banner);
    final dateRange = _formatDateRange(banner);
    return Card(
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: imageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(imageUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
              gradient: imageUrl == null
                  ? LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.3),
                        AppColors.primaryDark.withValues(alpha: 0.5),
                      ],
                    )
                  : null,
            ),
            child: imageUrl == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.image,
                          size: 48,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          description,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (description.isNotEmpty)
                              Text(
                                description,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          // Kategori etiketi - sol üst
          Positioned(
            top: 8,
            left: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(category),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _getCategoryLabel(category),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 4),
                // Tarih durumu etiketi
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getDateStatusColor(dateStatus),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        dateStatus == 'scheduled'
                            ? Icons.schedule
                            : dateStatus == 'expired'
                                ? Icons.timer_off
                                : Icons.check_circle,
                        size: 10,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getDateStatusLabel(dateStatus),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // Tarih aralığı
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.date_range, size: 10, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        dateRange,
                        style: const TextStyle(color: Colors.white, fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.success : AppColors.error,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isActive ? 'Aktif' : 'Pasif',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                  onPressed: () => _showBannerDialog(existingBanner: banner),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 16, color: Colors.white),
                  onPressed: bannerId != null
                      ? () => _deleteBanner(bannerId)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getLinkTypeSearchLabel(String? linkType) {
    switch (linkType) {
      case 'restaurant':
        return 'Restoran Ara';
      case 'menu_item':
        return 'Yemek Ara';
      case 'store':
        return 'Mağaza Ara';
      case 'product':
        return 'Ürün Ara';
      default:
        return 'Ara';
    }
  }

  IconData _getLinkTypeIcon(String? linkType) {
    switch (linkType) {
      case 'restaurant':
        return Icons.restaurant;
      case 'menu_item':
        return Icons.fastfood;
      case 'store':
        return Icons.store;
      case 'product':
        return Icons.shopping_bag;
      default:
        return Icons.link;
    }
  }

  Future<List<Map<String, dynamic>>> _searchForLinkTarget(String linkType, String query) async {
    final supabase = ref.read(supabaseProvider);
    List<Map<String, dynamic>> results = [];

    try {
      switch (linkType) {
        case 'restaurant':
          final response = await supabase
              .from('merchants')
              .select('id, business_name, logo_url, category_tags')
              .eq('type', 'restaurant')
              .ilike('business_name', '%$query%')
              .limit(10);
          results = (response as List).map((item) => <String, dynamic>{
            'id': item['id'],
            'name': item['business_name'],
            'image_url': item['logo_url'],
            'subtitle': item['category_tags']?.toString() ?? 'Restoran',
          }).toList();
          break;

        case 'menu_item':
          final response = await supabase
              .from('menu_items')
              .select('id, name, image_url, price, merchants(business_name)')
              .ilike('name', '%$query%')
              .limit(10);
          results = (response as List).map((item) => <String, dynamic>{
            'id': item['id'],
            'name': item['name'],
            'image_url': item['image_url'],
            'subtitle': '${item['merchants']?['business_name'] ?? ''} - ${item['price']} TL',
          }).toList();
          break;

        case 'store':
          final response = await supabase
              .from('merchants')
              .select('id, business_name, logo_url')
              .eq('type', 'store')
              .ilike('business_name', '%$query%')
              .limit(10);
          results = (response as List).map((item) => <String, dynamic>{
            'id': item['id'],
            'name': item['business_name'],
            'image_url': item['logo_url'],
            'subtitle': 'Mağaza',
          }).toList();
          break;

        case 'product':
          final response = await supabase
              .from('products')
              .select('id, name, image_url, price, merchants(business_name)')
              .ilike('name', '%$query%')
              .limit(10);
          results = (response as List).map((item) => <String, dynamic>{
            'id': item['id'],
            'name': item['name'],
            'image_url': item['image_url'],
            'subtitle': '${item['merchants']?['business_name'] ?? ''} - ${item['price']} TL',
          }).toList();
          break;
      }
    } catch (e) {
      debugPrint('Search error: $e');
    }

    return results;
  }

  Future<void> _deleteBanner(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Banner Sil'),
        content: const Text('Bu banner\'i silmek istediginizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final supabase = ref.read(supabaseProvider);
      await supabase.from('banners').delete().eq('id', id);
      ref.invalidate(bannersProvider);
    }
  }

  void _showBannerDialog({Map<String, dynamic>? existingBanner, String? defaultCategory}) {
    final titleController = TextEditingController(
      text: existingBanner?['title'] ?? '',
    );
    final descriptionController = TextEditingController(
      text: existingBanner?['description'] ?? '',
    );
    final linkController = TextEditingController(
      text: existingBanner?['link_url'] ?? '',
    );
    String selectedCategory = existingBanner?['category'] ?? defaultCategory ?? 'home';
    Uint8List? selectedImageBytes;
    String? selectedImageName;
    String? existingImageUrl = existingBanner?['image_url'];
    bool isLoading = false;

    // Link türü ve hedef seçimi
    String? selectedLinkType = existingBanner?['link_type'];
    String? selectedLinkId = existingBanner?['link_id'];
    String? selectedLinkName; // Seçilen öğenin adı (görüntüleme için)
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;
    final searchController = TextEditingController();

    // Tarih alanları
    DateTime startDate = existingBanner?['start_date'] != null
        ? DateTime.parse(existingBanner!['start_date'])
        : DateTime.now();
    DateTime? endDate = existingBanner?['end_date'] != null
        ? DateTime.parse(existingBanner!['end_date'])
        : DateTime.now().add(const Duration(days: 30)); // Varsayılan 30 gün

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existingBanner != null ? 'Banner Duzenle' : 'Banner Ekle'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: isLoading
                      ? null
                      : () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.image,
                            allowMultiple: false,
                            withData: true,
                          );
                          if (result != null && result.files.isNotEmpty) {
                            setDialogState(() {
                              selectedImageBytes = result.files.first.bytes;
                              selectedImageName = result.files.first.name;
                            });
                          }
                        },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.surfaceLight,
                        style: BorderStyle.solid,
                      ),
                      image: selectedImageBytes != null
                          ? DecorationImage(
                              image: MemoryImage(selectedImageBytes!),
                              fit: BoxFit.cover,
                            )
                          : existingImageUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(existingImageUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                    ),
                    child: (selectedImageBytes == null && existingImageUrl == null)
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.cloud_upload,
                                  size: 48,
                                  color: AppColors.textSecondary,
                                ),
                                SizedBox(height: 8),
                                Text('Resim yuklemek icin tiklayin'),
                              ],
                            ),
                          )
                        : Stack(
                            children: [
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                // Kategori seçimi
                DropdownButton<String>(
                  value: selectedCategory,
                  isExpanded: true,
                  underline: Container(
                    height: 1,
                    color: Colors.grey[400],
                  ),
                  items: const [
                    DropdownMenuItem(value: 'home', child: Text('Ana Sayfa')),
                    DropdownMenuItem(value: 'rental', child: Text('Araç Kiralama')),
                    DropdownMenuItem(value: 'food', child: Text('Yemek')),
                    DropdownMenuItem(value: 'store', child: Text('Market')),
                    DropdownMenuItem(value: 'jobs', child: Text('İş İlanları')),
                    DropdownMenuItem(value: 'emlak', child: Text('Emlak')),
                    DropdownMenuItem(value: 'car_sales', child: Text('Araç Satış')),
                  ],
                  onChanged: isLoading
                      ? null
                      : (value) {
                          debugPrint('Category changed to: $value');
                          setDialogState(() {
                            selectedCategory = value ?? 'home';
                            debugPrint('selectedCategory updated to: $selectedCategory');
                          });
                        },
                ),
                const SizedBox(height: 8),
                Text('Kategori: $selectedCategory', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Banner Başlığı'),
                  enabled: !isLoading,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Açıklama (alt başlık)'),
                  enabled: !isLoading,
                ),
                const SizedBox(height: 16),
                // Link Türü Seçimi
                const Text('Tıklandığında Yönlendirme', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: selectedLinkType,
                  decoration: const InputDecoration(
                    labelText: 'Link Türü',
                    hintText: 'Seçiniz (opsiyonel)',
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Yok (Tıklanamaz)')),
                    DropdownMenuItem(value: 'restaurant', child: Text('Restoran')),
                    DropdownMenuItem(value: 'menu_item', child: Text('Yemek (Menü Ürünü)')),
                    DropdownMenuItem(value: 'store', child: Text('Mağaza')),
                    DropdownMenuItem(value: 'product', child: Text('Ürün')),
                    DropdownMenuItem(value: 'external', child: Text('Harici Link (URL)')),
                  ],
                  onChanged: isLoading
                      ? null
                      : (value) {
                          setDialogState(() {
                            selectedLinkType = value;
                            selectedLinkId = null;
                            selectedLinkName = null;
                            searchResults = [];
                            searchController.clear();
                          });
                        },
                ),
                const SizedBox(height: 12),

                // Link türüne göre arama veya URL girişi
                if (selectedLinkType == 'external') ...[
                  TextField(
                    controller: linkController,
                    decoration: const InputDecoration(
                      labelText: 'Harici URL',
                      hintText: 'https://example.com',
                      prefixIcon: Icon(Icons.link),
                    ),
                    enabled: !isLoading,
                  ),
                ] else if (selectedLinkType != null) ...[
                  // Arama alanı
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      labelText: _getLinkTypeSearchLabel(selectedLinkType),
                      hintText: 'Aramak için yazın...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: isSearching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                    ),
                    enabled: !isLoading,
                    onChanged: (value) async {
                      if (value.length < 2) {
                        setDialogState(() => searchResults = []);
                        return;
                      }
                      setDialogState(() => isSearching = true);
                      try {
                        final results = await _searchForLinkTarget(selectedLinkType!, value);
                        setDialogState(() {
                          searchResults = results;
                          isSearching = false;
                        });
                      } catch (e) {
                        setDialogState(() => isSearching = false);
                      }
                    },
                  ),
                  // Seçilen öğe gösterimi
                  if (selectedLinkId != null && selectedLinkName != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.success),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Seçilen:', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                Text(selectedLinkName!, style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              setDialogState(() {
                                selectedLinkId = null;
                                selectedLinkName = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Arama sonuçları
                  if (searchResults.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 150),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.surfaceLight),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          final item = searchResults[index];
                          return ListTile(
                            dense: true,
                            leading: item['image_url'] != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(
                                      item['image_url'],
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 40,
                                        height: 40,
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.image, size: 20),
                                      ),
                                    ),
                                  )
                                : Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Icon(_getLinkTypeIcon(selectedLinkType), size: 20),
                                  ),
                            title: Text(item['name'] ?? '', style: const TextStyle(fontSize: 14)),
                            subtitle: item['subtitle'] != null
                                ? Text(item['subtitle'], style: const TextStyle(fontSize: 12))
                                : null,
                            onTap: () {
                              setDialogState(() {
                                selectedLinkId = item['id'];
                                selectedLinkName = item['name'];
                                searchResults = [];
                                searchController.clear();
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                // Tarih aralığı
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: isLoading
                            ? null
                            : () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: startDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setDialogState(() => startDate = picked);
                                }
                              },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Başlangıç Tarihi',
                            suffixIcon: Icon(Icons.calendar_today, size: 18),
                          ),
                          child: Text(
                            DateFormat('dd/MM/yyyy').format(startDate),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: isLoading
                            ? null
                            : () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: endDate ?? DateTime.now().add(const Duration(days: 30)),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setDialogState(() => endDate = picked);
                                }
                              },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Bitiş Tarihi',
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (endDate != null)
                                  IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: isLoading
                                        ? null
                                        : () => setDialogState(() => endDate = null),
                                    tooltip: 'Süresiz yap',
                                  ),
                                const Icon(Icons.calendar_today, size: 18),
                              ],
                            ),
                          ),
                          child: Text(
                            endDate != null
                                ? DateFormat('dd/MM/yyyy').format(endDate!)
                                : 'Süresiz',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Not: Bitiş tarihi boş bırakılırsa banner süresiz olarak gösterilir.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Iptal'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Banner basligi zorunludur'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isLoading = true);

                      try {
                        final supabase = ref.read(supabaseProvider);
                        String? imageUrl = existingImageUrl;

                        // Upload image if selected
                        if (selectedImageBytes != null && selectedImageName != null) {
                          // Sanitize filename - remove special characters
                          final sanitizedName = selectedImageName!
                              .replaceAll(RegExp(r'[^\w\.]'), '_')
                              .toLowerCase();
                          final fileName =
                              'banners/${DateTime.now().millisecondsSinceEpoch}_$sanitizedName';
                          await supabase.storage
                              .from('images')
                              .uploadBinary(fileName, selectedImageBytes!);
                          imageUrl = supabase.storage
                              .from('images')
                              .getPublicUrl(fileName);
                        }

                        // Debug: kategori değerini kontrol et
                        debugPrint('Saving banner with category: $selectedCategory');

                        final bannerData = {
                          'title': title,
                          'description': descriptionController.text.trim().isEmpty
                              ? null
                              : descriptionController.text.trim(),
                          'link_url': selectedLinkType == 'external' && linkController.text.trim().isNotEmpty
                              ? linkController.text.trim()
                              : null,
                          'link_type': selectedLinkType,
                          'link_id': selectedLinkId,
                          'image_url': imageUrl,
                          'category': selectedCategory,
                          'is_active': true,
                          'start_date': startDate.toUtc().toIso8601String(),
                          'end_date': endDate?.toUtc().toIso8601String(),
                          'updated_at': DateTime.now().toIso8601String(),
                        };

                        debugPrint('Banner data: $bannerData');

                        if (existingBanner != null) {
                          // Update existing banner
                          await supabase
                              .from('banners')
                              .update(bannerData)
                              .eq('id', existingBanner['id']);
                        } else {
                          // Insert new banner
                          final maxOrderResult = await supabase
                              .from('banners')
                              .select('sort_order')
                              .order('sort_order', ascending: false)
                              .limit(1);
                          final maxOrder = maxOrderResult.isNotEmpty
                              ? (maxOrderResult[0]['sort_order'] ?? 0) + 1
                              : 1;

                          bannerData['sort_order'] = maxOrder;
                          bannerData['created_at'] = DateTime.now().toIso8601String();
                          await supabase.from('banners').insert(bannerData);
                        }

                        ref.invalidate(bannersProvider);
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(existingBanner != null
                                  ? 'Banner guncellendi'
                                  : 'Banner eklendi'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isLoading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Hata: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}
