import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../core/theme.dart';
import '../../core/services/notification_sound_service.dart';
import '../../shared/widgets/floating_ai_assistant.dart';

class AppShell extends StatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _isCollapsed = false;
  String? _companyName;
  String? _companyId;

  // Realtime subscription for new bookings
  RealtimeChannel? _bookingChannel;
  // Realtime subscription for new reviews
  RealtimeChannel? _reviewChannel;
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _pendingBookingsCount = 0;
  bool _hasNewBooking = false;
  int _newReviewsCount = 0;
  bool _hasNewReview = false;

  @override
  void initState() {
    super.initState();
    _loadCompanyInfo();
  }

  Future<void> _loadCompanyInfo() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final response = await Supabase.instance.client
        .from('rental_companies')
        .select('company_name, id')
        .eq('owner_user_id', user.id)
        .maybeSingle();

    if (mounted && response != null) {
      setState(() {
        _companyName = response['company_name'] as String?;
        _companyId = response['id'] as String?;
      });

      // Company ID alındıktan sonra realtime subscription başlat
      if (_companyId != null) {
        _setupBookingSubscription();
        _setupReviewSubscription();
        _loadPendingBookingsCount();
      }
    }
  }

  /// Bekleyen rezervasyon sayısını yükle
  Future<void> _loadPendingBookingsCount() async {
    if (_companyId == null) return;

    try {
      final response = await Supabase.instance.client
          .from('rental_bookings')
          .select('id')
          .eq('company_id', _companyId!)
          .eq('status', 'pending');

      if (mounted) {
        setState(() {
          _pendingBookingsCount = (response as List).length;
        });
      }
    } catch (e) {
      debugPrint('Error loading pending bookings count: $e');
    }
  }

  /// Yeni rezervasyonlar için realtime subscription
  void _setupBookingSubscription() {
    if (_companyId == null) return;

    _bookingChannel = Supabase.instance.client
        .channel('booking_notifications_${_companyId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'rental_bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'company_id',
            value: _companyId!,
          ),
          callback: (payload) {
            debugPrint('New booking received: ${payload.newRecord}');
            _onNewBookingReceived(payload.newRecord);
          },
        )
        .subscribe();
  }

  /// Yeni yorumlar için realtime subscription (notifications tablosu üzerinden)
  void _setupReviewSubscription() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _reviewChannel = Supabase.instance.client
        .channel('review_notifications_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final type = payload.newRecord['type'] as String?;
            if (type == 'rental_review_received') {
              _onNewReviewReceived(payload.newRecord);
            }
          },
        )
        .subscribe();
  }

  /// Yeni yorum geldiğinde
  void _onNewReviewReceived(Map<String, dynamic> notification) {
    if (!mounted) return;

    _playNotificationSound();

    setState(() {
      _newReviewsCount++;
      _hasNewReview = true;
    });

    final body = notification['body'] as String? ?? 'Yeni bir yorum aldınız';
    final title = notification['title'] as String? ?? 'Yeni Müşteri Yorumu!';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.star, color: Colors.amber),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    body,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.amber.shade800,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'GÖRÜNTÜLE',
          textColor: Colors.white,
          onPressed: () {
            context.go('/reviews');
          },
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _hasNewReview = false;
        });
      }
    });
  }

  /// Yeni rezervasyon geldiğinde
  void _onNewBookingReceived(Map<String, dynamic> booking) {
    if (!mounted) return;

    // Bildirim sesini çal
    _playNotificationSound();

    // State güncelle
    setState(() {
      _pendingBookingsCount++;
      _hasNewBooking = true;
    });

    // Snackbar göster
    final customerName = booking['customer_name'] ?? 'Müşteri';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Yeni Rezervasyon Talebi!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$customerName yeni bir rezervasyon talebi gönderdi',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'GÖRÜNTÜLE',
          textColor: Colors.white,
          onPressed: () {
            context.go('/bookings');
          },
        ),
      ),
    );

    // 3 saniye sonra animasyonu kaldır
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _hasNewBooking = false;
        });
      }
    });
  }

  /// Bildirim sesini çal
  Future<void> _playNotificationSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
    } catch (e) {
      debugPrint('Error playing notification sound: $e');
      // Ses dosyası yoksa URL'den çal
      try {
        await _audioPlayer.play(UrlSource(
          'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3',
        ));
      } catch (e2) {
        debugPrint('Error playing fallback sound: $e2');
      }
    }
  }

  @override
  void dispose() {
    _bookingChannel?.unsubscribe();
    _reviewChannel?.unsubscribe();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).matchedLocation;

    return Stack(
      children: [
        Scaffold(
          body: Row(
            children: [
              // Sidebar
              AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isCollapsed ? 70 : 260,
            child: Container(
              color: AppColors.surface,
              child: Column(
                children: [
                  // Header
                  Container(
                    height: 70,
                    padding: EdgeInsets.symmetric(
                      horizontal: _isCollapsed ? 12 : 20,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.secondary],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.car_rental,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        if (!_isCollapsed) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _companyName ?? 'Rent a Car',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Text(
                                  'Yönetim Paneli',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // Menu items
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        _buildMenuItem(
                          icon: Icons.dashboard_outlined,
                          activeIcon: Icons.dashboard,
                          label: 'Dashboard',
                          path: '/dashboard',
                          currentPath: currentPath,
                        ),
                        _buildMenuItem(
                          icon: Icons.directions_car_outlined,
                          activeIcon: Icons.directions_car,
                          label: 'Araçlar',
                          path: '/cars',
                          currentPath: currentPath,
                        ),
                        _buildMenuItem(
                          icon: Icons.book_outlined,
                          activeIcon: Icons.book,
                          label: 'Rezervasyonlar',
                          path: '/bookings',
                          currentPath: currentPath,
                          badgeCount: _pendingBookingsCount,
                          showPulse: _hasNewBooking,
                        ),
                        _buildMenuItem(
                          icon: Icons.calendar_month_outlined,
                          activeIcon: Icons.calendar_month,
                          label: 'Takvim',
                          path: '/calendar',
                          currentPath: currentPath,
                        ),
                        _buildMenuItem(
                          icon: Icons.location_on_outlined,
                          activeIcon: Icons.location_on,
                          label: 'Lokasyonlar',
                          path: '/locations',
                          currentPath: currentPath,
                        ),
                        _buildMenuItem(
                          icon: Icons.account_balance_wallet_outlined,
                          activeIcon: Icons.account_balance_wallet,
                          label: 'Finans',
                          path: '/finance',
                          currentPath: currentPath,
                        ),
                        _buildMenuItem(
                          icon: Icons.star_outline,
                          activeIcon: Icons.star,
                          label: 'Yorumlar',
                          path: '/reviews',
                          currentPath: currentPath,
                          badgeCount: _newReviewsCount,
                          showPulse: _hasNewReview,
                        ),
                        _buildMenuItem(
                          icon: Icons.inventory_2_outlined,
                          activeIcon: Icons.inventory_2,
                          label: 'Paketler',
                          path: '/packages',
                          currentPath: currentPath,
                        ),
                        _buildMenuItem(
                          icon: Icons.build_outlined,
                          activeIcon: Icons.build,
                          label: 'Ek Hizmetler',
                          path: '/services',
                          currentPath: currentPath,
                        ),

                        const SizedBox(height: 16),
                        if (!_isCollapsed)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              'AYARLAR',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),

                        _buildMenuItem(
                          icon: Icons.settings_outlined,
                          activeIcon: Icons.settings,
                          label: 'Ayarlar',
                          path: '/settings',
                          currentPath: currentPath,
                        ),
                      ],
                    ),
                  ),

                  // Collapse button & Logout
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        // Collapse toggle
                        ListTile(
                          dense: true,
                          leading: Icon(
                            _isCollapsed
                                ? Icons.chevron_right
                                : Icons.chevron_left,
                            color: AppColors.textMuted,
                          ),
                          title: _isCollapsed
                              ? null
                              : const Text(
                                  'Daralt',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 13,
                                  ),
                                ),
                          onTap: () {
                            setState(() {
                              _isCollapsed = !_isCollapsed;
                            });
                          },
                        ),

                        // Logout
                        ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.logout,
                            color: AppColors.error,
                          ),
                          title: _isCollapsed
                              ? null
                              : const Text(
                                  'Çıkış Yap',
                                  style: TextStyle(
                                    color: AppColors.error,
                                    fontSize: 13,
                                  ),
                                ),
                          onTap: () => _logout(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main content
          Expanded(
            child: widget.child,
          ),
        ],
      ),
    ),
    // Floating AI Assistant
    const FloatingAIAssistant(),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required String path,
    required String currentPath,
    int badgeCount = 0,
    bool showPulse = false,
  }) {
    final isActive = currentPath.startsWith(path);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _isCollapsed ? 8 : 12,
        vertical: 2,
      ),
      child: Material(
        color: isActive
            ? AppColors.primary.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            NotificationSoundService.initializeAudio();
            context.go(path);
            // Rezervasyonlar sayfasına gidildiğinde sayacı güncelle
            if (path == '/bookings') {
              _loadPendingBookingsCount();
            }
            // Yorumlar sayfasına gidildiğinde sayacı sıfırla
            if (path == '/reviews') {
              setState(() {
                _newReviewsCount = 0;
              });
            }
          },
          child: Container(
            height: 44,
            padding: EdgeInsets.symmetric(
              horizontal: _isCollapsed ? 12 : 16,
            ),
            child: Row(
              children: [
                // Icon with badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: showPulse
                          ? BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.warning.withValues(alpha: 0.6),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            )
                          : null,
                      child: Icon(
                        isActive ? activeIcon : icon,
                        color: isActive ? AppColors.primary : AppColors.textSecondary,
                        size: 22,
                      ),
                    ),
                    // Badge (sadece collapsed modda veya her zaman icon üzerinde)
                    if (badgeCount > 0 && _isCollapsed)
                      Positioned(
                        right: -6,
                        top: -4,
                        child: _buildBadge(badgeCount, showPulse),
                      ),
                  ],
                ),
                if (!_isCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color:
                            isActive ? AppColors.primary : AppColors.textSecondary,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  // Badge (expanded modda sağda)
                  if (badgeCount > 0) _buildBadge(badgeCount, showPulse),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(int count, bool pulse) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: pulse ? AppColors.warning : AppColors.error,
        borderRadius: BorderRadius.circular(10),
        boxShadow: pulse
            ? [
                BoxShadow(
                  color: AppColors.warning.withValues(alpha: 0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Çıkış yapmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        context.go('/login');
      }
    }
  }
}
