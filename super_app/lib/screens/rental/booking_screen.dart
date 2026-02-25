import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/rental/rental_models.dart';
import '../../services/rental_service.dart';
import '../../core/services/rental_service.dart' as core_rental;
import '../../core/theme/app_theme.dart';
import '../../widgets/common/shimmer_widgets.dart';

class BookingScreen extends StatefulWidget {
  final RentalCar car;
  final RentalLocation? initialPickupLocation;
  final RentalLocation? initialDropoffLocation;
  final DateTime? initialPickupDate;
  final DateTime? initialDropoffDate;
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

class _BookingScreenState extends State<BookingScreen> {
  RentalLocation? _pickupLocation;
  RentalLocation? _dropoffLocation;
  DateTime? _pickupDate;
  DateTime? _dropoffDate;
  TimeOfDay? _pickupTime;
  TimeOfDay? _dropoffTime;
  List<RentalPackage> _packages = [];
  List<AdditionalService> _availableServices = [];
  RentalPackage? _selectedPackage;
  final Set<String> _selectedServices = {};
  bool _isLoadingPackages = true;
  bool _sameDropoffLocation = true;
  bool _agreeTerms = false;
  bool _isSubmitting = false;

  // Expandable section states
  bool _isDateLocationExpanded = true;
  bool _isPackageExpanded = false;
  bool _isServicesExpanded = false;

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
    _loadLocations();
    _loadPackagesAndServices();
    _pickupDate = widget.initialPickupDate ?? DateTime.now().add(const Duration(days: 1));
    _dropoffDate = widget.initialDropoffDate ?? DateTime.now().add(const Duration(days: 4));
    _pickupTime = const TimeOfDay(hour: 10, minute: 0);
    _dropoffTime = const TimeOfDay(hour: 10, minute: 0);
  }

  Future<void> _loadPackagesAndServices() async {
    try {
      final rentalService = RentalService();
      final companyId = widget.car.companyId;
      final packagesData = await rentalService.getCompanyPackages(companyId);
      final servicesData = await rentalService.getCompanyServices(companyId);
      if (mounted) {
        setState(() {
          _packages = packagesData.map((p) => RentalPackage.fromJson(p)).toList();
          _availableServices = servicesData.map((s) => AdditionalService.fromJson(s)).toList();
          if (_packages.isNotEmpty) {
            _selectedPackage = _packages.firstWhere(
              (p) => p.tier == 'comfort',
              orElse: () => _packages.first,
            );
          }
          _isLoadingPackages = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading packages/services: $e');
      if (mounted) setState(() => _isLoadingPackages = false);
    }
  }

  Future<void> _loadLocations() async {
    try {
      final locations = await core_rental.RentalService.getLocations();
      if (mounted) {
        setState(() {
          _locations = locations;
          _isPickupCustomAddress = widget.initialIsPickupCustomAddress;
          _isDropoffCustomAddress = widget.initialIsDropoffCustomAddress;

          if (widget.initialIsPickupCustomAddress && widget.initialPickupCustomAddress != null) {
            _pickupCustomAddressController.text = widget.initialPickupCustomAddress!;
            if (widget.initialPickupCustomAddressNote != null) {
              _pickupCustomAddressNotesController.text = widget.initialPickupCustomAddressNote!;
            }
            _pickupLocation = null;
          } else {
            _pickupLocation = widget.initialPickupLocation ?? (_locations.isNotEmpty ? _locations.first : null);
          }

          if (widget.initialIsDropoffCustomAddress && widget.initialDropoffCustomAddress != null) {
            _dropoffCustomAddressController.text = widget.initialDropoffCustomAddress!;
            if (widget.initialDropoffCustomAddressNote != null) {
              _dropoffCustomAddressNotesController.text = widget.initialDropoffCustomAddressNote!;
            }
            _dropoffLocation = null;
          } else {
            _dropoffLocation = widget.initialDropoffLocation ?? (_locations.isNotEmpty ? _locations.first : null);
          }

          if (!_isPickupCustomAddress && !_isDropoffCustomAddress) {
            _sameDropoffLocation = _pickupLocation?.id == _dropoffLocation?.id;
          } else {
            _sameDropoffLocation = false;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading locations: $e');
      if (mounted) {
        setState(() {
          _locations = [];
          _isPickupCustomAddress = widget.initialIsPickupCustomAddress;
          _isDropoffCustomAddress = widget.initialIsDropoffCustomAddress;
          if (widget.initialIsPickupCustomAddress && widget.initialPickupCustomAddress != null) {
            _pickupCustomAddressController.text = widget.initialPickupCustomAddress!;
            if (widget.initialPickupCustomAddressNote != null) {
              _pickupCustomAddressNotesController.text = widget.initialPickupCustomAddressNote!;
            }
          } else {
            _pickupLocation = widget.initialPickupLocation;
          }
          if (widget.initialIsDropoffCustomAddress && widget.initialDropoffCustomAddress != null) {
            _dropoffCustomAddressController.text = widget.initialDropoffCustomAddress!;
            if (widget.initialDropoffCustomAddressNote != null) {
              _dropoffCustomAddressNotesController.text = widget.initialDropoffCustomAddressNote!;
            }
          } else {
            _dropoffLocation = widget.initialDropoffLocation;
          }
          if (!_isPickupCustomAddress && !_isDropoffCustomAddress) {
            _sameDropoffLocation = _pickupLocation?.id == _dropoffLocation?.id;
          } else {
            _sameDropoffLocation = false;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _pickupCustomAddressController.dispose();
    _pickupCustomAddressNotesController.dispose();
    _dropoffCustomAddressController.dispose();
    _dropoffCustomAddressNotesController.dispose();
    super.dispose();
  }

  int get _rentalDays {
    if (_pickupDate == null || _dropoffDate == null) return 1;
    final d = _dropoffDate!.difference(_pickupDate!).inDays;
    return d < 1 ? 1 : d;
  }

  double get _carDailyPrice => widget.car.discountedDailyPrice;
  double get _carTotalPrice => _carDailyPrice * _rentalDays;

  double get _packagePrice => (_selectedPackage?.dailyPrice ?? 0) * _rentalDays;

  double get _servicesPrice {
    double total = 0;
    for (final serviceId in _selectedServices) {
      try {
        final service = _availableServices.firstWhere((s) => s.id == serviceId);
        total += service.dailyPrice * _rentalDays;
      } catch (_) {}
    }
    return total;
  }

  double get _totalPrice => _carTotalPrice + _packagePrice + _servicesPrice;

  bool get _canConfirm {
    final pickupValid = _isPickupCustomAddress
        ? _pickupCustomAddressController.text.trim().isNotEmpty
        : _pickupLocation != null;
    final dropoffValid = _sameDropoffLocation
        ? pickupValid
        : (_isDropoffCustomAddress
            ? _dropoffCustomAddressController.text.trim().isNotEmpty
            : _dropoffLocation != null);
    return pickupValid && dropoffValid && _pickupDate != null && _dropoffDate != null && _agreeTerms;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rezervasyon',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              widget.car.fullName,
              style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  // Car summary (always visible)
                  _buildCarSummary(theme),
                  const SizedBox(height: 12),

                  // Date & Location section
                  _buildExpandableSection(
                    theme: theme,
                    icon: Icons.location_on,
                    title: 'Tarih & Konum',
                    subtitle: _dateLocationSummary,
                    isExpanded: _isDateLocationExpanded,
                    onToggle: () => setState(() => _isDateLocationExpanded = !_isDateLocationExpanded),
                    child: _buildDateLocationContent(theme),
                  ),
                  const SizedBox(height: 8),

                  // Package section
                  _buildExpandableSection(
                    theme: theme,
                    icon: Icons.workspace_premium,
                    title: 'Paket Secin',
                    subtitle: _packageSummary,
                    isExpanded: _isPackageExpanded,
                    onToggle: () => setState(() => _isPackageExpanded = !_isPackageExpanded),
                    child: _buildPackageContent(theme),
                  ),
                  const SizedBox(height: 8),

                  // Services section
                  _buildExpandableSection(
                    theme: theme,
                    icon: Icons.add_circle_outline,
                    title: 'Ek Hizmetler',
                    subtitle: _servicesSummary,
                    isExpanded: _isServicesExpanded,
                    onToggle: () => setState(() => _isServicesExpanded = !_isServicesExpanded),
                    child: _buildServicesContent(theme),
                  ),
                  const SizedBox(height: 12),

                  // Price breakdown (always visible)
                  _buildPriceBreakdown(theme),
                  const SizedBox(height: 12),

                  // Terms
                  _buildTermsCheckbox(theme),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          // Sticky bottom bar
          _buildBottomBar(theme),
        ],
      ),
    );
  }

  // --- Summaries for collapsed headers ---

  String get _dateLocationSummary {
    if (_pickupDate == null) return 'Tarih ve konum secin';
    final loc = _isPickupCustomAddress ? 'Adrese Teslim' : (_pickupLocation?.name ?? '');
    return '$loc  ·  ${_pickupDate!.day}/${_pickupDate!.month} - ${_dropoffDate!.day}/${_dropoffDate!.month}';
  }

  String get _packageSummary {
    if (_isLoadingPackages) return 'Yukleniyor...';
    if (_selectedPackage == null) return 'Paket secilmedi';
    final price = _packagePrice;
    return '${_selectedPackage!.name}${price > 0 ? '  ·  +₺${price.toInt()}' : '  ·  Dahil'}';
  }

  String get _servicesSummary {
    if (_selectedServices.isEmpty) return 'Opsiyonel';
    return '${_selectedServices.length} hizmet  ·  +₺${_servicesPrice.toInt()}';
  }

  // --- Car Summary ---

  Widget _buildCarSummary(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: widget.car.thumbnailUrl,
                width: 80,
                height: 56,
                fit: BoxFit.cover,
                memCacheWidth: 160,
                memCacheHeight: 112,
                placeholder: (_, __) => Container(width: 80, height: 56, color: theme.dividerColor),
                errorWidget: (_, __, ___) => Container(
                  width: 80, height: 56, color: theme.dividerColor,
                  child: Icon(Icons.directions_car, color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.car.fullName,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.car.transmissionName} · ${widget.car.fuelTypeName}',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Text(
              '₺${_carDailyPrice.toInt()}/gun',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }

  // --- Expandable Section ---

  Widget _buildExpandableSection({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isExpanded ? theme.colorScheme.primary.withValues(alpha: 0.3) : theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isExpanded
                          ? theme.colorScheme.primary.withValues(alpha: 0.1)
                          : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: isExpanded ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        if (!isExpanded) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: isExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: child,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // --- Date & Location Content ---

  Widget _buildDateLocationContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text('Alis Noktasi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
        const SizedBox(height: 8),
        _buildLocationSelector(value: _pickupLocation, onChanged: (loc) {
          setState(() {
            _pickupLocation = loc;
            if (_sameDropoffLocation) _dropoffLocation = loc;
          });
        }, isPickup: true),

        const SizedBox(height: 12),
        // Same location toggle
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            setState(() {
              _sameDropoffLocation = !_sameDropoffLocation;
              if (_sameDropoffLocation) _dropoffLocation = _pickupLocation;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 22, height: 22,
                  child: Checkbox(
                    value: _sameDropoffLocation,
                    onChanged: (val) {
                      setState(() {
                        _sameDropoffLocation = val ?? false;
                        if (_sameDropoffLocation) _dropoffLocation = _pickupLocation;
                      });
                    },
                    activeColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                Text('Ayni noktaya teslim et', style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface)),
              ],
            ),
          ),
        ),

        if (!_sameDropoffLocation) ...[
          const SizedBox(height: 12),
          Text('Teslim Noktasi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 8),
          _buildLocationSelector(value: _dropoffLocation, onChanged: (loc) => setState(() => _dropoffLocation = loc), isPickup: false),
        ],

        const SizedBox(height: 16),
        Text('Tarih ve Saat', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildDateTimeCard(title: 'Alis', date: _pickupDate, time: _pickupTime, onDateTap: () => _selectDate(true), onTimeTap: () => _selectTime(true))),
            const SizedBox(width: 12),
            Expanded(child: _buildDateTimeCard(title: 'Teslim', date: _dropoffDate, time: _dropoffTime, onDateTap: () => _selectDate(false), onTimeTap: () => _selectTime(false))),
          ],
        ),

        if (_pickupDate != null && _dropoffDate != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today, color: theme.colorScheme.primary, size: 18),
                const SizedBox(width: 8),
                Text('Toplam $_rentalDays gun kiralama', style: TextStyle(color: theme.colorScheme.primary, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // --- Location Selector ---

  Widget _buildLocationSelector({
    required RentalLocation? value,
    required ValueChanged<RentalLocation> onChanged,
    required bool isPickup,
  }) {
    final isCustomAddress = isPickup ? _isPickupCustomAddress : _isDropoffCustomAddress;
    final addressController = isPickup ? _pickupCustomAddressController : _dropoffCustomAddressController;
    final notesController = isPickup ? _pickupCustomAddressNotesController : _dropoffCustomAddressNotesController;
    final theme = Theme.of(context);

    return Column(
      children: [
        // Standard locations
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.dividerColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: _locations.map((location) {
              final isSelected = !isCustomAddress && value?.id == location.id;
              return InkWell(
                onTap: () {
                  setState(() {
                    if (isPickup) { _isPickupCustomAddress = false; } else { _isDropoffCustomAddress = false; }
                  });
                  onChanged(location);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.08) : null,
                    border: Border(bottom: BorderSide(
                      color: location != _locations.last ? theme.dividerColor : Colors.transparent,
                    )),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        location.isAirport ? Icons.flight : Icons.location_on,
                        color: location.isAirport ? AppColors.info : AppColors.success,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(location.name, style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              fontSize: 14,
                            )),
                            Text(location.workingHours, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 20),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 8),

        // Custom Address Option
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            setState(() {
              if (isPickup) { _isPickupCustomAddress = !_isPickupCustomAddress; } else { _isDropoffCustomAddress = !_isDropoffCustomAddress; }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isCustomAddress ? theme.colorScheme.primary : theme.dividerColor, width: isCustomAddress ? 1.5 : 1),
            ),
            child: Row(
              children: [
                Icon(Icons.home, color: AppColors.warning, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Adrese Teslim', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: isCustomAddress ? FontWeight.w600 : FontWeight.normal, fontSize: 14)),
                      Text('Araci istediginiz adrese teslim edelim', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (isCustomAddress) Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 20),
              ],
            ),
          ),
        ),

        // Custom Address Input
        if (isCustomAddress) ...[
          const SizedBox(height: 8),
          TextField(
            controller: addressController,
            decoration: InputDecoration(
              labelText: 'Adres *',
              hintText: 'Orn: Ataturk Cad. No:123, Kadikoy',
              prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
            ),
            maxLines: 2,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: notesController,
            decoration: InputDecoration(
              labelText: 'Adres Tarifi (Opsiyonel)',
              hintText: 'Orn: Kapi kodu 1234, 3. kat',
              prefixIcon: const Icon(Icons.notes_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.warning, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Adrese teslim icin ek ucret uygulanabilir', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // --- Date Time Card ---

  Widget _buildDateTimeCard({
    required String title,
    required DateTime? date,
    required TimeOfDay? time,
    required VoidCallback onDateTap,
    required VoidCallback onTimeTap,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: theme.colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          InkWell(
            onTap: onDateTap,
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: theme.colorScheme.onSurfaceVariant, size: 16),
                const SizedBox(width: 8),
                Text(
                  date != null ? '${date.day}/${date.month}/${date.year}' : 'Tarih sec',
                  style: TextStyle(fontSize: 14, color: date != null ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: onTimeTap,
            child: Row(
              children: [
                Icon(Icons.access_time, color: theme.colorScheme.onSurfaceVariant, size: 16),
                const SizedBox(width: 8),
                Text(
                  time != null ? time.format(context) : 'Saat sec',
                  style: TextStyle(fontSize: 14, color: time != null ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Package Content ---

  Widget _buildPackageContent(ThemeData theme) {
    if (_isLoadingPackages) {
      return Column(children: List.generate(2, (_) => const ShimmerSelectionCard()));
    }
    if (_packages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text('Paket bulunamadi', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
      );
    }
    return Column(
      children: _packages.map((package) {
        final isSelected = _selectedPackage?.id == package.id;
        return _buildPackageCard(package, isSelected, theme);
      }).toList(),
    );
  }

  Widget _buildPackageCard(RentalPackage package, bool isSelected, ThemeData theme) {
    final packagePrice = package.dailyPrice * _rentalDays;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _selectedPackage = package),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? theme.colorScheme.primary : theme.dividerColor, width: isSelected ? 1.5 : 1),
            color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.04) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_getPackageIcon(package.iconName), color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(package.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface)),
                            if (package.isPopular) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(6)),
                                child: const Text('Onerilen', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                            ],
                          ],
                        ),
                        Text(package.description, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  packagePrice > 0
                      ? Text('+₺${packagePrice.toInt()}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface))
                      : Text('Dahil', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.success)),
                ],
              ),
              if (package.includedServices.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: package.includedServices.map((service) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, color: AppColors.success, size: 12),
                          const SizedBox(width: 4),
                          Text(service, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // --- Services Content ---

  Widget _buildServicesContent(ThemeData theme) {
    if (_isLoadingPackages) {
      return Column(children: List.generate(3, (_) => const ShimmerSelectionCard()));
    }
    if (_availableServices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text('Ek hizmet bulunamadi', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
      );
    }
    return Column(
      children: _availableServices.map((service) {
        final isSelected = _selectedServices.contains(service.id);
        return _buildServiceCard(service, isSelected, theme);
      }).toList(),
    );
  }

  Widget _buildServiceCard(AdditionalService service, bool isSelected, ThemeData theme) {
    final totalPrice = service.dailyPrice * _rentalDays;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() {
            if (isSelected) { _selectedServices.remove(service.id); } else { _selectedServices.add(service.id); }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? theme.colorScheme.primary : theme.dividerColor, width: isSelected ? 1.5 : 1),
            color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.04) : null,
          ),
          child: Row(
            children: [
              Icon(_getServiceIcon(service.iconName), color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                    Text(service.description, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₺${totalPrice.toInt()}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface)),
                  Text('₺${service.dailyPrice.toInt()}/gun', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 22, height: 22,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) { _selectedServices.add(service.id); } else { _selectedServices.remove(service.id); }
                    });
                  },
                  activeColor: theme.colorScheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Price Breakdown ---

  Widget _buildPriceBreakdown(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.dividerColor)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fiyat Detayi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 10),
            _buildPriceRow('Arac kirasi ($_rentalDays gun)', _carTotalPrice, theme),
            if (_packagePrice > 0) ...[
              const SizedBox(height: 6),
              _buildPriceRow('${_selectedPackage?.name ?? ''} paket', _packagePrice, theme),
            ],
            if (_servicesPrice > 0) ...[
              const SizedBox(height: 6),
              _buildPriceRow('Ek hizmetler', _servicesPrice, theme),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: theme.dividerColor, height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Toplam', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('₺${_totalPrice.toInt()}', style: TextStyle(color: theme.colorScheme.primary, fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, double price, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
        Text('₺${price.toInt()}', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // --- Terms ---

  Widget _buildTermsCheckbox(ThemeData theme) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _agreeTerms = !_agreeTerms),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _agreeTerms ? theme.colorScheme.primary : theme.dividerColor),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22, height: 22,
              child: Checkbox(
                value: _agreeTerms,
                onChanged: (val) => setState(() => _agreeTerms = val ?? false),
                activeColor: theme.colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                  children: [
                    const TextSpan(text: 'Kiralama '),
                    TextSpan(text: 'sartlar ve kosullari', style: TextStyle(color: theme.colorScheme.primary, decoration: TextDecoration.underline)),
                    const TextSpan(text: ' okudum ve kabul ediyorum.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Bottom Bar ---

  Widget _buildBottomBar(ThemeData theme) {
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Toplam', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                Text('₺${_totalPrice.toInt()}', style: TextStyle(color: theme.colorScheme.primary, fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _canConfirm && !_isSubmitting ? _completeBooking : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: theme.dividerColor,
              disabledForegroundColor: theme.colorScheme.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSubmitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Onayla', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(width: 6),
                      Icon(Icons.check, size: 20),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // --- Actions ---

  Future<void> _selectDate(bool isPickup) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isPickup ? DateTime.now() : (_pickupDate ?? DateTime.now()).add(const Duration(days: 1)),
      firstDate: isPickup ? DateTime.now() : (_pickupDate ?? DateTime.now()),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isPickup) {
          _pickupDate = picked;
          if (_dropoffDate != null && _dropoffDate!.isBefore(picked)) _dropoffDate = null;
        } else {
          _dropoffDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(bool isPickup) async {
    final TimeOfDay? picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) {
      setState(() {
        if (isPickup) { _pickupTime = picked; } else { _dropoffTime = picked; }
      });
    }
  }

  Future<void> _completeBooking() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showErrorDialog('Rezervasyon yapmak icin giris yapmalisiniz.');
      return;
    }
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final rentalService = RentalService();
      final selectedServicesData = _selectedServices.map((serviceId) {
        final service = _availableServices.firstWhere((s) => s.id == serviceId);
        return {'id': service.id, 'name': service.name, 'daily_price': service.dailyPrice, 'total_price': service.dailyPrice * _rentalDays};
      }).toList();

      final booking = await rentalService.createBooking(
        carId: widget.car.id,
        companyId: widget.car.companyId,
        pickupLocationId: _isPickupCustomAddress ? null : _pickupLocation!.id,
        dropoffLocationId: _isDropoffCustomAddress ? null : _dropoffLocation!.id,
        pickupDate: DateTime(_pickupDate!.year, _pickupDate!.month, _pickupDate!.day, _pickupTime?.hour ?? 10, _pickupTime?.minute ?? 0),
        dropoffDate: DateTime(_dropoffDate!.year, _dropoffDate!.month, _dropoffDate!.day, _dropoffTime?.hour ?? 10, _dropoffTime?.minute ?? 0),
        dailyRate: _carDailyPrice,
        rentalDays: _rentalDays,
        customerName: user.userMetadata?['full_name'] ?? user.email?.split('@').first ?? 'Musteri',
        customerPhone: user.userMetadata?['phone'] ?? '',
        customerEmail: user.email ?? '',
        selectedServices: selectedServicesData,
        servicesTotal: _servicesPrice,
        depositAmount: widget.car.depositAmount,
        packageId: _selectedPackage?.id,
        packageTier: _selectedPackage?.tier,
        packageName: _selectedPackage?.name,
        packageDailyPrice: _selectedPackage?.dailyPrice ?? 0,
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
              Navigator.of(dialogContext, rootNavigator: true).pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
              });
            },
          ),
        );
      } else {
        _showErrorDialog('Rezervasyon olusturulurken bir hata olustu.');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Hata: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [Icon(Icons.error_outline, color: AppColors.error), SizedBox(width: 8), Text('Hata')]),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tamam'))],
      ),
    );
  }

  IconData _getPackageIcon(String name) {
    switch (name) {
      case 'directions_car': return Icons.directions_car;
      case 'star': return Icons.star;
      case 'workspace_premium': return Icons.workspace_premium;
      default: return Icons.check_circle;
    }
  }

  IconData _getServiceIcon(String name) {
    switch (name) {
      case 'gps_fixed': return Icons.gps_fixed;
      case 'child_care': return Icons.child_care;
      case 'person_add': return Icons.person_add;
      case 'wifi': return Icons.wifi;
      case 'ac_unit': return Icons.ac_unit;
      case 'luggage': return Icons.luggage;
      default: return Icons.add_circle;
    }
  }
}

// --- Success Dialog (kept as-is) ---

class _BookingSuccessDialog extends StatefulWidget {
  final RentalCar car;
  final double totalPrice;
  final String bookingNumber;
  final VoidCallback onClose;

  const _BookingSuccessDialog({required this.car, required this.totalPrice, required this.bookingNumber, required this.onClose});

  @override
  State<_BookingSuccessDialog> createState() => _BookingSuccessDialogState();
}

class _BookingSuccessDialogState extends State<_BookingSuccessDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 24)],
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 40),
                    ),
                    const SizedBox(height: 24),
                    Text('Rezervasyon Basarili!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 12),
                    Text('${widget.car.fullName} icin rezervasyonunuz alindi.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant)),
                    if (widget.bookingNumber.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text('Rezervasyon No: ${widget.bookingNumber}', style: TextStyle(color: theme.colorScheme.primary, fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Toplam: ', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 16)),
                          Text('₺${widget.totalPrice.toInt()}', style: TextStyle(color: theme.colorScheme.primary, fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: widget.onClose,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Tamam', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
