import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../models/car_sales/car_sales_models.dart';
import '../../services/car_sales/car_chat_service.dart';

class CarConversationsScreen extends StatefulWidget {
  const CarConversationsScreen({super.key});

  @override
  State<CarConversationsScreen> createState() => _CarConversationsScreenState();
}

class _CarConversationsScreenState extends State<CarConversationsScreen> {
  final CarChatService _chatService = CarChatService.instance;
  List<Map<String, dynamic>>? _conversations;
  String? _error;

  String? get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _error = null;
    });

    try {
      final conversations = await _chatService.getConversations();

      // Her konuşma için karşı tarafın adını al
      for (var i = 0; i < conversations.length; i++) {
        final conv = conversations[i];
        final isBuyer = conv['buyer_id'] == _currentUserId;
        final otherUserId =
            isBuyer ? conv['seller_id'] : conv['buyer_id'];

        // car_dealers'dan dene
        final dealer = await Supabase.instance.client
            .from('car_dealers')
            .select('owner_name, business_name')
            .eq('user_id', otherUserId as String)
            .maybeSingle();

        if (dealer != null) {
          conversations[i]['_other_name'] =
              dealer['business_name'] ?? dealer['owner_name'] ?? 'Satici';
        } else {
          // user_profiles'dan dene
          final profile = await Supabase.instance.client
              .from('user_profiles')
              .select('full_name')
              .eq('id', otherUserId)
              .maybeSingle();
          conversations[i]['_other_name'] =
              profile?['full_name'] ?? 'Kullanici';
        }
        conversations[i]['_is_buyer'] = isBuyer;
      }

      if (mounted) {
        setState(() {
          _conversations = conversations;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _conversations = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: CarSalesColors.background(isDark),
      appBar: AppBar(
        backgroundColor: CarSalesColors.background(isDark),
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: CarSalesColors.textPrimary(isDark),
          ),
        ),
        title: Text(
          'Arac Mesajlari',
          style: TextStyle(
            color: CarSalesColors.textPrimary(isDark),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_conversations == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: CarSalesColors.textTertiary(isDark)),
            const SizedBox(height: 12),
            Text('Mesajlar yuklenirken hata olustu',
                style:
                    TextStyle(color: CarSalesColors.textSecondary(isDark))),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loadConversations,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    if (_conversations!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                size: 64, color: CarSalesColors.textTertiary(isDark)),
            const SizedBox(height: 16),
            Text(
              'Henuz mesajiniz yok',
              style: TextStyle(
                color: CarSalesColors.textPrimary(isDark),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bir ilana mesaj gonderdiginizde\nkonusmalariniz burada gorunecek.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: CarSalesColors.textSecondary(isDark),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _conversations!.length,
        itemBuilder: (context, index) {
          return _buildConversationTile(
              _conversations![index], isDark);
        },
      ),
    );
  }

  Widget _buildConversationTile(
      Map<String, dynamic> conv, bool isDark) {
    final listing = conv['car_listings'] as Map<String, dynamic>?;
    final isBuyer = conv['_is_buyer'] == true;
    final otherName = conv['_other_name'] as String? ?? 'Kullanici';
    final lastMessage = conv['last_message'] as String?;
    final lastMessageAt = conv['last_message_at'] != null
        ? DateTime.parse(conv['last_message_at'] as String)
        : null;

    final unreadCount = isBuyer
        ? (conv['buyer_unread_count'] as int? ?? 0)
        : (conv['seller_unread_count'] as int? ?? 0);
    final hasUnread = unreadCount > 0;

    final listingImages = listing?['images'] as List?;
    final firstImage =
        listingImages != null && listingImages.isNotEmpty
            ? listingImages.first.toString()
            : null;

    final brandName = listing?['brand_name'] as String? ?? '';
    final modelName = listing?['model_name'] as String? ?? '';
    final year = listing?['year'] as int?;
    final listingTitle = '$brandName $modelName${year != null ? ' ($year)' : ''}';

    return InkWell(
      onTap: () {
        context.push(
          '/car-sales/chat/${conv['id']}',
          extra: listing,
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hasUnread
              ? CarSalesColors.primary.withValues(alpha: 0.04)
              : CarSalesColors.card(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasUnread
                ? CarSalesColors.primary.withValues(alpha: 0.2)
                : CarSalesColors.border(isDark),
          ),
        ),
        child: Row(
          children: [
            // Araç resmi
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: firstImage != null
                  ? CachedNetworkImage(
                      imageUrl: firstImage,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _buildPlaceholder(),
                      errorWidget: (_, __, ___) => _buildPlaceholder(),
                    )
                  : _buildPlaceholder(),
            ),
            const SizedBox(width: 12),
            // İçerik
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          otherName,
                          style: TextStyle(
                            fontWeight: hasUnread
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontSize: 15,
                            color: CarSalesColors.textPrimary(isDark),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (lastMessageAt != null)
                        Text(
                          _formatTime(lastMessageAt),
                          style: TextStyle(
                            color: hasUnread
                                ? CarSalesColors.primary
                                : CarSalesColors.textTertiary(isDark),
                            fontSize: 12,
                            fontWeight: hasUnread
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Son mesaj
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage ?? '',
                          style: TextStyle(
                            color: hasUnread
                                ? CarSalesColors.textPrimary(isDark)
                                : CarSalesColors.textSecondary(isDark),
                            fontSize: 13,
                            fontWeight: hasUnread
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: CarSalesColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  // İlan bilgisi
                  const SizedBox(height: 6),
                  Text(
                    listingTitle,
                    style: TextStyle(
                      color: CarSalesColors.textTertiary(isDark),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.directions_car, color: Colors.grey[400], size: 28),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('d.M.y').format(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}g';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}s';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}dk';
    } else {
      return 'Simdi';
    }
  }
}
