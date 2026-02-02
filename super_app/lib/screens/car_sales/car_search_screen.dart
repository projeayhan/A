import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/car_sales/car_sales_models.dart';
import 'car_detail_screen.dart';

class CarSearchScreen extends StatefulWidget {
  final String? initialBrandId;
  final CarBodyType? initialBodyType;

  const CarSearchScreen({
    super.key,
    this.initialBrandId,
    this.initialBodyType,
  });

  @override
  State<CarSearchScreen> createState() => _CarSearchScreenState();
}

class _CarSearchScreenState extends State<CarSearchScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late TextEditingController _searchController;
  final FocusNode _searchFocusNode = FocusNode();

  CarSearchFilter _filter = const CarSearchFilter();
  List<CarListing> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _searchController = TextEditingController();

    // Apply initial filters if provided
    if (widget.initialBrandId != null || widget.initialBodyType != null) {
      _filter = _filter.copyWith(
        brandIds: widget.initialBrandId != null
            ? [widget.initialBrandId!]
            : null,
        bodyTypes: widget.initialBodyType != null
            ? [widget.initialBodyType!]
            : null,
      );
    }

    _performSearch();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _performSearch() {
    setState(() => _isSearching = true);

    // Simulate search delay
    Future.delayed(const Duration(milliseconds: 300), () {
      var results = CarSalesDemoData.listings;

      // Apply text search
      if (_searchController.text.isNotEmpty) {
        final query = _searchController.text.toLowerCase();
        results = results.where((car) {
          return car.fullName.toLowerCase().contains(query) ||
              car.description.toLowerCase().contains(query);
        }).toList();
      }

      // Apply brand filter
      if (_filter.brandIds?.isNotEmpty ?? false) {
        results = results.where((car) {
          return _filter.brandIds!.contains(car.brand.id);
        }).toList();
      }

      // Apply body type filter
      if (_filter.bodyTypes?.isNotEmpty ?? false) {
        results = results.where((car) {
          return _filter.bodyTypes!.contains(car.bodyType);
        }).toList();
      }

      // Apply fuel type filter
      if (_filter.fuelTypes?.isNotEmpty ?? false) {
        results = results.where((car) {
          return _filter.fuelTypes!.contains(car.fuelType);
        }).toList();
      }

      // Apply price filter
      if (_filter.minPrice != null) {
        results = results.where((car) => car.price >= _filter.minPrice!).toList();
      }
      if (_filter.maxPrice != null) {
        results = results.where((car) => car.price <= _filter.maxPrice!).toList();
      }

      // Apply year filter
      if (_filter.minYear != null) {
        results = results.where((car) => car.year >= _filter.minYear!).toList();
      }
      if (_filter.maxYear != null) {
        results = results.where((car) => car.year <= _filter.maxYear!).toList();
      }

      // Apply sorting
      switch (_filter.sortBy) {
        case CarSortOption.newest:
          results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          break;
        case CarSortOption.oldest:
          results.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          break;
        case CarSortOption.priceLow:
          results.sort((a, b) => a.price.compareTo(b.price));
          break;
        case CarSortOption.priceHigh:
          results.sort((a, b) => b.price.compareTo(a.price));
          break;
        case CarSortOption.mileageLow:
          results.sort((a, b) => a.mileage.compareTo(b.mileage));
          break;
        case CarSortOption.mileageHigh:
          results.sort((a, b) => b.mileage.compareTo(a.mileage));
          break;
        case CarSortOption.yearNew:
          results.sort((a, b) => b.year.compareTo(a.year));
          break;
        case CarSortOption.yearOld:
          results.sort((a, b) => a.year.compareTo(b.year));
          break;
      }

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    });
  }

  void _clearFilters() {
    setState(() {
      _filter = const CarSearchFilter();
      _searchController.clear();
    });
    _performSearch();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: CarSalesColors.background(isDark),
        body: SafeArea(
          child: Column(
            children: [
              // Search Header
              _buildSearchHeader(isDark),

              // Active Filters
              if (_filter.activeFilterCount > 0)
                _buildActiveFilters(isDark),

              // Results
              Expanded(
                child: _isSearching
                    ? _buildLoadingState(isDark)
                    : _searchResults.isEmpty
                        ? _buildEmptyState(isDark)
                        : _buildResultsList(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CarSalesColors.card(isDark),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search Row
          Row(
            children: [
              // Back Button
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: CarSalesColors.surface(isDark),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.arrow_back,
                    color: CarSalesColors.textPrimary(isDark),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Search Field
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: CarSalesColors.surface(isDark),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: (_) => _performSearch(),
                    style: TextStyle(
                      color: CarSalesColors.textPrimary(isDark),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Marka, model veya anahtar kelime...',
                      hintStyle: TextStyle(
                        color: CarSalesColors.textTertiary(isDark),
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: CarSalesColors.textTertiary(isDark),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                _performSearch();
                              },
                              child: Icon(
                                Icons.close,
                                color: CarSalesColors.textTertiary(isDark),
                              ),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Filter Button
              GestureDetector(
                onTap: () => _showFilterSheet(isDark),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _filter.activeFilterCount > 0
                        ? CarSalesColors.primary
                        : CarSalesColors.surface(isDark),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          Icons.tune,
                          color: _filter.activeFilterCount > 0
                              ? Colors.white
                              : CarSalesColors.textPrimary(isDark),
                        ),
                      ),
                      if (_filter.activeFilterCount > 0)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: CarSalesColors.accent,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${_filter.activeFilterCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Sort & Results Count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_searchResults.length} sonuç bulundu',
                style: TextStyle(
                  color: CarSalesColors.textSecondary(isDark),
                  fontSize: 13,
                ),
              ),
              GestureDetector(
                onTap: () => _showSortSheet(isDark),
                child: Row(
                  children: [
                    Icon(
                      _filter.sortBy.icon,
                      size: 18,
                      color: CarSalesColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _filter.sortBy.label,
                      style: const TextStyle(
                        color: CarSalesColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: CarSalesColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilters(bool isDark) {
    final chips = <Widget>[];

    // Brand chips
    if (_filter.brandIds?.isNotEmpty ?? false) {
      for (final brandId in _filter.brandIds!) {
        final brand = CarBrand.allBrands.firstWhere(
          (b) => b.id == brandId,
          orElse: () => CarBrand.allBrands.first,
        );
        chips.add(_buildFilterChip(isDark, brand.name, () {
          setState(() {
            final newBrands = List<String>.from(_filter.brandIds!)
              ..remove(brandId);
            _filter = _filter.copyWith(
              brandIds: newBrands.isEmpty ? null : newBrands,
            );
          });
          _performSearch();
        }));
      }
    }

    // Body type chips
    if (_filter.bodyTypes?.isNotEmpty ?? false) {
      for (final bodyType in _filter.bodyTypes!) {
        chips.add(_buildFilterChip(isDark, bodyType.label, () {
          setState(() {
            final newTypes = List<CarBodyType>.from(_filter.bodyTypes!)
              ..remove(bodyType);
            _filter = _filter.copyWith(
              bodyTypes: newTypes.isEmpty ? null : newTypes,
            );
          });
          _performSearch();
        }));
      }
    }

    // Price range chip
    if (_filter.minPrice != null || _filter.maxPrice != null) {
      final priceText = _filter.minPrice != null && _filter.maxPrice != null
          ? '${_formatPrice(_filter.minPrice!)} - ${_formatPrice(_filter.maxPrice!)}'
          : _filter.minPrice != null
              ? '${_formatPrice(_filter.minPrice!)}+'
              : '${_formatPrice(_filter.maxPrice!)} altı';
      chips.add(_buildFilterChip(isDark, priceText, () {
        setState(() {
          _filter = _filter.copyWith(minPrice: null, maxPrice: null);
        });
        _performSearch();
      }));
    }

    // Clear all button
    chips.add(
      GestureDetector(
        onTap: _clearFilters,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: CarSalesColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.clear_all, size: 16, color: CarSalesColors.accent),
              SizedBox(width: 4),
              Text(
                'Temizle',
                style: TextStyle(
                  color: CarSalesColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: chips,
        ),
      ),
    );
  }

  Widget _buildFilterChip(bool isDark, String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: CarSalesColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: CarSalesColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close,
              size: 16,
              color: CarSalesColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: CarSalesColors.primary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Aranıyor...',
            style: TextStyle(
              color: CarSalesColors.textSecondary(isDark),
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
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: CarSalesColors.surface(isDark),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off,
              size: 40,
              color: CarSalesColors.textTertiary(isDark),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Sonuç Bulunamadı',
            style: TextStyle(
              color: CarSalesColors.textPrimary(isDark),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Farklı filtreler deneyebilirsiniz',
            style: TextStyle(
              color: CarSalesColors.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _clearFilters,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: CarSalesColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Filtreleri Temizle',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final car = _searchResults[index];
        return _buildCarCard(car, isDark);
      },
    );
  }

  Widget _buildCarCard(CarListing car, bool isDark) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CarDetailScreen(car: car),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: CarSalesColors.card(isDark),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: Image.network(
                    car.images.first,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 180,
                      color: CarSalesColors.surface(isDark),
                      child: Icon(
                        Icons.directions_car,
                        size: 60,
                        color: CarSalesColors.textTertiary(isDark),
                      ),
                    ),
                  ),
                ),
                // Premium Badge
                if (car.isPremiumListing)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: CarSalesColors.goldGradient,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Premium',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Favorite Button
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_border,
                      color: CarSalesColors.accent,
                      size: 20,
                    ),
                  ),
                ),
                // Image Count
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.photo_library,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${car.images.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    car.fullName,
                    style: TextStyle(
                      color: CarSalesColors.textPrimary(isDark),
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Specs Row
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildSpecBadge(isDark, Icons.calendar_today, '${car.year}'),
                      _buildSpecBadge(isDark, Icons.speed, car.formattedMileage),
                      _buildSpecBadge(isDark, car.fuelType.icon, car.fuelType.label),
                      _buildSpecBadge(isDark, car.transmission.icon, car.transmission.label),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Price Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            car.fullFormattedPrice,
                            style: const TextStyle(
                              color: CarSalesColors.primary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (car.location.isNotEmpty)
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: CarSalesColors.textTertiary(isDark),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  car.location,
                                  style: TextStyle(
                                    color: CarSalesColors.textTertiary(isDark),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      Row(
                        children: [
                          if (car.isPriceNegotiable)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: CarSalesColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Pazarlık',
                                style: TextStyle(
                                  color: CarSalesColors.success,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          Text(
                            car.timeAgo,
                            style: TextStyle(
                              color: CarSalesColors.textTertiary(isDark),
                              fontSize: 12,
                            ),
                          ),
                        ],
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

  Widget _buildSpecBadge(bool isDark, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: CarSalesColors.surface(isDark),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: CarSalesColors.textSecondary(isDark)),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: CarSalesColors.textSecondary(isDark),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterBottomSheet(
        filter: _filter,
        isDark: isDark,
        onApply: (newFilter) {
          setState(() => _filter = newFilter);
          _performSearch();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showSortSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: CarSalesColors.card(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sıralama',
              style: TextStyle(
                color: CarSalesColors.textPrimary(isDark),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...CarSortOption.values.map((option) {
              final isSelected = _filter.sortBy == option;
              return ListTile(
                onTap: () {
                  setState(() {
                    _filter = _filter.copyWith(sortBy: option);
                  });
                  _performSearch();
                  Navigator.of(context).pop();
                },
                leading: Icon(
                  option.icon,
                  color: isSelected
                      ? CarSalesColors.primary
                      : CarSalesColors.textSecondary(isDark),
                ),
                title: Text(
                  option.label,
                  style: TextStyle(
                    color: isSelected
                        ? CarSalesColors.primary
                        : CarSalesColors.textPrimary(isDark),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check, color: CarSalesColors.primary)
                    : null,
              );
            }),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  String _formatPrice(int price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M TL';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K TL';
    }
    return '$price TL';
  }
}

// Filter Bottom Sheet
class _FilterBottomSheet extends StatefulWidget {
  final CarSearchFilter filter;
  final bool isDark;
  final Function(CarSearchFilter) onApply;

  const _FilterBottomSheet({
    required this.filter,
    required this.isDark,
    required this.onApply,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late CarSearchFilter _tempFilter;

  @override
  void initState() {
    super.initState();
    _tempFilter = widget.filter;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: CarSalesColors.card(widget.isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: CarSalesColors.border(widget.isDark),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filtreler',
                  style: TextStyle(
                    color: CarSalesColors.textPrimary(widget.isDark),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _tempFilter = const CarSearchFilter();
                    });
                  },
                  child: const Text(
                    'Sıfırla',
                    style: TextStyle(
                      color: CarSalesColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Filter Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brands
                  _buildFilterSection('Marka'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: CarBrand.popularBrands.map((brand) {
                      final isSelected =
                          _tempFilter.brandIds?.contains(brand.id) ?? false;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            final newBrands =
                                List<String>.from(_tempFilter.brandIds ?? []);
                            if (isSelected) {
                              newBrands.remove(brand.id);
                            } else {
                              newBrands.add(brand.id);
                            }
                            _tempFilter = _tempFilter.copyWith(
                              brandIds: newBrands.isEmpty ? null : newBrands,
                            );
                          });
                        },
                        child: _buildFilterChip(brand.name, isSelected),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Body Types
                  _buildFilterSection('Kasa Tipi'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: CarBodyType.values.take(8).map((type) {
                      final isSelected =
                          _tempFilter.bodyTypes?.contains(type) ?? false;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            final newTypes = List<CarBodyType>.from(
                                _tempFilter.bodyTypes ?? []);
                            if (isSelected) {
                              newTypes.remove(type);
                            } else {
                              newTypes.add(type);
                            }
                            _tempFilter = _tempFilter.copyWith(
                              bodyTypes: newTypes.isEmpty ? null : newTypes,
                            );
                          });
                        },
                        child: _buildFilterChip(type.label, isSelected),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Fuel Types
                  _buildFilterSection('Yakıt Tipi'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: CarFuelType.values.map((type) {
                      final isSelected =
                          _tempFilter.fuelTypes?.contains(type) ?? false;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            final newTypes = List<CarFuelType>.from(
                                _tempFilter.fuelTypes ?? []);
                            if (isSelected) {
                              newTypes.remove(type);
                            } else {
                              newTypes.add(type);
                            }
                            _tempFilter = _tempFilter.copyWith(
                              fuelTypes: newTypes.isEmpty ? null : newTypes,
                            );
                          });
                        },
                        child: _buildFilterChip(type.label, isSelected),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Year Range
                  _buildFilterSection('Model Yılı'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildYearDropdown(
                          'Min',
                          _tempFilter.minYear,
                          (value) {
                            setState(() {
                              _tempFilter = _tempFilter.copyWith(minYear: value);
                            });
                          },
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('-'),
                      ),
                      Expanded(
                        child: _buildYearDropdown(
                          'Max',
                          _tempFilter.maxYear,
                          (value) {
                            setState(() {
                              _tempFilter = _tempFilter.copyWith(maxYear: value);
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // Apply Button
          Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: 16 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: CarSalesColors.card(widget.isDark),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: GestureDetector(
              onTap: () => widget.onApply(_tempFilter),
              child: Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: CarSalesColors.primaryGradient,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    'Filtrele (${_tempFilter.activeFilterCount} aktif)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(String title) {
    return Text(
      title,
      style: TextStyle(
        color: CarSalesColors.textPrimary(widget.isDark),
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? CarSalesColors.primary
            : CarSalesColors.surface(widget.isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? CarSalesColors.primary
              : CarSalesColors.border(widget.isDark),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected
              ? Colors.white
              : CarSalesColors.textPrimary(widget.isDark),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildYearDropdown(String hint, int? value, Function(int?) onChanged) {
    final currentYear = DateTime.now().year;
    final years = List.generate(30, (index) => currentYear - index);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: CarSalesColors.surface(widget.isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CarSalesColors.border(widget.isDark)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: value,
          hint: Text(
            hint,
            style: TextStyle(color: CarSalesColors.textTertiary(widget.isDark)),
          ),
          isExpanded: true,
          dropdownColor: CarSalesColors.card(widget.isDark),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(
                hint,
                style: TextStyle(
                  color: CarSalesColors.textTertiary(widget.isDark),
                ),
              ),
            ),
            ...years.map((year) => DropdownMenuItem<int>(
                  value: year,
                  child: Text(
                    year.toString(),
                    style: TextStyle(
                      color: CarSalesColors.textPrimary(widget.isDark),
                    ),
                  ),
                )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
