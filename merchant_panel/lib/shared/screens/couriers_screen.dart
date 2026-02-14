import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/merchant_provider.dart';
import '../../core/utils/app_dialogs.dart';

// Restorana ait kuryeler (work_mode = 'restaurant' veya 'both' ve merchant_id eşleşen)
// StreamProvider ile realtime güncellemeler
final merchantCouriersProvider = StreamProvider<List<Map<String, dynamic>>>((ref) async* {
  final supabase = ref.watch(supabaseProvider);
  final merchant = ref.watch(currentMerchantProvider).value;

  debugPrint('merchantCouriersProvider: merchant = ${merchant?.id}');

  if (merchant == null) {
    debugPrint('merchantCouriersProvider: merchant is null, yielding empty');
    yield [];
    return;
  }

  // İlk veriyi getir
  Future<List<Map<String, dynamic>>> fetchCouriers() async {
    debugPrint('fetchCouriers: fetching for merchant ${merchant.id}');

    // merchant_id eşleşen tüm kuryeler (onaylanmış)
    final response = await supabase
        .from('couriers')
        .select()
        .eq('merchant_id', merchant.id)
        .eq('status', 'approved')
        .order('created_at', ascending: false);

    debugPrint('fetchCouriers: got ${response.length} couriers');
    for (var c in response) {
      debugPrint('  - ${c['full_name']}: online=${c['is_online']}, busy=${c['is_busy']}, work_mode=${c['work_mode']}');
    }

    return List<Map<String, dynamic>>.from(response);
  }

  yield await fetchCouriers();

  // Realtime dinle - merchant'a ait kuryeler
  await for (final _ in supabase
      .from('couriers')
      .stream(primaryKey: ['id'])
      .eq('merchant_id', merchant.id)) {
    debugPrint('merchantCouriersProvider: realtime update received, refreshing...');
    yield await fetchCouriers();
  }
});

// Platform kuryeleri (work_mode = 'platform' veya 'both', online ve müsait)
// StreamProvider ile realtime güncellemeler
final availablePlatformCouriersProvider = StreamProvider<List<Map<String, dynamic>>>((ref) async* {
  final supabase = ref.watch(supabaseProvider);

  // İlk veriyi getir
  Future<List<Map<String, dynamic>>> fetchCouriers() async {
    final response = await supabase
        .from('couriers')
        .select()
        .eq('status', 'approved')
        .eq('is_online', true)
        .eq('is_busy', false) // Platform kuryeleri için müsaitlik kontrolü
        .inFilter('work_mode', ['platform', 'both'])
        .order('rating', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(response);
  }

  yield await fetchCouriers();

  // Tüm kuryeleri dinle (online durumu için)
  await for (final _ in supabase
      .from('couriers')
      .stream(primaryKey: ['id'])) {
    yield await fetchCouriers();
  }
});

// Kurye bağlantı istekleri (pending olanlar)
// StreamProvider ile realtime güncellemeler
final courierRequestsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) async* {
  final supabase = ref.watch(supabaseProvider);
  final merchant = ref.watch(currentMerchantProvider).value;

  if (merchant == null) {
    yield [];
    return;
  }

  // İlk veriyi getir
  Future<List<Map<String, dynamic>>> fetchRequests() async {
    final response = await supabase
        .from('merchant_courier_requests')
        .select('*, couriers(id, full_name, phone, vehicle_type, vehicle_plate, rating, total_deliveries, work_mode)')
        .eq('merchant_id', merchant.id)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  yield await fetchRequests();

  // Kurye isteklerini dinle
  await for (final _ in supabase
      .from('merchant_courier_requests')
      .stream(primaryKey: ['id'])
      .eq('merchant_id', merchant.id)) {
    yield await fetchRequests();
  }
});

class CouriersScreen extends ConsumerStatefulWidget {
  const CouriersScreen({super.key});

  @override
  ConsumerState<CouriersScreen> createState() => _CouriersScreenState();
}

class _CouriersScreenState extends ConsumerState<CouriersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Realtime artık StreamProvider'lar tarafından yönetiliyor
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kurye Yonetimi',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Restoraniniza bagli kuryeleri ve platform kuryelerini goruntuleyiin',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              tabs: [
                const Tab(text: 'Kuryelerim'),
                _buildRequestsTab(),
                const Tab(text: 'Platform Kuryeleri'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMyCouriersTab(),
                _buildCourierRequestsTab(),
                _buildPlatformCouriersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // İstekler sekmesi başlığı (badge ile)
  Widget _buildRequestsTab() {
    final requestsAsync = ref.watch(courierRequestsProvider);
    return requestsAsync.when(
      loading: () => const Tab(text: 'Istekler'),
      error: (_, __) => const Tab(text: 'Istekler'),
      data: (requests) {
        if (requests.isEmpty) {
          return const Tab(text: 'Istekler');
        }
        return Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Istekler'),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  requests.length.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Kurye istekleri sekmesi içeriği
  Widget _buildCourierRequestsTab() {
    final requestsAsync = ref.watch(courierRequestsProvider);

    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Hata: $err')),
      data: (requests) {
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: AppColors.textMuted),
                const SizedBox(height: 16),
                Text(
                  'Bekleyen kurye istegi yok',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Kuryeler restoraniniza baglanti istegi gonderdiginde burada gorunecek',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.pending_actions, color: AppColors.warning),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${requests.length} kurye restoraniniza baglanmak istiyor. Onayladiginiz kuryeler sizin kurye listenize eklenir.',
                        style: TextStyle(color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Card(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: requests.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final request = requests[index];
                      return _buildCourierRequestTile(request);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Kurye istek satırı
  Widget _buildCourierRequestTile(Map<String, dynamic> request) {
    final courier = request['couriers'] as Map<String, dynamic>?;
    if (courier == null) return const SizedBox.shrink();

    final rating = (courier['rating'] as num?)?.toDouble() ?? 0.0;
    final totalDeliveries = courier['total_deliveries'] as int? ?? 0;
    final workMode = courier['work_mode'] as String? ?? 'restaurant';
    final message = request['message'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              (courier['full_name'] as String?)?.substring(0, 1).toUpperCase() ?? 'K',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          // Bilgiler
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      courier['full_name'] ?? 'Kurye',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: workMode == 'both'
                            ? AppColors.info.withValues(alpha: 0.1)
                            : AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        workMode == 'both' ? 'Platform+Restoran' : 'Restoran',
                        style: TextStyle(
                          color: workMode == 'both' ? AppColors.info : AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      _getVehicleIcon(courier['vehicle_type']),
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getVehicleText(courier['vehicle_type']),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      courier['vehicle_plate'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.star, size: 14, color: AppColors.warning),
                    const SizedBox(width: 4),
                    Text(
                      rating.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.local_shipping, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '$totalDeliveries teslimat',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                if (message != null && message.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.message, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            message,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Butonlar
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () => _approveRequest(request['id'], courier['id']),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Onayla'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _rejectRequest(request['id']),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Reddet'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // İsteği onayla
  Future<void> _approveRequest(String requestId, String courierId) async {
    try {
      final supabase = ref.read(supabaseProvider);
      final merchant = ref.read(currentMerchantProvider).value;
      if (merchant == null) return;

      // İsteği onayla
      await supabase
          .from('merchant_courier_requests')
          .update({'status': 'approved', 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', requestId);

      // Kurye'nin merchant_id'sini ve work_mode'unu güncelle
      await supabase
          .from('couriers')
          .update({
            'merchant_id': merchant.id,
            'work_mode': 'both',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', courierId);

      // Provider'ları yenile
      ref.invalidate(courierRequestsProvider);
      ref.invalidate(merchantCouriersProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Kurye onaylandi ve listenize eklendi'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showError(context, 'Hata: $e');
      }
    }
  }

  // İsteği reddet
  Future<void> _rejectRequest(String requestId) async {
    // Önce red sebebi sor
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _RejectReasonDialog(),
    );

    if (reason == null) return; // İptal edildi

    try {
      final supabase = ref.read(supabaseProvider);

      await supabase.from('merchant_courier_requests').update({
        'status': 'rejected',
        'rejection_reason': reason.isEmpty ? null : reason,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);

      ref.invalidate(courierRequestsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kurye istegi reddedildi')),
        );
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showError(context, 'Hata: $e');
      }
    }
  }

  Widget _buildMyCouriersTab() {
    final couriersAsync = ref.watch(merchantCouriersProvider);

    return couriersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Hata: $err')),
      data: (couriers) {
        if (couriers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delivery_dining, size: 64, color: AppColors.textMuted),
                const SizedBox(height: 16),
                Text(
                  'Henuz restoraniniza bagli kurye yok',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Kuryeler kayit olurken restoraninizi sectiginde burada gorunecekler',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.symmetric(horizontal: 48),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.info, size: 32),
                      const SizedBox(height: 12),
                      Text(
                        'Kurye Nasil Eklenir?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.info,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '1. Kurye, kurye uygulamasindan kayit olur\n'
                        '2. "Restoran Kuryesi" veya "Her Ikisi" modunu secer\n'
                        '3. Restoraninizin e-posta adresini girer\n'
                        '4. Admin onayindan sonra burada gorunur',
                        style: TextStyle(color: AppColors.info, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Stats Row
              Row(
                children: [
                  _buildStatCard(
                    'Toplam Kurye',
                    couriers.length.toString(),
                    Icons.people,
                    AppColors.primary,
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    'Online',
                    couriers.where((c) => c['is_online'] == true).length.toString(),
                    Icons.circle,
                    AppColors.success,
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    'Teslimatta',
                    couriers.where((c) => c['is_busy'] == true).length.toString(),
                    Icons.delivery_dining,
                    AppColors.info,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Couriers List
              Expanded(
                child: Card(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: couriers.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final courier = couriers[index];
                      return _buildCourierTile(courier, isOwnCourier: true);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlatformCouriersTab() {
    final couriersAsync = ref.watch(availablePlatformCouriersProvider);

    return couriersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Hata: $err')),
      data: (couriers) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.info),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Platform kuryeleri "Platform Kuryesi Kullan" secenegini sectiginizde otomatik olarak atanir. En yakin ve musait kurye siparisi alir.',
                        style: TextStyle(color: AppColors.info),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Musait Platform Kuryeleri',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${couriers.length} kurye',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => ref.invalidate(availablePlatformCouriersProvider),
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Yenile',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (couriers.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: AppColors.textMuted),
                        const SizedBox(height: 16),
                        Text(
                          'Su an musait platform kuryesi yok',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Kuryeler online oldugunda burada gorunecekler',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: Card(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: couriers.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final courier = couriers[index];
                        return _buildCourierTile(courier, isOwnCourier: false);
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.headlineSmall),
                Text(title, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourierTile(Map<String, dynamic> courier, {required bool isOwnCourier}) {
    final isOnline = courier['is_online'] == true;
    final isBusy = courier['is_busy'] == true;
    final workMode = courier['work_mode'] as String? ?? 'platform';
    final rating = (courier['rating'] as num?)?.toDouble() ?? 0.0;
    final totalDeliveries = courier['total_deliveries'] as int? ?? 0;

    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              (courier['full_name'] as String?)?.substring(0, 1).toUpperCase() ?? 'K',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isOnline ? AppColors.success : AppColors.textMuted,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2),
              ),
            ),
          ),
        ],
      ),
      title: Row(
        children: [
          Text(courier['full_name'] ?? 'Kurye'),
          const SizedBox(width: 8),
          if (isOwnCourier && workMode == 'both')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Platform+Restoran',
                style: TextStyle(
                  color: AppColors.info,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
      subtitle: Row(
        children: [
          Icon(
            _getVehicleIcon(courier['vehicle_type']),
            size: 14,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            _getVehicleText(courier['vehicle_type']),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 12),
          Icon(Icons.star, size: 14, color: AppColors.warning),
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 12),
          Icon(Icons.local_shipping, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            '$totalDeliveries teslimat',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isBusy)
            _buildStatusChip('Teslimatta', AppColors.info)
          else if (isOnline)
            _buildStatusChip('Musait', AppColors.success)
          else
            _buildStatusChip('Cevrimdisi', AppColors.textMuted),
          if (isOwnCourier && courier['phone'] != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.phone, size: 20),
              onPressed: () => _callCourier(courier['phone']),
              tooltip: 'Ara',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  IconData _getVehicleIcon(String? vehicleType) {
    switch (vehicleType) {
      case 'bicycle':
        return Icons.pedal_bike;
      case 'motorcycle':
        return Icons.two_wheeler;
      case 'car':
        return Icons.directions_car;
      default:
        return Icons.delivery_dining;
    }
  }

  String _getVehicleText(String? vehicleType) {
    switch (vehicleType) {
      case 'bicycle':
        return 'Bisiklet';
      case 'motorcycle':
        return 'Motosiklet';
      case 'car':
        return 'Araba';
      default:
        return 'Belirsiz';
    }
  }

  Future<void> _callCourier(String phone) async {
    // URL launcher ile arama yapılabilir
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Aranıyor: $phone')),
    );
  }
}

// Red sebebi dialog'u
class _RejectReasonDialog extends StatefulWidget {
  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Istegi Reddet'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bu kurye istegini reddetmek istediginize emin misiniz?'),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Red sebebi (opsiyonel)',
              hintText: 'Kurye bu mesaji gorecek',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Iptal'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          child: const Text('Reddet'),
        ),
      ],
    );
  }
}
