import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/emlak/emlak_models.dart';
import '../../services/emlak/property_service.dart';
import '../../core/providers/emlak_provider.dart';

class PropertySearchScreen extends ConsumerStatefulWidget {
  const PropertySearchScreen({super.key});

  @override
  ConsumerState<PropertySearchScreen> createState() => _PropertySearchScreenState();
}

class _PropertySearchScreenState extends ConsumerState<PropertySearchScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  List<Property> _searchResults = [];
  List<String> _recentSearches = [];

  bool _isSearching = false;
  PropertyFilter _filter = const PropertyFilter();
  SortOption _sortOption = SortOption.newest;

  Timer? _debounce;

  static const _recentSearchesKey = 'emlak_recent_searches';
  static const _maxRecentSearches = 10;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _focusNode.requestFocus();
    _animationController.forward();
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _animationController.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final searches = prefs.getStringList(_recentSearchesKey) ?? [];
    if (mounted) {
      setState(() => _recentSearches = searches);
    }
  }

  Future<void> _saveRecentSearch(String query) async {
    if (query.trim().isEmpty) return;
    final trimmed = query.trim();

    // Zaten varsa önce kaldır (en üste eklemek için)
    _recentSearches.remove(trimmed);
    _recentSearches.insert(0, trimmed);

    // Maksimum sayıyı aşmasın
    if (_recentSearches.length > _maxRecentSearches) {
      _recentSearches = _recentSearches.sublist(0, _maxRecentSearches);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentSearchesKey, _recentSearches);
  }

  Future<void> _clearRecentSearches() async {
    setState(() => _recentSearches = []);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
  }

  Future<void> _removeRecentSearch(String query) async {
    setState(() => _recentSearches.remove(query));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentSearchesKey, _recentSearches);
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    // Son aramalara kaydet
    _saveRecentSearch(query);

    try {
      final service = PropertyService();
      final results = await service.searchProperties(
        searchQuery: query,
        filter: _filter,
        sortOption: _sortOption,
      );

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  void _applyFilter(PropertyFilter filter) {
    setState(() => _filter = filter);
    if (_searchController.text.isNotEmpty) {
      _search(_searchController.text);
    }
  }

  void _applyQuickFilter(PropertyFilter filter) {
    setState(() {
      _filter = filter;
      _searchController.text = '';
    });
    // Hızlı filtre ile tüm ilanları ara (boş query yerine wildcard)
    _searchWithFilter(filter);
  }

  Future<void> _searchWithFilter(PropertyFilter filter) async {
    setState(() => _isSearching = true);
    try {
      final service = PropertyService();
      final results = await service.getProperties(
        filter: filter,
        sortOption: _sortOption,
        limit: 50,
      );

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  void _setSortOption(SortOption option) {
    setState(() => _sortOption = option);
    if (_searchController.text.isNotEmpty) {
      _search(_searchController.text);
    } else if (_searchResults.isNotEmpty) {
      _searchWithFilter(_filter);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: EmlakColors.background(isDark),
        body: SafeArea(
          child: Column(
            children: [
              // Search Header
              _buildSearchHeader(context, isDark),

              // Filter Chips
              _buildFilterChips(context, isDark),

              // Content
              Expanded(
                child: _searchController.text.isEmpty && _searchResults.isEmpty
                    ? _buildRecentSearches(isDark)
                    : _isSearching
                        ? _buildLoadingState()
                        : _searchResults.isEmpty
                            ? _buildEmptyState(isDark)
                            : _buildSearchResults(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchHeader(BuildContext context, bool isDark) {
    final activeFilterCount = _filter.activeCount;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Material(
            color: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                context.pop();
              },
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: isDark ? Colors.white : Colors.grey[800],
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Hero(
              tag: 'search_bar',
              child: Material(
                color: Colors.transparent,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _focusNode.hasFocus
                          ? EmlakColors.primary
                          : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
                      width: _focusNode.hasFocus ? 2 : 1,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    onChanged: _onSearchChanged,
                    onSubmitted: (query) {
                      if (query.isNotEmpty) _search(query);
                    },
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.grey[900],
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Konum, özellik veya ilan no ara...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.grey[500] : Colors.grey[400],
                        fontSize: 15,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: EmlakColors.primary,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                _searchController.clear();
                                setState(() {
                                  _searchResults = [];
                                  _isSearching = false;
                                });
                              },
                              icon: Icon(
                                Icons.close_rounded,
                                color: isDark ? Colors.grey[500] : Colors.grey[400],
                              ),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Stack(
            children: [
              Material(
                color: EmlakColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _showFilterSheet(context);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: EmlakColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      color: EmlakColors.primary,
                    ),
                  ),
                ),
              ),
              if (activeFilterCount > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: EmlakColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: EmlakColors.background(isDark), width: 2),
                    ),
                    child: Text(
                      '$activeFilterCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, bool isDark) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildFilterChip(
            label: 'Tümü',
            isSelected: _filter.listingType == null && _filter.type == null,
            onTap: () => _applyFilter(const PropertyFilter()),
            isDark: isDark,
          ),
          _buildFilterChip(
            label: 'Satılık',
            isSelected: _filter.listingType == ListingType.sale,
            onTap: () => _applyFilter(const PropertyFilter(listingType: ListingType.sale)),
            isDark: isDark,
            color: ListingType.sale.color,
          ),
          _buildFilterChip(
            label: 'Kiralık',
            isSelected: _filter.listingType == ListingType.rent,
            onTap: () => _applyFilter(const PropertyFilter(listingType: ListingType.rent)),
            isDark: isDark,
            color: ListingType.rent.color,
          ),
          const SizedBox(width: 8),
          Container(
            width: 1,
            height: 24,
            color: isDark ? Colors.grey[800] : Colors.grey[300],
          ),
          const SizedBox(width: 8),
          ...PropertyType.values.take(5).map((type) {
            return _buildFilterChip(
              label: type.label,
              isSelected: _filter.type == type,
              onTap: () => _applyFilter(PropertyFilter(type: type)),
              isDark: isDark,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    Color? color,
  }) {
    final activeColor = color ?? EmlakColors.primary;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: isSelected ? activeColor : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? activeColor
                    : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.grey[400] : Colors.grey[600]),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentSearches(bool isDark) {
    final citiesAsync = ref.watch(citiesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent Searches
          if (_recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Son Aramalar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.grey[900],
                  ),
                ),
                TextButton(
                  onPressed: _clearRecentSearches,
                  child: Text(
                    'Temizle',
                    style: TextStyle(
                      color: EmlakColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._recentSearches.map((search) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.history_rounded,
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                    size: 20,
                  ),
                ),
                title: Text(
                  search,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.grey[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _removeRecentSearch(search),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          color: isDark ? Colors.grey[600] : Colors.grey[400],
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.north_west_rounded,
                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                      size: 18,
                    ),
                  ],
                ),
                onTap: () {
                  _searchController.text = search;
                  _searchController.selection = TextSelection.fromPosition(
                    TextPosition(offset: search.length),
                  );
                  _search(search);
                },
              );
            }),
            const SizedBox(height: 32),
          ],

          // Popular Locations - DB'den
          Text(
            'Popüler Lokasyonlar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.grey[900],
            ),
          ),
          const SizedBox(height: 16),
          citiesAsync.when(
            loading: () => Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(5, (_) => Container(
                width: 100,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.grey[200],
                  borderRadius: BorderRadius.circular(25),
                ),
              )),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (cities) => Wrap(
              spacing: 10,
              runSpacing: 10,
              children: cities.map((location) {
                return Material(
                  color: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(25),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _searchController.text = location;
                      _searchController.selection = TextSelection.fromPosition(
                        TextPosition(offset: location.length),
                      );
                      _search(location);
                    },
                    borderRadius: BorderRadius.circular(25),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            color: EmlakColors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            location,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.grey[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 32),

          // Quick Filters
          Text(
            'Hızlı Filtreler',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.grey[900],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildQuickFilterCard(
                  icon: Icons.pool_rounded,
                  label: 'Havuzlu',
                  color: Colors.blue,
                  isDark: isDark,
                  onTap: () {
                    _applyQuickFilter(const PropertyFilter(
                      hasPrivatePool: true,
                    ));
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickFilterCard(
                  icon: Icons.beach_access_rounded,
                  label: 'Denize Sıfır',
                  color: Colors.cyan,
                  isDark: isDark,
                  onTap: () {
                    _applyQuickFilter(const PropertyFilter(
                      isSeafront: true,
                    ));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildQuickFilterCard(
                  icon: Icons.workspace_premium_rounded,
                  label: 'Premium',
                  color: Colors.amber,
                  isDark: isDark,
                  onTap: () {
                    // Premium ilanları göster
                    context.push('/emlak/featured');
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickFilterCard(
                  icon: Icons.smart_toy_rounded,
                  label: 'Akıllı Ev',
                  color: Colors.purple,
                  isDark: isDark,
                  onTap: () {
                    _searchController.text = 'Akıllı Ev';
                    _applyQuickFilter(const PropertyFilter(
                      keyword: 'akıllı ev',
                    ));
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilterCard({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: EmlakColors.primary,
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Aranıyor...',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: EmlakColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 50,
              color: EmlakColors.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Sonuç Bulunamadı',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.grey[900],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Farklı anahtar kelimeler deneyin',
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_searchResults.length} sonuç bulundu',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _showSortSheet(context);
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        Icons.sort_rounded,
                        size: 18,
                        color: EmlakColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _sortOption.label,
                        style: TextStyle(
                          color: EmlakColors.primary,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final property = _searchResults[index];
              return _buildSearchResultCard(property, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultCard(Property property, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            context.push('/emlak/property/${property.id}');
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: property.isPremium
                  ? Border.all(color: EmlakColors.accent, width: 2)
                  : null,
            ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image - full width, mobile style
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  child: property.images.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: property.images.first,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Container(
                            height: 180,
                            color: Colors.grey[200],
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          errorWidget: (_, _, _) => Container(
                            height: 180,
                            color: EmlakColors.primary.withValues(alpha: 0.2),
                            child: const Icon(Icons.image, color: Colors.white54, size: 40),
                          ),
                        )
                      : Container(
                          height: 180,
                          color: EmlakColors.primary.withValues(alpha: 0.2),
                          child: const Icon(Icons.home, color: Colors.white54, size: 40),
                        ),
                ),
                // Listing type badge
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: property.listingType.color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      property.listingType.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                // Premium/Featured badge
                if (property.isPremium || property.isFeatured)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: EmlakColors.accent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            property.isPremium ? Icons.workspace_premium_rounded : Icons.star_rounded,
                            color: Colors.white,
                            size: 13,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            property.isPremium ? 'Premium' : 'Öne Çıkan',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Favorite icon
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.favorite_border_rounded,
                      size: 18,
                      color: isDark ? Colors.grey[700] : Colors.grey[500],
                    ),
                  ),
                ),
              ],
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.grey[900],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          property.location.shortAddress,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[500] : Colors.grey[500],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildMiniFeature(Icons.bed_outlined, '${property.rooms}+1'),
                      const SizedBox(width: 10),
                      _buildMiniFeature(Icons.square_foot, '${property.squareMeters} m²'),
                      if (property.bathrooms > 0) ...[
                        const SizedBox(width: 10),
                        _buildMiniFeature(Icons.bathtub_outlined, '${property.bathrooms}'),
                      ],
                      const Spacer(),
                      Text(
                        property.formattedPrice,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: EmlakColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
      ),
    );
  }

  Widget _buildMiniFeature(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _FilterSheet(
        filter: _filter,
        onApply: (filter) {
          Navigator.pop(context);
          _applyFilter(filter);
          // Filtre uygulandıysa ve arama kutusu boşsa, filtreli arama yap
          if (_searchController.text.isEmpty && filter.activeCount > 0) {
            _searchWithFilter(filter);
          }
        },
      ),
    );
  }

  void _showSortSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Sıralama',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.grey[900],
                  ),
                ),
              ),
              ...SortOption.values.map((option) {
                final isSelected = _sortOption == option;
                return ListTile(
                  leading: Icon(
                    option.icon,
                    color: isSelected ? EmlakColors.primary : (isDark ? Colors.grey[500] : Colors.grey[600]),
                  ),
                  title: Text(
                    option.label,
                    style: TextStyle(
                      color: isSelected ? EmlakColors.primary : (isDark ? Colors.white : Colors.grey[800]),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: EmlakColors.primary)
                      : null,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context);
                    _setSortOption(option);
                  },
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final PropertyFilter filter;
  final Function(PropertyFilter) onApply;

  const _FilterSheet({
    required this.filter,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late PropertyFilter _filter;
  late RangeValues _priceRange;
  late RangeValues _sizeRange;
  Set<String> _selectedRooms = {};

  @override
  void initState() {
    super.initState();
    _filter = widget.filter;

    // Mevcut filtre değerlerinden başlat
    _priceRange = RangeValues(
      widget.filter.minPrice ?? 0,
      widget.filter.maxPrice ?? 50000000,
    );
    _sizeRange = RangeValues(
      (widget.filter.minSquareMeters ?? 0).toDouble(),
      (widget.filter.maxSquareMeters ?? 500).toDouble(),
    );
    _selectedRooms = widget.filter.roomTypes ?? {};
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filtreler',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.grey[900],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _filter = const PropertyFilter();
                      _priceRange = const RangeValues(0, 50000000);
                      _sizeRange = const RangeValues(0, 500);
                      _selectedRooms = {};
                    });
                  },
                  child: Text(
                    'Sıfırla',
                    style: TextStyle(
                      color: EmlakColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Listing Type
                  _buildSectionTitle('İlan Tipi', isDark),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildOptionChip(
                        'Tümü',
                        _filter.listingType == null,
                        () => setState(() => _filter = const PropertyFilter()),
                        isDark,
                      ),
                      _buildOptionChip(
                        'Satılık',
                        _filter.listingType == ListingType.sale,
                        () => setState(() => _filter = _filter.copyWith(
                            listingType: ListingType.sale)),
                        isDark,
                      ),
                      _buildOptionChip(
                        'Kiralık',
                        _filter.listingType == ListingType.rent,
                        () => setState(() => _filter = _filter.copyWith(
                            listingType: ListingType.rent)),
                        isDark,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Property Type
                  _buildSectionTitle('Emlak Tipi', isDark),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: PropertyType.values.map((type) {
                      return _buildOptionChip(
                        type.label,
                        _filter.type == type,
                        () => setState(() => _filter = _filter.copyWith(type: type)),
                        isDark,
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Price Range
                  _buildSectionTitle('Fiyat Aralığı', isDark),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatPrice(_priceRange.start),
                        style: TextStyle(
                          color: EmlakColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _priceRange.end >= 50000000
                            ? '50M+ TL'
                            : _formatPrice(_priceRange.end),
                        style: TextStyle(
                          color: EmlakColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  RangeSlider(
                    values: _priceRange,
                    min: 0,
                    max: 50000000,
                    divisions: 20,
                    activeColor: EmlakColors.primary,
                    inactiveColor: isDark ? Colors.grey[700] : Colors.grey[300],
                    onChanged: (values) {
                      setState(() => _priceRange = values);
                    },
                  ),

                  const SizedBox(height: 24),

                  // Size Range
                  _buildSectionTitle('Alan (m²)', isDark),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_sizeRange.start.toInt()} m²',
                        style: TextStyle(
                          color: EmlakColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _sizeRange.end >= 500
                            ? '500+ m²'
                            : '${_sizeRange.end.toInt()} m²',
                        style: TextStyle(
                          color: EmlakColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  RangeSlider(
                    values: _sizeRange,
                    min: 0,
                    max: 500,
                    divisions: 50,
                    activeColor: EmlakColors.primary,
                    inactiveColor: isDark ? Colors.grey[700] : Colors.grey[300],
                    onChanged: (values) {
                      setState(() => _sizeRange = values);
                    },
                  ),

                  const SizedBox(height: 24),

                  // Rooms
                  _buildSectionTitle('Oda Sayısı', isDark),
                  const SizedBox(height: 12),
                  Row(
                    children: ['1+1', '2+1', '3+1', '4+1', '5+'].map((room) {
                      final isSelected = _selectedRooms.contains(room);
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Material(
                            color: isSelected
                                ? EmlakColors.primary
                                : (isDark ? Colors.grey[800] : Colors.grey[100]),
                            borderRadius: BorderRadius.circular(10),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  if (isSelected) {
                                    _selectedRooms.remove(room);
                                  } else {
                                    _selectedRooms = {..._selectedRooms, room};
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? EmlakColors.primary
                                        : (isDark
                                            ? Colors.grey[700]!
                                            : Colors.grey[300]!),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    room,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark ? Colors.white : Colors.grey[800]),
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              16 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  // Tüm filtre değerlerini birleştir
                  PropertyFilter finalFilter = _filter;

                  // Fiyat aralığı (varsayılan sınırlar değilse)
                  final hasMinPrice = _priceRange.start > 0;
                  final hasMaxPrice = _priceRange.end < 50000000;
                  if (hasMinPrice || hasMaxPrice) {
                    finalFilter = PropertyFilter(
                      type: finalFilter.type,
                      listingType: finalFilter.listingType,
                      minPrice: hasMinPrice ? _priceRange.start : null,
                      maxPrice: hasMaxPrice ? _priceRange.end : null,
                      minSquareMeters: _sizeRange.start > 0 ? _sizeRange.start.toInt() : null,
                      maxSquareMeters: _sizeRange.end < 500 ? _sizeRange.end.toInt() : null,
                      roomTypes: _selectedRooms.isNotEmpty ? _selectedRooms : null,
                    );
                  } else {
                    finalFilter = PropertyFilter(
                      type: finalFilter.type,
                      listingType: finalFilter.listingType,
                      minSquareMeters: _sizeRange.start > 0 ? _sizeRange.start.toInt() : null,
                      maxSquareMeters: _sizeRange.end < 500 ? _sizeRange.end.toInt() : null,
                      roomTypes: _selectedRooms.isNotEmpty ? _selectedRooms : null,
                    );
                  }

                  widget.onApply(finalFilter);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: EmlakColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Filtreleri Uygula',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : Colors.grey[900],
      ),
    );
  }

  Widget _buildOptionChip(
    String label,
    bool isSelected,
    VoidCallback onTap,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: isSelected ? EmlakColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(25),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(25),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: isSelected
                    ? EmlakColors.primary
                    : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M TL';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K TL';
    }
    return '${price.toStringAsFixed(0)} TL';
  }
}
