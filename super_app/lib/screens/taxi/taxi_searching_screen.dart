import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/taxi/taxi_models.dart';
import '../../core/services/taxi_service.dart';
import '../../core/utils/app_dialogs.dart';
import 'taxi_ride_screen.dart';

class TaxiSearchingScreen extends ConsumerStatefulWidget {
  final TaxiLocation pickup;
  final TaxiLocation dropoff;
  final VehicleType vehicleType;
  final double fare;
  final double distanceKm;
  final int durationMinutes;
  final TaxiRide? existingRide;

  const TaxiSearchingScreen({
    super.key,
    required this.pickup,
    required this.dropoff,
    required this.vehicleType,
    required this.fare,
    required this.distanceKm,
    required this.durationMinutes,
    this.existingRide,
  });

  @override
  ConsumerState<TaxiSearchingScreen> createState() =>
      _TaxiSearchingScreenState();
}

class _TaxiSearchingScreenState extends ConsumerState<TaxiSearchingScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late AnimationController _fadeController;
  late AnimationController _carController;

  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _fadeAnimation;

  // State
  bool _isSearching = true;
  bool _isCancelling = false;
  String _statusText = 'Sürücü aranıyor...';
  TaxiRide? _ride;
  StreamSubscription? _rideSubscription;

  // Search timer
  int _searchSeconds = 0;
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _rotateController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    _carController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rotateAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(_rotateController);

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _startSearchTimer();

    if (widget.existingRide != null) {
      _ride = widget.existingRide;
      if (mounted) {
        _subscribeToRide(_ride!.id);
      }
    } else {
      _createRide();
    }
  }

  @override
  void dispose() {
    // Timer'ları iptal et
    _searchTimer?.cancel();
    _searchTimer = null;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _rideSubscription?.cancel();
    _rideSubscription = null;

    // Realtime channel'ı güvenli şekilde kapat
    if (_realtimeChannel != null) {
      try {
        final channel = _realtimeChannel;
        _realtimeChannel = null;
        if (channel is RealtimeChannel) {
          channel.unsubscribe();
        }
      } catch (e) {
        debugPrint('Dispose unsubscribe error: $e');
      }
    }

    // Animation controller'ları dispose et
    _pulseController.dispose();
    _rotateController.dispose();
    _fadeController.dispose();
    _carController.dispose();

    super.dispose();
  }

  dynamic _realtimeChannel;

  void _startSearchTimer() {
    _searchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !_isCancelling) {
        setState(() {
          _searchSeconds++;
          if (_searchSeconds % 5 == 0) {
            _updateSearchStatus();
          }
        });
      } else if (_isCancelling) {
        timer.cancel();
      }
    });
  }

  void _updateSearchStatus() {
    final messages = [
      'Yakındaki sürücüler aranıyor...',
      'En uygun sürücü seçiliyor...',
      'Sürücülere bildirim gönderiliyor...',
      'Cevap bekleniyor...',
    ];

    final index = (_searchSeconds ~/ 5) % messages.length;
    setState(() => _statusText = messages[index]);
  }

  Future<void> _createRide() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        _showError('Oturum açmanız gerekiyor');
        return;
      }

      // Create ride request
      final rideData = await TaxiService.createRide(
        pickupLat: widget.pickup.latitude,
        pickupLng: widget.pickup.longitude,
        pickupAddress: widget.pickup.address,
        dropoffLat: widget.dropoff.latitude,
        dropoffLng: widget.dropoff.longitude,
        dropoffAddress: widget.dropoff.address,
        vehicleTypeId: widget.vehicleType.id,
        estimatedFare: widget.fare,
        distanceKm: widget.distanceKm,
        durationMinutes: widget.durationMinutes,
      );

      if (mounted) {
        final ride = TaxiRide.fromJson(rideData);
        setState(() => _ride = ride);
        _subscribeToRide(ride.id);
      }
    } catch (e) {
      _showError('Sürüş talebi oluşturulamadı: $e');
    }
  }

  void _subscribeToRide(String rideId) {
    // Realtime subscription
    final channel = TaxiService.subscribeToRide(rideId, (rideData) async {
      debugPrint('Realtime update received for ride: $rideId');
      await _checkRideStatus(rideId);
    });

    // Store channel for cleanup
    _realtimeChannel = channel;

    // Also start polling as backup (every 3 seconds)
    _startPolling(rideId);
  }

  Timer? _pollingTimer;

  void _startPolling(String rideId) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted || _isCancelling) {
        timer.cancel();
        return;
      }
      await _checkRideStatus(rideId);
    });
  }

  Future<void> _checkRideStatus(String rideId) async {
    if (!mounted) return;

    final fullRideData = await TaxiService.getRide(rideId);
    if (fullRideData == null || !mounted) return;

    final ride = TaxiRide.fromJson(fullRideData);
    debugPrint(
      'Polling check - status: ${ride.status}, driver_id: ${ride.driverId}',
    );

    // Only update if status changed
    // İptal ediliyor ise güncelleme yapma
    if (_isCancelling) return;

    if (_ride?.status != ride.status) {
      if (mounted) {
        setState(() => _ride = ride);
      }

      switch (ride.status) {
        case RideStatus.accepted:
          _pollingTimer?.cancel();
          _onDriverFound(ride);
          break;
        case RideStatus.cancelled:
          _pollingTimer?.cancel();
          _onRideCancelled();
          break;
        default:
          break;
      }
    }
  }

  void _onDriverFound(TaxiRide ride) {
    if (_isCancelling) return;

    _searchTimer?.cancel();
    if (mounted) {
      setState(() {
        _isSearching = false;
        _statusText = 'Sürücü bulundu!';
      });
    }

    // Navigate to ride screen
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_isCancelling) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                TaxiRideScreen(ride: ride),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  void _onRideCancelled() {
    if (_isCancelling) return;

    _searchTimer?.cancel();
    if (mounted) {
      setState(() {
        _isSearching = false;
        _statusText = 'Sürüş iptal edildi';
      });
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_isCancelling) Navigator.pop(context);
    });
  }

  Future<void> _cancelRide() async {
    // Çift tıklama koruması
    if (_isCancelling) return;

    if (_ride == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sürüşü İptal Et'),
        content: const Text(
          'Sürüş talebinizi iptal etmek istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hayır'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Evet, İptal Et'),
          ),
        ],
      ),
    );

    if (confirm == true && _ride != null && mounted) {
      setState(() => _isCancelling = true);

      // Önce timer'ları durdur
      _searchTimer?.cancel();
      _searchTimer = null;
      _pollingTimer?.cancel();
      _pollingTimer = null;

      // Realtime subscription'ı güvenli şekilde kapat
      if (_realtimeChannel != null) {
        try {
          final channel = _realtimeChannel;
          _realtimeChannel = null;
          if (channel is RealtimeChannel) {
            await channel.unsubscribe();
          }
        } catch (e) {
          debugPrint('Unsubscribe error: $e');
        }
      }

      // Ride'ı iptal et
      try {
        await TaxiService.cancelRide(_ride!.id, reason: 'user_cancelled');
      } catch (e) {
        debugPrint('Cancel ride error: $e');
        // Hata olsa bile çık, çünkü kullanıcı iptal etmek istiyor
      }

      // Güvenli bir şekilde geri dön
      if (mounted) {
        // WidgetsBinding ile bir sonraki frame'de çık
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    }
  }

  Future<void> _showError(String message) async {
    if (!mounted) return;
    await AppDialogs.showError(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Header
              _buildHeader(theme, colorScheme),

              // Main content
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Pulse animation
                      _buildPulseAnimation(colorScheme),

                      const SizedBox(height: 48),

                      // Status text
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _statusText,
                          key: ValueKey(_statusText),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Timer
                      if (_isSearching)
                        Text(
                          _formatTime(_searchSeconds),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),

                      // Driver found animation
                      if (!_isSearching && _ride?.driver != null)
                        _buildDriverFoundCard(theme, colorScheme),
                    ],
                  ),
                ),
              ),

              // Bottom info
              _buildBottomInfo(theme, colorScheme),

              // Cancel button
              if (_isSearching)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: _buildCancelButton(theme, colorScheme),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.vehicleType.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              widget.vehicleType.icon,
              color: widget.vehicleType.color,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.vehicleType.displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${widget.distanceKm.toStringAsFixed(1)} km - ${widget.durationMinutes} dk',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${widget.fare.toStringAsFixed(2)} TL',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulseAnimation(ColorScheme colorScheme) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulse rings
          ...List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final delay = index * 0.3;
                final value = ((_pulseController.value + delay) % 1.0);
                final scale = 0.5 + (value * 0.8);
                final opacity = (1.0 - value).clamp(0.0, 0.5);

                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.vehicleType.color.withValues(
                          alpha: opacity,
                        ),
                        width: 3,
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          // Rotating dots
          AnimatedBuilder(
            animation: _rotateController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotateAnimation.value,
                child: child,
              );
            },
            child: SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                children: List.generate(8, (index) {
                  final angle = (index / 8) * 2 * math.pi;
                  return Positioned(
                    left: 80 + 70 * math.cos(angle) - 5,
                    top: 80 + 70 * math.sin(angle) - 5,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: widget.vehicleType.color.withValues(
                          alpha: 0.3 + (index / 8) * 0.7,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          // Center icon
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isSearching ? _pulseAnimation.value : 1.0,
                child: child,
              );
            },
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: widget.vehicleType.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.vehicleType.color.withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                _isSearching ? Icons.search_rounded : Icons.check_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),

          // Animated car
          if (_isSearching)
            AnimatedBuilder(
              animation: _carController,
              builder: (context, child) {
                final angle = _carController.value * 2 * math.pi;
                return Positioned(
                  left: 100 + 90 * math.cos(angle) - 16,
                  top: 100 + 90 * math.sin(angle) - 16,
                  child: Transform.rotate(
                    angle: angle + math.pi / 2,
                    child: Icon(
                      Icons.local_taxi_rounded,
                      color: widget.vehicleType.color,
                      size: 32,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDriverFoundCard(ThemeData theme, ColorScheme colorScheme) {
    final driver = _ride!.driver!;

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: widget.vehicleType.color.withValues(alpha: 0.2),
            backgroundImage: driver.avatarUrl != null
                ? NetworkImage(driver.avatarUrl!)
                : null,
            child: driver.avatarUrl == null
                ? Icon(
                    Icons.person_rounded,
                    color: widget.vehicleType.color,
                    size: 32,
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                driver.fullName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  if (driver.isNewDriver) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Yeni Sürücü',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ] else ...[
                    Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      driver.rating.toStringAsFixed(1),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(width: 8),
                  Text(
                    driver.vehicleInfo,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomInfo(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildLocationRow(
            icon: Icons.circle,
            iconColor: Colors.green,
            title: 'Alış',
            address: widget.pickup.address,
            theme: theme,
            colorScheme: colorScheme,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Container(
              width: 2,
              height: 24,
              color: colorScheme.outlineVariant,
            ),
          ),
          _buildLocationRow(
            icon: Icons.square_rounded,
            iconColor: widget.vehicleType.color,
            title: 'Varış',
            address: widget.dropoff.address,
            theme: theme,
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String address,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 12),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                address,
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCancelButton(ThemeData theme, ColorScheme colorScheme) {
    return TextButton(
      onPressed: _isCancelling ? null : _cancelRide,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: _isCancelling ? colorScheme.outlineVariant : colorScheme.outline,
          ),
        ),
      ),
      child: _isCancelling
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.error,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'İptal Ediliyor...',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          : Text(
              'Aramayı İptal Et',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

class AnimatedBuilder extends StatelessWidget {
  final Animation<double> animation;
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required this.animation,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder2(
      animation: animation,
      builder: builder,
      child: child,
    );
  }
}

class AnimatedBuilder2 extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const AnimatedBuilder2({
    super.key,
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
