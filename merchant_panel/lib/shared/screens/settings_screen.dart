import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/models/merchant_models.dart';
import '../../core/providers/merchant_provider.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/geocoding_service.dart';
import '../widgets/delivery_zones_map.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

// Working hours model
class WorkingHours {
  final String id;
  final String merchantId;
  final int dayOfWeek;
  final bool isOpen;
  final String openTime;
  final String closeTime;

  WorkingHours({
    required this.id,
    required this.merchantId,
    required this.dayOfWeek,
    required this.isOpen,
    required this.openTime,
    required this.closeTime,
  });

  factory WorkingHours.fromJson(Map<String, dynamic> json) {
    return WorkingHours(
      id: json['id'] ?? '',
      merchantId: json['merchant_id'] ?? '',
      dayOfWeek: json['day_of_week'] ?? 0,
      isOpen: json['is_open'] ?? true,
      openTime: json['open_time']?.toString().substring(0, 5) ?? '10:00',
      closeTime: json['close_time']?.toString().substring(0, 5) ?? '22:00',
    );
  }
}

// Merchant settings model
class MerchantSettings {
  final String id;
  final String merchantId;
  final bool deliveryEnabled;
  final bool pickupEnabled;
  final double minOrderAmount;
  final double deliveryFee;
  final double freeDeliveryThreshold;
  final int minPreparationTime;
  final int maxPreparationTime;
  final bool notifyNewOrder;
  final bool notifyOrderCancel;
  final bool notifySoundEnabled;
  final bool notifyNewReview;
  final bool notifyLowStock;
  final bool notifyWeeklyReport;

  MerchantSettings({
    required this.id,
    required this.merchantId,
    required this.deliveryEnabled,
    required this.pickupEnabled,
    required this.minOrderAmount,
    required this.deliveryFee,
    required this.freeDeliveryThreshold,
    required this.minPreparationTime,
    required this.maxPreparationTime,
    required this.notifyNewOrder,
    required this.notifyOrderCancel,
    required this.notifySoundEnabled,
    required this.notifyNewReview,
    required this.notifyLowStock,
    required this.notifyWeeklyReport,
  });

  factory MerchantSettings.fromJson(Map<String, dynamic> json) {
    return MerchantSettings(
      id: json['id'] ?? '',
      merchantId: json['merchant_id'] ?? '',
      deliveryEnabled: json['delivery_enabled'] ?? true,
      pickupEnabled: json['pickup_enabled'] ?? true,
      minOrderAmount: (json['min_order_amount'] ?? 50).toDouble(),
      deliveryFee: (json['delivery_fee'] ?? 15).toDouble(),
      freeDeliveryThreshold: (json['free_delivery_threshold'] ?? 150).toDouble(),
      minPreparationTime: json['min_preparation_time'] ?? 20,
      maxPreparationTime: json['max_preparation_time'] ?? 45,
      notifyNewOrder: json['notify_new_order'] ?? true,
      notifyOrderCancel: json['notify_order_cancel'] ?? true,
      notifySoundEnabled: json['notify_sound_enabled'] ?? true,
      notifyNewReview: json['notify_new_review'] ?? true,
      notifyLowStock: json['notify_low_stock'] ?? true,
      notifyWeeklyReport: json['notify_weekly_report'] ?? false,
    );
  }

  factory MerchantSettings.empty(String merchantId) {
    return MerchantSettings(
      id: '',
      merchantId: merchantId,
      deliveryEnabled: true,
      pickupEnabled: true,
      minOrderAmount: 50,
      deliveryFee: 15,
      freeDeliveryThreshold: 150,
      minPreparationTime: 20,
      maxPreparationTime: 45,
      notifyNewOrder: true,
      notifyOrderCancel: true,
      notifySoundEnabled: true,
      notifyNewReview: true,
      notifyLowStock: true,
      notifyWeeklyReport: false,
    );
  }
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _selectedTab = 0;

  // Business info controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  String? _logoUrl;
  String? _coverUrl;
  bool _isLoading = false;
  bool _dataLoaded = false;

  // Working hours state
  List<WorkingHours> _workingHours = [];
  bool _workingHoursLoading = true;

  // Settings state
  MerchantSettings? _settings;
  bool _settingsLoading = true;

  // Delivery settings controllers
  final _minOrderController = TextEditingController();
  final _deliveryFeeController = TextEditingController();
  final _freeDeliveryController = TextEditingController();
  final _minPrepTimeController = TextEditingController();
  final _maxPrepTimeController = TextEditingController();

  final _tabs = [
    'Isletme Bilgileri',
    'Calisma Saatleri',
    'Teslimat Ayarlari',
    'Bildirimler',
    'Dogrulama',
    'Destek',
    'Hesap',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMerchantData();
      _loadWorkingHours();
      _loadSettings();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _minOrderController.dispose();
    _deliveryFeeController.dispose();
    _freeDeliveryController.dispose();
    _minPrepTimeController.dispose();
    _maxPrepTimeController.dispose();
    super.dispose();
  }

  Future<void> _loadMerchantData() async {
    final merchant = ref.read(currentMerchantProvider).valueOrNull;
    if (merchant == null || _dataLoaded) return;

    setState(() {
      _nameController.text = merchant.businessName;
      _descriptionController.text = merchant.description ?? '';
      _phoneController.text = merchant.phone ?? '';
      _emailController.text = merchant.email ?? '';
      _addressController.text = merchant.address ?? '';
      _latitudeController.text = merchant.latitude?.toString() ?? '';
      _longitudeController.text = merchant.longitude?.toString() ?? '';
      _logoUrl = merchant.logoUrl;
      _coverUrl = merchant.coverUrl;
      _dataLoaded = true;
    });
  }

  Future<void> _loadWorkingHours() async {
    final merchant = ref.read(currentMerchantProvider).valueOrNull;
    if (merchant == null) return;

    try {
      final supabase = ref.read(supabaseProvider);

      // First check if working hours exist
      final response = await supabase
          .from('merchant_working_hours')
          .select()
          .eq('merchant_id', merchant.id)
          .order('day_of_week');

      if (response.isEmpty) {
        // Initialize default working hours
        await supabase.rpc(
          'initialize_merchant_working_hours',
          params: {'p_merchant_id': merchant.id},
        );

        // Fetch again
        final newResponse = await supabase
            .from('merchant_working_hours')
            .select()
            .eq('merchant_id', merchant.id)
            .order('day_of_week');

        if (mounted) {
          setState(() {
            _workingHours =
                newResponse.map<WorkingHours>((e) => WorkingHours.fromJson(e)).toList();
            _workingHoursLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _workingHours =
                response.map<WorkingHours>((e) => WorkingHours.fromJson(e)).toList();
            _workingHoursLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _workingHoursLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Calisma saatleri yuklenemedi: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _loadSettings() async {
    final merchant = ref.read(currentMerchantProvider).valueOrNull;
    if (merchant == null) return;

    try {
      final supabase = ref.read(supabaseProvider);

      final response = await supabase
          .from('merchant_settings')
          .select()
          .eq('merchant_id', merchant.id)
          .maybeSingle();

      if (response == null) {
        // Initialize default settings
        await supabase.rpc(
          'initialize_merchant_settings',
          params: {'p_merchant_id': merchant.id},
        );

        // Fetch again
        final newResponse = await supabase
            .from('merchant_settings')
            .select()
            .eq('merchant_id', merchant.id)
            .single();

        if (mounted) {
          final settings = MerchantSettings.fromJson(newResponse);
          setState(() {
            _settings = settings;
            _settingsLoading = false;
          });
          _updateSettingsControllers(settings);
        }
      } else {
        if (mounted) {
          final settings = MerchantSettings.fromJson(response);
          setState(() {
            _settings = settings;
            _settingsLoading = false;
          });
          _updateSettingsControllers(settings);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _settingsLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ayarlar yuklenemedi: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _updateSettingsControllers(MerchantSettings settings) {
    _minOrderController.text = settings.minOrderAmount.toStringAsFixed(0);
    _deliveryFeeController.text = settings.deliveryFee.toStringAsFixed(0);
    _freeDeliveryController.text = settings.freeDeliveryThreshold.toStringAsFixed(0);
    _minPrepTimeController.text = settings.minPreparationTime.toString();
    _maxPrepTimeController.text = settings.maxPreparationTime.toString();
  }

  Future<void> _pickAndUploadImage(String type) async {
    final merchant = ref.read(currentMerchantProvider).valueOrNull;
    if (merchant == null) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() => _isLoading = true);

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() => _isLoading = false);
        return;
      }

      final supabase = ref.read(supabaseProvider);
      final safeFileName = file.name.replaceAll(
        RegExp(r'[^a-zA-Z0-9._-]'),
        '_',
      );
      final fileName =
          '${type}_${merchant.id}_${DateTime.now().millisecondsSinceEpoch}_$safeFileName';

      await supabase.storage
          .from('images')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      final imageUrl = supabase.storage.from('images').getPublicUrl(fileName);

      // Update merchant in database
      final updateField = type == 'logo' ? 'logo_url' : 'cover_url';
      await supabase
          .from('merchants')
          .update({updateField: imageUrl})
          .eq('id', merchant.id);

      setState(() {
        if (type == 'logo') {
          _logoUrl = imageUrl;
        } else {
          _coverUrl = imageUrl;
        }
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${type == 'logo' ? 'Logo' : 'Kapak resmi'} yuklendi!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _saveBusinessInfo() async {
    final merchant = ref.read(currentMerchantProvider).valueOrNull;
    if (merchant == null) return;

    setState(() => _isLoading = true);

    try {
      final supabase = ref.read(supabaseProvider);
      await supabase
          .from('merchants')
          .update({
            'business_name': _nameController.text.trim(),
            'description': _descriptionController.text.trim(),
            'phone': _phoneController.text.trim(),
            'email': _emailController.text.trim(),
            'address': _addressController.text.trim(),
          })
          .eq('id', merchant.id);

      // Reload merchant data
      await ref
          .read(currentMerchantProvider.notifier)
          .loadMerchantByUserId(supabase.auth.currentUser!.id);

      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bilgiler kaydedildi!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _updateWorkingHours(WorkingHours hours, {bool? isOpen, String? openTime, String? closeTime}) async {
    try {
      final supabase = ref.read(supabaseProvider);

      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (isOpen != null) updates['is_open'] = isOpen;
      if (openTime != null) updates['open_time'] = openTime;
      if (closeTime != null) updates['close_time'] = closeTime;

      await supabase
          .from('merchant_working_hours')
          .update(updates)
          .eq('id', hours.id);

      // Update local state
      setState(() {
        final index = _workingHours.indexWhere((h) => h.id == hours.id);
        if (index != -1) {
          _workingHours[index] = WorkingHours(
            id: hours.id,
            merchantId: hours.merchantId,
            dayOfWeek: hours.dayOfWeek,
            isOpen: isOpen ?? hours.isOpen,
            openTime: openTime ?? hours.openTime,
            closeTime: closeTime ?? hours.closeTime,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _formatCoordinate(TextEditingController controller, String value, {required bool isLatitude}) {
    // Zaten nokta varsa dokunma
    if (value.contains('.')) return;

    // Sadece rakamları al
    final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return;

    String formatted;
    if (isLatitude) {
      // Enlem: 2 haneli tam kısım (35.165554)
      if (digitsOnly.length > 2) {
        formatted = '${digitsOnly.substring(0, 2)}.${digitsOnly.substring(2)}';
      } else {
        formatted = digitsOnly;
      }
    } else {
      // Boylam: 2 haneli tam kısım (33.909293)
      if (digitsOnly.length > 2) {
        formatted = '${digitsOnly.substring(0, 2)}.${digitsOnly.substring(2)}';
      } else {
        formatted = digitsOnly;
      }
    }

    if (formatted != controller.text) {
      controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  Future<void> _saveLocationCoordinates() async {
    final merchant = ref.read(currentMerchantProvider).valueOrNull;
    if (merchant == null) return;

    final latText = _latitudeController.text.trim();
    final lngText = _longitudeController.text.trim();

    final lat = double.tryParse(latText);
    final lng = double.tryParse(lngText);

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gecerli koordinat degerleri girin'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Koordinat aralığı kontrolü
    if (lat < -90 || lat > 90) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enlem -90 ile 90 arasi olmali. Girilen: $lat'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (lng < -180 || lng > 180) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Boylam -180 ile 180 arasi olmali. Girilen: $lng'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = ref.read(supabaseProvider);

      // Koordinattan adres al
      final address = await GeocodingService.getAddressFromCoordinates(lat, lng);

      // Koordinatları ve adresi kaydet
      final updateData = <String, dynamic>{
        'latitude': lat,
        'longitude': lng,
      };

      // Adres bulunduysa onu da güncelle
      if (address != null) {
        updateData['address'] = address;
        _addressController.text = address;
      }

      await supabase
          .from('merchants')
          .update(updateData)
          .eq('id', merchant.id);

      // Reload merchant data
      await ref
          .read(currentMerchantProvider.notifier)
          .loadMerchantByUserId(supabase.auth.currentUser!.id);

      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(address != null
              ? 'Konum ve adres kaydedildi!'
              : 'Konum kaydedildi! (${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)})'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Widget _buildLocationMap() {
    final merchant = ref.watch(currentMerchantProvider).valueOrNull;
    final isRestaurant = merchant?.type == MerchantType.restaurant;
    final businessLabel = isRestaurant ? 'Restoraniniz' : 'Magazaniz';

    final lat = double.tryParse(_latitudeController.text);
    final lng = double.tryParse(_longitudeController.text);

    if (lat == null || lng == null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 8),
              Text(
                'Gecerli koordinat girin',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    // Windows platformunda harita desteklenmiyor
    if (defaultTargetPlatform == TargetPlatform.windows && !kIsWeb) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha:0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map, size: 48, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(
              'Konum: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Harita Windows\'ta desteklenmiyor',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () async {
                final url = Uri.parse('https://www.google.com/maps?q=$lat,$lng');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tarayici acilamadi')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Google Maps\'te Gör'),
            ),
          ],
        ),
      );
    }

    // Web ve mobil platformlar için Google Maps
    final position = LatLng(lat, lng);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 250,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: position,
            zoom: 16,
          ),
          markers: {
            Marker(
              markerId: const MarkerId('merchant_location'),
              position: position,
              infoWindow: InfoWindow(title: businessLabel),
            ),
          },
          zoomControlsEnabled: true,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
        ),
      ),
    );
  }

  Future<void> _saveDeliverySettings() async {
    final merchant = ref.read(currentMerchantProvider).valueOrNull;
    if (merchant == null || _settings == null) return;

    setState(() => _isLoading = true);

    try {
      final supabase = ref.read(supabaseProvider);
      await supabase
          .from('merchant_settings')
          .update({
            'min_order_amount': double.tryParse(_minOrderController.text) ?? 50,
            'delivery_fee': double.tryParse(_deliveryFeeController.text) ?? 15,
            'free_delivery_threshold': double.tryParse(_freeDeliveryController.text) ?? 150,
            'min_preparation_time': int.tryParse(_minPrepTimeController.text) ?? 20,
            'max_preparation_time': int.tryParse(_maxPrepTimeController.text) ?? 45,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('merchant_id', merchant.id);

      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Teslimat ayarlari kaydedildi!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _updateDeliveryOption(String field, bool value) async {
    final merchant = ref.read(currentMerchantProvider).valueOrNull;
    if (merchant == null) return;

    try {
      final supabase = ref.read(supabaseProvider);
      await supabase
          .from('merchant_settings')
          .update({
            field: value,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('merchant_id', merchant.id);

      setState(() {
        if (_settings != null) {
          _settings = MerchantSettings(
            id: _settings!.id,
            merchantId: _settings!.merchantId,
            deliveryEnabled: field == 'delivery_enabled' ? value : _settings!.deliveryEnabled,
            pickupEnabled: field == 'pickup_enabled' ? value : _settings!.pickupEnabled,
            minOrderAmount: _settings!.minOrderAmount,
            deliveryFee: _settings!.deliveryFee,
            freeDeliveryThreshold: _settings!.freeDeliveryThreshold,
            minPreparationTime: _settings!.minPreparationTime,
            maxPreparationTime: _settings!.maxPreparationTime,
            notifyNewOrder: _settings!.notifyNewOrder,
            notifyOrderCancel: _settings!.notifyOrderCancel,
            notifySoundEnabled: _settings!.notifySoundEnabled,
            notifyNewReview: _settings!.notifyNewReview,
            notifyLowStock: _settings!.notifyLowStock,
            notifyWeeklyReport: _settings!.notifyWeeklyReport,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _updateNotificationSetting(String field, bool value) async {
    final merchant = ref.read(currentMerchantProvider).valueOrNull;
    if (merchant == null) return;

    try {
      final supabase = ref.read(supabaseProvider);
      await supabase
          .from('merchant_settings')
          .update({
            field: value,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('merchant_id', merchant.id);

      setState(() {
        if (_settings != null) {
          _settings = MerchantSettings(
            id: _settings!.id,
            merchantId: _settings!.merchantId,
            deliveryEnabled: _settings!.deliveryEnabled,
            pickupEnabled: _settings!.pickupEnabled,
            minOrderAmount: _settings!.minOrderAmount,
            deliveryFee: _settings!.deliveryFee,
            freeDeliveryThreshold: _settings!.freeDeliveryThreshold,
            minPreparationTime: _settings!.minPreparationTime,
            maxPreparationTime: _settings!.maxPreparationTime,
            notifyNewOrder: field == 'notify_new_order' ? value : _settings!.notifyNewOrder,
            notifyOrderCancel: field == 'notify_order_cancel' ? value : _settings!.notifyOrderCancel,
            notifySoundEnabled: field == 'notify_sound_enabled' ? value : _settings!.notifySoundEnabled,
            notifyNewReview: field == 'notify_new_review' ? value : _settings!.notifyNewReview,
            notifyLowStock: field == 'notify_low_stock' ? value : _settings!.notifyLowStock,
            notifyWeeklyReport: field == 'notify_weekly_report' ? value : _settings!.notifyWeeklyReport,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _logout() async {
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.auth.signOut();
      if (mounted) {
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cikis yapilamadi: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _changePassword() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sifre Degistir'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Yeni Sifre',
                hintText: 'En az 6 karakter',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Yeni Sifre (Tekrar)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (newPasswordController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sifre en az 6 karakter olmali')),
                );
                return;
              }
              if (newPasswordController.text != confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sifreler eslesmiyor')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Degistir'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final supabase = ref.read(supabaseProvider);
        await supabase.auth.updateUser(
          UserAttributes(password: newPasswordController.text),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sifre basariyla degistirildi!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }

    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Settings Navigation
        Container(
          width: 250,
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(right: BorderSide(color: AppColors.border)),
          ),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _tabs.length,
            itemBuilder: (context, index) {
              final isSelected = _selectedTab == index;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  onTap: () => setState(() => _selectedTab = index),
                  selected: isSelected,
                  selectedTileColor: AppColors.primary.withAlpha(30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  leading: Icon(
                    _getTabIcon(index),
                    color:
                        isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                  ),
                  title: Text(
                    _tabs[index],
                    style: TextStyle(
                      color:
                          isSelected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Settings Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildSettingsContent(),
          ),
        ),
      ],
    );
  }

  IconData _getTabIcon(int index) {
    switch (index) {
      case 0:
        return Icons.store;
      case 1:
        return Icons.schedule;
      case 2:
        return Icons.local_shipping;
      case 3:
        return Icons.notifications;
      case 4:
        return Icons.verified_user;
      case 5:
        return Icons.support_agent;
      case 6:
        return Icons.person;
      default:
        return Icons.settings;
    }
  }

  Widget _buildSettingsContent() {
    switch (_selectedTab) {
      case 0:
        return _buildBusinessSettings();
      case 1:
        return _buildWorkingHoursSettings();
      case 2:
        return _buildDeliverySettings();
      case 3:
        return _buildNotificationSettings();
      case 4:
        return _buildVerificationSettings();
      case 5:
        return _buildSupportSettings();
      case 6:
        return _buildAccountSettings();
      default:
        return const SizedBox();
    }
  }

  Widget _buildBusinessSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Isletme Bilgileri',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Isletmenizin temel bilgilerini duzenleyin',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),

        _SettingsCard(
          title: 'Logo ve Kapak Resmi',
          children: [
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  // Logo
                  Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                          image:
                              _logoUrl != null
                                  ? DecorationImage(
                                    image: NetworkImage(_logoUrl!),
                                    fit: BoxFit.cover,
                                  )
                                  : null,
                        ),
                        child:
                            _logoUrl == null
                                ? const Icon(
                                  Icons.add_photo_alternate,
                                  size: 32,
                                  color: AppColors.textMuted,
                                )
                                : null,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => _pickAndUploadImage('logo'),
                        child: Text(
                          _logoUrl == null ? 'Logo Yukle' : 'Logo Degistir',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 32),
                  // Cover
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          height: 100,
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                            image:
                                _coverUrl != null
                                    ? DecorationImage(
                                      image: NetworkImage(_coverUrl!),
                                      fit: BoxFit.cover,
                                    )
                                    : null,
                          ),
                          child:
                              _coverUrl == null
                                  ? const Center(
                                    child: Icon(
                                      Icons.panorama,
                                      size: 32,
                                      color: AppColors.textMuted,
                                    ),
                                  )
                                  : null,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => _pickAndUploadImage('cover'),
                          child: Text(
                            _coverUrl == null
                                ? 'Kapak Resmi Yukle'
                                : 'Kapak Resmini Degistir',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 24),

        _SettingsCard(
          title: 'Temel Bilgiler',
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Isletme Adi'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Aciklama'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(labelText: 'Telefon'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'E-posta'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Adres'),
            ),
          ],
        ),
        const SizedBox(height: 24),

        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveBusinessInfo,
            child:
                _isLoading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text('Degisiklikleri Kaydet'),
          ),
        ),
      ],
    );
  }

  Widget _buildWorkingHoursSettings() {
    final days = [
      'Pazartesi',
      'Sali',
      'Carsamba',
      'Persembe',
      'Cuma',
      'Cumartesi',
      'Pazar',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Calisma Saatleri',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Isletmenizin acik oldugu saatleri belirleyin',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),

        _SettingsCard(
          title: 'Haftalik Program',
          children: [
            if (_workingHoursLoading)
              const Center(child: CircularProgressIndicator())
            else
              ...List.generate(7, (index) {
                final hours = _workingHours.firstWhere(
                  (h) => h.dayOfWeek == index,
                  orElse: () => WorkingHours(
                    id: '',
                    merchantId: '',
                    dayOfWeek: index,
                    isOpen: index != 6,
                    openTime: '10:00',
                    closeTime: '22:00',
                  ),
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          days[index],
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Switch(
                        value: hours.isOpen,
                        onChanged: (value) => _updateWorkingHours(hours, isOpen: value),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Row(
                          children: [
                            _TimePickerButton(
                              time: hours.openTime,
                              enabled: hours.isOpen,
                              onTimeSelected: (time) => _updateWorkingHours(hours, openTime: time),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text('-'),
                            ),
                            _TimePickerButton(
                              time: hours.closeTime,
                              enabled: hours.isOpen,
                              onTimeSelected: (time) => _updateWorkingHours(hours, closeTime: time),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ],
    );
  }

  Widget _buildDeliverySettings() {
    final merchant = ref.watch(currentMerchantProvider).valueOrNull;
    final isRestaurant = merchant?.type == MerchantType.restaurant;
    final businessTypeLabel = isRestaurant ? 'restoran' : 'magaza';
    final businessTypeLabelCapital = isRestaurant ? 'Restoran' : 'Magaza';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Teslimat Ayarlari',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Teslimat bolgeleri ve ucretleri yapilandirin',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),

        if (_settingsLoading)
          const Center(child: CircularProgressIndicator())
        else ...[
          // Konum Ayarları (Koordinatlar)
          _SettingsCard(
            title: '$businessTypeLabelCapital Konumu',
            children: [
              Text(
                'Teslimat mesafesi hesaplamalari icin ${businessTypeLabel}nizin koordinatlarini girin. Sadece rakamlari girin, nokta otomatik eklenir.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latitudeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Enlem (Latitude)',
                        hintText: '35165554',
                        prefixIcon: Icon(Icons.north),
                        helperText: 'Ornek: 35165554 -> 35.165554',
                      ),
                      onChanged: (value) => _formatCoordinate(_latitudeController, value, isLatitude: true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _longitudeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Boylam (Longitude)',
                        hintText: '33909293',
                        prefixIcon: Icon(Icons.east),
                        helperText: 'Ornek: 33909293 -> 33.909293',
                      ),
                      onChanged: (value) => _formatCoordinate(_longitudeController, value, isLatitude: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveLocationCoordinates,
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('Konumu Kaydet'),
                ),
              ),
              // Harita gösterimi
              if (_latitudeController.text.isNotEmpty && _longitudeController.text.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  'Haritada Konumunuz',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildLocationMap(),
              ],
            ],
          ),
          const SizedBox(height: 24),

          _SettingsCard(
            title: 'Teslimat Secenekleri',
            children: [
              _SettingsSwitch(
                title: 'Teslimat Aktif',
                subtitle: 'Teslimat siparisleri kabul edin',
                value: _settings?.deliveryEnabled ?? true,
                onChanged: (value) => _updateDeliveryOption('delivery_enabled', value),
              ),
              const Divider(height: 32),
              _SettingsSwitch(
                title: 'Gel-Al Aktif',
                subtitle: 'Musteri isletmeden alsin',
                value: _settings?.pickupEnabled ?? true,
                onChanged: (value) => _updateDeliveryOption('pickup_enabled', value),
              ),
            ],
          ),
          const SizedBox(height: 24),

          _SettingsCard(
            title: 'Teslimat Ucreti',
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minOrderController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Minimum Siparis Tutari',
                        suffixText: 'TL',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _deliveryFeeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Teslimat Ucreti',
                        suffixText: 'TL',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _freeDeliveryController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Ucretsiz Teslimat Limiti',
                  suffixText: 'TL',
                  helperText: 'Bu tutarin uzerindeki siparislerde teslimat ucretsiz',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          _SettingsCard(
            title: 'Hazirlama Suresi',
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minPrepTimeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Minimum Sure',
                        suffixText: 'dk',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _maxPrepTimeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Maksimum Sure',
                        suffixText: 'dk',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveDeliverySettings,
              child:
                  _isLoading
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('Degisiklikleri Kaydet'),
            ),
          ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 32),

          // Delivery Zones Map
          const DeliveryZonesMap(),
        ],
      ],
    );
  }

  Widget _buildNotificationSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bildirim Ayarlari',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Hangi bildirimleri almak istediginizi secin',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),

        if (_settingsLoading)
          const Center(child: CircularProgressIndicator())
        else ...[
          _SettingsCard(
            title: 'Siparis Bildirimleri',
            children: [
              _SettingsSwitch(
                title: 'Yeni Siparis',
                subtitle: 'Yeni siparis geldiginde bildirim al',
                value: _settings?.notifyNewOrder ?? true,
                onChanged: (value) => _updateNotificationSetting('notify_new_order', value),
              ),
              const Divider(height: 32),
              _SettingsSwitch(
                title: 'Siparis Iptali',
                subtitle: 'Siparis iptal edildiginde bildirim al',
                value: _settings?.notifyOrderCancel ?? true,
                onChanged: (value) => _updateNotificationSetting('notify_order_cancel', value),
              ),
              const Divider(height: 32),
              _SettingsSwitch(
                title: 'Sesli Bildirim',
                subtitle: 'Yeni siparislerde ses cal',
                value: _settings?.notifySoundEnabled ?? true,
                onChanged: (value) => _updateNotificationSetting('notify_sound_enabled', value),
              ),
            ],
          ),
          const SizedBox(height: 24),

          _SettingsCard(
            title: 'Diger Bildirimler',
            children: [
              _SettingsSwitch(
                title: 'Yeni Yorum',
                subtitle: 'Musteri yorum biraktiginda bildirim al',
                value: _settings?.notifyNewReview ?? true,
                onChanged: (value) => _updateNotificationSetting('notify_new_review', value),
              ),
              const Divider(height: 32),
              _SettingsSwitch(
                title: 'Dusuk Stok Uyarisi',
                subtitle: 'Urun stoku azaldiginda bildirim al',
                value: _settings?.notifyLowStock ?? true,
                onChanged: (value) => _updateNotificationSetting('notify_low_stock', value),
              ),
              const Divider(height: 32),
              _SettingsSwitch(
                title: 'Haftalik Rapor',
                subtitle: 'Her hafta performans raporu al',
                value: _settings?.notifyWeeklyReport ?? false,
                onChanged: (value) => _updateNotificationSetting('notify_weekly_report', value),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildVerificationSettings() {
    return const _VerificationSettings();
  }

  Widget _buildSupportSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Destek',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Yardim alin veya sorularinizi sorun',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),

        _SettingsCard(
          title: 'AI Asistan',
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.smart_toy, color: Colors.white),
              ),
              title: const Text(
                'Isletme Asistani',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '7/24 AI destekli yardim alin',
                style: TextStyle(color: AppColors.textMuted),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Cevrimici',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              onTap: () => context.push('/support/ai-chat'),
            ),
          ],
        ),
        const SizedBox(height: 24),

        _SettingsCard(
          title: 'Sikca Sorulan Sorular',
          children: [
            _buildFaqItem(
              'Siparis nasil onaylanir?',
              'Siparisler sayfasindan gelen siparisleri gorebilir ve onaylayabilirsiniz.',
            ),
            const Divider(height: 24),
            _buildFaqItem(
              'Menu nasil guncellenir?',
              'Menu sayfasindan urun ekleyebilir, duzenleyebilir veya silebilirsiniz.',
            ),
            const Divider(height: 24),
            _buildFaqItem(
              'Raporlari nasil gorurum?',
              'Raporlar sayfasindan satis, siparis ve musteri raporlarinizi inceleyebilirsiniz.',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          answer,
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildAccountSettings() {
    final supabase = ref.read(supabaseProvider);
    final user = supabase.auth.currentUser;
    final merchant = ref.read(currentMerchantProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hesap Ayarlari',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Hesap bilgilerinizi ve guvenlik ayarlarinizi yonetin',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),

        _SettingsCard(
          title: 'Hesap Bilgileri',
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primary.withAlpha(30),
                  backgroundImage: _logoUrl != null ? NetworkImage(_logoUrl!) : null,
                  child: _logoUrl == null
                      ? const Icon(
                          Icons.person,
                          size: 40,
                          color: AppColors.primary,
                        )
                      : null,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        merchant?.businessName ?? 'Isletme',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        user?.email ?? '',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),

        _SettingsCard(
          title: 'Guvenlik',
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lock, color: AppColors.primary),
              ),
              title: const Text('Sifre Degistir'),
              subtitle: Text(
                'Hesap guvenliginizi artirin',
                style: TextStyle(color: AppColors.textMuted),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _changePassword,
            ),
          ],
        ),
        const SizedBox(height: 24),

        _SettingsCard(
          title: 'Tehlikeli Bolge',
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout, color: AppColors.error),
              ),
              title: const Text(
                'Cikis Yap',
                style: TextStyle(color: AppColors.error),
              ),
              subtitle: Text(
                'Hesabinizdan cikis yapin',
                style: TextStyle(color: AppColors.textMuted),
              ),
              trailing: const Icon(Icons.chevron_right, color: AppColors.error),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Cikis Yap'),
                    content: const Text('Hesabinizdan cikis yapmak istediginize emin misiniz?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Iptal'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                        child: const Text('Cikis Yap'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  _logout();
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _VerificationSettings extends ConsumerStatefulWidget {
  const _VerificationSettings();

  @override
  ConsumerState<_VerificationSettings> createState() =>
      _VerificationSettingsState();
}

class _VerificationSettingsState extends ConsumerState<_VerificationSettings> {
  final _documents = [
    {'type': 'tax_plate', 'label': 'Vergi Levhasi (Zorunlu)'},
    {'type': 'id_card', 'label': 'Kimlik Fotokopisi (Zorunlu)'},
    {'type': 'activity_cert', 'label': 'Faaliyet Belgesi (Opsiyonel)'},
    {'type': 'signature_circular', 'label': 'Imza Sirkusu (Opsiyonel)'},
  ];

  Map<String, dynamic> _uploadedDocs = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
  }

  Future<void> _fetchDocuments() async {
    try {
      final merchant = ref.read(currentMerchantProvider).valueOrNull;
      if (merchant == null) return;

      final supabase = ref.read(supabaseProvider);
      final response = await supabase
          .from('merchant_documents')
          .select()
          .eq('merchant_id', merchant.id);

      final docs = <String, dynamic>{};
      for (var doc in response) {
        docs[doc['type']] = doc;
      }

      if (mounted) {
        setState(() {
          _uploadedDocs = docs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _uploadDocument(String type) async {
    try {
      final merchant = ref.read(currentMerchantProvider).valueOrNull;
      if (merchant == null) return;

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() => _isLoading = true);
        final file = result.files.single;
        final supabase = ref.read(supabaseProvider);

        // Upload to storage
        final bytes = file.bytes;
        if (bytes == null) {
          setState(() => _isLoading = false);
          return;
        }

        final safeFileName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        final path = 'documents/${merchant.id}/${type}_${DateTime.now().millisecondsSinceEpoch}_$safeFileName';

        await supabase.storage.from('images').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );

        final url = supabase.storage.from('images').getPublicUrl(path);

        // Check if exists
        final existing = _uploadedDocs[type];
        if (existing != null) {
          await supabase
              .from('merchant_documents')
              .update({
                'url': url,
                'status': 'pending',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', existing['id']);
        } else {
          await supabase.from('merchant_documents').insert({
            'merchant_id': merchant.id,
            'type': type,
            'url': url,
            'status': 'pending',
          });
        }

        await _fetchDocuments();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Belge yuklendi, onay bekleniyor'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dogrulama Belgeleri',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Hesabinizin onaylanmasi icin asagidaki belgeleri yukleyin',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),

        _SettingsCard(
          title: 'Gerekli Belgeler',
          children:
              _documents.map((doc) {
                final type = doc['type']!;
                final uploaded = _uploadedDocs[type];
                final status = uploaded?['status'] ?? 'missing';

                Color statusColor;
                IconData statusIcon;
                String statusText;

                switch (status) {
                  case 'approved':
                    statusColor = AppColors.success;
                    statusIcon = Icons.check_circle;
                    statusText = 'Onaylandi';
                    break;
                  case 'rejected':
                    statusColor = AppColors.error;
                    statusIcon = Icons.error;
                    statusText = 'Reddedildi';
                    break;
                  case 'pending':
                    statusColor = AppColors.warning;
                    statusIcon = Icons.access_time;
                    statusText = 'Onay Bekliyor';
                    break;
                  default:
                    statusColor = AppColors.textMuted;
                    statusIcon = Icons.upload_file;
                    statusText = 'Yuklenmedi';
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColor.withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(statusIcon, color: statusColor),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doc['label']!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (status == 'rejected' &&
                                uploaded?['rejection_reason'] != null)
                              Text(
                                'Red Nedeni: ${uploaded['rejection_reason']}',
                                style: TextStyle(
                                  color: AppColors.error,
                                  fontSize: 12,
                                ),
                              )
                            else
                              Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (status != 'approved')
                        OutlinedButton.icon(
                          onPressed: () => _uploadDocument(type),
                          icon: const Icon(Icons.upload, size: 18),
                          label: Text(
                            status == 'missing' ? 'Yukle' : 'Yeniden Yukle',
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _TimePickerButton extends StatelessWidget {
  final String time;
  final bool enabled;
  final Function(String)? onTimeSelected;

  const _TimePickerButton({
    required this.time,
    this.enabled = true,
    this.onTimeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled
          ? () async {
              final parts = time.split(':');
              final hour = int.tryParse(parts[0]) ?? 10;
              final minute = int.tryParse(parts[1]) ?? 0;

              final selectedTime = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: hour, minute: minute),
                builder: (context, child) {
                  return MediaQuery(
                    data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                    child: child!,
                  );
                },
              );

              if (selectedTime != null && onTimeSelected != null) {
                final formattedTime =
                    '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
                onTimeSelected!(formattedTime);
              }
            }
          : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: enabled ? AppColors.background : AppColors.background.withAlpha(128),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          time,
          style: TextStyle(
            color: enabled ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
