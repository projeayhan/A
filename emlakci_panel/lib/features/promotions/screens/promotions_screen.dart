import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/emlak_models.dart';
import '../../../services/realtor_service.dart';
import '../../../services/stripe_service.dart';

// ==================== PROVIDERS ====================

final propertyPromoPricesProvider =
    FutureProvider<List<PropertyPromotionPrice>>((ref) async {
  final raw = await RealtorService().getPropertyPromotionPrices();
  return raw.map((e) => PropertyPromotionPrice.fromJson(e)).toList();
});

final myPropertyPromotionsProvider =
    FutureProvider<List<PropertyPromotion>>((ref) async {
  final raw = await RealtorService().getMyPropertyPromotions();
  return raw.map((e) => PropertyPromotion.fromJson(e)).toList();
});

final activePropertyListingsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];
  final response = await Supabase.instance.client
      .from('property_listings')
      .select('id, title, images, city, district, price, status, is_featured, is_premium')
      .eq('user_id', userId)
      .eq('status', 'active')
      .order('created_at', ascending: false);
  return (response as List).cast<Map<String, dynamic>>();
});

// ==================== SCREEN ====================

class EmlakPromotionsScreen extends ConsumerStatefulWidget {
  const EmlakPromotionsScreen({super.key});

  @override
  ConsumerState<EmlakPromotionsScreen> createState() =>
      _EmlakPromotionsScreenState();
}

class _EmlakPromotionsScreenState extends ConsumerState<EmlakPromotionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            color: AppColors.sidebarBg,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        color: Color(0xFFF59E0B), size: 28),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Öne Çıkarma',
                            style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        const Text('İlanlarınızı öne çıkarın',
                            style: TextStyle(
                                fontSize: 13, color: Colors.white54)),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        ref.invalidate(myPropertyPromotionsProvider);
                        ref.invalidate(activePropertyListingsProvider);
                      },
                      icon: const Icon(Icons.refresh_rounded,
                          color: Colors.white70),
                      tooltip: 'Yenile',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Talep Gönder'),
                    Tab(text: 'Geçmiş'),
                  ],
                  indicatorColor: const Color(0xFFF59E0B),
                  labelColor: const Color(0xFFF59E0B),
                  unselectedLabelColor: Colors.white54,
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _RequestTab(isDark: isDark),
                _HistoryTab(isDark: isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: Talep Gönder ───────────────────────────────────────────────────────

class _RequestTab extends ConsumerWidget {
  final bool isDark;
  const _RequestTab({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(activePropertyListingsProvider);

    return listingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
      data: (listings) {
        if (listings.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.home_work_rounded,
                    size: 64,
                    color: isDark
                        ? Colors.white24
                        : const Color(0xFFCBD5E1)),
                const SizedBox(height: 16),
                const Text('Aktif ilanınız bulunmuyor',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                const Text('Öne çıkarmak için önce ilan oluşturun.',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: listings.length,
          itemBuilder: (ctx, i) =>
              _ListingPromoCard(listing: listings[i], isDark: isDark),
        );
      },
    );
  }
}

class _ListingPromoCard extends ConsumerWidget {
  final Map<String, dynamic> listing;
  final bool isDark;
  const _ListingPromoCard({required this.listing, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final isFeatured = listing['is_featured'] as bool? ?? false;
    final isPremium = listing['is_premium'] as bool? ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: isDark
                ? const Color(0xFF334155)
                : const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 64,
                height: 64,
                child: _buildImage(listing['images']),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          listing['title'] as String? ?? 'Emlak İlanı',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isPremium)
                        _badge('Premium', Colors.purple)
                      else if (isFeatured)
                        _badge('Öne Çıkıyor', Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${listing['city'] ?? ''} ${listing['district'] ?? ''}'.trim(),
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _showPriceSheet(context, ref, listing),
              icon: const Icon(Icons.star_rounded, size: 16),
              label: const Text('Öne Çıkar',
                  style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(dynamic images) {
    if (images is List && images.isNotEmpty) {
      return Image.network(
        images.first.toString(),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            const Icon(Icons.home_work_rounded, size: 32, color: Colors.grey),
      );
    }
    return Container(
      color: const Color(0xFF334155),
      child: const Icon(Icons.home_work_rounded, size: 32, color: Colors.grey),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11)),
    );
  }

  void _showPriceSheet(
      BuildContext context, WidgetRef ref, Map<String, dynamic> listing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PriceSheet(
        listingId: listing['id'] as String,
        listingTitle:
            listing['title'] as String? ?? 'Emlak İlanı',
        onSuccess: () {
          ref.invalidate(myPropertyPromotionsProvider);
          ref.invalidate(activePropertyListingsProvider);
        },
      ),
    );
  }
}

// ── Price Sheet ───────────────────────────────────────────────────────────────

class _PriceSheet extends ConsumerStatefulWidget {
  final String listingId;
  final String listingTitle;
  final VoidCallback onSuccess;

  const _PriceSheet({
    required this.listingId,
    required this.listingTitle,
    required this.onSuccess,
  });

  @override
  ConsumerState<_PriceSheet> createState() => _PriceSheetState();
}

class _PriceSheetState extends ConsumerState<_PriceSheet> {
  PropertyPromotionPrice? _selected;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final pricesAsync = ref.watch(propertyPromoPricesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white24
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Paket Seçin',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(widget.listingTitle,
                      style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? Colors.white54
                              : const Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: pricesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Hata: $e')),
                data: (prices) => ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: prices.map((price) {
                    final isSelected = _selected?.id == price.id;
                    return _PriceCard(
                      price: price,
                      isSelected: isSelected,
                      isDark: isDark,
                      onTap: () =>
                          setState(() => _selected = price),
                    );
                  }).toList(),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _selected != null
                        ? const Color(0xFFF59E0B)
                        : Colors.grey,
                    padding:
                        const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed:
                      _selected == null || _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white))
                      : Text(
                          _selected != null
                              ? 'Satın Al  •  ₺${_selected!.effectivePrice.toStringAsFixed(0)}'
                              : 'Paket Seçin',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_selected == null) return;
    setState(() => _loading = true);

    // 1. Önce pending promosyon kaydı oluştur → ID al
    final pending = await RealtorService().submitPropertyPromotionRequest(
      listingId: widget.listingId,
      priceId: _selected!.id,
      status: 'pending_payment',
    );

    if (!mounted) return;
    if (pending == null) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Promosyon başlatılamadı. Lütfen tekrar deneyin.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 2. Stripe ödeme — promotion_id metadata'ya ekleniyor (webhook için)
    final isPaid = await StripeService.instance.processPayment(
      amount: _selected!.effectivePrice,
      description: '${_selected!.promotionType == 'premium' ? 'Premium' : 'Öne Çıkar'} - ${_selected!.durationDays} gün',
      metadata: {
        'type': 'property_promotion',
        'promotion_id': pending['id'] as String,
        'listing_id': widget.listingId,
        'promotion_type': _selected!.promotionType,
      },
    );

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    if (!isPaid) {
      setState(() => _loading = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Ödeme tamamlanamadı.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 3. Ödeme başarılı → client-side aktifleştir
    //    (webhook da aynısını yapacak — güvenlik ağı olarak)
    await RealtorService().activatePropertyPromotion(
      pending['id'] as String,
      widget.listingId,
      _selected!.promotionType,
    );

    if (!mounted) return;
    setState(() => _loading = false);
    nav.pop();
    widget.onSuccess();

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Ödeme alındı! İlanınız öne çıkarıldı.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  final PropertyPromotionPrice price;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _PriceCard({
    required this.price,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPremium = price.promotionType == 'premium';
    final accentColor =
        isPremium ? Colors.purple : const Color(0xFFF59E0B);
    final cardBg =
        isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.12)
              : cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? accentColor
                : (isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isPremium
                    ? Icons.workspace_premium_rounded
                    : Icons.star_rounded,
                color: accentColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    price.label ??
                        '${isPremium ? 'Premium' : 'Öne Çıkar'} - ${price.durationDays} gün',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  if (price.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(price.description!,
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white54
                                : const Color(0xFF64748B))),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (price.hasDiscount) ...[
                  Text(
                    '₺${price.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey,
                        fontSize: 12),
                  ),
                  Text(
                    '₺${price.discountedPrice!.toStringAsFixed(0)}',
                    style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                ] else
                  Text(
                    '₺${price.price.toStringAsFixed(0)}',
                    style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_circle_rounded,
                  color: accentColor, size: 22),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Tab 2: Geçmiş ─────────────────────────────────────────────────────────────

class _HistoryTab extends ConsumerWidget {
  final bool isDark;
  const _HistoryTab({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promoAsync = ref.watch(myPropertyPromotionsProvider);
    final fmt = NumberFormat.currency(
        locale: 'tr_TR', symbol: '₺', decimalDigits: 0);
    final dateFmt = DateFormat('dd.MM.yyyy', 'tr_TR');

    return promoAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
      data: (promotions) {
        if (promotions.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history_rounded,
                    size: 64,
                    color: isDark
                        ? Colors.white24
                        : const Color(0xFFCBD5E1)),
                const SizedBox(height: 16),
                const Text('Henüz promosyon kaydı yok',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: promotions.length,
          itemBuilder: (ctx, i) {
            final promo = promotions[i];
            final statusColor = _statusColor(promo.status);

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (promo.promotionType == 'premium'
                                ? Colors.purple
                                : const Color(0xFFF59E0B))
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        promo.promotionType == 'premium'
                            ? Icons.workspace_premium_rounded
                            : Icons.star_rounded,
                        color: promo.promotionType == 'premium'
                            ? Colors.purple
                            : const Color(0xFFF59E0B),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            promo.listingTitle ?? 'Emlak İlanı',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${promo.promotionType == 'premium' ? 'Premium' : 'Öne Çıkar'}  •  ${promo.durationDays} gün  •  ${fmt.format(promo.amountPaid)}',
                            style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.white54
                                    : const Color(0xFF64748B)),
                          ),
                          if (promo.startedAt != null &&
                              promo.expiresAt != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${dateFmt.format(promo.startedAt!)} – ${dateFmt.format(promo.expiresAt!)}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(promo.statusLabel,
                              style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12)),
                        ),
                        if (promo.status == 'pending') ...[
                          const SizedBox(height: 6),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => _cancel(
                                context, ref, promo.id),
                            child: const Text('İptal',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ],
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

  Color _statusColor(String status) {
    switch (status) {
      case 'pending': return Colors.amber;
      case 'active': return Colors.green;
      case 'expired': return Colors.blueGrey;
      case 'cancelled': return Colors.grey;
      default: return Colors.grey;
    }
  }

  Future<void> _cancel(
      BuildContext context, WidgetRef ref, String id) async {
    final ok =
        await RealtorService().cancelPropertyPromotion(id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'Promosyon talebi iptal edildi.'
            : 'İptal başarısız.'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
      if (ok) ref.invalidate(myPropertyPromotionsProvider);
    }
  }
}
