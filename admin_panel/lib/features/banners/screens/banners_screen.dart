import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';

// ─── Providers ───────────────────────────────────────────────────────────────

final bannersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase
      .from('banners')
      .select()
      .order('sort_order', ascending: true);
  return List<Map<String, dynamic>>.from(response);
});

final pendingBannersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final response = await supabase
      .from('banners')
      .select('*, merchants(business_name), banner_packages(name, duration_days, price)')
      .eq('status', 'pending_approval')
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(response);
});

// ─── Screen ─────────────────────────────────────────────────────────────────

class BannersScreen extends ConsumerStatefulWidget {
  const BannersScreen({super.key});

  @override
  ConsumerState<BannersScreen> createState() => _BannersScreenState();
}

class _BannersScreenState extends ConsumerState<BannersScreen>
    with SingleTickerProviderStateMixin {
  String _selectedCategory = 'all';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  final List<Map<String, String>> _categories = [
    {'value': 'all', 'label': 'Tümü'},
    {'value': 'home', 'label': 'Ana Sayfa'},
    {'value': 'rental', 'label': 'Araç Kiralama'},
    {'value': 'food', 'label': 'Yemek'},
    {'value': 'market', 'label': 'Market'},
    {'value': 'store', 'label': 'Mağaza'},
    {'value': 'jobs', 'label': 'İş İlanları'},
    {'value': 'emlak', 'label': 'Emlak'},
    {'value': 'car_sales', 'label': 'Araç Satış'},
  ];

  // ── Build ──────────────────────────────────────────────────────────────────

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
                      'Uygulama bannerlarını yönetin – Reklam alanları',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                if (_tabController.index == 0)
                  ElevatedButton.icon(
                    onPressed: () => _showBannerDialog(
                      defaultCategory:
                          _selectedCategory == 'all' ? 'home' : _selectedCategory,
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Banner Ekle'),
                  ),
              ],
            ),
          ),

          // Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: [
                const Tab(text: 'Aktif Bannerlar'),
                Tab(
                  child: Row(
                    children: [
                      const Text('Onay Bekleyenler'),
                      const SizedBox(width: 6),
                      Consumer(builder: (context, ref, _) {
                        final pending = ref.watch(pendingBannersProvider);
                        final count = pending.valueOrNull?.length ?? 0;
                        if (count == 0) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('$count',
                              style: const TextStyle(color: Colors.white, fontSize: 11)),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Category filter chips (only for tab 0)
          if (_tabController.index == 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Wrap(
                spacing: 8,
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat['value'];
                  return FilterChip(
                    selected: isSelected,
                    label: Text(cat['label']!),
                    onSelected: (_) =>
                        setState(() => _selectedCategory = cat['value']!),
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primary,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 0: Aktif Bannerlar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: bannersAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(child: Text('Hata: $err')),
                    data: (banners) {
                      final filtered = _selectedCategory == 'all'
                          ? banners
                          : banners.where((b) => b['category'] == _selectedCategory).toList();
                      if (filtered.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.image, size: 64, color: AppColors.textMuted),
                              const SizedBox(height: 16),
                              Text(
                                _selectedCategory == 'all' ? 'Henüz banner eklenmemiş' : 'Bu kategoride banner yok',
                                style: const TextStyle(color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        );
                      }
                      return GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 2,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) => _buildBannerCard(filtered[index]),
                      );
                    },
                  ),
                ),

                // Tab 1: Onay Bekleyenler
                _PendingBannersTab(
                  onAction: () {
                    ref.invalidate(pendingBannersProvider);
                    ref.invalidate(bannersProvider);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Banner card ────────────────────────────────────────────────────────────

  Widget _buildBannerCard(Map<String, dynamic> banner) {
    final title = banner['title'] as String? ?? 'Banner';
    final description = banner['description'] as String? ?? '';
    final isActive = banner['is_active'] as bool? ?? false;
    final imageUrl = banner['image_url'] as String?;
    final bannerId = banner['id'] as String?;
    final category = banner['category'] as String? ?? 'home';
    final dateStatus = _getDateStatus(banner);
    final dateRange = _formatDateRange(banner);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background
          Positioned.fill(
            child: imageUrl != null
                ? Image.network(imageUrl, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _gradientPlaceholder())
                : _gradientPlaceholder(),
          ),

          // Dark gradient overlay (bottom)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.65),
                  ],
                ),
              ),
            ),
          ),

          // Bottom-left title
          Positioned(
            left: 12,
            bottom: 10,
            right: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (description.isNotEmpty)
                  Text(
                    description,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // Top-left badges
          Positioned(
            top: 8,
            left: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _badge(_getCategoryLabel(category),
                    _getCategoryColor(category)),
                const SizedBox(height: 4),
                _badge(
                  _getDateStatusLabel(dateStatus),
                  _getDateStatusColor(dateStatus),
                  icon: dateStatus == 'scheduled'
                      ? Icons.schedule
                      : dateStatus == 'expired'
                          ? Icons.timer_off
                          : Icons.check_circle,
                ),
                const SizedBox(height: 4),
                _badge(dateRange, Colors.black54,
                    icon: Icons.date_range),
              ],
            ),
          ),

          // Top-right controls
          Positioned(
            top: 6,
            right: 6,
            child: Row(
              children: [
                // Active/inactive label
                _badge(
                  isActive ? 'Aktif' : 'Pasif',
                  isActive ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: 4),
                // Toggle active
                _iconBtn(
                  isActive ? Icons.toggle_on : Icons.toggle_off,
                  isActive ? AppColors.success : AppColors.textMuted,
                  tooltip: isActive ? 'Pasife Al' : 'Aktife Al',
                  onTap: bannerId != null
                      ? () => _toggleActive(bannerId, isActive)
                      : null,
                ),
                // Edit
                _iconBtn(
                  Icons.edit,
                  Colors.white,
                  tooltip: 'Düzenle',
                  onTap: () => _showBannerDialog(existingBanner: banner),
                ),
                // Delete
                _iconBtn(
                  Icons.delete,
                  Colors.white,
                  tooltip: 'Sil',
                  onTap: bannerId != null
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

  Widget _gradientPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.3),
            AppColors.primaryDark.withValues(alpha: 0.5),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 9, color: Colors.white),
            const SizedBox(width: 3),
          ],
          Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color,
      {required VoidCallback? onTap, String? tooltip}) {
    final btn = InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip, child: btn);
    }
    return btn;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _getCategoryLabel(String? cat) {
    const map = {
      'home': 'Ana Sayfa',
      'rental': 'Araç Kiralama',
      'food': 'Yemek',
      'market': 'Market',
      'store': 'Mağaza',
      'jobs': 'İş İlanları',
      'emlak': 'Emlak',
      'car_sales': 'Araç Satış',
    };
    return map[cat] ?? 'Ana Sayfa';
  }

  Color _getCategoryColor(String? cat) {
    const map = {
      'rental': Colors.purple,
      'food': Colors.orange,
      'market': Colors.green,
      'store': Colors.teal,
      'jobs': Colors.indigo,
      'emlak': Colors.brown,
      'car_sales': Colors.red,
    };
    return map[cat] ?? AppColors.primary;
  }

  String _getDateStatus(Map<String, dynamic> banner) {
    final now = DateTime.now();
    final start = banner['start_date'] != null
        ? DateTime.tryParse(banner['start_date'])
        : null;
    final end = banner['end_date'] != null
        ? DateTime.tryParse(banner['end_date'])
        : null;
    if (start != null && now.isBefore(start)) return 'scheduled';
    if (end != null && now.isAfter(end)) return 'expired';
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
    final fmt = DateFormat('dd/MM/yy');
    final start = banner['start_date'] != null
        ? DateTime.tryParse(banner['start_date'])
        : null;
    final end = banner['end_date'] != null
        ? DateTime.tryParse(banner['end_date'])
        : null;
    if (start == null && end == null) return 'Süresiz';
    if (end == null) return '${fmt.format(start!)} – Süresiz';
    if (start == null) return '– ${fmt.format(end)}';
    return '${fmt.format(start)} – ${fmt.format(end)}';
  }

  // ── CRUD operations ────────────────────────────────────────────────────────

  Future<void> _toggleActive(String id, bool currentValue) async {
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase
          .from('banners')
          .update({'is_active': !currentValue})
          .eq('id', id);
      ref.invalidate(bannersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                currentValue ? 'Banner pasife alındı' : 'Banner aktife alındı'),
            backgroundColor:
                currentValue ? AppColors.warning : AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deleteBanner(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Banner Sil'),
        content: const Text(
            "Bu banner'ı silmek istediğinizden emin misiniz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.from('banners').delete().eq('id', id);
      ref.invalidate(bannersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Banner silindi'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ── Dialog: Create / Edit ──────────────────────────────────────────────────

  void _showBannerDialog({
    Map<String, dynamic>? existingBanner,
    String? defaultCategory,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _BannerFormDialog(
        existingBanner: existingBanner,
        defaultCategory: defaultCategory ?? 'home',
        onSaved: () => ref.invalidate(bannersProvider),
      ),
    );
  }
}

// ─── Banner Form Dialog ──────────────────────────────────────────────────────

class _BannerFormDialog extends ConsumerStatefulWidget {
  const _BannerFormDialog({
    this.existingBanner,
    required this.defaultCategory,
    required this.onSaved,
  });

  final Map<String, dynamic>? existingBanner;
  final String defaultCategory;
  final VoidCallback onSaved;

  @override
  ConsumerState<_BannerFormDialog> createState() => _BannerFormDialogState();
}

class _BannerFormDialogState extends ConsumerState<_BannerFormDialog> {
  // Controllers
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _linkUrlCtrl;
  late final TextEditingController _sortOrderCtrl;
  final TextEditingController _searchCtrl = TextEditingController();

  // State
  late String _category;
  late bool _isActive;
  late DateTime _startDate;
  DateTime? _endDate;
  String? _linkType;
  String? _linkId;
  String? _linkName;
  Uint8List? _imageBytes;
  String? _imageName;
  String? _existingImageUrl;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.existingBanner;
    _titleCtrl = TextEditingController(text: b?['title'] ?? '');
    _descCtrl = TextEditingController(text: b?['description'] ?? '');
    _linkUrlCtrl = TextEditingController(text: b?['link_url'] ?? '');
    _sortOrderCtrl =
        TextEditingController(text: (b?['sort_order'] ?? '').toString());
    _category = b?['category'] ?? widget.defaultCategory;
    _isActive = b?['is_active'] ?? true;
    _existingImageUrl = b?['image_url'];
    _linkType = b?['link_type'];
    _linkId = b?['link_id'];
    _startDate = b?['start_date'] != null
        ? DateTime.tryParse(b!['start_date']) ?? DateTime.now()
        : DateTime.now();
    _endDate = b?['end_date'] != null
        ? DateTime.tryParse(b!['end_date'])
        : DateTime.now().add(const Duration(days: 30));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _linkUrlCtrl.dispose();
    _sortOrderCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingBanner != null;

    return AlertDialog(
      title: Text(isEditing ? 'Banner Düzenle' : 'Yeni Banner Ekle'),
      content: SizedBox(
        width: 520,
        height: 580,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Image picker ──
              _buildImagePicker(),
              const SizedBox(height: 16),

              // ── Category dropdown ──
              _sectionLabel('Kategori'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                items: const [
                  DropdownMenuItem(value: 'home', child: Text('Ana Sayfa')),
                  DropdownMenuItem(
                      value: 'rental', child: Text('Araç Kiralama')),
                  DropdownMenuItem(value: 'food', child: Text('Yemek')),
                  DropdownMenuItem(value: 'market', child: Text('Market')),
                  DropdownMenuItem(value: 'store', child: Text('Mağaza')),
                  DropdownMenuItem(
                      value: 'jobs', child: Text('İş İlanları')),
                  DropdownMenuItem(value: 'emlak', child: Text('Emlak')),
                  DropdownMenuItem(
                      value: 'car_sales', child: Text('Araç Satış')),
                ],
                onChanged: _isSaving
                    ? null
                    : (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 16),

              // ── Title ──
              TextField(
                controller: _titleCtrl,
                enabled: !_isSaving,
                decoration: const InputDecoration(
                  labelText: 'Banner Başlığı *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // ── Description ──
              TextField(
                controller: _descCtrl,
                enabled: !_isSaving,
                decoration: const InputDecoration(
                  labelText: 'Açıklama (alt başlık)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // ── Link type ──
              _sectionLabel('Tıklandığında Yönlendirme'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String?>(
                initialValue: _linkType,
                decoration: const InputDecoration(
                  labelText: 'Link Türü',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                      value: null, child: Text('Yok (Tıklanamaz)')),
                  DropdownMenuItem(
                      value: 'external', child: Text('Harici URL')),
                  DropdownMenuItem(
                      value: 'screen', child: Text('Uygulama Sayfası')),
                  DropdownMenuItem(
                      value: 'restaurant', child: Text('Restoran')),
                  DropdownMenuItem(
                      value: 'store', child: Text('Mağaza')),
                  DropdownMenuItem(
                      value: 'product', child: Text('Ürün')),
                  DropdownMenuItem(
                      value: 'rental_car', child: Text('Kiralık Araç')),
                  DropdownMenuItem(
                      value: 'car_listing', child: Text('Satılık Araç')),
                  DropdownMenuItem(
                      value: 'job_listing', child: Text('İş İlanı')),
                  DropdownMenuItem(
                      value: 'promotion', child: Text('Promosyon')),
                ],
                onChanged: _isSaving
                    ? null
                    : (v) => setState(() {
                          _linkType = v;
                          _linkId = null;
                          _linkName = null;
                          _searchResults = [];
                          _searchCtrl.clear();
                        }),
              ),
              const SizedBox(height: 12),

              // ── Link sub-fields ──
              if (_linkType == 'external') ...[
                TextField(
                  controller: _linkUrlCtrl,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(
                    labelText: 'Harici URL',
                    hintText: 'https://example.com',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
              ] else if (_linkType == 'screen') ...[
                DropdownButtonFormField<String>(
                  initialValue: _linkId,
                  decoration: const InputDecoration(
                    labelText: 'Uygulama Sayfası',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_android),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'home', child: Text('Ana Sayfa')),
                    DropdownMenuItem(value: 'food', child: Text('Yemek Siparişi')),
                    DropdownMenuItem(value: 'store', child: Text('Market / Mağaza')),
                    DropdownMenuItem(value: 'taxi', child: Text('Taksi')),
                    DropdownMenuItem(value: 'rental', child: Text('Araç Kiralama')),
                    DropdownMenuItem(value: 'car_sales', child: Text('Araç Satış')),
                    DropdownMenuItem(value: 'emlak', child: Text('Emlak')),
                    DropdownMenuItem(value: 'jobs', child: Text('İş İlanları')),
                    DropdownMenuItem(value: 'profile', child: Text('Profil')),
                  ],
                  onChanged: _isSaving
                      ? null
                      : (v) => setState(() {
                            _linkId = v;
                            _linkName = v;
                          }),
                ),
              ] else if (_linkType != null) ...[
                // Search field for entity lookup
                TextField(
                  controller: _searchCtrl,
                  enabled: !_isSaving,
                  decoration: InputDecoration(
                    labelText: 'Ara...',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  onChanged: (q) async {
                    if (q.length < 2) {
                      setState(() => _searchResults = []);
                      return;
                    }
                    setState(() => _isSearching = true);
                    final results = await _searchEntities(_linkType!, q);
                    if (mounted) {
                      setState(() {
                        _searchResults = results;
                        _isSearching = false;
                      });
                    }
                  },
                ),
                if (_linkId != null && _linkName != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.success),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: AppColors.success, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_linkName!,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => setState(() {
                            _linkId = null;
                            _linkName = null;
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_searchResults.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 160),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.surfaceLight),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final item = _searchResults[i];
                        return ListTile(
                          dense: true,
                          title: Text(item['name'] ?? '',
                              style: const TextStyle(fontSize: 13)),
                          subtitle: item['subtitle'] != null
                              ? Text(item['subtitle'],
                                  style: const TextStyle(fontSize: 11))
                              : null,
                          onTap: () => setState(() {
                            _linkId = item['id'];
                            _linkName = item['name'];
                            _searchResults = [];
                            _searchCtrl.clear();
                          }),
                        );
                      },
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 16),

              // ── Date range ──
              _sectionLabel('Yayın Tarihi'),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: _datePicker(
                    label: 'Başlangıç',
                    date: _startDate,
                    onPicked: (d) => setState(() => _startDate = d),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _datePicker(
                    label: 'Bitiş (boş = süresiz)',
                    date: _endDate,
                    nullable: true,
                    onPicked: (d) => setState(() => _endDate = d),
                    onCleared: () => setState(() => _endDate = null),
                  )),
                ],
              ),
              const SizedBox(height: 16),

              // ── Sort order + active toggle ──
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _sortOrderCtrl,
                      enabled: !_isSaving,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Görüntüleme Sırası',
                        hintText: '1, 2, 3...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.sort),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Column(
                    children: [
                      const Text('Aktif',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary)),
                      Switch(
                        value: _isActive,
                        onChanged: _isSaving
                            ? null
                            : (v) => setState(() => _isActive = v),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Kaydet'),
        ),
      ],
    );
  }

  // ── Subwidgets ─────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary));
  }

  Widget _buildImagePicker() {
    return InkWell(
      onTap: _isSaving ? null : _pickImage,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceLight),
          image: _imageBytes != null
              ? DecorationImage(
                  image: MemoryImage(_imageBytes!), fit: BoxFit.cover)
              : _existingImageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(_existingImageUrl!),
                      fit: BoxFit.cover)
                  : null,
        ),
        child: (_imageBytes == null && _existingImageUrl == null)
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_upload,
                        size: 40, color: AppColors.textSecondary),
                    SizedBox(height: 6),
                    Text('Resim yüklemek için tıklayın',
                        style:
                            TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              )
            : Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4)),
                    child: const Icon(Icons.edit,
                        size: 14, color: Colors.white),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _datePicker({
    required String label,
    required DateTime? date,
    bool nullable = false,
    required void Function(DateTime) onPicked,
    VoidCallback? onCleared,
  }) {
    return InkWell(
      onTap: _isSaving
          ? null
          : () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) onPicked(picked);
            },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: nullable && date != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: onCleared,
                  tooltip: 'Süresiz yap',
                )
              : const Icon(Icons.calendar_today, size: 16),
        ),
        child: Text(
          date != null
              ? DateFormat('dd/MM/yyyy').format(date)
              : 'Süresiz',
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  // ── Image pick ─────────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _imageBytes = result.files.first.bytes;
        _imageName = result.files.first.name;
      });
    }
  }

  // ── Entity search ──────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _searchEntities(
      String type, String query) async {
    final supabase = ref.read(supabaseProvider);
    try {
      switch (type) {
        case 'restaurant':
          final res = await supabase
              .from('merchants')
              .select('id, business_name')
              .eq('type', 'restaurant')
              .ilike('business_name', '%$query%')
              .limit(10);
          return (res as List)
              .map((e) => {'id': e['id'], 'name': e['business_name']})
              .toList();

        case 'store':
          final res = await supabase
              .from('merchants')
              .select('id, business_name')
              .eq('type', 'store')
              .ilike('business_name', '%$query%')
              .limit(10);
          return (res as List)
              .map((e) => {'id': e['id'], 'name': e['business_name']})
              .toList();

        case 'product':
          final res = await supabase
              .from('products')
              .select('id, name, price')
              .ilike('name', '%$query%')
              .limit(10);
          return (res as List)
              .map((e) => {
                    'id': e['id'],
                    'name': e['name'],
                    'subtitle': '${e['price']} ₺',
                  })
              .toList();

        case 'rental_car':
          final res = await supabase
              .from('rental_cars')
              .select('id, brand, model, year')
              .or('brand.ilike.%$query%,model.ilike.%$query%')
              .limit(10);
          return (res as List)
              .map((e) => {
                    'id': e['id'],
                    'name': '${e['brand']} ${e['model']} (${e['year']})',
                  })
              .toList();

        case 'car_listing':
          final res = await supabase
              .from('car_listings')
              .select('id, title, price')
              .ilike('title', '%$query%')
              .limit(10);
          return (res as List)
              .map((e) => {
                    'id': e['id'],
                    'name': e['title'],
                    'subtitle': '${e['price']} ₺',
                  })
              .toList();

        case 'job_listing':
          final res = await supabase
              .from('job_listings')
              .select('id, title, city')
              .ilike('title', '%$query%')
              .limit(10);
          return (res as List)
              .map((e) => {
                    'id': e['id'],
                    'name': e['title'],
                    'subtitle': e['city'] ?? '',
                  })
              .toList();

        case 'promotion':
          final res = await supabase
              .from('promotions')
              .select('id, name, code')
              .or('name.ilike.%$query%,code.ilike.%$query%')
              .limit(10);
          return (res as List)
              .map((e) => {
                    'id': e['id'],
                    'name': '${e['name']} (${e['code']})',
                  })
              .toList();

        default:
          return [];
      }
    } catch (e) {
      debugPrint('Search error: $e');
      return [];
    }
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Banner başlığı zorunludur'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final supabase = ref.read(supabaseProvider);

      // Upload image if a new one was picked
      String? imageUrl = _existingImageUrl;
      if (_imageBytes != null && _imageName != null) {
        final sanitized =
            _imageName!.replaceAll(RegExp(r'[^\w\.]'), '_').toLowerCase();
        final path =
            'banners/${DateTime.now().millisecondsSinceEpoch}_$sanitized';
        await supabase.storage.from('images').uploadBinary(path, _imageBytes!);
        imageUrl = supabase.storage.from('images').getPublicUrl(path);
      }

      // Sort order
      int? sortOrder = int.tryParse(_sortOrderCtrl.text.trim());

      final data = <String, dynamic>{
        'title': title,
        'description':
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'link_url': _linkType == 'external' ? _linkUrlCtrl.text.trim() : null,
        'link_type': _linkType,
        'link_id': _linkId,
        'image_url': imageUrl,
        'category': _category,
        'is_active': _isActive,
        'start_date': _startDate.toUtc().toIso8601String(),
        'end_date': _endDate?.toUtc().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (widget.existingBanner != null) {
        // UPDATE
        if (sortOrder != null) data['sort_order'] = sortOrder;
        await supabase
            .from('banners')
            .update(data)
            .eq('id', widget.existingBanner!['id']);
      } else {
        // INSERT – auto sort_order if not specified
        if (sortOrder != null) {
          data['sort_order'] = sortOrder;
        } else {
          final maxRes = await supabase
              .from('banners')
              .select('sort_order')
              .order('sort_order', ascending: false)
              .limit(1);
          data['sort_order'] =
              maxRes.isNotEmpty ? (maxRes[0]['sort_order'] ?? 0) + 1 : 1;
        }
        data['created_at'] = DateTime.now().toIso8601String();
        await supabase.from('banners').insert(data);
      }

      widget.onSaved();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingBanner != null
                ? 'Banner güncellendi'
                : 'Banner eklendi'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

// ─── Pending Banners Tab ──────────────────────────────────────────────────────

class _PendingBannersTab extends ConsumerWidget {
  final VoidCallback onAction;
  const _PendingBannersTab({required this.onAction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingBannersProvider);
    final currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 0);

    return pendingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e', style: const TextStyle(color: AppColors.error))),
      data: (banners) {
        if (banners.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: AppColors.success),
                SizedBox(height: 16),
                Text('Onay bekleyen banner yok', style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: banners.length,
          separatorBuilder: (context, i) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _PendingBannerCard(
            banner: banners[i],
            currencyFormat: currencyFormat,
            onAction: onAction,
          ),
        );
      },
    );
  }
}

class _PendingBannerCard extends StatefulWidget {
  final Map<String, dynamic> banner;
  final NumberFormat currencyFormat;
  final VoidCallback onAction;

  const _PendingBannerCard({
    required this.banner,
    required this.currencyFormat,
    required this.onAction,
  });

  @override
  State<_PendingBannerCard> createState() => _PendingBannerCardState();
}

class _PendingBannerCardState extends State<_PendingBannerCard> {
  bool _loading = false;

  // Storage'dan görsel sil (hata olsa da sessizce geç)
  Future<void> _deleteStorageImage(String? imageUrl) async {
    if (imageUrl == null) return;
    try {
      final path = imageUrl.split('merchant-assets/').last;
      await SupabaseService.client.storage.from('merchant-assets').remove([path]);
    } catch (_) {}
  }

  // Merchant'a bildirim gönder (best-effort — hata olursa ana işlemi etkilemez)
  Future<void> _notifyMerchant({
    required String merchantId,
    required String title,
    required String body,
  }) async {
    try {
      await SupabaseService.client.from('notifications').insert({
        'user_id': merchantId,
        'title': title,
        'body': body,
        'type': 'info',
        'data': {'target_type': 'specific_user'},
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
      await SupabaseService.client.functions.invoke('send-push-notification', body: {
        'title': title,
        'body': body,
        'target_type': 'specific_user',
        'target_id': merchantId,
        'notification_type': 'info',
      });
    } catch (_) {}
  }

  Future<void> _approve() async {
    setState(() => _loading = true);
    try {
      final supabase = SupabaseService.client;
      final pkg = widget.banner['banner_packages'] as Map<String, dynamic>?;
      final days = pkg?['duration_days'] as int? ?? 30;
      await supabase.from('banners').update({
        'status': 'active',
        'is_active': true,
        'approved_at': DateTime.now().toIso8601String(),
        'starts_at': DateTime.now().toIso8601String(),
        'ends_at': DateTime.now().add(Duration(days: days)).toIso8601String(),
      }).eq('id', widget.banner['id']);

      // Merchant'a onay bildirimi
      final merchantId = widget.banner['merchant_id'] as String?;
      if (merchantId != null) {
        final bannerTitle = widget.banner['title'] as String? ?? 'Bannerınız';
        _notifyMerchant(
          merchantId: merchantId,
          title: 'Banner Onaylandı!',
          body: '"$bannerTitle" yayına alındı ve $days gün boyunca görünecek.',
        );
      }

      widget.onAction();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Banner onaylandı ve yayına alındı'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reject() async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Banner Reddet', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Red nedeni',
            border: OutlineInputBorder(),
          ),
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reddet'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final reason = reasonCtrl.text.trim();
    setState(() => _loading = true);
    try {
      await SupabaseService.client.from('banners').update({
        'status': 'rejected',
        'is_active': false,
        'rejection_reason': reason,
      }).eq('id', widget.banner['id']);

      // Storage'dan görseli sil
      await _deleteStorageImage(widget.banner['image_url'] as String?);

      // Merchant'a red bildirimi
      final merchantId = widget.banner['merchant_id'] as String?;
      if (merchantId != null) {
        final bannerTitle = widget.banner['title'] as String? ?? 'Bannerınız';
        _notifyMerchant(
          merchantId: merchantId,
          title: 'Banner Reddedildi',
          body: '"$bannerTitle" reddedildi.${reason.isNotEmpty ? " Neden: $reason" : ""}',
        );
      }

      widget.onAction();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Banner reddedildi'), backgroundColor: AppColors.warning),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final banner = widget.banner;
    final merchant = banner['merchants'] as Map<String, dynamic>?;
    final pkg = banner['banner_packages'] as Map<String, dynamic>?;
    final imageUrl = banner['image_url'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          // Görsel önizleme
          if (imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(imageUrl, width: 160, height: 90, fit: BoxFit.cover),
            )
          else
            Container(
              width: 160, height: 90,
              decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.image_not_supported, color: AppColors.textMuted),
            ),
          const SizedBox(width: 20),

          // Bilgiler
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(banner['title'] as String? ?? '-',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                if (merchant != null)
                  Text('İşletme: ${merchant['business_name']}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                if (pkg != null) ...[
                  const SizedBox(height: 2),
                  Text('Paket: ${pkg['name']} · ${pkg['duration_days']} gün · ${widget.currencyFormat.format((pkg['price'] as num).toDouble())}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
                if (banner['description'] != null && (banner['description'] as String).isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(banner['description'] as String,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Aksiyonlar
          if (_loading)
            const CircularProgressIndicator()
          else
            Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _approve,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Onayla'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _reject,
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Reddet'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
