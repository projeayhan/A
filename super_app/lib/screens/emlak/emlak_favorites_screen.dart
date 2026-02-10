import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/emlak/emlak_models.dart';
import '../../core/providers/unified_favorites_provider.dart';

class EmlakFavoritesScreen extends ConsumerStatefulWidget {
  const EmlakFavoritesScreen({super.key});

  @override
  ConsumerState<EmlakFavoritesScreen> createState() => _EmlakFavoritesScreenState();
}

class _EmlakFavoritesScreenState extends ConsumerState<EmlakFavoritesScreen>
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
      if (!_isSelectionMode) {
        _selectedIds.clear();
      }
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

  void _selectAll(List<FavoriteProperty> favorites) {
    setState(() {
      if (_selectedIds.length == favorites.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(favorites.map((p) => p.id));
      }
    });
  }

  void _removeSelected(List<FavoriteProperty> favorites) {
    if (_selectedIds.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: EmlakColors.card(isDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Favorilerden Kaldır',
            style: TextStyle(color: EmlakColors.textPrimary(isDark)),
          ),
          content: Text(
            '${_selectedIds.length} ilanı favorilerden kaldırmak istediğinize emin misiniz?',
            style: TextStyle(color: EmlakColors.textSecondary(isDark)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'İptal',
                style: TextStyle(color: EmlakColors.textSecondary(isDark)),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Seçili ilanları kaldır
                for (final id in _selectedIds) {
                  ref.read(emlakFavoriteProvider.notifier).removeProperty(id);
                }
                setState(() {
                  _selectedIds.clear();
                  _isSelectionMode = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Seçili ilanlar favorilerden kaldırıldı'),
                    backgroundColor: EmlakColors.primary,
                  ),
                );
              },
              child: Text(
                'Kaldır',
                style: TextStyle(color: EmlakColors.error),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final favoritesState = ref.watch(emlakFavoriteProvider);
    final favorites = favoritesState.properties;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: EmlakColors.background(isDark),
        appBar: AppBar(
          backgroundColor: EmlakColors.background(isDark),
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: EmlakColors.textPrimary(isDark),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            _isSelectionMode
                ? '${_selectedIds.length} seçildi'
                : 'Favorilerim',
            style: TextStyle(
              color: EmlakColors.textPrimary(isDark),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            if (favorites.isNotEmpty) ...[
              if (_isSelectionMode) ...[
                IconButton(
                  icon: Icon(
                    _selectedIds.length == favorites.length
                        ? Icons.deselect
                        : Icons.select_all,
                    color: EmlakColors.primary,
                  ),
                  onPressed: () => _selectAll(favorites),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: _selectedIds.isEmpty
                        ? EmlakColors.textTertiary(isDark)
                        : EmlakColors.error,
                  ),
                  onPressed: _selectedIds.isEmpty ? null : () => _removeSelected(favorites),
                ),
              ],
              IconButton(
                icon: Icon(
                  _isSelectionMode ? Icons.close : Icons.checklist,
                  color: EmlakColors.textPrimary(isDark),
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
                color: EmlakColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite_border,
                size: 60,
                color: EmlakColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Henüz Favoriniz Yok',
              style: TextStyle(
                color: EmlakColors.textPrimary(isDark),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Beğendiğiniz ilanları favorilere ekleyerek daha sonra kolayca ulaşabilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: EmlakColors.textSecondary(isDark),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => context.push('/emlak'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [EmlakColors.primary, const Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: EmlakColors.primary.withValues(alpha: 0.3),
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
                      'İlanları Keşfet',
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

  Widget _buildFavoritesList(bool isDark, List<FavoriteProperty> favorites) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final property = favorites[index];
        final isSelected = _selectedIds.contains(property.id);

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
                  0.1 * index,
                  0.1 * index + 0.5,
                  curve: Curves.easeOut,
                ),
              )),
              child: FadeTransition(
                opacity: _animationController,
                child: child,
              ),
            );
          },
          child: _buildFavoriteCard(property, isDark, isSelected),
        );
      },
    );
  }

  Widget _buildFavoriteCard(FavoriteProperty property, bool isDark, bool isSelected) {
    final isSale = property.type == 'sale';

    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(property.id);
        } else {
          context.push('/emlak/property/${property.id}');
        }
      },
      onLongPress: () {
        if (!_isSelectionMode) {
          _toggleSelectionMode();
          _toggleSelection(property.id);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? EmlakColors.primary.withValues(alpha: 0.1)
              : EmlakColors.card(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? EmlakColors.primary
                : Colors.transparent,
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
            // Image - full width
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: CachedNetworkImage(
                    imageUrl: property.imageUrl,
                    height: 170,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 170,
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 170,
                      color: EmlakColors.surface(isDark),
                      child: Icon(
                        Icons.home,
                        size: 40,
                        color: EmlakColors.textTertiary(isDark),
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
                            ? EmlakColors.primary
                            : Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? EmlakColors.primary
                              : EmlakColors.border(isDark),
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : null,
                    ),
                  ),
                // Listing type badge
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSale
                          ? EmlakColors.primary
                          : const Color(0xFF8B5CF6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isSale ? 'Satılık' : 'Kiralık',
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
                      onTap: () => _removeFavorite(property),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.favorite,
                          color: EmlakColors.error,
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
                    property.title,
                    style: TextStyle(
                      color: EmlakColors.textPrimary(isDark),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 13,
                        color: EmlakColors.textSecondary(isDark),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          property.location,
                          style: TextStyle(
                            color: EmlakColors.textSecondary(isDark),
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
                      _buildFeatureChip(
                        '${property.rooms}+1',
                        Icons.bed,
                        isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildFeatureChip(
                        '${property.area} m²',
                        Icons.square_foot,
                        isDark,
                      ),
                      const Spacer(),
                      Text(
                        property.formattedPrice,
                        style: TextStyle(
                          color: EmlakColors.primary,
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
        color: EmlakColors.surface(isDark),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: EmlakColors.textSecondary(isDark)),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: EmlakColors.textSecondary(isDark),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _removeFavorite(FavoriteProperty property) {
    HapticFeedback.lightImpact();
    ref.read(emlakFavoriteProvider.notifier).removeProperty(property.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${property.title} favorilerden kaldırıldı'),
        backgroundColor: EmlakColors.primary,
      ),
    );
  }
}
