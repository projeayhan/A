import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/car_sales/car_sales_models.dart';
import '../../core/providers/unified_favorites_provider.dart';

class CarFavoritesScreen extends ConsumerStatefulWidget {
  const CarFavoritesScreen({super.key});

  @override
  ConsumerState<CarFavoritesScreen> createState() => _CarFavoritesScreenState();
}

class _CarFavoritesScreenState extends ConsumerState<CarFavoritesScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<FavoriteCar> favorites) {
    setState(() {
      if (_selectedIds.length == favorites.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(favorites.map((c) => c.id));
      }
    });
  }

  void _removeSelected() {
    if (_selectedIds.isEmpty) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: CarSalesColors.card(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Favorilerden Kaldır',
          style: TextStyle(color: CarSalesColors.textPrimary(isDark)),
        ),
        content: Text(
          '${_selectedIds.length} aracı favorilerden kaldırmak istediğinize emin misiniz?',
          style: TextStyle(color: CarSalesColors.textSecondary(isDark)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'İptal',
              style: TextStyle(color: CarSalesColors.textSecondary(isDark)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              for (final id in _selectedIds) {
                ref.read(carFavoriteProvider.notifier).removeCar(id);
              }
              setState(() {
                _selectedIds.clear();
                _isSelectionMode = false;
              });
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(
                  content: Text('Seçili araçlar favorilerden kaldırıldı'),
                  backgroundColor: CarSalesColors.primary,
                ),
              );
            },
            child: const Text(
              'Kaldır',
              style: TextStyle(color: CarSalesColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  void _removeFavorite(FavoriteCar car) {
    HapticFeedback.lightImpact();
    ref.read(carFavoriteProvider.notifier).removeCar(car.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${car.title} favorilerden kaldırıldı'),
        backgroundColor: CarSalesColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final favorites = ref.watch(carFavoriteProvider).cars;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: CarSalesColors.background(isDark),
        appBar: AppBar(
          backgroundColor: CarSalesColors.background(isDark),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: CarSalesColors.textPrimary(isDark)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            _isSelectionMode ? '${_selectedIds.length} seçildi' : 'Favori Araçlarım',
            style: TextStyle(
              color: CarSalesColors.textPrimary(isDark),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            if (favorites.isNotEmpty) ...[
              if (_isSelectionMode) ...[
                IconButton(
                  icon: Icon(
                    _selectedIds.length == favorites.length ? Icons.deselect : Icons.select_all,
                    color: CarSalesColors.primary,
                  ),
                  onPressed: () => _selectAll(favorites),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: _selectedIds.isEmpty
                        ? CarSalesColors.textTertiary(isDark)
                        : CarSalesColors.accent,
                  ),
                  onPressed: _selectedIds.isEmpty ? null : _removeSelected,
                ),
              ],
              IconButton(
                icon: Icon(
                  _isSelectionMode ? Icons.close : Icons.checklist,
                  color: CarSalesColors.textPrimary(isDark),
                ),
                onPressed: _toggleSelectionMode,
              ),
            ],
          ],
        ),
        body: favorites.isEmpty
            ? _buildEmptyState(isDark)
            : _buildFavoritesList(isDark, favorites),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: CarSalesColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_border,
                size: 60,
                color: CarSalesColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Henüz Favori Aracınız Yok',
              style: TextStyle(
                color: CarSalesColors.textPrimary(isDark),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Beğendiğiniz araç ilanlarını favorilere ekleyerek daha sonra kolayca ulaşabilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: CarSalesColors.textSecondary(isDark),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: CarSalesColors.primaryGradient),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: CarSalesColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Araçları Keşfet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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

  Widget _buildFavoritesList(bool isDark, List<FavoriteCar> favorites) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final car = favorites[index];
        final isSelected = _selectedIds.contains(car.id);

        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0, 0.1 * (index + 1)),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: _animationController,
                curve: Interval(
                  (0.1 * index).clamp(0.0, 0.5),
                  (0.1 * index + 0.5).clamp(0.0, 1.0),
                  curve: Curves.easeOut,
                ),
              )),
              child: FadeTransition(
                opacity: _animationController,
                child: child,
              ),
            );
          },
          child: _buildFavoriteCard(car, isDark, isSelected),
        );
      },
    );
  }

  Widget _buildFavoriteCard(FavoriteCar car, bool isDark, bool isSelected) {
    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(car.id);
        } else {
          context.push('/car-sales/detail/${car.id}');
        }
      },
      onLongPress: () {
        if (!_isSelectionMode) {
          _toggleSelectionMode();
          _toggleSelection(car.id);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? CarSalesColors.primary.withValues(alpha: 0.1)
              : CarSalesColors.card(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? CarSalesColors.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
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
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: CachedNetworkImage(
                    imageUrl: car.imageUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 180,
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 180,
                      color: CarSalesColors.surface(isDark),
                      child: Icon(
                        Icons.directions_car,
                        size: 40,
                        color: CarSalesColors.textTertiary(isDark),
                      ),
                    ),
                  ),
                ),
                // Selection checkbox
                if (_isSelectionMode)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? CarSalesColors.primary
                            : Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? CarSalesColors.primary
                              : CarSalesColors.border(isDark),
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : null,
                    ),
                  ),
                // Year badge
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: CarSalesColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${car.year}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Remove favorite button
                if (!_isSelectionMode)
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: () => _removeFavorite(car),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: CarSalesColors.accent,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    car.title,
                    style: TextStyle(
                      color: CarSalesColors.textPrimary(isDark),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 13, color: CarSalesColors.textSecondary(isDark)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          car.location,
                          style: TextStyle(
                            color: CarSalesColors.textSecondary(isDark),
                            fontSize: 12,
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
                      _buildFeatureChip(car.formattedKm, Icons.speed, isDark),
                      const SizedBox(width: 8),
                      _buildFeatureChip(car.fuelType, Icons.local_gas_station, isDark),
                      const SizedBox(width: 8),
                      _buildFeatureChip(car.transmission, Icons.settings, isDark),
                      const Spacer(),
                      Text(
                        car.formattedPrice,
                        style: const TextStyle(
                          color: CarSalesColors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildFeatureChip(String text, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: CarSalesColors.surface(isDark),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: CarSalesColors.textSecondary(isDark)),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: CarSalesColors.textSecondary(isDark),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
