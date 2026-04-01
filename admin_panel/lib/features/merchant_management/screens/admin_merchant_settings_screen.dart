import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../providers/merchant_management_providers.dart';

// Store category model for admin panel
class _StoreCategory {
  final String id;
  final String name;
  final String? iconName;
  _StoreCategory({required this.id, required this.name, this.iconName});
}

final _storeCategoriesProvider = FutureProvider<List<_StoreCategory>>((
  ref,
) async {
  final client = ref.watch(supabaseProvider);
  final response = await client
      .from('store_categories')
      .select('id, name, icon_name')
      .eq('is_active', true)
      .order('sort_order');
  return (response as List)
      .map(
        (e) => _StoreCategory(
          id: e['id'] as String,
          name: e['name'] as String,
          iconName: e['icon_name'] as String?,
        ),
      )
      .toList();
});

// Merchant documents provider
final _merchantDocumentsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      merchantId,
    ) async {
      final client = ref.watch(supabaseProvider);
      final response = await client
          .from('merchant_documents')
          .select()
          .eq('merchant_id', merchantId);
      return List<Map<String, dynamic>>.from(response);
    });

class AdminMerchantSettingsScreen extends ConsumerStatefulWidget {
  final String merchantId;

  const AdminMerchantSettingsScreen({super.key, required this.merchantId});

  @override
  ConsumerState<AdminMerchantSettingsScreen> createState() =>
      _AdminMerchantSettingsScreenState();
}

class _AdminMerchantSettingsScreenState
    extends ConsumerState<AdminMerchantSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isLoaded = false;

  // Business info
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _commissionController = TextEditingController();
  final _discountBadgeController = TextEditingController();
  String? _logoUrl;
  String? _coverUrl;
  bool _isOpen = true;
  bool _isApproved = true;

  // Store categories
  List<String> _storeCategoryIds = [];
  String? _merchantType;

  // Working hours
  static const List<String> _dayNames = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];
  late List<TimeOfDay> _openingTimes;
  late List<TimeOfDay> _closingTimes;
  late List<bool> _dayClosed;

  // Delivery settings
  final _minOrderController = TextEditingController();
  final _deliveryFeeController = TextEditingController();
  final _freeDeliveryController = TextEditingController();
  final _minPrepTimeController = TextEditingController();
  final _maxPrepTimeController = TextEditingController();
  bool _deliveryEnabled = true;
  bool _pickupEnabled = true;

  // Delivery zones
  List<Map<String, dynamic>> _deliveryZones = [];
  bool _deliveryZonesLoaded = false;

  // Notifications
  bool _notifyNewOrder = true;
  bool _notifyOrderCancel = true;
  bool _notifySoundEnabled = true;
  bool _notifyNewReview = true;
  bool _notifyLowStock = true;
  bool _notifyWeeklyReport = false;

  // Settings loaded flag
  bool _settingsLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _openingTimes = List.generate(
      7,
      (_) => const TimeOfDay(hour: 9, minute: 0),
    );
    _closingTimes = List.generate(
      7,
      (_) => const TimeOfDay(hour: 22, minute: 0),
    );
    _dayClosed = List.generate(7, (_) => false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _commissionController.dispose();
    _discountBadgeController.dispose();
    _minOrderController.dispose();
    _deliveryFeeController.dispose();
    _freeDeliveryController.dispose();
    _minPrepTimeController.dispose();
    _maxPrepTimeController.dispose();
    super.dispose();
  }

  void _populateFields(Map<String, dynamic> data) {
    if (_isLoaded) return;
    _isLoaded = true;

    _nameController.text = data['business_name'] as String? ?? '';
    _emailController.text = data['email'] as String? ?? '';
    _phoneController.text = data['phone'] as String? ?? '';
    _addressController.text = data['address'] as String? ?? '';
    _descriptionController.text = data['description'] as String? ?? '';
    _latitudeController.text = (data['latitude'] as num?)?.toString() ?? '';
    _longitudeController.text = (data['longitude'] as num?)?.toString() ?? '';
    _commissionController.text =
        (data['commission_rate'] as num?)?.toString() ?? '15';
    _discountBadgeController.text = data['discount_badge'] as String? ?? '';
    _logoUrl = data['logo_url'] as String?;
    _coverUrl = data['cover_url'] as String?;
    _isOpen = data['is_open'] as bool? ?? true;
    _isApproved = data['is_approved'] as bool? ?? false;
    _merchantType = data['type'] as String?;

    // Store category ids
    final categoryIds = data['store_category_ids'];
    if (categoryIds is List) {
      _storeCategoryIds = List<String>.from(categoryIds);
    }

    // Delivery settings from merchants table
    _minOrderController.text =
        (data['min_order_amount'] as num?)?.toStringAsFixed(0) ?? '0';
    _deliveryFeeController.text =
        (data['delivery_fee'] as num?)?.toStringAsFixed(0) ?? '0';
    _freeDeliveryController.text =
        (data['free_delivery_threshold'] as num?)?.toStringAsFixed(0) ?? '0';

    // Parse working hours
    final workingHours = data['working_hours'];
    if (workingHours is Map<String, dynamic>) {
      for (int i = 0; i < 7; i++) {
        final dayData = workingHours[i.toString()];
        if (dayData is Map<String, dynamic>) {
          _dayClosed[i] = dayData['closed'] == true;
          if (dayData['open'] is String) {
            _openingTimes[i] = _parseTime(dayData['open'] as String);
          }
          if (dayData['close'] is String) {
            _closingTimes[i] = _parseTime(dayData['close'] as String);
          }
        }
      }
    }

    // Load merchant_settings
    _loadMerchantSettings();
    // Load delivery zones
    _loadDeliveryZones();
  }

  Future<void> _loadMerchantSettings() async {
    if (_settingsLoaded) return;
    _settingsLoaded = true;

    try {
      final client = ref.read(supabaseProvider);
      final response = await client
          .from('merchant_settings')
          .select()
          .eq('merchant_id', widget.merchantId)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _deliveryEnabled = response['delivery_enabled'] as bool? ?? true;
          _pickupEnabled = response['pickup_enabled'] as bool? ?? true;
          _minPrepTimeController.text =
              (response['min_preparation_time'] as num?)?.toString() ?? '20';
          _maxPrepTimeController.text =
              (response['max_preparation_time'] as num?)?.toString() ?? '45';
          _notifyNewOrder = response['notify_new_order'] as bool? ?? true;
          _notifyOrderCancel = response['notify_order_cancel'] as bool? ?? true;
          _notifySoundEnabled =
              response['notify_sound_enabled'] as bool? ?? true;
          _notifyNewReview = response['notify_new_review'] as bool? ?? true;
          _notifyLowStock = response['notify_low_stock'] as bool? ?? true;
          _notifyWeeklyReport =
              response['notify_weekly_report'] as bool? ?? false;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadDeliveryZones() async {
    if (_deliveryZonesLoaded) return;
    _deliveryZonesLoaded = true;

    try {
      final client = ref.read(supabaseProvider);
      final response = await client
          .from('merchant_delivery_zones')
          .select()
          .eq('merchant_id', widget.merchantId)
          .order('sort_order');

      if (mounted) {
        setState(() {
          _deliveryZones = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (_) {
      // Table may not exist, that's fine
    }
  }

  Future<void> _addDeliveryZone() async {
    final nextSort = _deliveryZones.isEmpty
        ? 1
        : (_deliveryZones
                  .map((z) => (z['sort_order'] as int?) ?? 0)
                  .reduce((a, b) => a > b ? a : b) +
              1);
    final nextRadius = _deliveryZones.isEmpty
        ? 2.0
        : (_deliveryZones
                  .map((z) => (z['radius_km'] as num?)?.toDouble() ?? 2.0)
                  .reduce((a, b) => a > b ? a : b) +
              3);
    final colors = [
      '#4CAF50',
      '#FF9800',
      '#F44336',
      '#2196F3',
      '#9C27B0',
      '#00BCD4',
    ];
    final colorIndex = _deliveryZones.length % colors.length;

    try {
      final client = ref.read(supabaseProvider);
      final response = await client
          .from('merchant_delivery_zones')
          .insert({
            'merchant_id': widget.merchantId,
            'zone_name': 'Bölge $nextSort',
            'radius_km': nextRadius,
            'delivery_fee': 15 + (nextSort * 10),
            'min_order_amount': 50 + (nextSort * 25),
            'color': colors[colorIndex],
            'sort_order': nextSort,
            'is_active': true,
          })
          .select()
          .single();

      setState(() {
        _deliveryZones.add(Map<String, dynamic>.from(response));
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yeni teslimat bölgesi eklendi'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bölge eklenemedi: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _updateDeliveryZone(Map<String, dynamic> zone) async {
    try {
      final client = ref.read(supabaseProvider);
      await client
          .from('merchant_delivery_zones')
          .update({
            'zone_name': zone['zone_name'],
            'radius_km': zone['radius_km'],
            'delivery_fee': zone['delivery_fee'],
            'min_order_amount': zone['min_order_amount'],
            'is_active': zone['is_active'],
            'color': zone['color'],
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', zone['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bölge güncellendi'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bölge güncellenemedi: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteDeliveryZone(String zoneId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bölge Sil'),
        content: const Text(
          'Bu teslimat bölgesini silmek istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final client = ref.read(supabaseProvider);
      await client.from('merchant_delivery_zones').delete().eq('id', zoneId);

      setState(() {
        _deliveryZones.removeWhere((z) => z['id'] == zoneId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bölge silindi'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bölge silinemedi: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showEditZoneDialog(Map<String, dynamic> zone) {
    final nameCtrl = TextEditingController(text: zone['zone_name'] ?? '');
    final radiusCtrl = TextEditingController(text: '${zone['radius_km'] ?? 2}');
    final feeCtrl = TextEditingController(
      text: '${(zone['delivery_fee'] as num?)?.toInt() ?? 15}',
    );
    final minOrderCtrl = TextEditingController(
      text: '${(zone['min_order_amount'] as num?)?.toInt() ?? 50}',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bölge Düzenle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Bölge Adı',
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: radiusCtrl,
                decoration: const InputDecoration(
                  labelText: 'Yarıçap (km)',
                  prefixIcon: Icon(Icons.radar),
                  suffixText: 'km',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: feeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Teslimat Ücreti',
                  prefixIcon: Icon(Icons.payments_outlined),
                  suffixText: '₺',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: minOrderCtrl,
                decoration: const InputDecoration(
                  labelText: 'Min. Sipariş Tutarı',
                  prefixIcon: Icon(Icons.shopping_cart_outlined),
                  suffixText: '₺',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              final idx = _deliveryZones.indexWhere(
                (z) => z['id'] == zone['id'],
              );
              if (idx != -1) {
                setState(() {
                  _deliveryZones[idx] = {
                    ..._deliveryZones[idx],
                    'zone_name': nameCtrl.text.trim(),
                    'radius_km':
                        double.tryParse(radiusCtrl.text) ?? zone['radius_km'],
                    'delivery_fee':
                        double.tryParse(feeCtrl.text) ?? zone['delivery_fee'],
                    'min_order_amount':
                        double.tryParse(minOrderCtrl.text) ??
                        zone['min_order_amount'],
                  };
                });
                _updateDeliveryZone(_deliveryZones[idx]);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  TimeOfDay _parseTime(String time) {
    try {
      final parts = time.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Map<String, dynamic> _buildWorkingHoursJson() {
    final Map<String, dynamic> result = {};
    for (int i = 0; i < 7; i++) {
      result[i.toString()] = {
        'closed': _dayClosed[i],
        'open': _formatTime(_openingTimes[i]),
        'close': _formatTime(_closingTimes[i]),
      };
    }
    return result;
  }

  Future<void> _pickAndUploadImage(String type) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      setState(() => _isSaving = true);
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() => _isSaving = false);
        return;
      }

      final client = ref.read(supabaseProvider);
      final safeFileName = file.name.replaceAll(
        RegExp(r'[^a-zA-Z0-9._-]'),
        '_',
      );
      final fileName =
          '${type}_${widget.merchantId}_${DateTime.now().millisecondsSinceEpoch}_$safeFileName';

      await client.storage
          .from('images')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(
              cacheControl: '31536000',
              upsert: true,
            ),
          );

      final imageUrl = client.storage.from('images').getPublicUrl(fileName);
      final updateField = type == 'logo' ? 'logo_url' : 'cover_url';
      await client
          .from('merchants')
          .update({updateField: imageUrl})
          .eq('id', widget.merchantId);

      setState(() {
        if (type == 'logo') {
          _logoUrl = imageUrl;
        } else {
          _coverUrl = imageUrl;
        }
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${type == 'logo' ? 'Logo' : 'Kapak resmi'} yüklendi!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _toggleStoreCategory(String categoryId, bool selected) async {
    final newIds = List<String>.from(_storeCategoryIds);
    if (selected) {
      newIds.add(categoryId);
    } else {
      newIds.remove(categoryId);
    }

    try {
      final client = ref.read(supabaseProvider);
      await client
          .from('merchants')
          .update({'store_category_ids': newIds})
          .eq('id', widget.merchantId);
      setState(() => _storeCategoryIds = newIds);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kategoriler güncellendi'),
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

  Future<void> _updateDocumentStatus(
    String docId,
    String status, {
    String? rejectionReason,
  }) async {
    try {
      final client = ref.read(supabaseProvider);
      final updateData = <String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (rejectionReason != null) {
        updateData['rejection_reason'] = rejectionReason;
      } else if (status == 'approved') {
        updateData['rejection_reason'] = null;
      }

      await client
          .from('merchant_documents')
          .update(updateData)
          .eq('id', docId);

      // Refresh documents
      ref.invalidate(_merchantDocumentsProvider(widget.merchantId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'approved' ? 'Belge onaylandı' : 'Belge reddedildi',
            ),
            backgroundColor: status == 'approved'
                ? AppColors.success
                : AppColors.error,
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

  Future<void> _showRejectDialog(String docId) async {
    final reasonController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Belgeyi Reddet',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Red nedenini yazın:',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: reasonController,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Örn: Belge okunamıyor, lütfen tekrar yükleyin',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.surfaceLight),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context, reasonController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reddet', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null) {
      await _updateDocumentStatus(docId, 'rejected', rejectionReason: result);
    }
    reasonController.dispose();
  }

  Future<void> _saveAll() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final client = ref.read(supabaseProvider);

      // Save merchants table
      await client
          .from('merchants')
          .update({
            'business_name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'address': _addressController.text.trim(),
            'description': _descriptionController.text.trim(),
            'latitude': double.tryParse(_latitudeController.text.trim()),
            'longitude': double.tryParse(_longitudeController.text.trim()),
            'commission_rate':
                double.tryParse(_commissionController.text.trim()) ?? 15,
            'discount_badge': _discountBadgeController.text.trim().isEmpty
                ? null
                : _discountBadgeController.text.trim(),
            'is_open': _isOpen,
            'is_approved': _isApproved,
            'min_order_amount':
                double.tryParse(_minOrderController.text.trim()) ?? 0,
            'delivery_fee':
                double.tryParse(_deliveryFeeController.text.trim()) ?? 0,
            'free_delivery_threshold':
                double.tryParse(_freeDeliveryController.text.trim()) ?? 0,
            'working_hours': _buildWorkingHoursJson(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.merchantId);

      // Save merchant_settings table
      await client.from('merchant_settings').upsert({
        'merchant_id': widget.merchantId,
        'delivery_enabled': _deliveryEnabled,
        'pickup_enabled': _pickupEnabled,
        'min_order_amount':
            double.tryParse(_minOrderController.text.trim()) ?? 0,
        'delivery_fee':
            double.tryParse(_deliveryFeeController.text.trim()) ?? 0,
        'free_delivery_threshold':
            double.tryParse(_freeDeliveryController.text.trim()) ?? 0,
        'min_preparation_time':
            int.tryParse(_minPrepTimeController.text.trim()) ?? 20,
        'max_preparation_time':
            int.tryParse(_maxPrepTimeController.text.trim()) ?? 45,
        'notify_new_order': _notifyNewOrder,
        'notify_order_cancel': _notifyOrderCancel,
        'notify_sound_enabled': _notifySoundEnabled,
        'notify_new_review': _notifyNewReview,
        'notify_low_stock': _notifyLowStock,
        'notify_weekly_report': _notifyWeeklyReport,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'merchant_id');

      ref.invalidate(merchantSettingsProvider(widget.merchantId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tüm ayarlar başarıyla kaydedildi'),
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
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(
      merchantSettingsProvider(widget.merchantId),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Hata: $e',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        data: (data) {
          if (data == null) {
            return const Center(
              child: Text(
                'İşletme bulunamadı',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }
          _populateFields(data);

          return Form(
            key: _formKey,
            child: Column(
              children: [
                // Tab bar
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      bottom: BorderSide(color: AppColors.surfaceLight),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.textMuted,
                    tabs: const [
                      Tab(
                        text: 'İşletme Bilgileri',
                        icon: Icon(Icons.store, size: 18),
                      ),
                      Tab(
                        text: 'Çalışma & Teslimat',
                        icon: Icon(Icons.delivery_dining, size: 18),
                      ),
                      Tab(
                        text: 'Bildirimler',
                        icon: Icon(Icons.notifications, size: 18),
                      ),
                      Tab(
                        text: 'Doğrulama',
                        icon: Icon(Icons.verified_user, size: 18),
                      ),
                      Tab(
                        text: 'Durum & Admin',
                        icon: Icon(Icons.admin_panel_settings, size: 18),
                      ),
                    ],
                  ),
                ),
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBusinessInfoTab(),
                      _buildDeliveryTab(),
                      _buildNotificationsTab(),
                      _buildVerificationTab(),
                      _buildStatusTab(),
                    ],
                  ),
                ),
                // Save button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      top: BorderSide(color: AppColors.surfaceLight),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveAll,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save, size: 20),
                      label: const Text(
                        'Tüm Ayarları Kaydet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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

  // ==================== TAB 1: İŞLETME BİLGİLERİ ====================
  Widget _buildBusinessInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo & Cover
          _buildSectionCard(
            title: 'Görseller',
            icon: Icons.image_outlined,
            children: [
              Row(
                children: [
                  // Logo
                  Column(
                    children: [
                      const Text(
                        'Logo',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _pickAndUploadImage('logo'),
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.surfaceLight),
                          ),
                          child: _logoUrl != null && _logoUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    _logoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.store,
                                      size: 40,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.add_a_photo,
                                  size: 32,
                                  color: AppColors.textMuted,
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 24),
                  // Cover
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Kapak Resmi',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _pickAndUploadImage('cover'),
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.surfaceLight),
                            ),
                            child: _coverUrl != null && _coverUrl!.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      _coverUrl!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      errorBuilder: (_, _, _) => const Icon(
                                        Icons.panorama,
                                        size: 40,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  )
                                : const Center(
                                    child: Icon(
                                      Icons.add_photo_alternate,
                                      size: 32,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
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

          // Business Info
          _buildSectionCard(
            title: 'Temel Bilgiler',
            icon: Icons.store_outlined,
            children: [
              _buildTextField(
                controller: _nameController,
                label: 'İşletme Adı',
                icon: Icons.badge_outlined,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Zorunlu alan' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _descriptionController,
                label: 'Açıklama',
                icon: Icons.description_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _emailController,
                      label: 'E-posta',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _phoneController,
                      label: 'Telefon',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _addressController,
                label: 'Adres',
                icon: Icons.location_on_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _discountBadgeController,
                label: 'İndirim Etiketi',
                icon: Icons.local_offer_outlined,
                hint: 'Örn: %20 İndirim',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Store Category Selection (only for store type merchants)
          if (_merchantType == 'store') ...[
            _buildSectionCard(
              title: 'Mağaza Kategorileri',
              icon: Icons.category_outlined,
              children: [_buildStoreCategorySelector()],
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildStoreCategorySelector() {
    final categoriesAsync = ref.watch(_storeCategoriesProvider);
    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) {
          return const Text(
            'Henüz kategori tanımlanmamış',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mağazanın bulunduğu kategorileri seçin (birden fazla seçilebilir)',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((c) {
                final isSelected = _storeCategoryIds.contains(c.id);
                return FilterChip(
                  label: Text(c.name),
                  selected: isSelected,
                  onSelected: (selected) =>
                      _toggleStoreCategory(c.id, selected),
                  selectedColor: AppColors.primary.withValues(alpha: 0.25),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textPrimary,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                  backgroundColor: AppColors.background,
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : AppColors.surfaceLight,
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (_, _) => const Text(
        'Kategoriler yüklenemedi',
        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
      ),
    );
  }

  // ==================== TAB 2: ÇALIŞMA & TESLİMAT ====================
  Widget _buildDeliveryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Working Hours
          _buildSectionCard(
            title: 'Çalışma Saatleri',
            icon: Icons.schedule_outlined,
            children: [_buildWorkingHoursGrid()],
          ),
          const SizedBox(height: 24),

          // Delivery Settings
          _buildSectionCard(
            title: 'Teslimat Ayarları',
            icon: Icons.delivery_dining_outlined,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SwitchListTile(
                      value: _deliveryEnabled,
                      onChanged: (v) => setState(() => _deliveryEnabled = v),
                      title: const Text(
                        'Teslimat Aktif',
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SwitchListTile(
                      value: _pickupEnabled,
                      onChanged: (v) => setState(() => _pickupEnabled = v),
                      title: const Text(
                        'Gel-Al Aktif',
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _minOrderController,
                      label: 'Min. Sipariş (\u20BA)',
                      icon: Icons.payments_outlined,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _deliveryFeeController,
                      label: 'Teslimat Ücreti (\u20BA)',
                      icon: Icons.local_shipping_outlined,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _freeDeliveryController,
                label: 'Ücretsiz Teslimat Eşiği (\u20BA)',
                icon: Icons.money_off_outlined,
                keyboardType: TextInputType.number,
                hint: '0 = Her zaman ücretli',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _minPrepTimeController,
                      label: 'Min. Hazırlama (dk)',
                      icon: Icons.timer_outlined,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _maxPrepTimeController,
                      label: 'Max. Hazırlama (dk)',
                      icon: Icons.timer_off_outlined,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Location Map
          _buildLocationSection(),
          const SizedBox(height: 24),

          // Delivery Zones
          _buildSectionCard(
            title: 'Teslimat Bölgeleri',
            icon: Icons.map_outlined,
            children: [_buildDeliveryZonesSection()],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    final lat = double.tryParse(_latitudeController.text) ?? 0;
    final lng = double.tryParse(_longitudeController.text) ?? 0;
    final hasValidCoords = lat != 0 && lng != 0;

    return _buildSectionCard(
      title: 'Konum',
      icon: Icons.location_on_outlined,
      children: [
        if (hasValidCoords) ...[
          SizedBox(
            height: 250,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(lat, lng),
                  zoom: 16,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('business'),
                    position: LatLng(lat, lng),
                    infoWindow: InfoWindow(title: _nameController.text),
                  ),
                },
                zoomControlsEnabled: true,
                mapToolbarEnabled: false,
                myLocationButtonEnabled: false,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _latitudeController,
                label: 'Enlem',
                icon: Icons.explore,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: _longitudeController,
                label: 'Boylam',
                icon: Icons.explore,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDeliveryZonesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with add button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _deliveryZones.isEmpty
                  ? 'Henüz teslimat bölgesi tanımlanmamış'
                  : '${_deliveryZones.length} teslimat bölgesi tanımlı',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            ElevatedButton.icon(
              onPressed: _addDeliveryZone,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Bölge Ekle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_deliveryZones.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceLight),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.map_outlined,
                  size: 48,
                  color: AppColors.textMuted.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Teslimat bölgesi tanımlanmamış',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Yukarıdaki "Bölge Ekle" butonuyla yeni teslimat bölgesi oluşturabilirsiniz.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...(_deliveryZones.map((zone) {
            final name = zone['zone_name'] as String? ?? 'Bölge';
            final radiusKm = zone['radius_km'] as num?;
            final fee = zone['delivery_fee'] as num?;
            final minOrder = zone['min_order_amount'] as num?;
            final isActive = zone['is_active'] as bool? ?? true;
            final color = zone['color'] as String? ?? '#4CAF50';

            Color zoneColor;
            try {
              final hex = color.replaceAll('#', '');
              zoneColor = Color(int.parse('FF$hex', radix: 16));
            } catch (_) {
              zoneColor = AppColors.primary;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive
                      ? AppColors.surfaceLight
                      : AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  // Zone color indicator
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: zoneColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: zoneColor, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        radiusKm?.toStringAsFixed(0) ?? '?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: zoneColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${radiusKm != null ? '$radiusKm km yarıçap' : 'Yarıçap belirtilmemiş'}'
                          '${fee != null ? ' • ${fee.toStringAsFixed(0)}₺ teslimat' : ''}'
                          '${minOrder != null ? ' • Min ${minOrder.toStringAsFixed(0)}₺' : ''}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Active/Inactive toggle
                  Switch(
                    value: isActive,
                    activeTrackColor: AppColors.success,
                    onChanged: (value) {
                      final idx = _deliveryZones.indexWhere(
                        (z) => z['id'] == zone['id'],
                      );
                      if (idx != -1) {
                        setState(() {
                          _deliveryZones[idx] = {
                            ..._deliveryZones[idx],
                            'is_active': value,
                          };
                        });
                        _updateDeliveryZone(_deliveryZones[idx]);
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  // Edit button
                  IconButton(
                    onPressed: () => _showEditZoneDialog(zone),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: 'Düzenle',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Delete button
                  IconButton(
                    onPressed: () => _deleteDeliveryZone(zone['id']),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    tooltip: 'Sil',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.error.withValues(alpha: 0.1),
                      foregroundColor: AppColors.error,
                    ),
                  ),
                ],
              ),
            );
          })),
      ],
    );
  }

  // ==================== TAB 3: BİLDİRİMLER ====================
  Widget _buildNotificationsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _buildSectionCard(
        title: 'Bildirim Ayarları',
        icon: Icons.notifications_outlined,
        children: [
          _buildNotificationTile(
            'Yeni Sipariş Bildirimi',
            'Yeni sipariş geldiğinde bildirim gönder',
            _notifyNewOrder,
            (v) => setState(() => _notifyNewOrder = v),
          ),
          _buildNotificationTile(
            'Sipariş İptal Bildirimi',
            'Sipariş iptal edildiğinde bildirim gönder',
            _notifyOrderCancel,
            (v) => setState(() => _notifyOrderCancel = v),
          ),
          _buildNotificationTile(
            'Ses Bildirimi',
            'Bildirim geldiğinde ses çal',
            _notifySoundEnabled,
            (v) => setState(() => _notifySoundEnabled = v),
          ),
          _buildNotificationTile(
            'Yeni Yorum Bildirimi',
            'Yeni yorum yazıldığında bildirim gönder',
            _notifyNewReview,
            (v) => setState(() => _notifyNewReview = v),
          ),
          _buildNotificationTile(
            'Düşük Stok Uyarısı',
            'Stok azaldığında uyarı gönder',
            _notifyLowStock,
            (v) => setState(() => _notifyLowStock = v),
          ),
          _buildNotificationTile(
            'Haftalık Rapor',
            'Her hafta özet rapor gönder',
            _notifyWeeklyReport,
            (v) => setState(() => _notifyWeeklyReport = v),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        contentPadding: EdgeInsets.zero,
        activeThumbColor: AppColors.success,
      ),
    );
  }

  // ==================== TAB 4: DOĞRULAMA ====================
  Widget _buildVerificationTab() {
    final docsAsync = ref.watch(_merchantDocumentsProvider(widget.merchantId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.info, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'İşletmenin yüklediği doğrulama belgelerini buradan inceleyip onaylayabilir veya reddedebilirsiniz.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          docsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Center(
              child: Text(
                'Belgeler yüklenemedi: $e',
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
            data: (docs) {
              final docsMap = <String, Map<String, dynamic>>{};
              for (var doc in docs) {
                docsMap[doc['type'] as String] = doc;
              }

              return Column(
                children: [
                  _buildDocumentCard(
                    docType: 'tax_certificate',
                    label: 'Vergi Levhası',
                    icon: Icons.receipt_long_outlined,
                    doc: docsMap['tax_certificate'],
                  ),
                  const SizedBox(height: 16),
                  _buildDocumentCard(
                    docType: 'business_license',
                    label: 'İşyeri Ruhsatı',
                    icon: Icons.business_outlined,
                    doc: docsMap['business_license'],
                  ),
                  const SizedBox(height: 16),
                  _buildDocumentCard(
                    docType: 'id_card',
                    label: 'Yetkili Kimlik',
                    icon: Icons.badge_outlined,
                    doc: docsMap['id_card'],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard({
    required String docType,
    required String label,
    required IconData icon,
    Map<String, dynamic>? doc,
  }) {
    final status = doc?['status'] as String? ?? 'missing';
    final url = doc?['url'] as String?;
    final rejectionReason = doc?['rejection_reason'] as String?;
    final docId = doc?['id'] as String?;
    final updatedAt = doc?['updated_at'] as String?;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'approved':
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle;
        statusText = 'Onaylandı';
        break;
      case 'rejected':
        statusColor = AppColors.error;
        statusIcon = Icons.cancel;
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
        statusText = 'Yüklenmedi';
    }

    return _buildSectionCard(
      title: label,
      icon: icon,
      children: [
        // Status row
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(statusIcon, color: statusColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (updatedAt != null)
                    Text(
                      'Son güncelleme: ${_formatDate(updatedAt)}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),

        // Rejection reason
        if (status == 'rejected' &&
            rejectionReason != null &&
            rejectionReason.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 16, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Red Nedeni: $rejectionReason',
                    style: TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Action buttons (only if document exists)
        if (doc != null && docId != null) ...[
          const SizedBox(height: 16),
          const Divider(color: AppColors.surfaceLight),
          const SizedBox(height: 12),
          Row(
            children: [
              // Preview button
              if (url != null && url.isNotEmpty)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showDocumentPreview(url, label),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('Önizle'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.info,
                      side: BorderSide(
                        color: AppColors.info.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              if (url != null && url.isNotEmpty) const SizedBox(width: 10),
              // Approve button
              if (status != 'approved')
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateDocumentStatus(docId, 'approved'),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Onayla'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              if (status != 'approved') const SizedBox(width: 10),
              // Reject button
              if (status != 'rejected')
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showRejectDialog(docId),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Reddet'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],

        // No document uploaded message
        if (doc == null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.surfaceLight,
                style: BorderStyle.solid,
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  size: 20,
                  color: AppColors.textMuted,
                ),
                SizedBox(width: 8),
                Text(
                  'İşletme henüz bu belgeyi yüklememiş',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _showDocumentPreview(String url, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.surfaceLight),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.description_outlined,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              // Image preview
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: url.toLowerCase().endsWith('.pdf')
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.picture_as_pdf,
                              size: 64,
                              color: AppColors.error,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'PDF belgesi tarayıcıda açılmalıdır',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                // Open in browser - URL is already public
                                Navigator.pop(context);
                              },
                              icon: const Icon(Icons.open_in_new, size: 18),
                              label: const Text('Tarayıcıda Aç'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                              ),
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            url,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.broken_image,
                                  size: 64,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Görsel yüklenemedi',
                                  style: TextStyle(color: AppColors.textMuted),
                                ),
                              ],
                            ),
                            loadingBuilder: (_, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            },
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  // ==================== TAB 5: DURUM & ADMİN ====================
  Widget _buildStatusTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Admin Controls
          _buildSectionCard(
            title: 'Admin Kontrolleri',
            icon: Icons.admin_panel_settings_outlined,
            children: [
              _buildTextField(
                controller: _commissionController,
                label: 'Komisyon Oranı (%)',
                icon: Icons.percent_outlined,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Open/Close
          _buildSectionCard(
            title: 'İşletme Durumu',
            icon: Icons.toggle_on_outlined,
            children: [
              SwitchListTile(
                value: _isOpen,
                onChanged: (v) => setState(() => _isOpen = v),
                title: Text(
                  _isOpen ? 'Açık' : 'Kapalı',
                  style: TextStyle(
                    color: _isOpen ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                subtitle: Text(
                  _isOpen ? 'İşletme sipariş alıyor' : 'İşletme şu anda kapalı',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Approval
          _buildSectionCard(
            title: 'Onay Durumu',
            icon: Icons.verified_outlined,
            children: [_buildApprovalSelector()],
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalSelector() {
    final options = [
      {
        'value': true,
        'label': 'Onaylı',
        'color': AppColors.success,
        'icon': Icons.check_circle_outline,
      },
      {
        'value': false,
        'label': 'Onay Bekliyor',
        'color': AppColors.warning,
        'icon': Icons.hourglass_empty_outlined,
      },
    ];

    return Row(
      children: options.map((option) {
        final isSelected = _isApproved == option['value'];
        final color = option['color'] as Color;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: option != options.last ? 12 : 0),
            child: InkWell(
              onTap: () =>
                  setState(() => _isApproved = option['value'] as bool),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.15)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? color.withValues(alpha: 0.5)
                        : AppColors.surfaceLight,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      option['icon'] as IconData,
                      color: isSelected ? color : AppColors.textMuted,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      option['label'] as String,
                      style: TextStyle(
                        color: isSelected ? color : AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ==================== SHARED WIDGETS ====================
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.surfaceLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.surfaceLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textMuted),
      ),
    );
  }

  Widget _buildWorkingHoursGrid() {
    return Column(
      children: List.generate(7, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index < 6 ? 12 : 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceLight),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    _dayNames[index],
                    style: TextStyle(
                      color: _dayClosed[index]
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () =>
                      setState(() => _dayClosed[index] = !_dayClosed[index]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _dayClosed[index]
                          ? AppColors.error.withValues(alpha: 0.15)
                          : AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _dayClosed[index]
                            ? AppColors.error.withValues(alpha: 0.3)
                            : AppColors.success.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _dayClosed[index] ? 'Kapalı' : 'Açık',
                      style: TextStyle(
                        color: _dayClosed[index]
                            ? AppColors.error
                            : AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                if (!_dayClosed[index]) ...[
                  _buildTimePicker(
                    time: _openingTimes[index],
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _openingTimes[index],
                        builder: (c, child) => Theme(
                          data: Theme.of(c).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: AppColors.primary,
                              surface: AppColors.surface,
                              onSurface: AppColors.textPrimary,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setState(() => _openingTimes[index] = picked);
                      }
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '-',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  _buildTimePicker(
                    time: _closingTimes[index],
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _closingTimes[index],
                        builder: (c, child) => Theme(
                          data: Theme.of(c).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: AppColors.primary,
                              surface: AppColors.surface,
                              onSurface: AppColors.textPrimary,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setState(() => _closingTimes[index] = picked);
                      }
                    },
                  ),
                ] else
                  const Expanded(
                    child: Text(
                      'Gün kapalı',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTimePicker({
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.access_time, color: AppColors.textMuted, size: 16),
            const SizedBox(width: 6),
            Text(
              _formatTime(time),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
