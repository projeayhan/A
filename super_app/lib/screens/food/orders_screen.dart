import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_responsive.dart';
import 'food_home_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Örnek sipariş verileri
  final List<Map<String, dynamic>> _activeOrders = [
    {
      'id': 'ORD-2024-001',
      'restaurantName': 'Burger King',
      'restaurantImage': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=200',
      'items': ['Whopper Menu', 'Onion Rings'],
      'itemCount': 2,
      'totalPrice': 250.00,
      'status': 'preparing', // preparing, on_the_way, delivered
      'statusText': 'Hazırlanıyor',
      'estimatedTime': '25-30 dk',
      'orderDate': '14:32',
      'address': 'Levent Mah. Caddebostan Sok. No: 15/4',
    },
    {
      'id': 'ORD-2024-002',
      'restaurantName': 'Pizza Hut',
      'restaurantImage': 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=200',
      'items': ['Pepperoni Pizza (L)', 'Garlic Bread', 'Cola'],
      'itemCount': 3,
      'totalPrice': 385.00,
      'status': 'on_the_way',
      'statusText': 'Yolda',
      'estimatedTime': '10-15 dk',
      'orderDate': '13:45',
      'address': 'Levent Mah. Caddebostan Sok. No: 15/4',
    },
  ];

  final List<Map<String, dynamic>> _completedOrders = [
    {
      'id': 'ORD-2024-098',
      'restaurantName': 'McDonald\'s',
      'restaurantImage': 'https://images.unsplash.com/photo-1586816001966-79b736744398?w=200',
      'items': ['Big Mac Menu', 'McFlurry'],
      'itemCount': 2,
      'totalPrice': 195.00,
      'status': 'delivered',
      'statusText': 'Teslim Edildi',
      'orderDate': '2 Ocak 2024',
      'deliveredTime': '14:45',
      'rating': 4.5,
    },
    {
      'id': 'ORD-2024-095',
      'restaurantName': 'Domino\'s Pizza',
      'restaurantImage': 'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=200',
      'items': ['Margarita Pizza', 'Chicken Wings', 'Sprite'],
      'itemCount': 3,
      'totalPrice': 320.00,
      'status': 'delivered',
      'statusText': 'Teslim Edildi',
      'orderDate': '31 Aralık 2023',
      'deliveredTime': '20:15',
      'rating': 5.0,
    },
    {
      'id': 'ORD-2024-090',
      'restaurantName': 'KFC',
      'restaurantImage': 'https://images.unsplash.com/photo-1626645738196-c2a7c87a8f58?w=200',
      'items': ['Bucket Menu', 'Coleslaw'],
      'itemCount': 2,
      'totalPrice': 275.00,
      'status': 'delivered',
      'statusText': 'Teslim Edildi',
      'orderDate': '28 Aralık 2023',
      'deliveredTime': '19:30',
      'rating': 4.0,
    },
    {
      'id': 'ORD-2024-085',
      'restaurantName': 'Starbucks',
      'restaurantImage': 'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=200',
      'items': ['Caramel Macchiato', 'Brownie'],
      'itemCount': 2,
      'totalPrice': 145.00,
      'status': 'delivered',
      'statusText': 'Teslim Edildi',
      'orderDate': '25 Aralık 2023',
      'deliveredTime': '11:20',
      'rating': null, // Henüz değerlendirilmemiş
    },
  ];

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? FoodColors.backgroundDark : FoodColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: isDark ? FoodColors.backgroundDark : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Siparişlerim',
          style: TextStyle(
            fontSize: context.heading1Size,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1C130D),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: FoodColors.primary,
          indicatorWeight: 3,
          labelColor: FoodColors.primary,
          unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
          labelStyle: TextStyle(
            fontSize: context.heading2Size,
            fontWeight: FontWeight.bold,
          ),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Aktif'),
                  if (_activeOrders.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: FoodColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _activeOrders.length.toString(),
                        style: TextStyle(
                          fontSize: context.captionSize,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Geçmiş'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Aktif Siparişler
          _buildActiveOrdersList(isDark),
          // Geçmiş Siparişler
          _buildCompletedOrdersList(isDark),
        ],
      ),
    );
  }

  Widget _buildActiveOrdersList(bool isDark) {
    if (_activeOrders.isEmpty) {
      return _buildEmptyState(
        isDark,
        icon: Icons.delivery_dining,
        title: 'Aktif sipariş yok',
        subtitle: 'Şu anda devam eden bir siparişiniz bulunmuyor',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activeOrders.length,
      itemBuilder: (context, index) {
        return _buildActiveOrderCard(_activeOrders[index], isDark);
      },
    );
  }

  Widget _buildCompletedOrdersList(bool isDark) {
    if (_completedOrders.isEmpty) {
      return _buildEmptyState(
        isDark,
        icon: Icons.receipt_long,
        title: 'Geçmiş sipariş yok',
        subtitle: 'Henüz tamamlanmış bir siparişiniz bulunmuyor',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _completedOrders.length,
      itemBuilder: (context, index) {
        return _buildCompletedOrderCard(_completedOrders[index], isDark);
      },
    );
  }

  Widget _buildEmptyState(bool isDark, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: isDark
                  ? FoodColors.primary.withValues(alpha: 0.2)
                  : FoodColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 50,
              color: FoodColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
              fontSize: context.heading1Size,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1C130D),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: context.bodySize,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => context.go('/food'),
            style: ElevatedButton.styleFrom(
              backgroundColor: FoodColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Sipariş Ver',
              style: TextStyle(
                fontSize: context.heading2Size,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveOrderCard(Map<String, dynamic> order, bool isDark) {
    final status = order['status'] as String;
    final statusColor = _getStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? FoodColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Üst kısım - Durum ve tahmini süre
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                // Animasyonlu durum ikonu
                _buildStatusIcon(status, statusColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order['statusText'],
                        style: TextStyle(
                          fontSize: context.heading2Size,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tahmini süre: ${order['estimatedTime']}',
                        style: TextStyle(
                          fontSize: context.bodySmallSize,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Takip Et butonu
                ElevatedButton(
                  onPressed: () {
                    context.push('/food/order-tracking/${order['id']}');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: statusColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.map, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'Takip Et',
                        style: TextStyle(
                          fontSize: context.bodySmallSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Sipariş progress bar
          _buildOrderProgress(status, statusColor),

          // Restoran ve sipariş bilgileri
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Restoran resmi
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: order['restaurantImage'],
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 60,
                      height: 60,
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      child: const Icon(Icons.restaurant, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order['restaurantName'],
                        style: TextStyle(
                          fontSize: context.heading2Size,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1C130D),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (order['items'] as List).join(', '),
                        style: TextStyle(
                          fontSize: context.bodySmallSize,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${order['itemCount']} ürün',
                            style: TextStyle(
                              fontSize: context.captionSize,
                              color: isDark ? Colors.grey[500] : Colors.grey[500],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '•',
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${order['totalPrice'].toStringAsFixed(0)} TL',
                            style: TextStyle(
                              fontSize: context.bodySize,
                              fontWeight: FontWeight.bold,
                              color: FoodColors.primary,
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

          // Alt kısım - Sipariş detayları ve işlemler
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withValues(alpha: 0.2) : FoodColors.backgroundLight,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Sipariş: ${order['orderDate']}',
                      style: TextStyle(
                        fontSize: context.captionSize,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => _showOrderDetails(order, isDark),
                  child: Text(
                    'Detayları Gör',
                    style: TextStyle(
                      fontSize: context.bodySmallSize,
                      fontWeight: FontWeight.bold,
                      color: FoodColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(String status, Color color) {
    IconData icon;
    switch (status) {
      case 'preparing':
        icon = Icons.restaurant;
        break;
      case 'on_the_way':
        icon = Icons.delivery_dining;
        break;
      default:
        icon = Icons.check_circle;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildOrderProgress(String status, Color color) {
    final steps = ['Alındı', 'Hazırlanıyor', 'Yolda', 'Teslim'];
    int currentStep;
    switch (status) {
      case 'preparing':
        currentStep = 1;
        break;
      case 'on_the_way':
        currentStep = 2;
        break;
      case 'delivered':
        currentStep = 3;
        break;
      default:
        currentStep = 0;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            // Çizgi
            final stepIndex = index ~/ 2;
            final isCompleted = stepIndex < currentStep;
            return Expanded(
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: isCompleted ? color : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          } else {
            // Nokta
            final stepIndex = index ~/ 2;
            final isCompleted = stepIndex <= currentStep;
            final isCurrent = stepIndex == currentStep;
            return Container(
              width: isCurrent ? 12 : 8,
              height: isCurrent ? 12 : 8,
              decoration: BoxDecoration(
                color: isCompleted ? color : Colors.grey[300],
                shape: BoxShape.circle,
                border: isCurrent
                    ? Border.all(color: color.withValues(alpha: 0.3), width: 3)
                    : null,
              ),
            );
          }
        }),
      ),
    );
  }

  Widget _buildCompletedOrderCard(Map<String, dynamic> order, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? FoodColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showOrderDetails(order, isDark),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // Restoran resmi
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: order['restaurantImage'],
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 56,
                        height: 56,
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 56,
                        height: 56,
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        child: const Icon(Icons.restaurant, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              order['restaurantName'],
                              style: TextStyle(
                                fontSize: context.heading2Size,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1C130D),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    size: 12,
                                    color: Color(0xFF22C55E),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Teslim Edildi',
                                    style: TextStyle(
                                      fontSize: context.captionSmallSize,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF22C55E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (order['items'] as List).join(', '),
                          style: TextStyle(
                            fontSize: context.bodySmallSize,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              order['orderDate'],
                              style: TextStyle(
                                fontSize: context.captionSize,
                                color: isDark ? Colors.grey[500] : Colors.grey[500],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '•',
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${order['totalPrice'].toStringAsFixed(0)} TL',
                              style: TextStyle(
                                fontSize: context.bodySmallSize,
                                fontWeight: FontWeight.bold,
                                color: FoodColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Alt kısım - Değerlendirme ve tekrar sipariş
              Row(
                children: [
                  // Değerlendirme
                  if (order['rating'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : FoodColors.backgroundLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, size: 16, color: Color(0xFFFACC15)),
                          const SizedBox(width: 4),
                          Text(
                            order['rating'].toString(),
                            style: TextStyle(
                              fontSize: context.bodySmallSize,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1C130D),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    TextButton.icon(
                      onPressed: () => _showRatingDialog(order, isDark),
                      icon: const Icon(Icons.star_border, size: 18, color: FoodColors.primary),
                      label: Text(
                        'Değerlendir',
                        style: TextStyle(
                          fontSize: context.bodySmallSize,
                          fontWeight: FontWeight.w600,
                          color: FoodColors.primary,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  const Spacer(),
                  // Tekrar sipariş ver butonu
                  ElevatedButton.icon(
                    onPressed: () {
                      // Tekrar sipariş ver
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sipariş sepete eklendi'),
                          backgroundColor: FoodColors.primary,
                        ),
                      );
                    },
                    icon: const Icon(Icons.replay, size: 16, color: Colors.white),
                    label: Text(
                      'Tekrarla',
                      style: TextStyle(
                        fontSize: context.bodySmallSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FoodColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'preparing':
        return const Color(0xFFF59E0B); // Amber
      case 'on_the_way':
        return const Color(0xFF3B82F6); // Blue
      case 'delivered':
        return const Color(0xFF22C55E); // Green
      default:
        return Colors.grey;
    }
  }

  void _showOrderDetails(Map<String, dynamic> order, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OrderDetailSheet(order: order, isDark: isDark),
    );
  }

  void _showRatingDialog(Map<String, dynamic> order, bool isDark) {
    int selectedRating = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? FoodColors.surfaceDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Siparişi Değerlendir',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1C130D),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                order['restaurantName'],
                style: TextStyle(
                  fontSize: context.heading2Size,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() => selectedRating = index + 1);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        index < selectedRating ? Icons.star : Icons.star_border,
                        size: 40,
                        color: const Color(0xFFFACC15),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'İptal',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: selectedRating > 0
                  ? () {
                      Navigator.pop(context);
                      setState(() {
                        order['rating'] = selectedRating.toDouble();
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Değerlendirmeniz kaydedildi'),
                          backgroundColor: FoodColors.primary,
                        ),
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: FoodColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Gönder',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Sipariş Detay Bottom Sheet
class _OrderDetailSheet extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool isDark;

  const _OrderDetailSheet({
    required this.order,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? FoodColors.backgroundDark : Colors.white,
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
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.all(context.pagePaddingH),
                  children: [
                    // Header
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: order['restaurantImage'],
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey[200],
                              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey[300],
                              child: const Icon(Icons.restaurant),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order['restaurantName'],
                                style: TextStyle(
                                  fontSize: context.heading1Size,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF1C130D),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Sipariş No: ${order['id']}',
                                style: TextStyle(
                                  fontSize: context.bodySmallSize,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Sipariş durumu
                    _buildSection(
                      'Sipariş Durumu',
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _getStatusColor(order['status']).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getStatusIcon(order['status']),
                              color: _getStatusColor(order['status']),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              order['statusText'],
                              style: TextStyle(
                                fontSize: context.heading2Size,
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(order['status']),
                              ),
                            ),
                          ],
                        ),
                      ),
                      context,
                    ),
                    const SizedBox(height: 20),

                    // Ürünler
                    _buildSection(
                      'Sipariş Detayları',
                      Column(
                        children: (order['items'] as List).map((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: FoodColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '1',
                                      style: TextStyle(
                                        fontSize: context.captionSize,
                                        fontWeight: FontWeight.bold,
                                        color: FoodColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item.toString(),
                                    style: TextStyle(
                                      fontSize: context.heading2Size,
                                      color: isDark ? Colors.white : const Color(0xFF1C130D),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      context,
                    ),
                    const SizedBox(height: 20),

                    // Teslimat adresi
                    if (order['address'] != null)
                      _buildSection(
                        'Teslimat Adresi',
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: FoodColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: FoodColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                order['address'],
                                style: TextStyle(
                                  fontSize: context.bodySize,
                                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                        context,
                      ),
                    const SizedBox(height: 20),

                    // Ödeme özeti
                    _buildSection(
                      'Ödeme Özeti',
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? FoodColors.surfaceDark : FoodColors.backgroundLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _buildPriceRow('Ara Toplam', '${(order['totalPrice'] - 15).toStringAsFixed(0)} TL', isDark),
                            const SizedBox(height: 8),
                            _buildPriceRow('Teslimat', '15 TL', isDark),
                            const Divider(height: 24),
                            _buildPriceRow(
                              'Toplam',
                              '${order['totalPrice'].toStringAsFixed(0)} TL',
                              isDark,
                              isBold: true,
                            ),
                          ],
                        ),
                      ),
                      context,
                    ),
                    const SizedBox(height: 24),

                    // Aksiyon butonları
                    if (order['status'] != 'delivered')
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.push('/food/order-tracking/${order['id']}');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FoodColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.map, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'Siparişi Takip Et',
                              style: TextStyle(
                                fontSize: context.heading2Size,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sipariş sepete eklendi'),
                              backgroundColor: FoodColors.primary,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FoodColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.replay, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'Tekrar Sipariş Ver',
                              style: TextStyle(
                                fontSize: context.heading2Size,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),

                    // Yardım butonu
                    OutlinedButton(
                      onPressed: () {
                        // Yardım
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(
                          color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.help_outline,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Yardım Al',
                            style: TextStyle(
                              fontSize: context.heading2Size,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection(String title, Widget content, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: context.bodySize,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        content,
      ],
    );
  }

  Widget _buildPriceRow(String label, String value, bool isDark, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 18 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isBold
                ? FoodColors.primary
                : (isDark ? Colors.white : const Color(0xFF1C130D)),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'preparing':
        return const Color(0xFFF59E0B);
      case 'on_the_way':
        return const Color(0xFF3B82F6);
      case 'delivered':
        return const Color(0xFF22C55E);
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'preparing':
        return Icons.restaurant;
      case 'on_the_way':
        return Icons.delivery_dining;
      case 'delivered':
        return Icons.check_circle;
      default:
        return Icons.receipt;
    }
  }
}

// Bottom Navigation içinde kullanmak için AppBar'sız versiyon
class OrdersScreenContent extends StatefulWidget {
  const OrdersScreenContent({super.key});

  @override
  State<OrdersScreenContent> createState() => _OrdersScreenContentState();
}

class _OrdersScreenContentState extends State<OrdersScreenContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _activeOrders = [
    {
      'id': 'ORD-2024-001',
      'restaurantName': 'Burger King',
      'restaurantImage': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=200',
      'items': ['Whopper Menu', 'Onion Rings'],
      'itemCount': 2,
      'totalPrice': 250.00,
      'status': 'preparing',
      'statusText': 'Hazırlanıyor',
      'estimatedTime': '25-30 dk',
      'orderDate': '14:32',
      'address': 'Levent Mah. Caddebostan Sok. No: 15/4',
    },
    {
      'id': 'ORD-2024-002',
      'restaurantName': 'Pizza Hut',
      'restaurantImage': 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=200',
      'items': ['Pepperoni Pizza (L)', 'Garlic Bread', 'Cola'],
      'itemCount': 3,
      'totalPrice': 385.00,
      'status': 'on_the_way',
      'statusText': 'Yolda',
      'estimatedTime': '10-15 dk',
      'orderDate': '13:45',
      'address': 'Levent Mah. Caddebostan Sok. No: 15/4',
    },
  ];

  final List<Map<String, dynamic>> _completedOrders = [
    {
      'id': 'ORD-2024-098',
      'restaurantName': 'McDonald\'s',
      'restaurantImage': 'https://images.unsplash.com/photo-1586816001966-79b736744398?w=200',
      'items': ['Big Mac Menu', 'McFlurry'],
      'itemCount': 2,
      'totalPrice': 195.00,
      'status': 'delivered',
      'statusText': 'Teslim Edildi',
      'orderDate': '2 Ocak 2024',
      'deliveredTime': '14:45',
      'rating': 4.5,
    },
    {
      'id': 'ORD-2024-095',
      'restaurantName': 'Domino\'s Pizza',
      'restaurantImage': 'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=200',
      'items': ['Margarita Pizza', 'Chicken Wings', 'Sprite'],
      'itemCount': 3,
      'totalPrice': 320.00,
      'status': 'delivered',
      'statusText': 'Teslim Edildi',
      'orderDate': '31 Aralık 2023',
      'deliveredTime': '20:15',
      'rating': 5.0,
    },
    {
      'id': 'ORD-2024-090',
      'restaurantName': 'KFC',
      'restaurantImage': 'https://images.unsplash.com/photo-1626645738196-c2a7c87a8f58?w=200',
      'items': ['Bucket Menu', 'Coleslaw'],
      'itemCount': 2,
      'totalPrice': 275.00,
      'status': 'delivered',
      'statusText': 'Teslim Edildi',
      'orderDate': '28 Aralık 2023',
      'deliveredTime': '19:30',
      'rating': 4.0,
    },
  ];

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Safe area top padding
        SizedBox(height: MediaQuery.of(context).padding.top),

        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          color: isDark ? FoodColors.backgroundDark : Colors.white,
          child: Row(
            children: [
              Text(
                'Siparişlerim',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1C130D),
                ),
              ),
            ],
          ),
        ),

        // Tab bar
        Container(
          color: isDark ? FoodColors.backgroundDark : Colors.white,
          child: TabBar(
            controller: _tabController,
            indicatorColor: FoodColors.primary,
            indicatorWeight: 3,
            labelColor: FoodColors.primary,
            unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
            labelStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Aktif'),
                    if (_activeOrders.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: FoodColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _activeOrders.length.toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Tab(text: 'Geçmiş'),
            ],
          ),
        ),

        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildActiveOrdersList(isDark),
              _buildCompletedOrdersList(isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveOrdersList(bool isDark) {
    if (_activeOrders.isEmpty) {
      return _buildEmptyState(
        isDark,
        icon: Icons.delivery_dining,
        title: 'Aktif sipariş yok',
        subtitle: 'Şu anda devam eden bir siparişiniz bulunmuyor',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activeOrders.length,
      itemBuilder: (context, index) {
        return _buildActiveOrderCard(_activeOrders[index], isDark);
      },
    );
  }

  Widget _buildCompletedOrdersList(bool isDark) {
    if (_completedOrders.isEmpty) {
      return _buildEmptyState(
        isDark,
        icon: Icons.receipt_long,
        title: 'Geçmiş sipariş yok',
        subtitle: 'Henüz tamamlanmış bir siparişiniz bulunmuyor',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _completedOrders.length,
      itemBuilder: (context, index) {
        return _buildCompletedOrderCard(_completedOrders[index], isDark);
      },
    );
  }

  Widget _buildEmptyState(bool isDark, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: isDark
                  ? FoodColors.primary.withValues(alpha: 0.2)
                  : FoodColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 50, color: FoodColors.primary),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1C130D),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveOrderCard(Map<String, dynamic> order, bool isDark) {
    final status = order['status'] as String;
    final statusColor = _getStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? FoodColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Üst kısım - Durum
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    status == 'preparing' ? Icons.restaurant : Icons.delivery_dining,
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order['statusText'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      Text(
                        'Tahmini: ${order['estimatedTime']}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    context.push('/food/order-tracking/${order['id']}');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: statusColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map, size: 16, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Takip Et',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Sipariş bilgileri
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: order['restaurantImage'],
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 56,
                      height: 56,
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 56,
                      height: 56,
                      color: Colors.grey[300],
                      child: const Icon(Icons.restaurant),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order['restaurantName'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1C130D),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${order['itemCount']} ürün • ${order['totalPrice'].toStringAsFixed(0)} TL',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedOrderCard(Map<String, dynamic> order, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? FoodColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: order['restaurantImage'],
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 56,
                      height: 56,
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 56,
                      height: 56,
                      color: Colors.grey[300],
                      child: const Icon(Icons.restaurant),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            order['restaurantName'],
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1C130D),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle, size: 12, color: Color(0xFF22C55E)),
                                SizedBox(width: 4),
                                Text(
                                  'Teslim Edildi',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF22C55E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${order['orderDate']} • ${order['totalPrice'].toStringAsFixed(0)} TL',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (order['rating'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : FoodColors.backgroundLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, size: 16, color: Color(0xFFFACC15)),
                        const SizedBox(width: 4),
                        Text(
                          order['rating'].toString(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF1C130D),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sipariş sepete eklendi'),
                        backgroundColor: FoodColors.primary,
                      ),
                    );
                  },
                  icon: const Icon(Icons.replay, size: 16, color: Colors.white),
                  label: const Text(
                    'Tekrarla',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FoodColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'preparing':
        return const Color(0xFFF59E0B);
      case 'on_the_way':
        return const Color(0xFF3B82F6);
      case 'delivered':
        return const Color(0xFF22C55E);
      default:
        return Colors.grey;
    }
  }
}
