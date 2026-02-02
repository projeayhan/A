import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/car_models.dart';
import '../../providers/dealer_provider.dart';
import '../../services/listing_service.dart';

class AddListingScreen extends ConsumerStatefulWidget {
  final String? listingId;

  const AddListingScreen({super.key, this.listingId});

  @override
  ConsumerState<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends ConsumerState<AddListingScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1: Temel Bilgiler
  CarBrand? _selectedBrand;
  final _modelController = TextEditingController();
  int? _selectedYear;
  CarBodyType? _selectedBodyType;
  String? _selectedExteriorColor;
  String? _selectedInteriorColor;

  // Step 2: Teknik Özellikler
  CarFuelType? _selectedFuelType;
  CarTransmission? _selectedTransmission;
  CarTraction? _selectedTraction;
  final _engineCcController = TextEditingController();
  final _horsepowerController = TextEditingController();
  final _mileageController = TextEditingController();

  // Step 3: Durum & Geçmiş
  CarCondition? _selectedCondition;
  int _previousOwners = 1;
  bool _hasOriginalPaint = true;
  bool _hasAccidentHistory = false;
  bool _hasWarranty = false;
  final _warrantyDetailsController = TextEditingController();
  final _damageReportController = TextEditingController();

  // Step 4: Özellikler
  Set<String> _selectedFeatures = {};

  // Step 5: Fiyat & Açıklama
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isPriceNegotiable = false;
  bool _isExchangeAccepted = false;
  List<String> _images = [];
  String _selectedCurrency = 'TRY';

  // Para birimleri
  final List<Map<String, String>> _currencies = [
    {'code': 'TRY', 'symbol': '₺', 'name': 'Türk Lirası'},
    {'code': 'USD', 'symbol': '\$', 'name': 'Amerikan Doları'},
    {'code': 'EUR', 'symbol': '€', 'name': 'Euro'},
    {'code': 'GBP', 'symbol': '£', 'name': 'İngiliz Sterlini'},
  ];

  // Dış Renkler
  final List<String> _exteriorColors = [
    'Beyaz', 'Siyah', 'Gümüş', 'Gri', 'Antrasit', 'Kırmızı', 'Mavi',
    'Lacivert', 'Yeşil', 'Sarı', 'Turuncu', 'Kahverengi', 'Bej',
    'Bordo', 'Şampanya', 'Altın', 'Bronz', 'Mor', 'Pembe', 'Turkuaz',
    'Koyu Mavi', 'Koyu Yeşil', 'Koyu Gri', 'Açık Mavi', 'Açık Gri',
    'Metalik Gri', 'Metalik Mavi', 'Metalik Kırmızı', 'Sedef Beyaz',
    'GT Gümüş', 'Karbon Siyah', 'Alpin Beyaz', 'Estoril Mavi'
  ];

  // İç Renkler
  final List<String> _interiorColors = [
    'Siyah', 'Bej', 'Krem', 'Kahverengi', 'Gri', 'Bordo', 'Beyaz',
    'Fildişi', 'Taba', 'Açık Gri', 'Koyu Gri', 'Kırmızı', 'Mavi',
    'Siyah/Kırmızı', 'Siyah/Beyaz', 'Siyah/Turuncu', 'Bej/Kahverengi'
  ];

  bool get isEditing => widget.listingId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _loadListing();
    }
  }

  @override
  void dispose() {
    _modelController.dispose();
    _engineCcController.dispose();
    _horsepowerController.dispose();
    _mileageController.dispose();
    _warrantyDetailsController.dispose();
    _damageReportController.dispose();
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadListing() async {
    // TODO: Load existing listing for editing
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CarSalesColors.backgroundLight,
      appBar: AppBar(
        title: Text(isEditing ? 'İlanı Düzenle' : 'Yeni İlan'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Progress Indicator
            _buildProgressIndicator(),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: _buildCurrentStep(),
                ),
              ),
            ),

            // Bottom Navigation
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Colors.white,
      child: Row(
        children: List.generate(5, (index) {
          final isCompleted = index < _currentStep;
          final isCurrent = index == _currentStep;

          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? CarSalesColors.success
                        : isCurrent
                            ? CarSalesColors.primary
                            : Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isCurrent ? Colors.white : Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                if (index < 4)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isCompleted ? CarSalesColors.success : Colors.grey[300],
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
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      case 3:
        return _buildStep4();
      case 4:
        return _buildStep5();
      default:
        return _buildStep1();
    }
  }

  // ==================== STEP 1: TEMEL BİLGİLER ====================
  Widget _buildStep1() {
    final brandsAsync = ref.watch(brandsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Temel Bilgiler',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Aracınızın marka, model ve yıl bilgilerini girin',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 24),

        // Marka Seçimi
        const Text('Marka *', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        brandsAsync.when(
          data: (brands) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: brands.map((brand) {
              final isSelected = _selectedBrand?.id == brand.id;
              return GestureDetector(
                onTap: () => setState(() => _selectedBrand = brand),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? CarSalesColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? CarSalesColors.primary : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    brand.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF1E293B),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('Hata: $e'),
        ),
        const SizedBox(height: 24),

        // Model
        TextFormField(
          controller: _modelController,
          decoration: const InputDecoration(
            labelText: 'Model *',
            hintText: 'Örn: Corolla, Civic, A4',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Model gerekli';
            return null;
          },
        ),
        const SizedBox(height: 24),

        // Yıl
        const Text('Yıl *', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(15, (index) {
            final year = DateTime.now().year - index;
            final isSelected = _selectedYear == year;
            return GestureDetector(
              onTap: () => setState(() => _selectedYear = year),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? CarSalesColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? CarSalesColors.primary : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  '$year',
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF1E293B),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 24),

        // Kasa Tipi
        const Text('Kasa Tipi *', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CarBodyType.values.map((type) {
            final isSelected = _selectedBodyType == type;
            return GestureDetector(
              onTap: () => setState(() => _selectedBodyType = type),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? CarSalesColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? CarSalesColors.primary : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  type.label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF1E293B),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // Renkler
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Dış Renk', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedExteriorColor,
                    decoration: const InputDecoration(hintText: 'Renk seçin'),
                    items: _exteriorColors.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _selectedExteriorColor = v),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('İç Renk', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedInteriorColor,
                    decoration: const InputDecoration(hintText: 'Renk seçin'),
                    items: _interiorColors.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _selectedInteriorColor = v),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==================== STEP 2: TEKNİK ÖZELLİKLER ====================
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Teknik Özellikler',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Aracınızın motor ve teknik bilgilerini girin',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 24),

        // Yakıt Tipi
        const Text('Yakıt Tipi *', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CarFuelType.values.map((type) {
            final isSelected = _selectedFuelType == type;
            return GestureDetector(
              onTap: () => setState(() => _selectedFuelType = type),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? type.color : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? type.color : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  type.label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF1E293B),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // Vites Tipi
        const Text('Vites Tipi *', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CarTransmission.values.map((type) {
            final isSelected = _selectedTransmission == type;
            return GestureDetector(
              onTap: () => setState(() => _selectedTransmission = type),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? CarSalesColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? CarSalesColors.primary : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  type.label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF1E293B),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // Çekiş Tipi
        const Text('Çekiş Tipi', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CarTraction.values.map((type) {
            final isSelected = _selectedTraction == type;
            return GestureDetector(
              onTap: () => setState(() => _selectedTraction = type),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? CarSalesColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? CarSalesColors.primary : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  type.label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF1E293B),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // Motor ve Beygir
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _engineCcController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Motor Hacmi (cc)',
                  hintText: 'Örn: 1600',
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _horsepowerController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Beygir Gücü (HP)',
                  hintText: 'Örn: 120',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Kilometre
        TextFormField(
          controller: _mileageController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Kilometre *',
            hintText: 'Örn: 50000',
            suffixText: 'km',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Kilometre gerekli';
            return null;
          },
        ),
      ],
    );
  }

  // ==================== STEP 3: DURUM & GEÇMİŞ ====================
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Durum & Geçmiş',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Aracınızın durumu ve geçmiş bilgileri',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 24),

        // Araç Durumu
        const Text('Araç Durumu *', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CarCondition.values.map((condition) {
            final isSelected = _selectedCondition == condition;
            return GestureDetector(
              onTap: () => setState(() => _selectedCondition = condition),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? condition.color : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? condition.color : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  condition.label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF1E293B),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // Sahip Sayısı
        const Text('Kaçıncı Sahibi', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              onPressed: _previousOwners > 1
                  ? () => setState(() => _previousOwners--)
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
              color: CarSalesColors.primary,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                '$_previousOwners',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              onPressed: _previousOwners < 10
                  ? () => setState(() => _previousOwners++)
                  : null,
              icon: const Icon(Icons.add_circle_outline),
              color: CarSalesColors.primary,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Toggle Seçenekleri
        _buildToggleOption(
          'Orijinal Boya',
          'Araç boyası orijinal mi?',
          _hasOriginalPaint,
          (v) => setState(() => _hasOriginalPaint = v),
        ),
        _buildToggleOption(
          'Kaza Kaydı',
          'Araç kaza geçmişi var mı?',
          _hasAccidentHistory,
          (v) => setState(() => _hasAccidentHistory = v),
        ),
        _buildToggleOption(
          'Garanti',
          'Araç garantili mi?',
          _hasWarranty,
          (v) => setState(() => _hasWarranty = v),
        ),

        if (_hasWarranty) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _warrantyDetailsController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Garanti Detayları',
              hintText: 'Garanti süresi ve kapsamı...',
            ),
          ),
        ],

        if (_hasAccidentHistory) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _damageReportController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Hasar Raporu',
              hintText: 'Kaza detayları ve hasar bilgileri...',
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildToggleOption(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
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
              return Colors.grey.shade400;
            }),
          ),
        ],
      ),
    );
  }

  // ==================== STEP 4: ÖZELLİKLER ====================
  Widget _buildStep4() {
    final featuresAsync = ref.watch(featuresProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Özellikler',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Aracınızda bulunan özellikleri seçin (${_selectedFeatures.length} seçili)',
          style: const TextStyle(color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 24),

        featuresAsync.when(
          data: (features) {
            final categories = features.map((f) => f.category).toSet().toList();

            return Column(
              children: categories.map((category) {
                final categoryFeatures = features.where((f) => f.category == category).toList();
                return _buildFeatureCategory(category, categoryFeatures);
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Hata: $e'),
        ),
      ],
    );
  }

  Widget _buildFeatureCategory(String category, List<CarFeature> features) {
    final categoryNames = {
      'security': 'Güvenlik',
      'comfort': 'Konfor',
      'multimedia': 'Multimedya',
      'exterior': 'Dış Donanım',
      'interior': 'İç Donanım',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          categoryNames[category] ?? category,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: features.map((feature) {
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
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? CarSalesColors.success.withValues(alpha: 0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? CarSalesColors.success : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected)
                      const Icon(Icons.check, color: CarSalesColors.success, size: 16),
                    if (isSelected) const SizedBox(width: 4),
                    Text(
                      feature.name,
                      style: TextStyle(
                        color: isSelected ? CarSalesColors.success : const Color(0xFF1E293B),
                        fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                        fontSize: 13,
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
  }

  // ==================== STEP 5: FİYAT & AÇIKLAMA ====================
  Widget _buildStep5() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fiyat & Açıklama',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'İlan başlığı, fiyat ve açıklama bilgilerini girin',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 24),

        // Başlık
        TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'İlan Başlığı *',
            hintText: 'Örn: 2022 Toyota Corolla 1.6 Dream',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Başlık gerekli';
            return null;
          },
        ),
        const SizedBox(height: 24),

        // Fiyat ve Para Birimi
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Fiyat *',
                  hintText: 'Örn: 750000',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Fiyat gerekli';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedCurrency,
                decoration: const InputDecoration(labelText: 'Para Birimi'),
                items: _currencies.map((c) => DropdownMenuItem(
                  value: c['code'],
                  child: Text('${c['symbol']} ${c['code']}'),
                )).toList(),
                onChanged: (v) => setState(() => _selectedCurrency = v ?? 'TRY'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Fiyat Seçenekleri
        Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                value: _isPriceNegotiable,
                onChanged: (v) => setState(() => _isPriceNegotiable = v ?? false),
                title: const Text('Pazarlık Payı Var', style: TextStyle(fontSize: 14)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            Expanded(
              child: CheckboxListTile(
                value: _isExchangeAccepted,
                onChanged: (v) => setState(() => _isExchangeAccepted = v ?? false),
                title: const Text('Takas Olur', style: TextStyle(fontSize: 14)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Açıklama
        TextFormField(
          controller: _descriptionController,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Açıklama',
            hintText: 'Aracınız hakkında detaylı bilgi verin...',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 24),

        // Fotoğraflar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Fotoğraflar', style: TextStyle(fontWeight: FontWeight.w600)),
            Text('${_images.length}/10', style: const TextStyle(color: Color(0xFF64748B))),
          ],
        ),
        const SizedBox(height: 8),

        // Seçilen fotoğraflar
        if (_images.isNotEmpty) ...[
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: _images[index].startsWith('http')
                            ? Image.network(_images[index], fit: BoxFit.cover, width: 120, height: 120)
                            : Image.file(File(_images[index]), fit: BoxFit.cover, width: 120, height: 120),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => _images.removeAt(index)),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                      if (index == 0)
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: CarSalesColors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Kapak', style: TextStyle(color: Colors.white, fontSize: 10)),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Fotoğraf ekleme butonu
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.solid),
          ),
          child: Column(
            children: [
              Icon(Icons.cloud_upload_outlined, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              const Text(
                'Fotoğraf yüklemek için tıklayın',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
              const Text(
                'En fazla 10 fotoğraf, her biri max 5MB',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _images.length < 10 ? _pickImagesFromGallery : null,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galeriden'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _images.length < 10 ? _pickImageFromCamera : null,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Kamera'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            OutlinedButton(
              onPressed: () => setState(() => _currentStep--),
              child: const Text('Geri'),
            ),
          const Spacer(),
          if (_currentStep < 4)
            ElevatedButton(
              onPressed: _validateAndContinue,
              child: const Text('Devam Et'),
            )
          else
            ElevatedButton(
              onPressed: _isLoading ? null : _submitListing,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(isEditing ? 'Güncelle' : 'İlanı Yayınla'),
            ),
        ],
      ),
    );
  }

  void _validateAndContinue() {
    bool isValid = true;

    switch (_currentStep) {
      case 0:
        isValid = _selectedBrand != null &&
            _modelController.text.isNotEmpty &&
            _selectedYear != null &&
            _selectedBodyType != null;
        break;
      case 1:
        isValid = _selectedFuelType != null &&
            _selectedTransmission != null &&
            _mileageController.text.isNotEmpty;
        break;
      case 2:
        isValid = _selectedCondition != null;
        break;
    }

    if (isValid) {
      setState(() => _currentStep++);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen zorunlu alanları doldurun'),
          backgroundColor: CarSalesColors.accent,
        ),
      );
    }
  }

  // ==================== FOTOĞRAF İŞLEMLERİ ====================

  Future<void> _pickImagesFromGallery() async {
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFiles.isNotEmpty) {
        final remainingSlots = 10 - _images.length;
        final filesToAdd = pickedFiles.take(remainingSlots).toList();

        setState(() => _isLoading = true);

        for (final file in filesToAdd) {
          final url = await _uploadImage(file);
          if (url != null) {
            setState(() => _images.add(url));
          }
        }

        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fotoğraf seçilemedi: $e'), backgroundColor: CarSalesColors.accent),
        );
      }
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() => _isLoading = true);

        final url = await _uploadImage(pickedFile);
        if (url != null) {
          setState(() => _images.add(url));
        }

        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fotoğraf çekilemedi: $e'), backgroundColor: CarSalesColors.accent),
        );
      }
    }
  }

  Future<String?> _uploadImage(XFile file) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final bytes = await file.readAsBytes();

      // Dosya uzantısı ve MIME type belirleme (web için özel işlem)
      String fileExt;
      String contentType;

      // XFile'ın mimeType'ını kontrol et
      if (file.mimeType != null && file.mimeType!.isNotEmpty) {
        contentType = file.mimeType!;
        fileExt = _getExtensionFromMimeType(contentType);
      } else if (file.name.contains('.')) {
        // Dosya adından uzantıyı al
        fileExt = file.name.split('.').last.toLowerCase();
        contentType = 'image/$fileExt';
      } else {
        // Magic bytes'tan dosya tipini belirle
        fileExt = _detectImageType(bytes);
        contentType = 'image/$fileExt';
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_images.length}.$fileExt';
      final filePath = 'car-listings/$userId/$fileName';

      await supabase.storage.from('images').uploadBinary(
        filePath,
        bytes,
        fileOptions: FileOptions(contentType: contentType),
      );

      final url = supabase.storage.from('images').getPublicUrl(filePath);
      return url;
    } catch (e) {
      debugPrint('Fotoğraf yüklenemedi: $e');
      return null;
    }
  }

  String _getExtensionFromMimeType(String mimeType) {
    switch (mimeType.toLowerCase()) {
      case 'image/jpeg':
      case 'image/jpg':
        return 'jpg';
      case 'image/png':
        return 'png';
      case 'image/gif':
        return 'gif';
      case 'image/webp':
        return 'webp';
      case 'image/heic':
        return 'heic';
      default:
        return 'jpg';
    }
  }

  String _detectImageType(List<int> bytes) {
    if (bytes.length < 4) return 'jpg';

    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
      return 'png';
    }
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'jpg';
    }
    // GIF: 47 49 46 38
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38) {
      return 'gif';
    }
    // WebP: 52 49 46 46 ... 57 45 42 50
    if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) {
      return 'webp';
    }

    return 'jpg'; // Varsayılan
  }

  Future<void> _submitListing() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final service = ListingService();

      final listing = CarListing(
        id: widget.listingId ?? '',
        userId: '',
        title: _titleController.text,
        description: _descriptionController.text,
        brandId: _selectedBrand!.id,
        brandName: _selectedBrand!.name,
        modelName: _modelController.text,
        year: _selectedYear!,
        bodyType: _selectedBodyType!,
        fuelType: _selectedFuelType!,
        transmission: _selectedTransmission!,
        traction: _selectedTraction ?? CarTraction.fwd,
        engineCc: int.tryParse(_engineCcController.text),
        horsepower: int.tryParse(_horsepowerController.text),
        mileage: int.parse(_mileageController.text),
        exteriorColor: _selectedExteriorColor,
        interiorColor: _selectedInteriorColor,
        condition: _selectedCondition!,
        previousOwners: _previousOwners,
        hasOriginalPaint: _hasOriginalPaint,
        hasAccidentHistory: _hasAccidentHistory,
        hasWarranty: _hasWarranty,
        warrantyDetails: _warrantyDetailsController.text.isEmpty ? null : _warrantyDetailsController.text,
        damageReport: _damageReportController.text.isEmpty ? null : _damageReportController.text,
        price: double.parse(_priceController.text),
        currency: _selectedCurrency,
        isPriceNegotiable: _isPriceNegotiable,
        isExchangeAccepted: _isExchangeAccepted,
        images: _images,
        features: _selectedFeatures.toList(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (isEditing) {
        await service.updateListing(widget.listingId!, listing.toJson());
      } else {
        await service.createListing(listing);
      }

      if (!mounted) return;

      _showSuccessDialog();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: CarSalesColors.accent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: CarSalesColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle, color: CarSalesColors.success),
            ),
            const SizedBox(width: 12),
            Text(isEditing ? 'İlan Güncellendi' : 'İlan Oluşturuldu'),
          ],
        ),
        content: Text(
          isEditing
              ? 'İlanınız başarıyla güncellendi.'
              : 'İlanınız başarıyla oluşturuldu ve onay için gönderildi.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/panel');
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }
}
