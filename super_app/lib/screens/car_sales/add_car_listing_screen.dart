import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/car_sales/car_sales_models.dart';
import '../../services/car_sales_service.dart';
import '../../core/utils/app_dialogs.dart';

class AddCarListingScreen extends StatefulWidget {
  const AddCarListingScreen({super.key});

  @override
  State<AddCarListingScreen> createState() => _AddCarListingScreenState();
}

class _AddCarListingScreenState extends State<AddCarListingScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _progressController;
  late AnimationController _stepAnimationController;

  int _currentStep = 0;
  final int _totalSteps = 5;

  // Form Controllers
  final _formKey = GlobalKey<FormState>();

  // Supabase service
  final CarSalesService _carSalesService = CarSalesService.instance;

  // Supabase'den gelen filtre verileri
  List<CarBodyTypeData> _bodyTypesData = [];
  List<CarFuelTypeData> _fuelTypesData = [];
  List<CarTransmissionData> _transmissionsData = [];
  List<CarFeatureData> _featuresData = [];
  Map<String, List<CarFeatureData>> _featuresByCategory = {};

  // Step 1: Basic Info
  CarBrand? _selectedBrand;
  // ignore: unused_field
  String? _selectedModel;
  final _yearController = TextEditingController();
  String? _selectedBodyTypeId;
  CarColor? _selectedExteriorColor;
  CarColor? _selectedInteriorColor;

  // Step 2: Technical Specs
  String? _selectedFuelTypeId;
  String? _selectedTransmissionId;
  CarTraction? _selectedTraction;
  final _engineCCController = TextEditingController();
  final _horsePowerController = TextEditingController();
  final _mileageController = TextEditingController();

  // Step 3: Condition & History
  CarCondition? _selectedCondition;
  int _previousOwners = 1;
  bool _hasOriginalPaint = true;
  bool _hasAccidentHistory = false;
  bool _hasWarranty = false;
  final _warrantyDetailsController = TextEditingController();
  final _damageReportController = TextEditingController();

  // Step 4: Features
  final Set<String> _selectedFeatures = {};

  // Step 5: Price & Description
  final _priceController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isPriceNegotiable = false;
  bool _isExchangeAccepted = false;

  // Images
  final List<String> _selectedImages = [];
  final List<XFile> _localImages = [];  // XFile works for both web and mobile
  final Map<String, Uint8List> _imageBytes = {};  // Cache for web image bytes
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingImage = false;

  bool _isLoadingFilters = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _stepAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _stepAnimationController.forward();
    _loadFilterData();
  }

  Future<void> _loadFilterData() async {
    try {
      final results = await Future.wait([
        _carSalesService.getBodyTypes(),
        _carSalesService.getFuelTypes(),
        _carSalesService.getTransmissions(),
        _carSalesService.getFeatures(),
      ]);
      if (mounted) {
        final features = results[3] as List<CarFeatureData>;
        // Kategorilere göre grupla
        final Map<String, List<CarFeatureData>> grouped = {};
        for (final feature in features) {
          final category = feature.category;
          if (!grouped.containsKey(category)) {
            grouped[category] = [];
          }
          grouped[category]!.add(feature);
        }

        setState(() {
          _bodyTypesData = results[0] as List<CarBodyTypeData>;
          _fuelTypesData = results[1] as List<CarFuelTypeData>;
          _transmissionsData = results[2] as List<CarTransmissionData>;
          _featuresData = features;
          _featuresByCategory = grouped;
          _isLoadingFilters = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading filter data: $e');
      if (mounted) {
        setState(() => _isLoadingFilters = false);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    _stepAnimationController.dispose();
    _yearController.dispose();
    _engineCCController.dispose();
    _horsePowerController.dispose();
    _mileageController.dispose();
    _warrantyDetailsController.dispose();
    _damageReportController.dispose();
    _priceController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _stepAnimationController.reverse().then((_) {
        setState(() => _currentStep++);
        _pageController.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
        );
        _stepAnimationController.forward();
      });
    } else {
      _submitListing();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _stepAnimationController.reverse().then((_) {
        setState(() => _currentStep--);
        _pageController.previousPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
        );
        _stepAnimationController.forward();
      });
    }
  }

  bool _isSubmitting = false;

  Future<void> _submitListing() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      // 1. Upload images
      List<String> imageUrls = [..._selectedImages]; // Already uploaded images

      for (final xFile in _localImages) {
        final bytes = await xFile.readAsBytes();
        final fileName = xFile.name.isNotEmpty ? xFile.name : 'image.jpg';
        final url = await _carSalesService.uploadCarImage(bytes, fileName);
        if (url != null) {
          imageUrls.add(url);
        }
      }

      // 2. Prepare listing data
      final data = <String, dynamic>{
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'brand_id': _selectedBrand?.id,
        'brand_name': _selectedBrand?.name ?? '',
        'model_name': _selectedModel ?? '',
        'year': int.tryParse(_yearController.text) ?? DateTime.now().year,
        'body_type': _selectedBodyTypeId,
        'fuel_type': _selectedFuelTypeId,
        'transmission': _selectedTransmissionId,
        'traction': _selectedTraction?.name,
        'engine_cc': int.tryParse(_engineCCController.text),
        'horsepower': int.tryParse(_horsePowerController.text),
        'mileage': int.tryParse(_mileageController.text) ?? 0,
        'exterior_color': _selectedExteriorColor?.name,
        'interior_color': _selectedInteriorColor?.name,
        'condition': _selectedCondition?.name,
        'previous_owners': _previousOwners,
        'has_original_paint': _hasOriginalPaint,
        'has_accident_history': _hasAccidentHistory,
        'has_warranty': _hasWarranty,
        'warranty_details': _warrantyDetailsController.text.trim(),
        'damage_report': _damageReportController.text.trim(),
        'price': double.tryParse(_priceController.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0,
        'currency': 'TRY',
        'is_price_negotiable': _isPriceNegotiable,
        'is_exchange_accepted': _isExchangeAccepted,
        'images': imageUrls,
        'features': _selectedFeatures.toList(),
      };

      // 3. Create listing
      await _carSalesService.createListing(data);

      if (mounted) {
        setState(() => _isSubmitting = false);
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => _buildSuccessDialog(dialogContext),
        );
      }
    } catch (e) {
      debugPrint('Error submitting listing: $e');
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppDialogs.showError(context, 'İlan oluşturulamadı: $e');
      }
    }
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
              // Header
              _buildHeader(isDark),

              // Progress Indicator
              _buildProgressIndicator(isDark),

              // Step Content
              Expanded(
                child: Form(
                  key: _formKey,
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildStep1BasicInfo(isDark),
                      _buildStep2TechnicalSpecs(isDark),
                      _buildStep3ConditionHistory(isDark),
                      _buildStep4Features(isDark),
                      _buildStep5PriceDescription(isDark),
                    ],
                  ),
                ),
              ),

              // Bottom Navigation
              _buildBottomNavigation(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final stepTitles = [
      'Temel Bilgiler',
      'Teknik Özellikler',
      'Durum & Geçmiş',
      'Donanım',
      'Fiyat & Açıklama',
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: CarSalesColors.surface(isDark),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.close,
                color: CarSalesColors.textPrimary(isDark),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yeni İlan Oluştur',
                  style: TextStyle(
                    color: CarSalesColors.textPrimary(isDark),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stepTitles[_currentStep],
                  style: TextStyle(
                    color: CarSalesColors.textSecondary(isDark),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: CarSalesColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_currentStep + 1}/$_totalSteps',
              style: const TextStyle(
                color: CarSalesColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(_totalSteps, (index) {
          final isCompleted = index < _currentStep;
          final isActive = index == _currentStep;

          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 8 : 0),
              child: Column(
                children: [
                  // Progress Bar
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 4,
                    decoration: BoxDecoration(
                      color: isCompleted || isActive
                          ? CarSalesColors.primary
                          : CarSalesColors.border(isDark),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Step Indicator
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? CarSalesColors.success
                          : isActive
                              ? CarSalesColors.primary
                              : CarSalesColors.surface(isDark),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCompleted || isActive
                            ? Colors.transparent
                            : CarSalesColors.border(isDark),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: isActive
                                    ? Colors.white
                                    : CarSalesColors.textSecondary(isDark),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStep1BasicInfo(bool isDark) {
    return FadeTransition(
      opacity: _stepAnimationController,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _stepAnimationController,
          curve: Curves.easeOutCubic,
        )),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Brand Selection
              _buildSectionTitle(isDark, 'Marka', true),
              const SizedBox(height: 12),
              _buildBrandSelector(isDark),
              const SizedBox(height: 24),

              // Model Input
              _buildSectionTitle(isDark, 'Model', true),
              const SizedBox(height: 12),
              _buildTextField(
                isDark,
                'Örn: Corolla, Golf, A4...',
                onChanged: (value) => _selectedModel = value,
              ),
              const SizedBox(height: 24),

              // Year Selection
              _buildSectionTitle(isDark, 'Model Yılı', true),
              const SizedBox(height: 12),
              _buildYearSelector(isDark),
              const SizedBox(height: 24),

              // Body Type
              _buildSectionTitle(isDark, 'Kasa Tipi', true),
              const SizedBox(height: 12),
              _buildBodyTypeSelector(isDark),
              const SizedBox(height: 24),

              // Colors
              _buildSectionTitle(isDark, 'Dış Renk', true),
              const SizedBox(height: 12),
              _buildColorSelector(isDark, true),
              const SizedBox(height: 24),

              _buildSectionTitle(isDark, 'İç Renk', false),
              const SizedBox(height: 12),
              _buildColorSelector(isDark, false),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep2TechnicalSpecs(bool isDark) {
    return FadeTransition(
      opacity: _stepAnimationController,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fuel Type
            _buildSectionTitle(isDark, 'Yakıt Tipi', true),
            const SizedBox(height: 12),
            _buildFuelTypeSelector(isDark),
            const SizedBox(height: 24),

            // Transmission
            _buildSectionTitle(isDark, 'Vites', true),
            const SizedBox(height: 12),
            _buildTransmissionSelector(isDark),
            const SizedBox(height: 24),

            // Traction
            _buildSectionTitle(isDark, 'Çekiş', true),
            const SizedBox(height: 12),
            _buildTractionSelector(isDark),
            const SizedBox(height: 24),

            // Engine
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(isDark, 'Motor (cc)', true),
                      const SizedBox(height: 12),
                      _buildTextField(
                        isDark,
                        '1600',
                        controller: _engineCCController,
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(isDark, 'Beygir (HP)', true),
                      const SizedBox(height: 12),
                      _buildTextField(
                        isDark,
                        '120',
                        controller: _horsePowerController,
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Mileage
            _buildSectionTitle(isDark, 'Kilometre', true),
            const SizedBox(height: 12),
            _buildTextField(
              isDark,
              'Örn: 75000',
              controller: _mileageController,
              keyboardType: TextInputType.number,
              suffix: 'km',
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3ConditionHistory(bool isDark) {
    return FadeTransition(
      opacity: _stepAnimationController,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Condition
            _buildSectionTitle(isDark, 'Araç Durumu', true),
            const SizedBox(height: 12),
            _buildConditionSelector(isDark),
            const SizedBox(height: 24),

            // Previous Owners
            _buildSectionTitle(isDark, 'Önceki Sahip Sayısı', false),
            const SizedBox(height: 12),
            _buildOwnerCounter(isDark),
            const SizedBox(height: 24),

            // Toggles
            _buildToggleOption(
              isDark,
              'Orijinal Boya',
              'Araç boyasız mı?',
              _hasOriginalPaint,
              (value) => setState(() => _hasOriginalPaint = value),
            ),
            const SizedBox(height: 12),

            _buildToggleOption(
              isDark,
              'Kaza Kaydı',
              'Araçta kaza kaydı var mı?',
              _hasAccidentHistory,
              (value) => setState(() => _hasAccidentHistory = value),
            ),
            const SizedBox(height: 12),

            _buildToggleOption(
              isDark,
              'Garanti',
              'Araç garantili mi?',
              _hasWarranty,
              (value) => setState(() => _hasWarranty = value),
            ),

            if (_hasWarranty) ...[
              const SizedBox(height: 16),
              _buildTextField(
                isDark,
                'Garanti detayları...',
                controller: _warrantyDetailsController,
                maxLines: 2,
              ),
            ],

            const SizedBox(height: 24),

            // Damage Report
            _buildSectionTitle(isDark, 'Hasar Kaydı', false),
            const SizedBox(height: 12),
            _buildTextField(
              isDark,
              'Varsa hasar detaylarını yazın...',
              controller: _damageReportController,
              maxLines: 3,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStep4Features(bool isDark) {
    return FadeTransition(
      opacity: _stepAnimationController,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Araçta bulunan donanımları seçin',
              style: TextStyle(
                color: CarSalesColors.textSecondary(isDark),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: CarSalesColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_selectedFeatures.length} özellik seçildi',
                style: const TextStyle(
                  color: CarSalesColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 24),

            if (_isLoadingFilters)
              const Center(child: CircularProgressIndicator())
            else if (_featuresByCategory.isEmpty)
              Center(
                child: Text(
                  'Donanım bulunamadı',
                  style: TextStyle(color: CarSalesColors.textSecondary(isDark)),
                ),
              )
            else
              ..._featuresByCategory.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: TextStyle(
                        color: CarSalesColors.textPrimary(isDark),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: entry.value.map((feature) {
                        final isSelected = _selectedFeatures.contains(feature.id);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedFeatures.remove(feature.id);
                              } else {
                                _selectedFeatures.add(feature.id);
                              }
                            });
                            HapticFeedback.selectionClick();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? CarSalesColors.primary
                                  : CarSalesColors.card(isDark),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? CarSalesColors.primary
                                    : CarSalesColors.border(isDark),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getFeatureIcon(feature.icon),
                                  size: 18,
                                  color: isSelected
                                      ? Colors.white
                                      : CarSalesColors.textSecondary(isDark),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  feature.name,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : CarSalesColors.textPrimary(isDark),
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  IconData _getFeatureIcon(String? iconName) {
    const iconMap = {
      'security': Icons.security,
      'shield': Icons.shield,
      'air': Icons.air,
      'ac_unit': Icons.ac_unit,
      'bluetooth': Icons.bluetooth,
      'usb': Icons.usb,
      'navigation': Icons.navigation,
      'camera': Icons.camera_alt,
      'camera_rear': Icons.camera_rear,
      'parking': Icons.local_parking,
      'sensor': Icons.sensors,
      'light': Icons.light,
      'sunroof': Icons.wb_sunny,
      'seat': Icons.event_seat,
      'leather': Icons.chair,
      'heated_seat': Icons.hot_tub,
      'cooled_seat': Icons.ac_unit,
      'electric_seat': Icons.electrical_services,
      'memory_seat': Icons.memory,
      'cruise': Icons.speed,
      'lane': Icons.swap_horiz,
      'blind_spot': Icons.visibility_off,
      'collision': Icons.warning,
      'abs': Icons.album,
      'esp': Icons.settings,
      'airbag': Icons.health_and_safety,
      'tire_pressure': Icons.tire_repair,
      'rain_sensor': Icons.water_drop,
      'light_sensor': Icons.light_mode,
      'auto_headlight': Icons.highlight,
      'fog_light': Icons.foggy,
      'led': Icons.lightbulb,
      'xenon': Icons.wb_incandescent,
      'keyless': Icons.key_off,
      'start_stop': Icons.power_settings_new,
      'electric_mirror': Icons.flip,
      'heated_mirror': Icons.hot_tub,
      'electric_window': Icons.window,
      'central_lock': Icons.lock,
      'alarm': Icons.notifications_active,
      'immobilizer': Icons.security,
      'check': Icons.check_circle,
    };
    return iconMap[iconName] ?? Icons.check_circle;
  }

  Widget _buildStep5PriceDescription(bool isDark) {
    return FadeTransition(
      opacity: _stepAnimationController,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Images
            _buildSectionTitle(isDark, 'Fotoğraflar', true),
            const SizedBox(height: 12),
            _buildImagePicker(isDark),
            const SizedBox(height: 24),

            // Title
            _buildSectionTitle(isDark, 'İlan Başlığı', true),
            const SizedBox(height: 12),
            _buildTextField(
              isDark,
              'Örn: 2023 Toyota Corolla 1.8 Hybrid',
              controller: _titleController,
            ),
            const SizedBox(height: 24),

            // Price
            _buildSectionTitle(isDark, 'Fiyat', true),
            const SizedBox(height: 12),
            _buildTextField(
              isDark,
              '1.250.000',
              controller: _priceController,
              keyboardType: TextInputType.number,
              suffix: 'TL',
            ),
            const SizedBox(height: 16),

            // Price Options
            Row(
              children: [
                Expanded(
                  child: _buildCheckOption(
                    isDark,
                    'Pazarlık Olur',
                    _isPriceNegotiable,
                    (value) => setState(() => _isPriceNegotiable = value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCheckOption(
                    isDark,
                    'Takas Olur',
                    _isExchangeAccepted,
                    (value) => setState(() => _isExchangeAccepted = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Description
            _buildSectionTitle(isDark, 'Açıklama', true),
            const SizedBox(height: 12),
            _buildTextField(
              isDark,
              'Aracınız hakkında detaylı bilgi verin...',
              controller: _descriptionController,
              maxLines: 6,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation(bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: 16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: CarSalesColors.card(isDark),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: GestureDetector(
                onTap: _previousStep,
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    border: Border.all(color: CarSalesColors.border(isDark)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_back,
                          color: CarSalesColors.textSecondary(isDark),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Geri',
                          style: TextStyle(
                            color: CarSalesColors.textSecondary(isDark),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: _currentStep == 0 ? 1 : 2,
            child: GestureDetector(
              onTap: _isSubmitting ? null : _nextStep,
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isSubmitting
                        ? [Colors.grey, Colors.grey]
                        : CarSalesColors.primaryGradient,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _isSubmitting
                      ? []
                      : [
                          BoxShadow(
                            color: CarSalesColors.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Center(
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currentStep == _totalSteps - 1
                                  ? 'İlanı Yayınla'
                                  : 'Devam Et',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _currentStep == _totalSteps - 1
                                  ? Icons.publish
                                  : Icons.arrow_forward,
                              color: Colors.white,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widgets
  Widget _buildSectionTitle(bool isDark, String title, bool isRequired) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: CarSalesColors.textPrimary(isDark),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (isRequired)
          const Text(
            ' *',
            style: TextStyle(
              color: CarSalesColors.accent,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  Widget _buildTextField(
    bool isDark,
    String hint, {
    TextEditingController? controller,
    Function(String)? onChanged,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: CarSalesColors.surface(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CarSalesColors.border(isDark)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(
          color: CarSalesColors.textPrimary(isDark),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: CarSalesColors.textTertiary(isDark),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          suffixText: suffix,
          suffixStyle: TextStyle(
            color: CarSalesColors.textSecondary(isDark),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildBrandSelector(bool isDark) {
    final brands = CarBrand.allBrands;

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: brands.length,
        itemBuilder: (context, index) {
          final brand = brands[index];
          final isSelected = _selectedBrand?.id == brand.id;

          return GestureDetector(
            onTap: () {
              setState(() => _selectedBrand = brand);
              HapticFeedback.selectionClick();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 85,
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? CarSalesColors.primary.withValues(alpha: 0.1)
                    : CarSalesColors.card(isDark),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? CarSalesColors.primary
                      : CarSalesColors.border(isDark),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: CarSalesColors.surface(isDark),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        brand.name.substring(0, 1),
                        style: TextStyle(
                          color: isSelected
                              ? CarSalesColors.primary
                              : CarSalesColors.textSecondary(isDark),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    brand.name.split('-').first.split(' ').first,
                    style: TextStyle(
                      color: isSelected
                          ? CarSalesColors.primary
                          : CarSalesColors.textSecondary(isDark),
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildYearSelector(bool isDark) {
    return _buildTextField(
      isDark,
      'Örn: 2020',
      controller: _yearController,
      keyboardType: TextInputType.number,
    );
  }

  Widget _buildBodyTypeSelector(bool isDark) {
    if (_isLoadingFilters) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: CarSalesColors.surface(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CarSalesColors.border(isDark)),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_bodyTypesData.isEmpty) {
      return Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: CarSalesColors.surface(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CarSalesColors.border(isDark)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: CarSalesColors.textTertiary(isDark), size: 20),
            const SizedBox(width: 8),
            Text('Kasa tipi bulunamadı', style: TextStyle(color: CarSalesColors.textTertiary(isDark))),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: CarSalesColors.surface(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CarSalesColors.border(isDark)),
      ),
      child: DropdownButton<String>(
        value: _selectedBodyTypeId,
        hint: Text('Kasa tipi seçin', style: TextStyle(color: CarSalesColors.textTertiary(isDark))),
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor: CarSalesColors.card(isDark),
        style: TextStyle(color: CarSalesColors.textPrimary(isDark)),
        icon: Icon(Icons.keyboard_arrow_down, color: CarSalesColors.textSecondary(isDark)),
        items: _bodyTypesData.map((type) {
          return DropdownMenuItem<String>(
            value: type.id,
            child: Text(type.name),
          );
        }).toList(),
        onChanged: (value) {
          setState(() => _selectedBodyTypeId = value);
          HapticFeedback.selectionClick();
        },
      ),
    );
  }

  Widget _buildColorSelector(bool isDark, bool isExterior) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: CarColor.values.map((color) {
        final isSelected = isExterior
            ? _selectedExteriorColor == color
            : _selectedInteriorColor == color;
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isExterior) {
                _selectedExteriorColor = color;
              } else {
                _selectedInteriorColor = color;
              }
            });
            HapticFeedback.selectionClick();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 72,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: CarSalesColors.card(isDark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? CarSalesColors.primary
                    : CarSalesColors.border(isDark),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: CarSalesColors.border(isDark),
                    ),
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          color: color.textColor,
                          size: 18,
                        )
                      : null,
                ),
                const SizedBox(height: 6),
                Text(
                  color.label,
                  style: TextStyle(
                    color: CarSalesColors.textSecondary(isDark),
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFuelTypeSelector(bool isDark) {
    if (_isLoadingFilters) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: CarSalesColors.surface(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CarSalesColors.border(isDark)),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_fuelTypesData.isEmpty) {
      return Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: CarSalesColors.surface(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CarSalesColors.border(isDark)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: CarSalesColors.textTertiary(isDark), size: 20),
            const SizedBox(width: 8),
            Text('Yakıt tipi bulunamadı', style: TextStyle(color: CarSalesColors.textTertiary(isDark))),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: CarSalesColors.surface(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CarSalesColors.border(isDark)),
      ),
      child: DropdownButton<String>(
        value: _selectedFuelTypeId,
        hint: Text('Yakıt tipi seçin', style: TextStyle(color: CarSalesColors.textTertiary(isDark))),
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor: CarSalesColors.card(isDark),
        style: TextStyle(color: CarSalesColors.textPrimary(isDark)),
        icon: Icon(Icons.keyboard_arrow_down, color: CarSalesColors.textSecondary(isDark)),
        items: _fuelTypesData.map((type) {
          return DropdownMenuItem<String>(
            value: type.id,
            child: Text(type.name),
          );
        }).toList(),
        onChanged: (value) {
          setState(() => _selectedFuelTypeId = value);
          HapticFeedback.selectionClick();
        },
      ),
    );
  }

  Widget _buildTransmissionSelector(bool isDark) {
    if (_isLoadingFilters) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: CarSalesColors.surface(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CarSalesColors.border(isDark)),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_transmissionsData.isEmpty) {
      return Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: CarSalesColors.surface(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CarSalesColors.border(isDark)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: CarSalesColors.textTertiary(isDark), size: 20),
            const SizedBox(width: 8),
            Text('Vites tipi bulunamadı', style: TextStyle(color: CarSalesColors.textTertiary(isDark))),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: CarSalesColors.surface(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CarSalesColors.border(isDark)),
      ),
      child: DropdownButton<String>(
        value: _selectedTransmissionId,
        hint: Text('Vites tipi seçin', style: TextStyle(color: CarSalesColors.textTertiary(isDark))),
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor: CarSalesColors.card(isDark),
        style: TextStyle(color: CarSalesColors.textPrimary(isDark)),
        icon: Icon(Icons.keyboard_arrow_down, color: CarSalesColors.textSecondary(isDark)),
        items: _transmissionsData.map((type) {
          return DropdownMenuItem<String>(
            value: type.id,
            child: Text(type.name),
          );
        }).toList(),
        onChanged: (value) {
          setState(() => _selectedTransmissionId = value);
          HapticFeedback.selectionClick();
        },
      ),
    );
  }

  Widget _buildTractionSelector(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: CarTraction.values.map((type) {
        final isSelected = _selectedTraction == type;
        return GestureDetector(
          onTap: () {
            setState(() => _selectedTraction = type);
            HapticFeedback.selectionClick();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? CarSalesColors.primary
                  : CarSalesColors.card(isDark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? CarSalesColors.primary
                    : CarSalesColors.border(isDark),
              ),
            ),
            child: Text(
              type.shortLabel,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : CarSalesColors.textPrimary(isDark),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildConditionSelector(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: CarCondition.values.map((condition) {
        final isSelected = _selectedCondition == condition;
        return GestureDetector(
          onTap: () {
            setState(() => _selectedCondition = condition);
            HapticFeedback.selectionClick();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? condition.color : CarSalesColors.card(isDark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? condition.color
                    : CarSalesColors.border(isDark),
              ),
            ),
            child: Text(
              condition.label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : CarSalesColors.textPrimary(isDark),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOwnerCounter(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CarSalesColors.card(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CarSalesColors.border(isDark)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              if (_previousOwners > 1) {
                setState(() => _previousOwners--);
                HapticFeedback.selectionClick();
              }
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: CarSalesColors.surface(isDark),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.remove,
                color: _previousOwners > 1
                    ? CarSalesColors.textPrimary(isDark)
                    : CarSalesColors.textTertiary(isDark),
              ),
            ),
          ),
          const SizedBox(width: 32),
          Text(
            '$_previousOwners',
            style: TextStyle(
              color: CarSalesColors.textPrimary(isDark),
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 32),
          GestureDetector(
            onTap: () {
              if (_previousOwners < 10) {
                setState(() => _previousOwners++);
                HapticFeedback.selectionClick();
              }
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: CarSalesColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption(
    bool isDark,
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CarSalesColors.card(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CarSalesColors.border(isDark)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: CarSalesColors.textPrimary(isDark),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: CarSalesColors.textTertiary(isDark),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: CarSalesColors.primary.withValues(alpha: 0.5),
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return CarSalesColors.primary;
              }
              return null;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckOption(
    bool isDark,
    String title,
    bool value,
    Function(bool) onChanged,
  ) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: value
              ? CarSalesColors.primary.withValues(alpha: 0.1)
              : CarSalesColors.card(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value
                ? CarSalesColors.primary
                : CarSalesColors.border(isDark),
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: value ? CarSalesColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: value
                      ? CarSalesColors.primary
                      : CarSalesColors.border(isDark),
                  width: 2,
                ),
              ),
              child: value
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: value
                    ? CarSalesColors.primary
                    : CarSalesColors.textPrimary(isDark),
                fontWeight: value ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker(bool isDark) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _localImages.length + _selectedImages.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            // Add Image Button
            return GestureDetector(
              onTap: _isUploadingImage ? null : _showImagePickerOptions,
              child: Container(
                width: 120,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: CarSalesColors.surface(isDark),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: CarSalesColors.primary,
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                ),
                child: _isUploadingImage
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: CarSalesColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add_a_photo,
                              color: CarSalesColors.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Fotoğraf Ekle',
                            style: TextStyle(
                              color: CarSalesColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${_localImages.length + _selectedImages.length}/10',
                            style: TextStyle(
                              color: CarSalesColors.textSecondary(isDark),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
              ),
            );
          }

          // Local Images (not yet uploaded)
          final localIndex = index - 1;
          if (localIndex < _localImages.length) {
            return Container(
              width: 120,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: CarSalesColors.surface(isDark),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _buildLocalImage(localIndex),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          final removed = _localImages.removeAt(localIndex);
                          _imageBytes.remove(removed.path);
                        });
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: CarSalesColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // Remote Images (already uploaded)
          final remoteIndex = localIndex - _localImages.length;
          return Container(
            width: 120,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: CarSalesColors.surface(isDark),
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: _selectedImages[remoteIndex],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (_, __) => Container(
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_not_supported, color: Colors.grey),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedImages.removeAt(remoteIndex);
                      });
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: CarSalesColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showImagePickerOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_localImages.length + _selectedImages.length >= 10) {
      AppDialogs.showWarning(context, 'En fazla 10 fotoğraf ekleyebilirsiniz');
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: CarSalesColors.card(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: CarSalesColors.border(isDark),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Fotoğraf Ekle',
                style: TextStyle(
                  color: CarSalesColors.textPrimary(isDark),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: CarSalesColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt, color: CarSalesColors.primary),
                ),
                title: Text('Kamera', style: TextStyle(color: CarSalesColors.textPrimary(isDark))),
                subtitle: Text('Fotoğraf çek', style: TextStyle(color: CarSalesColors.textSecondary(isDark))),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: CarSalesColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library, color: CarSalesColors.primary),
                ),
                title: Text('Galeri', style: TextStyle(color: CarSalesColors.textPrimary(isDark))),
                subtitle: Text('Galeriden seç', style: TextStyle(color: CarSalesColors.textSecondary(isDark))),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: CarSalesColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_outlined, color: CarSalesColors.primary),
                ),
                title: Text('Çoklu Seçim', style: TextStyle(color: CarSalesColors.textPrimary(isDark))),
                subtitle: Text('Birden fazla fotoğraf seç', style: TextStyle(color: CarSalesColors.textSecondary(isDark))),
                onTap: () {
                  Navigator.pop(context);
                  _pickMultipleImages();
                },
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        // Pre-load bytes for web
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          _imageBytes[image.path] = bytes;
        }
        setState(() {
          _localImages.add(image);
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        AppDialogs.showError(context, 'Fotoğraf seçilemedi: $e');
      }
    }
  }

  Future<void> _pickMultipleImages() async {
    try {
      final remaining = 10 - _localImages.length - _selectedImages.length;
      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
        limit: remaining,
      );

      if (images.isNotEmpty && mounted) {
        // Pre-load bytes for web
        if (kIsWeb) {
          for (final image in images) {
            final bytes = await image.readAsBytes();
            _imageBytes[image.path] = bytes;
          }
        }
        setState(() {
          for (final image in images) {
            if (_localImages.length + _selectedImages.length < 10) {
              _localImages.add(image);
            }
          }
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
      if (mounted) {
        AppDialogs.showError(context, 'Fotoğraflar seçilemedi: $e');
      }
    }
  }

  Widget _buildLocalImage(int index) {
    final xFile = _localImages[index];

    if (kIsWeb) {
      // Web: Use cached bytes with Image.memory
      final bytes = _imageBytes[xFile.path];
      if (bytes != null) {
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      }
      // Fallback: load bytes asynchronously
      return FutureBuilder<Uint8List>(
        future: xFile.readAsBytes(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Image.memory(
              snapshot.data!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            );
          }
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        },
      );
    } else {
      // Mobile: Use Image.file
      return Image.file(
        File(xFile.path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
  }

  Widget _buildSuccessDialog(BuildContext dialogContext) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: CarSalesColors.card(isDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: CarSalesColors.primaryGradient,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'İlan Oluşturuldu!',
              style: TextStyle(
                color: CarSalesColors.textPrimary(isDark),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'İlanınız başarıyla oluşturuldu ve onay sürecine alındı.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: CarSalesColors.textSecondary(isDark),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(); // Close dialog
                  Navigator.of(context).pop(); // Go back to car sales home
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: CarSalesColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Tamam',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
