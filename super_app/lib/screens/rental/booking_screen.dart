import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/rental/rental_models.dart';
import '../../services/rental_service.dart';
import '../../core/services/rental_service.dart' as core_rental;

// Booking screen theme colors - Light theme for better readability
class _BookingColors {
  static const Color primary = Color(0xFF256AF4);
  static const Color primaryLight = Color(0xFF5B8DEF);
  static const Color background = Color(0xFFF8F9FC);
  static const Color cardBg = Colors.white;
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
}

class BookingScreen extends StatefulWidget {
  final RentalCar car;
  final RentalLocation? initialPickupLocation;
  final RentalLocation? initialDropoffLocation;
  final DateTime? initialPickupDate;
  final DateTime? initialDropoffDate;
  // Özel adres bilgileri (rental_home_screen'den gelen)
  final bool initialIsPickupCustomAddress;
  final bool initialIsDropoffCustomAddress;
  final String? initialPickupCustomAddress;
  final String? initialDropoffCustomAddress;
  final String? initialPickupCustomAddressNote;
  final String? initialDropoffCustomAddressNote;

  const BookingScreen({
    super.key,
    required this.car,
    this.initialPickupLocation,
    this.initialDropoffLocation,
    this.initialPickupDate,
    this.initialDropoffDate,
    this.initialIsPickupCustomAddress = false,
    this.initialIsDropoffCustomAddress = false,
    this.initialPickupCustomAddress,
    this.initialDropoffCustomAddress,
    this.initialPickupCustomAddressNote,
    this.initialDropoffCustomAddressNote,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  int _currentStep = 0;
  RentalLocation? _pickupLocation;
  RentalLocation? _dropoffLocation;
  DateTime? _pickupDate;
  DateTime? _dropoffDate;
  TimeOfDay? _pickupTime;
  TimeOfDay? _dropoffTime;
  RentalPackage _selectedPackage = RentalPackage.packages[1]; // Comfort default
  final Set<String> _selectedServices = {};
  bool _sameDropoffLocation = true;
  bool _agreeTerms = false;
  bool _isLoadingLocations = true;

  // Custom address delivery
  bool _isPickupCustomAddress = false;
  bool _isDropoffCustomAddress = false;
  final TextEditingController _pickupCustomAddressController = TextEditingController();
  final TextEditingController _pickupCustomAddressNotesController = TextEditingController();
  final TextEditingController _dropoffCustomAddressController = TextEditingController();
  final TextEditingController _dropoffCustomAddressNotesController = TextEditingController();

  List<RentalLocation> _locations = [];

  @override
  void initState() {
    super.initState();

    // Lokasyonları yükle
    _loadLocations();

    // Tarih ve saat değerlerini ayarla
    _pickupDate = widget.initialPickupDate ?? DateTime.now().add(const Duration(days: 1));
    _dropoffDate = widget.initialDropoffDate ?? DateTime.now().add(const Duration(days: 4));
    _pickupTime = const TimeOfDay(hour: 10, minute: 0);
    _dropoffTime = const TimeOfDay(hour: 10, minute: 0);

    _mainController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.2, 1, curve: Curves.easeOutCubic),
      ),
    );

    _mainController.forward();
  }

  Future<void> _loadLocations() async {
    try {
      final locations = await core_rental.RentalService.getLocations();
      if (mounted) {
        setState(() {
          _locations = locations.isNotEmpty ? locations : RentalDemoData.locations;

          // Ana ekrandan gelen özel adres bilgilerini kullan
          _isPickupCustomAddress = widget.initialIsPickupCustomAddress;
          _isDropoffCustomAddress = widget.initialIsDropoffCustomAddress;

          if (widget.initialIsPickupCustomAddress && widget.initialPickupCustomAddress != null) {
            _pickupCustomAddressController.text = widget.initialPickupCustomAddress!;
            if (widget.initialPickupCustomAddressNote != null) {
              _pickupCustomAddressNotesController.text = widget.initialPickupCustomAddressNote!;
            }
            _pickupLocation = null;
          } else {
            _pickupLocation = widget.initialPickupLocation ?? _locations.first;
          }

          if (widget.initialIsDropoffCustomAddress && widget.initialDropoffCustomAddress != null) {
            _dropoffCustomAddressController.text = widget.initialDropoffCustomAddress!;
            if (widget.initialDropoffCustomAddressNote != null) {
              _dropoffCustomAddressNotesController.text = widget.initialDropoffCustomAddressNote!;
            }
            _dropoffLocation = null;
          } else {
            _dropoffLocation = widget.initialDropoffLocation ?? _locations.first;
          }

          // Aynı lokasyon mu kontrol et (sadece her ikisi de özel adres değilse)
          if (!_isPickupCustomAddress && !_isDropoffCustomAddress) {
            _sameDropoffLocation = _pickupLocation?.id == _dropoffLocation?.id;
          } else {
            _sameDropoffLocation = false;
          }
          _isLoadingLocations = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading locations: $e');
      if (mounted) {
        setState(() {
          _locations = RentalDemoData.locations;

          // Hata durumunda da özel adres bilgilerini kullan
          _isPickupCustomAddress = widget.initialIsPickupCustomAddress;
          _isDropoffCustomAddress = widget.initialIsDropoffCustomAddress;

          if (widget.initialIsPickupCustomAddress && widget.initialPickupCustomAddress != null) {
            _pickupCustomAddressController.text = widget.initialPickupCustomAddress!;
            if (widget.initialPickupCustomAddressNote != null) {
              _pickupCustomAddressNotesController.text = widget.initialPickupCustomAddressNote!;
            }
            _pickupLocation = null;
          } else {
            _pickupLocation = widget.initialPickupLocation ?? _locations.first;
          }

          if (widget.initialIsDropoffCustomAddress && widget.initialDropoffCustomAddress != null) {
            _dropoffCustomAddressController.text = widget.initialDropoffCustomAddress!;
            if (widget.initialDropoffCustomAddressNote != null) {
              _dropoffCustomAddressNotesController.text = widget.initialDropoffCustomAddressNote!;
            }
            _dropoffLocation = null;
          } else {
            _dropoffLocation = widget.initialDropoffLocation ?? _locations.first;
          }

          if (!_isPickupCustomAddress && !_isDropoffCustomAddress) {
            _sameDropoffLocation = _pickupLocation?.id == _dropoffLocation?.id;
          } else {
            _sameDropoffLocation = false;
          }
          _isLoadingLocations = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pickupCustomAddressController.dispose();
    _pickupCustomAddressNotesController.dispose();
    _dropoffCustomAddressController.dispose();
    _dropoffCustomAddressNotesController.dispose();
    super.dispose();
  }

  int get _rentalDays {
    if (_pickupDate == null || _dropoffDate == null) return 1;
    return _dropoffDate!.difference(_pickupDate!).inDays;
  }

  double get _carDailyPrice => widget.car.discountedDailyPrice;

  double get _carTotalPrice => _carDailyPrice * _rentalDays;

  double get _packagePrice =>
      _carTotalPrice * (_selectedPackage.priceMultiplier - 1);

  double get _servicesPrice {
    double total = 0;
    for (final serviceId in _selectedServices) {
      final service =
          AdditionalService.services.firstWhere((s) => s.id == serviceId);
      total += service.dailyPrice * _rentalDays;
    }
    return total;
  }

  double get _totalPrice => _carTotalPrice + _packagePrice + _servicesPrice;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _BookingColors.background,
      body: Stack(
        children: [
          // Background
          _buildBackground(),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                // App Bar
                _buildAppBar(),

                // Progress Indicator
                _buildProgressIndicator(),

                // Content
                Expanded(
                  child: AnimatedBuilder(
                    animation: _mainController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _slideAnimation.value),
                        child: Opacity(
                          opacity: _fadeAnimation.value,
                          child: _buildCurrentStep(),
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Navigation
                _buildBottomNavigation(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      color: _BookingColors.background,
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (_currentStep > 0) {
                _previousStep();
              } else {
                Navigator.pop(context);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _BookingColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _BookingColors.border),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: _BookingColors.textPrimary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rezervasyon',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _BookingColors.textPrimary,
                  ),
                ),
                Text(
                  widget.car.fullName,
                  style: TextStyle(
                    fontSize: 14,
                    color: _BookingColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final steps = ['Tarih & Konum', 'Paket', 'Ek Hizmetler', 'Onay'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: List.generate(steps.length, (index) {
          final isActive = index <= _currentStep;
          final isCompleted = index < _currentStep;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: isActive
                              ? const LinearGradient(
                                  colors: [
                                    _BookingColors.primary,
                                    _BookingColors.primaryLight
                                  ],
                                )
                              : null,
                          color: isActive ? null : _BookingColors.border,
                          shape: BoxShape.circle,
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: _BookingColors.primary
                                        .withValues(alpha: 0.3),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: isCompleted
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 18)
                              : Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isActive ? Colors.white : _BookingColors.textSecondary,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        steps[index],
                        style: TextStyle(
                          fontSize: 10,
                          color: isActive ? _BookingColors.primary : _BookingColors.textSecondary,
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                if (index < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        gradient: index < _currentStep
                            ? const LinearGradient(
                                colors: [_BookingColors.primary, _BookingColors.primaryLight],
                              )
                            : null,
                        color: index < _currentStep
                            ? null
                            : _BookingColors.border,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildDateLocationStep();
      case 1:
        return _buildPackageStep();
      case 2:
        return _buildServicesStep();
      case 3:
        return _buildConfirmationStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildDateLocationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pickup Location
          _buildSectionTitle('Alış Noktası'),
          const SizedBox(height: 12),
          _buildLocationSelector(
            value: _pickupLocation,
            onChanged: (location) {
              setState(() {
                _pickupLocation = location;
                if (_sameDropoffLocation) {
                  _dropoffLocation = location;
                }
              });
            },
            isPickup: true,
          ),

          const SizedBox(height: 24),

          // Same Location Toggle
          GestureDetector(
            onTap: () {
              setState(() {
                _sameDropoffLocation = !_sameDropoffLocation;
                if (_sameDropoffLocation) {
                  _dropoffLocation = _pickupLocation;
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _BookingColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _sameDropoffLocation ? _BookingColors.primary : _BookingColors.border,
                ),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      gradient: _sameDropoffLocation
                          ? const LinearGradient(
                              colors: [_BookingColors.primary, _BookingColors.primaryLight],
                            )
                          : null,
                      color: _sameDropoffLocation
                          ? null
                          : _BookingColors.border,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: _sameDropoffLocation
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Aynı noktaya teslim et',
                    style: TextStyle(
                      color: _BookingColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Different Dropoff Location
          if (!_sameDropoffLocation) ...[
            const SizedBox(height: 24),
            _buildSectionTitle('Teslim Noktası'),
            const SizedBox(height: 12),
            _buildLocationSelector(
              value: _dropoffLocation,
              onChanged: (location) {
                setState(() => _dropoffLocation = location);
              },
              isPickup: false,
            ),
          ],

          const SizedBox(height: 32),

          // Date & Time Selection
          _buildSectionTitle('Tarih ve Saat'),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildDateTimeCard(
                  title: 'Alış',
                  date: _pickupDate,
                  time: _pickupTime,
                  onDateTap: () => _selectDate(true),
                  onTimeTap: () => _selectTime(true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDateTimeCard(
                  title: 'Teslim',
                  date: _dropoffDate,
                  time: _dropoffTime,
                  onDateTap: () => _selectDate(false),
                  onTimeTap: () => _selectTime(false),
                ),
              ),
            ],
          ),

          if (_pickupDate != null && _dropoffDate != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _BookingColors.primary.withValues(alpha: 0.1),
                    _BookingColors.primaryLight.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _BookingColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today,
                      color: _BookingColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Toplam $_rentalDays gün kiralama',
                    style: const TextStyle(
                      color: _BookingColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: _BookingColors.textPrimary,
      ),
    );
  }

  Widget _buildLocationSelector({
    required RentalLocation? value,
    required ValueChanged<RentalLocation> onChanged,
    required bool isPickup,
  }) {
    final isCustomAddress = isPickup ? _isPickupCustomAddress : _isDropoffCustomAddress;
    final addressController = isPickup ? _pickupCustomAddressController : _dropoffCustomAddressController;
    final notesController = isPickup ? _pickupCustomAddressNotesController : _dropoffCustomAddressNotesController;

    return Column(
      children: [
        // Standard locations
        Container(
          decoration: BoxDecoration(
            color: _BookingColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _BookingColors.border,
            ),
          ),
          child: Column(
            children: _locations.map((location) {
              final isSelected = !isCustomAddress && value?.id == location.id;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isPickup) {
                      _isPickupCustomAddress = false;
                    } else {
                      _isDropoffCustomAddress = false;
                    }
                  });
                  onChanged(location);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _BookingColors.primary.withValues(alpha: 0.1)
                        : Colors.transparent,
                    border: Border(
                      bottom: BorderSide(
                        color: location != _locations.last
                            ? _BookingColors.border
                            : Colors.transparent,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: location.isAirport
                              ? const Color(0xFF1E88E5).withValues(alpha: 0.15)
                              : const Color(0xFF4CAF50).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          location.isAirport ? Icons.flight : Icons.location_on,
                          color: location.isAirport
                              ? const Color(0xFF1E88E5)
                              : const Color(0xFF4CAF50),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              location.name,
                              style: TextStyle(
                                color: _BookingColors.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              location.workingHours,
                              style: TextStyle(
                                fontSize: 12,
                                color: _BookingColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_BookingColors.primary, _BookingColors.primaryLight],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child:
                              const Icon(Icons.check, color: Colors.white, size: 16),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 12),

        // Custom Address Option
        GestureDetector(
          onTap: () {
            setState(() {
              if (isPickup) {
                _isPickupCustomAddress = !_isPickupCustomAddress;
              } else {
                _isDropoffCustomAddress = !_isDropoffCustomAddress;
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _BookingColors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCustomAddress ? _BookingColors.primary : _BookingColors.border,
                width: isCustomAddress ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.home,
                    color: Color(0xFFFF9800),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Adrese Teslim',
                        style: TextStyle(
                          color: _BookingColors.textPrimary,
                          fontWeight: isCustomAddress ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Aracı istediğiniz adrese teslim edelim',
                        style: TextStyle(
                          fontSize: 12,
                          color: _BookingColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCustomAddress)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_BookingColors.primary, _BookingColors.primaryLight],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 16),
                  ),
              ],
            ),
          ),
        ),

        // Custom Address Input Fields
        if (isCustomAddress) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _BookingColors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _BookingColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: addressController,
                  decoration: InputDecoration(
                    labelText: 'Adres *',
                    hintText: 'Örn: Atatürk Cad. No:123, Kadıköy',
                    prefixIcon: const Icon(Icons.location_on_outlined, color: _BookingColors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _BookingColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _BookingColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _BookingColors.primary, width: 2),
                    ),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(
                    labelText: 'Adres Tarifi (Opsiyonel)',
                    hintText: 'Örn: Kapı kodu 1234, 3. kat',
                    prefixIcon: const Icon(Icons.notes_outlined, color: _BookingColors.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _BookingColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _BookingColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _BookingColors.primary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFFFF9800), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Adrese teslim için ek ücret uygulanabilir',
                          style: TextStyle(
                            fontSize: 12,
                            color: _BookingColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDateTimeCard({
    required String title,
    required DateTime? date,
    required TimeOfDay? time,
    required VoidCallback onDateTap,
    required VoidCallback onTimeTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _BookingColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _BookingColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _BookingColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onDateTap,
            child: Row(
              children: [
                Icon(Icons.calendar_today,
                    color: _BookingColors.textSecondary, size: 18),
                const SizedBox(width: 8),
                Text(
                  date != null
                      ? '${date.day}/${date.month}/${date.year}'
                      : 'Tarih seç',
                  style: TextStyle(
                    color: date != null ? _BookingColors.textPrimary : _BookingColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onTimeTap,
            child: Row(
              children: [
                Icon(Icons.access_time, color: _BookingColors.textSecondary, size: 18),
                const SizedBox(width: 8),
                Text(
                  time != null ? time.format(context) : 'Saat seç',
                  style: TextStyle(
                    color: time != null ? _BookingColors.textPrimary : _BookingColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Kiralama Paketi Seçin'),
          const SizedBox(height: 8),
          Text(
            'İhtiyacınıza uygun paketi seçin',
            style: TextStyle(
              color: _BookingColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ...RentalPackage.packages.map((package) {
            final isSelected = _selectedPackage.id == package.id;
            return _buildPackageCard(package, isSelected);
          }),
        ],
      ),
    );
  }

  Widget _buildPackageCard(RentalPackage package, bool isSelected) {
    final packagePrice = _carTotalPrice * (package.priceMultiplier - 1);

    return GestureDetector(
      onTap: () => setState(() => _selectedPackage = package),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _BookingColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? _BookingColors.primary
                : _BookingColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: _BookingColors.primary.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _BookingColors.primary.withValues(alpha: 0.15)
                        : _BookingColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getPackageIcon(package.iconName),
                    color: isSelected ? _BookingColors.primary : _BookingColors.textSecondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            package.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? _BookingColors.primary
                                  : _BookingColors.textPrimary,
                            ),
                          ),
                          if (package.isPopular) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Önerilen',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        package.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: _BookingColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (packagePrice > 0)
                      Text(
                        '+₺${packagePrice.toInt()}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? _BookingColors.primary
                              : _BookingColors.textPrimary,
                        ),
                      )
                    else
                      const Text(
                        'Dahil',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: package.includedServices.map((service) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _BookingColors.primary.withValues(alpha: 0.1)
                        : _BookingColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: isSelected
                            ? _BookingColors.primary
                            : const Color(0xFF4CAF50),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        service,
                        style: TextStyle(
                          color: _BookingColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Ek Hizmetler'),
          const SizedBox(height: 8),
          Text(
            'İhtiyacınıza göre ekstra hizmetler ekleyin',
            style: TextStyle(
              color: _BookingColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ...AdditionalService.services.map((service) {
            final isSelected = _selectedServices.contains(service.id);
            return _buildServiceCard(service, isSelected);
          }),
        ],
      ),
    );
  }

  Widget _buildServiceCard(AdditionalService service, bool isSelected) {
    final totalPrice = service.dailyPrice * _rentalDays;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedServices.remove(service.id);
          } else {
            _selectedServices.add(service.id);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _BookingColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? _BookingColors.primary
                : _BookingColors.border,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: _BookingColors.primary.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? _BookingColors.primary.withValues(alpha: 0.15)
                    : _BookingColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getServiceIcon(service.iconName),
                color: isSelected ? _BookingColors.primary : _BookingColors.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? _BookingColors.primary : _BookingColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    service.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: _BookingColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₺${totalPrice.toInt()}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? _BookingColors.primary : _BookingColors.textPrimary,
                  ),
                ),
                Text(
                  '₺${service.dailyPrice.toInt()}/gün',
                  style: TextStyle(
                    fontSize: 11,
                    color: _BookingColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [_BookingColors.primary, _BookingColors.primaryLight],
                      )
                    : null,
                color: isSelected ? null : _BookingColors.border,
                borderRadius: BorderRadius.circular(6),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Car Summary
          _buildSectionTitle('Araç Bilgileri'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _BookingColors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _BookingColors.border,
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    widget.car.thumbnailUrl,
                    width: 80,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 80,
                        height: 60,
                        color: _BookingColors.background,
                        child: Icon(Icons.directions_car,
                            color: _BookingColors.textSecondary),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.car.fullName,
                        style: TextStyle(
                          color: _BookingColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${widget.car.transmissionName} • ${widget.car.fuelTypeName}',
                        style: TextStyle(
                          color: _BookingColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Booking Details
          _buildSectionTitle('Rezervasyon Detayları'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _BookingColors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _BookingColors.border,
              ),
            ),
            child: Column(
              children: [
                _buildDetailRow(
                  'Alış',
                  _isPickupCustomAddress
                      ? 'Adrese Teslim'
                      : (_pickupLocation?.name ?? '-'),
                  _isPickupCustomAddress ? Icons.home : Icons.location_on,
                ),
                if (_isPickupCustomAddress && _pickupCustomAddressController.text.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 30),
                    child: Text(
                      _pickupCustomAddressController.text,
                      style: TextStyle(
                        fontSize: 12,
                        color: _BookingColors.textSecondary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _buildDetailRow(
                  'Teslim',
                  _isDropoffCustomAddress
                      ? 'Adrese Teslim'
                      : (_dropoffLocation?.name ?? '-'),
                  _isDropoffCustomAddress ? Icons.home : Icons.flag,
                ),
                if (_isDropoffCustomAddress && _dropoffCustomAddressController.text.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 30),
                    child: Text(
                      _dropoffCustomAddressController.text,
                      style: TextStyle(
                        fontSize: 12,
                        color: _BookingColors.textSecondary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _buildDetailRow(
                  'Tarih',
                  _pickupDate != null && _dropoffDate != null
                      ? '${_pickupDate!.day}/${_pickupDate!.month} - ${_dropoffDate!.day}/${_dropoffDate!.month}'
                      : '-',
                  Icons.calendar_today,
                ),
                const SizedBox(height: 12),
                _buildDetailRow('Süre', '$_rentalDays gün', Icons.access_time),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Price Breakdown
          _buildSectionTitle('Fiyat Detayı'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _BookingColors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _BookingColors.border,
              ),
            ),
            child: Column(
              children: [
                _buildPriceRow(
                    'Araç kirası ($_rentalDays gün)', _carTotalPrice),
                if (_packagePrice > 0) ...[
                  const SizedBox(height: 8),
                  _buildPriceRow(
                      '${_selectedPackage.name} paket', _packagePrice),
                ],
                if (_servicesPrice > 0) ...[
                  const SizedBox(height: 8),
                  _buildPriceRow('Ek hizmetler', _servicesPrice),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: _BookingColors.border),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Toplam',
                      style: TextStyle(
                        color: _BookingColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '₺${_totalPrice.toInt()}',
                      style: const TextStyle(
                        color: _BookingColors.primary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Terms Agreement
          GestureDetector(
            onTap: () => setState(() => _agreeTerms = !_agreeTerms),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _BookingColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _agreeTerms
                      ? _BookingColors.primary
                      : _BookingColors.border,
                ),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      gradient: _agreeTerms
                          ? const LinearGradient(
                              colors: [_BookingColors.primary, _BookingColors.primaryLight],
                            )
                          : null,
                      color:
                          _agreeTerms ? null : _BookingColors.border,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: _agreeTerms
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          color: _BookingColors.textSecondary,
                          fontSize: 13,
                        ),
                        children: const [
                          TextSpan(text: 'Kiralama '),
                          TextSpan(
                            text: 'şartlar ve koşullarını',
                            style: TextStyle(
                              color: _BookingColors.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          TextSpan(text: ' okudum ve kabul ediyorum.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _BookingColors.primary, size: 18),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: _BookingColors.textSecondary,
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: _BookingColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(String label, double price) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _BookingColors.textSecondary,
            fontSize: 14,
          ),
        ),
        Text(
          '₺${price.toInt()}',
          style: TextStyle(
            color: _BookingColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigation() {
    final canProceed = _canProceedToNextStep();

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: _BookingColors.cardBg,
        border: Border(
          top: BorderSide(
            color: _BookingColors.border,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Price Summary
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Toplam',
                  style: TextStyle(
                    color: _BookingColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '₺${_totalPrice.toInt()}',
                  style: const TextStyle(
                    color: _BookingColors.primary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Next Button
          GestureDetector(
            onTap: canProceed ? _nextStep : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                gradient: canProceed
                    ? const LinearGradient(
                        colors: [_BookingColors.primary, _BookingColors.primaryLight],
                      )
                    : null,
                color: canProceed ? null : _BookingColors.border,
                borderRadius: BorderRadius.circular(16),
                boxShadow: canProceed
                    ? [
                        BoxShadow(
                          color: _BookingColors.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Text(
                    _currentStep == 3 ? 'Onayla' : 'Devam',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: canProceed ? Colors.white : _BookingColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _currentStep == 3 ? Icons.check : Icons.arrow_forward,
                    color: canProceed ? Colors.white : _BookingColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceedToNextStep() {
    switch (_currentStep) {
      case 0:
        // Alış noktası kontrolü: ya lokasyon seçili ya da özel adres girilmiş olmalı
        final pickupValid = _isPickupCustomAddress
            ? _pickupCustomAddressController.text.trim().isNotEmpty
            : _pickupLocation != null;

        // Teslim noktası kontrolü: ya lokasyon seçili ya da özel adres girilmiş olmalı
        final dropoffValid = _sameDropoffLocation
            ? pickupValid  // Aynı nokta ise alış geçerliyse teslim de geçerli
            : (_isDropoffCustomAddress
                ? _dropoffCustomAddressController.text.trim().isNotEmpty
                : _dropoffLocation != null);

        return pickupValid &&
            dropoffValid &&
            _pickupDate != null &&
            _dropoffDate != null;
      case 1:
        return true; // Package is always selected
      case 2:
        return true; // Services are optional
      case 3:
        return _agreeTerms;
      default:
        return false;
    }
  }

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _mainController.reset();
      _mainController.forward();
    } else {
      _completeBooking();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _mainController.reset();
      _mainController.forward();
    }
  }

  bool _isSubmitting = false;

  Future<void> _completeBooking() async {
    // Check if user is logged in
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showErrorDialog('Rezervasyon yapmak için giriş yapmalısınız.');
      return;
    }

    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final rentalService = RentalService();

      // Prepare selected services data
      final selectedServicesData = _selectedServices.map((serviceId) {
        final service = AdditionalService.services.firstWhere((s) => s.id == serviceId);
        return {
          'id': service.id,
          'name': service.name,
          'daily_price': service.dailyPrice,
          'total_price': service.dailyPrice * _rentalDays,
        };
      }).toList();

      // Create booking
      final booking = await rentalService.createBooking(
        carId: widget.car.id,
        companyId: widget.car.companyId,
        pickupLocationId: _isPickupCustomAddress ? null : _pickupLocation!.id,
        dropoffLocationId: _isDropoffCustomAddress ? null : _dropoffLocation!.id,
        pickupDate: DateTime(
          _pickupDate!.year,
          _pickupDate!.month,
          _pickupDate!.day,
          _pickupTime?.hour ?? 10,
          _pickupTime?.minute ?? 0,
        ),
        dropoffDate: DateTime(
          _dropoffDate!.year,
          _dropoffDate!.month,
          _dropoffDate!.day,
          _dropoffTime?.hour ?? 10,
          _dropoffTime?.minute ?? 0,
        ),
        dailyRate: _carDailyPrice,
        rentalDays: _rentalDays,
        customerName: user.userMetadata?['full_name'] ?? user.email?.split('@').first ?? 'Müşteri',
        customerPhone: user.userMetadata?['phone'] ?? '',
        customerEmail: user.email ?? '',
        selectedServices: selectedServicesData,
        servicesTotal: _servicesPrice,
        depositAmount: widget.car.depositAmount,
        // Custom address fields
        isPickupCustomAddress: _isPickupCustomAddress,
        pickupCustomAddress: _isPickupCustomAddress ? _pickupCustomAddressController.text.trim() : null,
        pickupCustomAddressNotes: _isPickupCustomAddress ? _pickupCustomAddressNotesController.text.trim() : null,
        isDropoffCustomAddress: _isDropoffCustomAddress,
        dropoffCustomAddress: _isDropoffCustomAddress ? _dropoffCustomAddressController.text.trim() : null,
        dropoffCustomAddressNotes: _isDropoffCustomAddress ? _dropoffCustomAddressNotesController.text.trim() : null,
      );

      if (!mounted) return;

      if (booking != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          useRootNavigator: true,
          builder: (dialogContext) => _BookingSuccessDialog(
            car: widget.car,
            totalPrice: _totalPrice,
            bookingNumber: booking['booking_number'] ?? '',
            onClose: () {
              // Dialog'u kapat ve rental sayfasına git
              Navigator.of(dialogContext, rootNavigator: true).pop();
              if (context.mounted) {
                context.go('/rental');
              }
            },
          ),
        );
      } else {
        _showErrorDialog('Rezervasyon oluşturulurken bir hata oluştu.');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Hata: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _BookingColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text('Hata', style: TextStyle(color: _BookingColors.textPrimary)),
          ],
        ),
        content: Text(message, style: TextStyle(color: _BookingColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(bool isPickup) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isPickup
          ? DateTime.now()
          : (_pickupDate ?? DateTime.now()).add(const Duration(days: 1)),
      firstDate: isPickup ? DateTime.now() : (_pickupDate ?? DateTime.now()),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _BookingColors.primary,
              onPrimary: Colors.black,
              surface: Colors.white,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isPickup) {
          _pickupDate = picked;
          if (_dropoffDate != null && _dropoffDate!.isBefore(picked)) {
            _dropoffDate = null;
          }
        } else {
          _dropoffDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(bool isPickup) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _BookingColors.primary,
              onPrimary: Colors.black,
              surface: Colors.white,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isPickup) {
          _pickupTime = picked;
        } else {
          _dropoffTime = picked;
        }
      });
    }
  }

  IconData _getPackageIcon(String name) {
    switch (name) {
      case 'directions_car':
        return Icons.directions_car;
      case 'star':
        return Icons.star;
      case 'workspace_premium':
        return Icons.workspace_premium;
      default:
        return Icons.check_circle;
    }
  }

  IconData _getServiceIcon(String name) {
    switch (name) {
      case 'gps_fixed':
        return Icons.gps_fixed;
      case 'child_care':
        return Icons.child_care;
      case 'person_add':
        return Icons.person_add;
      case 'wifi':
        return Icons.wifi;
      case 'ac_unit':
        return Icons.ac_unit;
      case 'luggage':
        return Icons.luggage;
      default:
        return Icons.add_circle;
    }
  }
}

class _BookingSuccessDialog extends StatefulWidget {
  final RentalCar car;
  final double totalPrice;
  final String bookingNumber;
  final VoidCallback onClose;

  const _BookingSuccessDialog({
    required this.car,
    required this.totalPrice,
    required this.bookingNumber,
    required this.onClose,
  });

  @override
  State<_BookingSuccessDialog> createState() => _BookingSuccessDialogState();
}

class _BookingSuccessDialogState extends State<_BookingSuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: _BookingColors.cardBg,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_BookingColors.primary, _BookingColors.primaryLight],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _BookingColors.primary.withValues(alpha: 0.4),
                            blurRadius: 24,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Rezervasyon Başarılı!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _BookingColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${widget.car.fullName} için rezervasyonunuz alındı.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: _BookingColors.textSecondary,
                      ),
                    ),
                    if (widget.bookingNumber.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _BookingColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Rezervasyon No: ${widget.bookingNumber}',
                          style: const TextStyle(
                            color: _BookingColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _BookingColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Toplam: ',
                            style: TextStyle(
                              color: _BookingColors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '₺${widget.totalPrice.toInt()}',
                            style: const TextStyle(
                              color: _BookingColors.primary,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_BookingColors.primary, _BookingColors.primaryLight],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            'Tamam',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
