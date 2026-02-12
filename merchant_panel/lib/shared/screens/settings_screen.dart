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
import '../../core/utils/app_dialogs.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

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
        AppDialogs.showError(context, 'Ayarlar yuklenemedi: $e');
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
            fileOptions: const FileOptions(cacheControl: '31536000', upsert: true),
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
        AppDialogs.showError(context, 'Hata: $e');
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
      AppDialogs.showError(context, 'Gecerli koordinat degerleri girin');
      return;
    }

    // Koordinat aralığı kontrolü
    if (lat < -90 || lat > 90) {
      AppDialogs.showError(context, 'Enlem -90 ile 90 arasi olmali. Girilen: $lat');
      return;
    }

    if (lng < -180 || lng > 180) {
      AppDialogs.showError(context, 'Boylam -180 ile 180 arasi olmali. Girilen: $lng');
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
        AppDialogs.showError(context, 'Hata: $e');
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
      final minPrep = int.tryParse(_minPrepTimeController.text) ?? 20;
      final maxPrep = int.tryParse(_maxPrepTimeController.text) ?? 45;

      await supabase
          .from('merchant_settings')
          .update({
            'min_order_amount': double.tryParse(_minOrderController.text) ?? 50,
            'delivery_fee': double.tryParse(_deliveryFeeController.text) ?? 15,
            'free_delivery_threshold': double.tryParse(_freeDeliveryController.text) ?? 150,
            'min_preparation_time': minPrep,
            'max_preparation_time': maxPrep,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('merchant_id', merchant.id);

      // Update delivery_time on merchants table so customers see the correct time
      await supabase
          .from('merchants')
          .update({'delivery_time': '$minPrep-$maxPrep dk'})
          .eq('id', merchant.id);

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
        AppDialogs.showError(context, 'Hata: $e');
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
        AppDialogs.showError(context, 'Hata: $e');
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
        AppDialogs.showError(context, 'Hata: $e');
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
        AppDialogs.showError(context, 'Cikis yapilamadi: $e');
      }
    }
  }

  Future<void> _changePassword() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (context) => AlertDialog(
          title: const Text('Sifre Degistir'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mevcut Sifre',
                  hintText: 'Guvenlik icin mevcut sifrenizi girin',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Yeni Sifre',
                  hintText: 'En az 6 karakter',
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Yeni Sifre (Tekrar)',
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Iptal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (currentPasswordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mevcut sifrenizi girin')),
                  );
                  return;
                }
                if (newPasswordController.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Yeni sifre en az 6 karakter olmali')),
                  );
                  return;
                }
                if (newPasswordController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Yeni sifreler eslesmiyor')),
                  );
                  return;
                }
                if (currentPasswordController.text == newPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Yeni sifre mevcut sifreden farkli olmali')),
                  );
                  return;
                }
                Navigator.pop(context, {
                  'current': currentPasswordController.text,
                  'new': newPasswordController.text,
                });
              },
              child: const Text('Degistir'),
            ),
          ],
        ),
    );

    if (result != null) {
      try {
        final supabase = ref.read(supabaseProvider);
        final email = supabase.auth.currentUser?.email;

        if (email == null) {
          if (mounted) {
            AppDialogs.showError(context, 'Kullanici bilgisi alinamadi');
          }
          return;
        }

        // Mevcut sifreyi dogrula
        try {
          await supabase.auth.signInWithPassword(
            email: email,
            password: result['current']!,
          );
        } catch (e) {
          if (mounted) {
            AppDialogs.showError(context, 'Mevcut sifre yanlis');
          }
          return;
        }

        // Yeni sifreyi kaydet
        await supabase.auth.updateUser(
          UserAttributes(password: result['new']!),
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
          AppDialogs.showError(context, 'Sifre degistirilemedi: $e');
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
        return Icons.local_shipping;
      case 2:
        return Icons.notifications;
      case 3:
        return Icons.verified_user;
      case 4:
        return Icons.support_agent;
      case 5:
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
        return _buildDeliverySettings();
      case 2:
        return _buildNotificationSettings();
      case 3:
        return _buildVerificationSettings();
      case 4:
        return _buildSupportSettings();
      case 5:
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
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.info.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.info.withAlpha(50)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.info, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Bu bilgiler kayit sirasinda belirlenmistir ve degistirilemez.',
                      style: TextStyle(
                        color: AppColors.info,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            TextFormField(
              controller: _nameController,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Isletme Adi'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Aciklama'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: 'Telefon'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _emailController,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: 'E-posta'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              maxLines: 2,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Adres'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDeliverySettings() {
    final merchant = ref.watch(currentMerchantProvider).valueOrNull;
    final merchantType = merchant?.type ?? MerchantType.restaurant;
    final isStore = merchantType == MerchantType.store;
    final isRestaurant = merchantType == MerchantType.restaurant;
    final isMarket = merchantType == MerchantType.market;
    final hasLocalDelivery = isRestaurant || isMarket; // Restoran ve market yerel teslimat

    final businessTypeLabel = isRestaurant ? 'restoran' : (isMarket ? 'market' : 'magaza');
    final businessTypeLabelCapital = isRestaurant ? 'Restoran' : (isMarket ? 'Market' : 'Magaza');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isStore ? 'Kargo Ayarlari' : 'Teslimat Ayarlari',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          isStore
              ? 'Kargo ve gonderim ayarlarini yapilandirin'
              : 'Teslimat bolgeleri ve ucretleri yapilandirin',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),

        // Mağazalar için kargo bilgi kutusu
        if (isStore) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.info.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.info.withAlpha(50)),
            ),
            child: Row(
              children: [
                Icon(Icons.local_shipping, color: AppColors.info, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kargo ile Gonderim',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Magazaniz tum KKTC\'ye kargo ile hizmet vermektedir. Teslimat bolgesi kisitlamasi yoktur.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        if (_settingsLoading)
          const Center(child: CircularProgressIndicator())
        else ...[
          // Restoran ve Market için konum ve teslimat bölgesi ayarları
          if (hasLocalDelivery) ...[
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

            // Delivery Zones Map - Sadece restoran ve market için
            const DeliveryZonesMap(),
          ],

          // Mağazalar için kargo ayarları
          if (isStore) ...[
            _SettingsCard(
              title: 'Kargo Secenekleri',
              children: [
                _SettingsSwitch(
                  title: 'Kargo ile Gonderim',
                  subtitle: 'Siparisleri kargo ile gonderin',
                  value: _settings?.deliveryEnabled ?? true,
                  onChanged: (value) => _updateDeliveryOption('delivery_enabled', value),
                ),
                const Divider(height: 32),
                _SettingsSwitch(
                  title: 'Magazadan Teslim',
                  subtitle: 'Musteri magazadan alabilsin',
                  value: _settings?.pickupEnabled ?? true,
                  onChanged: (value) => _updateDeliveryOption('pickup_enabled', value),
                ),
              ],
            ),
            const SizedBox(height: 24),

            _SettingsCard(
              title: 'Kargo Ucreti',
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
                          labelText: 'Kargo Ucreti',
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
                    labelText: 'Ucretsiz Kargo Limiti',
                    suffixText: 'TL',
                    helperText: 'Bu tutarin uzerindeki siparislerde kargo ucretsiz',
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
                          labelText: 'Minimum Hazirlama',
                          suffixText: 'gun',
                          helperText: 'Kargoya verilme suresi',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _maxPrepTimeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Maksimum Hazirlama',
                          suffixText: 'gun',
                          helperText: 'Kargoya verilme suresi',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Kargo Şirketleri
            _SettingsCard(
              title: 'Kargo Firmalari',
              children: [
                Text(
                  'Magazaniz asagidaki kargo firmalari ile calismaktadir:',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _CargoCompanyChip(name: 'Yurtici Kargo', isActive: true),
                    _CargoCompanyChip(name: 'Aras Kargo', isActive: true),
                    _CargoCompanyChip(name: 'MNG Kargo', isActive: false),
                    _CargoCompanyChip(name: 'PTT Kargo', isActive: false),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Kargo firmasi eklemek icin destek ile iletisime gecin.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
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
          ],
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

        // AI Asistan bilgilendirmesi
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withAlpha(30),
                AppColors.primary.withBlue(255).withAlpha(20),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withAlpha(50)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(100),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.smart_toy, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'AI Asistan',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Cevrimici',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ekranin sag alt kosesindeki mavi robota tiklayarak 7/24 AI destekli yardim alabilirsiniz.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.arrow_downward, size: 16, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Sag alttaki robota tiklayin',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
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
        const SizedBox(height: 24),

        _SettingsCard(
          title: 'Iletisim',
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.info.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.email, color: AppColors.info),
              ),
              title: const Text('E-posta Destek'),
              subtitle: Text(
                'destek@odabase.com',
                style: TextStyle(color: AppColors.textMuted),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final url = Uri.parse('mailto:destek@odabase.com');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
            ),
            const Divider(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.phone, color: AppColors.success),
              ),
              title: const Text('Telefon Destek'),
              subtitle: Text(
                '+90 392 000 00 00',
                style: TextStyle(color: AppColors.textMuted),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final url = Uri.parse('tel:+903920000000');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
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
            const Divider(height: 24),
            _buildFaqItem(
              'Teslimat bolgeleri nasil ayarlanir?',
              'Ayarlar > Teslimat Ayarlari sayfasindan teslimat bolgelerinizi harita uzerinden belirleyebilirsiniz.',
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
          fileOptions: const FileOptions(cacheControl: '31536000', upsert: true),
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
        AppDialogs.showError(context, 'Hata: $e');
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

class _CargoCompanyChip extends StatelessWidget {
  final String name;
  final bool isActive;

  const _CargoCompanyChip({
    required this.name,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.success.withAlpha(30)
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? AppColors.success
              : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.check_circle : Icons.circle_outlined,
            size: 18,
            color: isActive ? AppColors.success : AppColors.textMuted,
          ),
          const SizedBox(width: 8),
          Text(
            name,
            style: TextStyle(
              color: isActive ? AppColors.success : AppColors.textSecondary,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

