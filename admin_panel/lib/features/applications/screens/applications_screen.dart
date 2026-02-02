import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_theme.dart';

// Pagination sabitleri
const int _pageSize = 20;

// Partner Applications Provider with Pagination
final partnerApplicationsPageProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((
  ref,
  page,
) async {
  final supabase = ref.watch(supabaseProvider);
  final from = page * _pageSize;
  final to = from + _pageSize - 1;

  final response = await supabase
      .from('partner_applications')
      .select('*, partner_documents(*)')
      .order('created_at', ascending: false)
      .range(from, to);
  return List<Map<String, dynamic>>.from(response);
});

// Backward compatibility - ilk sayfa için
final partnerApplicationsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  return ref.watch(partnerApplicationsPageProvider(0).future);
});

// Merchant Applications Provider with Pagination
final merchantApplicationsPageProvider = FutureProvider.family<List<Map<String, dynamic>>, int>(
  (ref, page) async {
    final supabase = ref.watch(supabaseProvider);
    final from = page * _pageSize;
    final to = from + _pageSize - 1;

    try {
      final response = await supabase
          .from('merchants')
          .select('*')
          .order('created_at', ascending: false)
          .range(from, to);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  },
);

// Backward compatibility - ilk sayfa için
final merchantApplicationsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) async {
    return ref.watch(merchantApplicationsPageProvider(0).future);
  },
);

// Couriers Provider with Pagination
final couriersApplicationsPageProvider = FutureProvider.family<List<Map<String, dynamic>>, int>(
  (ref, page) async {
    final supabase = ref.watch(supabaseProvider);
    final from = page * _pageSize;
    final to = from + _pageSize - 1;

    try {
      final response = await supabase
          .from('couriers')
          .select('*')
          .order('created_at', ascending: false)
          .range(from, to);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  },
);

// Backward compatibility - ilk sayfa için
final couriersApplicationsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) async {
    return ref.watch(couriersApplicationsPageProvider(0).future);
  },
);

// Realtor Applications Provider with Pagination
final realtorApplicationsPageProvider = FutureProvider.family<List<Map<String, dynamic>>, int>(
  (ref, page) async {
    final supabase = ref.watch(supabaseProvider);
    final from = page * _pageSize;
    final to = from + _pageSize - 1;

    try {
      final response = await supabase
          .from('realtor_applications')
          .select('*')
          .order('created_at', ascending: false)
          .range(from, to);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  },
);

// Backward compatibility - ilk sayfa için
final realtorApplicationsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) async {
    return ref.watch(realtorApplicationsPageProvider(0).future);
  },
);

// Car Dealer Applications Provider with Pagination
final carDealerApplicationsPageProvider = FutureProvider.family<List<Map<String, dynamic>>, int>(
  (ref, page) async {
    final supabase = ref.watch(supabaseProvider);
    final from = page * _pageSize;
    final to = from + _pageSize - 1;

    try {
      final response = await supabase
          .from('car_dealer_applications')
          .select('*')
          .order('created_at', ascending: false)
          .range(from, to);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  },
);

// Backward compatibility - ilk sayfa için
final carDealerApplicationsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) async {
    return ref.watch(carDealerApplicationsPageProvider(0).future);
  },
);

class ApplicationsScreen extends ConsumerStatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  ConsumerState<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends ConsumerState<ApplicationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedStatus = 'pending';

  // ... (requiredDocuments map stays same, skipping to save tokens if possible, but replace needs context)
  // detailed map is needed... I will include it.

  static const Map<String, List<Map<String, String>>> requiredDocuments = {
    'taxi': [
      {
        'type': 'id_card',
        'name': 'Kimlik Fotokopisi',
        'description': 'TC Kimlik karti on ve arka yuzu',
      },
      {
        'type': 'license',
        'name': 'Surucu Belgesi (B Sinifi)',
        'description': 'Gecerli B sinifi ehliyet',
      },
      {
        'type': 'src',
        'name': 'SRC Belgesi',
        'description': 'Ticari taksi icin SRC belgesi',
      },
      {
        'type': 'psychotechnical',
        'name': 'Psikoteknik Belgesi',
        'description': 'Gecerli psikoteknik raporu',
      },
      {
        'type': 'criminal_record',
        'name': 'Sabika Kaydi',
        'description': 'Son 6 aylik sabika kaydi',
      },
      {
        'type': 'health_report',
        'name': 'Saglik Raporu',
        'description': 'Suruculuge engel hastalik olmadigi raporu',
      },
      {
        'type': 'registration',
        'name': 'Arac Ruhsati',
        'description': 'Arac tescil belgesi',
      },
      {
        'type': 'insurance',
        'name': 'Trafik Sigortasi',
        'description': 'Gecerli zorunlu trafik sigortasi',
      },
      {
        'type': 'taxi_license',
        'name': 'Taksi Plakasi/Ruhsati',
        'description': 'Ticari taksi plaka belgesi',
      },
      {
        'type': 'vehicle_inspection',
        'name': 'Muayene Belgesi',
        'description': 'Gecerli arac muayene belgesi',
      },
    ],
    'courier': [
      {
        'type': 'id_card',
        'name': 'Kimlik Fotokopisi',
        'description': 'TC Kimlik karti on ve arka yuzu',
      },
      {
        'type': 'license',
        'name': 'Surucu Belgesi',
        'description': 'Gecerli ehliyet (motor icin A, araba icin B)',
      },
      {
        'type': 'criminal_record',
        'name': 'Sabika Kaydi',
        'description': 'Son 6 aylik sabika kaydi',
      },
      {
        'type': 'registration',
        'name': 'Arac Ruhsati',
        'description': 'Motor/araba ruhsati',
      },
      {
        'type': 'insurance',
        'name': 'Trafik Sigortasi',
        'description': 'Zorunlu trafik sigortasi',
      },
      {
        'type': 'photo',
        'name': 'Vesikalik Fotograf',
        'description': 'Son 6 ayda cekilmis fotograf',
      },
    ],
    'merchant': [
      {
        'type': 'tax_certificate',
        'name': 'Vergi Levhasi',
        'description': 'Guncel vergi levhasi',
      },
      {
        'type': 'trade_registry',
        'name': 'Ticaret Sicil Gazetesi',
        'description': 'Sirket kurulusu icin',
      },
      {
        'type': 'signature_circular',
        'name': 'Imza Sirkuleri',
        'description': 'Yetkili imza ornegi',
      },
      {
        'type': 'business_license',
        'name': 'Isyeri Acma Ruhsati',
        'description': 'Belediyeden alinan ruhsat',
      },
      {
        'type': 'health_certificate',
        'name': 'Hijyen Belgesi',
        'description': 'Gida isletmeleri icin',
      },
      {
        'type': 'id_card',
        'name': 'Yetkili Kimlik',
        'description': 'Isletme yetkilisinin kimligi',
      },
      {
        'type': 'bank_account',
        'name': 'Banka Hesap Bilgisi',
        'description': 'IBAN ve hesap bilgileri',
      },
    ],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Basvuru Yonetimi',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Taksi, kurye ve isletme basvurularini inceleyin, belgelerini dogrulayin ve onaylayin',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildStatusFilter(),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _refreshAll,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Stats Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildStatsRow(),
          ),

          const SizedBox(height: 16),

          // Tabs with badge counts
          Consumer(
            builder: (context, ref, child) {
              final pendingCounts = ref.watch(notificationServiceProvider);
              return Container(
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
                    _buildTabWithBadge(
                      icon: Icons.local_taxi,
                      label: 'Taksi Suruculeri',
                      count: pendingCounts.taxiDrivers,
                    ),
                    _buildTabWithBadge(
                      icon: Icons.delivery_dining,
                      label: 'Kuryeler',
                      count: pendingCounts.couriers,
                    ),
                    _buildTabWithBadge(
                      icon: Icons.store,
                      label: 'Isletmeler',
                      count: pendingCounts.merchants,
                    ),
                    _buildTabWithBadge(
                      icon: Icons.home_work,
                      label: 'Emlakcilar',
                      count: pendingCounts.realtors,
                    ),
                    _buildTabWithBadge(
                      icon: Icons.directions_car,
                      label: 'Galericiler',
                      count: pendingCounts.carDealers,
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDriverApplicationsTab(),
                _buildCourierApplicationsTab(),
                _buildMerchantApplicationsTab(),
                _buildRealtorApplicationsTab(),
                _buildCarDealerApplicationsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedStatus,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('Tum Basvurular')),
            DropdownMenuItem(value: 'pending', child: Text('Bekleyenler')),
            DropdownMenuItem(value: 'approved', child: Text('Onaylananlar')),
            DropdownMenuItem(value: 'rejected', child: Text('Reddedilenler')),
          ],
          onChanged: (value) => setState(() => _selectedStatus = value!),
        ),
      ),
    );
  }

  Widget _buildTabWithBadge({
    required IconData icon,
    required String label,
    required int count,
  }) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final partnerApps = ref.watch(partnerApplicationsProvider);
    final merchantApps = ref.watch(merchantApplicationsProvider);
    final realtorApps = ref.watch(realtorApplicationsProvider);

    int pendingTotal = 0;
    int todayTotal = 0;

    partnerApps.whenData((apps) {
      pendingTotal += apps.where((a) => a['status'] == 'pending').length;
      todayTotal += _getTodayCount(apps);
    });

    merchantApps.whenData((apps) {
      // For merchants, check is_approved = false
      pendingTotal += apps.where((a) => a['is_approved'] == false).length;
      todayTotal += _getTodayCount(apps);
    });

    realtorApps.whenData((apps) {
      pendingTotal += apps.where((a) => a['status'] == 'pending').length;
      todayTotal += _getTodayCount(apps);
    });

    return Row(
      children: [
        _buildStatCard(
          'Bekleyen Basvuru',
          pendingTotal.toString(),
          Icons.hourglass_empty,
          AppColors.warning,
          isUrgent: true,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'Bugun Gelen',
          todayTotal.toString(),
          Icons.today,
          AppColors.info,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'Belge Bekleyen',
          _getPendingDocCount().toString(),
          Icons.folder_open,
          AppColors.primary,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          'Bu Hafta Onaylanan',
          _getApprovedThisWeekCount().toString(),
          Icons.check_circle,
          AppColors.success,
        ),
      ],
    );
  }

  int _getPendingDocCount() {
    int count = 0;
    // Driver & Courier docs
    ref.watch(partnerApplicationsProvider).whenData((apps) {
      for (var app in apps) {
        final docs = app['partner_documents'] as List? ?? [];
        count += docs.where((d) => d['status'] == 'pending').length;
      }
    });
    // Merchant docs (if any)
    ref.watch(merchantApplicationsProvider).whenData((apps) {
      for (var app in apps) {
        final docs = app['merchant_documents'] as List? ?? [];
        count += docs.where((d) => d['status'] == 'pending').length;
      }
    });
    return count;
  }

  int _getApprovedThisWeekCount() {
    int count = 0;
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));

    ref.watch(partnerApplicationsProvider).whenData((apps) {
      count += apps.where((a) {
        if (a['status'] != 'approved') return false;
        try {
          final date = DateTime.parse(a['updated_at'] ?? a['created_at']);
          return date.isAfter(weekAgo);
        } catch (e) {
          return false;
        }
      }).length;
    });

    ref.watch(merchantApplicationsProvider).whenData((apps) {
      count += apps.where((a) {
        if (a['is_approved'] != true) return false;
        try {
          final date = DateTime.parse(a['updated_at'] ?? a['created_at']);
          return date.isAfter(weekAgo);
        } catch (e) {
          return false;
        }
      }).length;
    });

    return count;
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool isUrgent = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isUrgent && int.tryParse(value) != null && int.parse(value) > 0
                ? AppColors.warning
                : AppColors.surfaceLight,
            width:
                isUrgent && int.tryParse(value) != null && int.parse(value) > 0
                ? 2
                : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodySmall),
                  Row(
                    children: [
                      Text(
                        value,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (isUrgent &&
                          int.tryParse(value) != null &&
                          int.parse(value) > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'ACIL',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverApplicationsTab() {
    // Use partnerApplicationsProvider for taxi drivers too
    final driversAsync = ref.watch(partnerApplicationsProvider);

    return driversAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Hata: $err')),
      data: (applications) {
        // Filter for taxi
        var filtered = applications
            .where((a) => a['application_type'] == 'taxi')
            .toList();

        if (_selectedStatus != 'all') {
          filtered = filtered.where((d) {
            final status = d['status'];
            if (_selectedStatus == 'pending') return status == 'pending';
            if (_selectedStatus == 'approved') return status == 'approved';
            if (_selectedStatus == 'rejected') return status == 'rejected';
            return true;
          }).toList();
        }

        return _buildApplicationsList(filtered, 'taxi');
      },
    );
  }

  Widget _buildCourierApplicationsTab() {
    // couriers tablosundan doğrudan oku
    final couriersAsync = ref.watch(couriersApplicationsProvider);

    return couriersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Hata: $err')),
      data: (couriers) {
        var filtered = couriers;
        if (_selectedStatus != 'all') {
          filtered = couriers
              .where((c) => c['status'] == _selectedStatus)
              .toList();
        }

        return _buildCouriersList(filtered);
      },
    );
  }

  // Kuryeler listesi (couriers tablosu için)
  Widget _buildCouriersList(List<Map<String, dynamic>> couriers) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${couriers.length} kurye listeleniyor',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Excel\'e Aktar'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: couriers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.delivery_dining,
                              size: 64,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Bu kriterlere uygun kurye bulunamadi',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: couriers.length,
                        itemBuilder: (context, index) {
                          return _buildCourierCard(couriers[index]);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Kurye kartı
  Widget _buildCourierCard(Map<String, dynamic> courier) {
    final status = courier['status'] ?? 'pending';
    final isPending = status == 'pending';
    final workMode = courier['work_mode'] ?? 'platform';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Icon(
                Icons.delivery_dining,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),

            // Bilgiler
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        courier['full_name'] ?? 'Kurye',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusBadge(status),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: workMode == 'platform'
                              ? AppColors.info.withValues(alpha: 0.1)
                              : workMode == 'both'
                                  ? AppColors.warning.withValues(alpha: 0.1)
                                  : AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          workMode == 'platform'
                              ? 'Platform'
                              : workMode == 'both'
                                  ? 'Platform+Restoran'
                                  : 'Restoran',
                          style: TextStyle(
                            fontSize: 11,
                            color: workMode == 'platform'
                                ? AppColors.info
                                : workMode == 'both'
                                    ? AppColors.warning
                                    : AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.phone, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        courier['phone'] ?? '-',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        courier['vehicle_type'] == 'motorcycle'
                            ? Icons.two_wheeler
                            : Icons.directions_car,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        courier['vehicle_plate'] ?? '-',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kayit: ${_formatDate(courier['created_at'])} - #${courier['id']?.toString().substring(0, 8) ?? ''}',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),

            // Aksiyonlar
            if (isPending)
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _approveCourier(courier),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Onayla'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _rejectCourier(courier),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reddet'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // Kurye onayla
  Future<void> _approveCourier(Map<String, dynamic> courier) async {
    final supabase = ref.read(supabaseProvider);

    try {
      await supabase
          .from('couriers')
          .update({
            'status': 'approved',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', courier['id']);

      ref.invalidate(couriersApplicationsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kurye basariyla onaylandi'),
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

  // Kurye reddet
  Future<void> _rejectCourier(Map<String, dynamic> courier) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kurye Basvurusunu Reddet'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${courier['full_name']} adli kurye basvurusu reddedilecek.'),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Red nedeni (opsiyonel)',
                  hintText: 'Neden reddedildigini yazin...',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reddet'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final supabase = ref.read(supabaseProvider);

    try {
      await supabase
          .from('couriers')
          .update({
            'status': 'rejected',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', courier['id']);

      ref.invalidate(couriersApplicationsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kurye basvurusu reddedildi'),
            backgroundColor: AppColors.error,
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

  Widget _buildMerchantApplicationsTab() {
    final merchantsAsync = ref.watch(merchantApplicationsProvider);

    return merchantsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Hata: $err')),
      data: (merchants) {
        var filtered = merchants;
        if (_selectedStatus != 'all') {
          filtered = merchants.where((m) {
            final isApproved = m['is_approved'] == true;
            if (_selectedStatus == 'pending') return !isApproved;
            if (_selectedStatus == 'approved') return isApproved;
            if (_selectedStatus == 'rejected') {
              return false; // Merchants table lacks 'rejected' state in simplified schema
            }
            return true;
          }).toList();
        }

        return _buildApplicationsList(filtered, 'merchant');
      },
    );
  }

  Widget _buildRealtorApplicationsTab() {
    final realtorsAsync = ref.watch(realtorApplicationsProvider);

    return realtorsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Hata: $err')),
      data: (realtors) {
        var filtered = realtors;
        if (_selectedStatus != 'all') {
          filtered = realtors
              .where((r) => r['status'] == _selectedStatus)
              .toList();
        }

        return _buildRealtorsList(filtered);
      },
    );
  }

  // Emlakçılar listesi
  Widget _buildRealtorsList(List<Map<String, dynamic>> realtors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${realtors.length} emlakci basvurusu listeleniyor',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Excel\'e Aktar'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: realtors.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.home_work,
                              size: 64,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Bu kriterlere uygun emlakci basvurusu bulunamadi',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: realtors.length,
                        itemBuilder: (context, index) {
                          return _buildRealtorCard(realtors[index]);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Emlakçı kartı
  Widget _buildRealtorCard(Map<String, dynamic> realtor) {
    final status = realtor['status'] ?? 'pending';
    final isPending = status == 'pending';

    // Uzmanlık alanlarını çözümle
    List<String> specializations = [];
    if (realtor['specialization'] != null) {
      if (realtor['specialization'] is List) {
        specializations = List<String>.from(realtor['specialization']);
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Icon(
                Icons.home_work,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),

            // Bilgiler
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        realtor['full_name'] ?? 'Emlakci',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusBadge(status),
                      if (realtor['company_name'] != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            realtor['company_name'],
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.info,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.phone, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        realtor['phone'] ?? '-',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.email, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        realtor['email'] ?? '-',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        realtor['city'] ?? '-',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                      if (realtor['experience_years'] != null) ...[
                        const SizedBox(width: 16),
                        Icon(Icons.work_history, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          '${realtor['experience_years']} yil deneyim',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                  if (specializations.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: specializations.take(3).map((spec) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          spec,
                          style: TextStyle(fontSize: 10, color: AppColors.primary),
                        ),
                      )).toList(),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Basvuru: ${_formatDate(realtor['created_at'])} - #${realtor['id']?.toString().substring(0, 8) ?? ''}',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),

            // Aksiyonlar
            if (isPending)
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showRealtorDetailDialog(realtor),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('Incele'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.info,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _approveRealtor(realtor),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Onayla'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _rejectRealtor(realtor),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reddet'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // Emlakçı detay dialogu
  void _showRealtorDetailDialog(Map<String, dynamic> realtor) {
    final status = realtor['status'] ?? 'pending';
    final isPending = status == 'pending';

    List<String> specializations = [];
    if (realtor['specialization'] != null && realtor['specialization'] is List) {
      specializations = List<String>.from(realtor['specialization']);
    }

    List<String> serviceCities = [];
    if (realtor['service_cities'] != null && realtor['service_cities'] is List) {
      serviceCities = List<String>.from(realtor['service_cities']);
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 700,
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: const Icon(Icons.home_work, size: 30, color: AppColors.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                realtor['full_name'] ?? '',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(width: 12),
                              _buildStatusBadge(status),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Emlakci Basvurusu - #${realtor['id']?.toString().substring(0, 8) ?? ''}',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailCard('Kisisel Bilgiler', Icons.person, [
                        _buildDetailItem('Ad Soyad', realtor['full_name']),
                        _buildDetailItem('E-posta', realtor['email']),
                        _buildDetailItem('Telefon', realtor['phone']),
                        _buildDetailItem('TC Kimlik No', realtor['tc_no']),
                      ]),
                      const SizedBox(height: 16),

                      _buildDetailCard('Profesyonel Bilgiler', Icons.work, [
                        _buildDetailItem('Sirket Adi', realtor['company_name']),
                        _buildDetailItem('Deneyim', '${realtor['experience_years'] ?? 0} yil'),
                        _buildDetailItem('Sehir', realtor['city']),
                        _buildDetailItem('Lisans No', realtor['license_number']),
                      ]),
                      const SizedBox(height: 16),

                      if (specializations.isNotEmpty)
                        _buildDetailCard('Uzmanlik Alanlari', Icons.category, [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: specializations.map((spec) => Chip(
                                label: Text(spec, style: const TextStyle(fontSize: 12)),
                                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              )).toList(),
                            ),
                          ),
                        ]),
                      const SizedBox(height: 16),

                      if (serviceCities.isNotEmpty)
                        _buildDetailCard('Hizmet Verdigi Sehirler', Icons.location_city, [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: serviceCities.map((city) => Chip(
                                label: Text(city, style: const TextStyle(fontSize: 12)),
                                backgroundColor: AppColors.info.withValues(alpha: 0.1),
                              )).toList(),
                            ),
                          ),
                        ]),
                      const SizedBox(height: 16),

                      _buildDetailCard('Basvuru Bilgileri', Icons.info, [
                        _buildDetailItem('Basvuru Tarihi', _formatDateTime(realtor['created_at'])),
                        _buildDetailItem('Son Guncelleme', _formatDateTime(realtor['updated_at'])),
                        if (realtor['rejection_reason'] != null)
                          _buildDetailItem('Red Nedeni', realtor['rejection_reason']),
                      ]),
                    ],
                  ),
                ),
              ),

              // Footer Actions
              if (isPending)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _rejectRealtor(realtor);
                        },
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Basvuruyu Reddet'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _approveRealtor(realtor);
                        },
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Basvuruyu Onayla'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Emlakçı onayla
  Future<void> _approveRealtor(Map<String, dynamic> realtor) async {
    final supabase = ref.read(supabaseProvider);

    try {
      // ÖNCE realtors tablosuna ekle (bu başarısız olursa applications güncellenmez)
      final existingRealtor = await supabase
          .from('realtors')
          .select()
          .eq('user_id', realtor['user_id'])
          .maybeSingle();

      if (existingRealtor == null) {
        // working_cities listesinden ilk şehri al
        final workingCities = realtor['working_cities'] as List?;
        final city = workingCities?.isNotEmpty == true ? workingCities!.first : null;

        await supabase.from('realtors').insert({
          'user_id': realtor['user_id'],
          'company_name': realtor['company_name'],
          'license_number': realtor['license_number'],
          'phone': realtor['phone'],
          'email': realtor['email'],
          'city': city,
          'status': 'approved',
          'is_verified': true,
          'approved_at': DateTime.now().toIso8601String(),
        });
      }

      // Realtors insert başarılı olduktan SONRA başvuruyu onayla
      await supabase
          .from('realtor_applications')
          .update({
            'status': 'approved',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', realtor['id']);

      ref.invalidate(realtorApplicationsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emlakci basvurusu basariyla onaylandi'),
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

  // Emlakçı reddet
  Future<void> _rejectRealtor(Map<String, dynamic> realtor) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Emlakci Basvurusunu Reddet'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${realtor['full_name']} adli emlakci basvurusu reddedilecek.'),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Red nedeni (opsiyonel)',
                  hintText: 'Neden reddedildigini yazin...',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reddet'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final supabase = ref.read(supabaseProvider);

    try {
      await supabase
          .from('realtor_applications')
          .update({
            'status': 'rejected',
            'rejection_reason': reasonController.text.isNotEmpty ? reasonController.text : null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', realtor['id']);

      ref.invalidate(realtorApplicationsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emlakci basvurusu reddedildi'),
            backgroundColor: AppColors.error,
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

  Widget _buildApplicationsList(
    List<Map<String, dynamic>> applications,
    String type,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${applications.length} basvuru listeleniyor',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Excel\'e Aktar'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: applications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox,
                              size: 64,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Bu kriterlere uygun basvuru bulunamadi',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: applications.length,
                        itemBuilder: (context, index) {
                          return _buildApplicationCard(
                            applications[index],
                            type,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> app, String type) {
    final status = _getStatus(app, type);
    final isPending = status == 'pending' || status == 'under_review';

    List docs = [];
    if (type == 'taxi') {
      docs = app['driver_documents'] ?? [];
    } else if (type == 'courier') {
      docs = app['partner_documents'] ?? [];
    } else {
      docs = app['merchant_documents'] ?? [];
    }

    final requiredDocs = requiredDocuments[type] ?? [];
    final uploadedDocTypes = docs.map((d) => d['document_type']).toSet();
    final verifiedDocs = docs
        .where((d) => d['status'] == 'verified' || d['status'] == 'approved')
        .length;
    final pendingDocs = docs.where((d) => d['status'] == 'pending').length;
    final missingDocs = requiredDocs
        .where((r) => !uploadedDocTypes.contains(r['type']))
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.surface,
      child: InkWell(
        onTap: () => _showDetailedApplicationDialog(app, type),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    backgroundImage: _getAvatarUrl(app, type) != null
                        ? NetworkImage(_getAvatarUrl(app, type)!)
                        : null,
                    child: _getAvatarUrl(app, type) == null
                        ? Icon(
                            _getTypeIcon(type),
                            color: AppColors.primary,
                            size: 28,
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _getDisplayName(app, type),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            _buildStatusBadge(status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.phone,
                              size: 14,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              app['phone'] ?? '-',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(
                              Icons.email,
                              size: 14,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              app['email'] ?? '-',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Basvuru: ${_formatDate(app['created_at'])} - #${app['id']?.toString().substring(0, 8) ?? ''}',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Actions
                  if (isPending)
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () =>
                              _showDetailedApplicationDialog(app, type),
                          icon: const Icon(Icons.visibility, size: 18),
                          label: const Text('Incele'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.info,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed:
                              docs.isNotEmpty &&
                                  missingDocs.isEmpty &&
                                  pendingDocs == 0
                              ? () => _approveApplication(app, type)
                              : null,
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Onayla'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _showRejectDialog(app, type),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Reddet'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                ],
              ),

              const Divider(height: 24),

              // Vehicle/Business Info (for taxi/courier)
              if (type == 'taxi' || type == 'courier')
                _buildVehicleInfoSection(app, type),

              if (type == 'merchant') _buildMerchantInfoSection(app),

              const SizedBox(height: 12),

              // Documents Section
              _buildDocumentsSection(
                docs,
                requiredDocs,
                missingDocs,
                verifiedDocs,
                pendingDocs,
                app,
                type,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleInfoSection(Map<String, dynamic> app, String type) {
    String vehicleType = '-';
    String brand = '-';
    String model = '-';
    String year = '-';
    String plate = '-';
    String color = '-';

    // Araç bilgilerini doğrudan partner_applications tablosundan oku
    vehicleType = app['vehicle_type'] ?? '-';
    brand = app['vehicle_brand'] ?? '-';
    model = app['vehicle_model'] ?? '-';
    year = app['vehicle_year']?.toString() ?? '-';
    plate = app['vehicle_plate'] ?? '-';
    color = app['vehicle_color'] ?? '-';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            vehicleType == 'motorcycle'
                ? Icons.two_wheeler
                : Icons.directions_car,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _buildInfoChip('Arac Tipi', _getVehicleTypeName(vehicleType)),
                _buildInfoChip('Marka', brand),
                _buildInfoChip('Model', model),
                _buildInfoChip('Yil', year),
                _buildInfoChip('Plaka', plate),
                _buildInfoChip('Renk', color),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMerchantInfoSection(Map<String, dynamic> app) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.store, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _buildInfoChip(
                  'Isletme Tipi',
                  _getBusinessTypeName(app['business_type']),
                ),
                _buildInfoChip(
                  'Adres',
                  '${app['district'] ?? ''}, ${app['city'] ?? ''}',
                ),
                _buildInfoChip(
                  'Teslimat Ucreti',
                  '${app['delivery_fee'] ?? 0} TL',
                ),
                _buildInfoChip(
                  'Min. Siparis',
                  '${app['minimum_order_amount'] ?? 0} TL',
                ),
                _buildInfoChip('Komisyon', '%${app['commission_rate'] ?? 0}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDocumentsSection(
    List docs,
    List<Map<String, String>> requiredDocs,
    List<Map<String, String>> missingDocs,
    int verifiedDocs,
    int pendingDocs,
    Map<String, dynamic> app,
    String type,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.folder, size: 18),
                const SizedBox(width: 8),
                Text('Belgeler', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(width: 12),
                _buildDocProgressBar(
                  verifiedDocs,
                  docs.length,
                  requiredDocs.length,
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () =>
                  _showDocumentsDialog(app, type, docs, requiredDocs),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Tum Belgeler'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Document status chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...docs.map((doc) => _buildDocChip(doc)),
            ...missingDocs.map((doc) => _buildMissingDocChip(doc)),
          ],
        ),

        // Warning for missing documents
        if (missingDocs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: AppColors.warning, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${missingDocs.length} zorunlu belge eksik',
                  style: TextStyle(color: AppColors.warning, fontSize: 12),
                ),
              ],
            ),
          ),

        // Warning for pending documents
        if (pendingDocs > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(Icons.hourglass_empty, color: AppColors.info, size: 16),
                const SizedBox(width: 4),
                Text(
                  '$pendingDocs belge inceleme bekliyor',
                  style: TextStyle(color: AppColors.info, fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDocProgressBar(int verified, int uploaded, int required) {
    final progress = required > 0 ? verified / required : 0.0;
    Color color;
    if (progress >= 1) {
      color = AppColors.success;
    } else if (progress >= 0.5) {
      color = AppColors.warning;
    } else {
      color = AppColors.error;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 60,
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.surfaceLight,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$verified/$required onaylandi',
          style: TextStyle(fontSize: 11, color: color),
        ),
      ],
    );
  }

  Widget _buildDocChip(Map<String, dynamic> doc) {
    final status = doc['status'];
    Color color;
    IconData icon;

    switch (status) {
      case 'verified':
      case 'approved':
        color = AppColors.success;
        icon = Icons.check_circle;
        break;
      case 'rejected':
        color = AppColors.error;
        icon = Icons.cancel;
        break;
      default:
        color = AppColors.warning;
        icon = Icons.hourglass_empty;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            _getDocumentTypeName(doc['document_type']),
            style: TextStyle(fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildMissingDocChip(Map<String, String> doc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.2),
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_circle_outline,
            size: 14,
            color: AppColors.error.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 4),
          Text(
            doc['name'] ?? '',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.error.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailedApplicationDialog(Map<String, dynamic> app, String type) {
    List docs = [];
    if (type == 'taxi') {
      docs = app['driver_documents'] ?? [];
    } else if (type == 'courier') {
      docs = app['partner_documents'] ?? [];
    } else {
      docs = app['merchant_documents'] ?? [];
    }

    final requiredDocs = requiredDocuments[type] ?? [];
    final status = _getStatus(app, type);
    final isPending = status == 'pending' || status == 'under_review';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 900,
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      backgroundImage: _getAvatarUrl(app, type) != null
                          ? NetworkImage(_getAvatarUrl(app, type)!)
                          : null,
                      child: _getAvatarUrl(app, type) == null
                          ? Icon(
                              _getTypeIcon(type),
                              size: 30,
                              color: AppColors.primary,
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _getDisplayName(app, type),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(width: 12),
                              _buildStatusBadge(status),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_getTypeName(type)} Basvurusu - #${app['id']?.toString().substring(0, 8) ?? ''}',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column - Personal & Vehicle Info
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailCard('Kisisel Bilgiler', Icons.person, [
                              if (type == 'taxi') ...[
                                _buildDetailItem('Ad', app['first_name']),
                                _buildDetailItem('Soyad', app['last_name']),
                                _buildDetailItem(
                                  'TC Kimlik No',
                                  app['tc_no'] ?? app['national_id'],
                                ),
                                _buildDetailItem(
                                  'Dogum Tarihi',
                                  _formatDate(app['date_of_birth']),
                                ),
                              ] else if (type == 'courier') ...[
                                _buildDetailItem('Ad Soyad', app['full_name']),
                                _buildDetailItem('TC Kimlik No', app['tc_no']),
                                _buildDetailItem(
                                  'Dogum Tarihi',
                                  _formatDate(app['birth_date']),
                                ),
                              ] else ...[
                                _buildDetailItem(
                                  'Isletme Adi',
                                  app['business_name'],
                                ),
                                _buildDetailItem('Yetkili', app['owner_name']),
                                _buildDetailItem('Vergi No', app['tax_number']),
                              ],
                              _buildDetailItem('E-posta', app['email']),
                              _buildDetailItem('Telefon', app['phone']),
                              _buildDetailItem('Adres', app['address']),
                              if (app['city'] != null)
                                _buildDetailItem(
                                  'Sehir',
                                  '${app['district'] ?? ''}, ${app['city']}',
                                ),
                            ]),

                            const SizedBox(height: 16),

                            if (type == 'taxi' || type == 'courier')
                              _buildVehicleDetailCard(app, type),

                            if (type == 'merchant')
                              _buildMerchantDetailCard(app),

                            const SizedBox(height: 16),

                            _buildDetailCard('Basvuru Bilgileri', Icons.info, [
                              _buildDetailItem(
                                'Basvuru Tarihi',
                                _formatDateTime(app['created_at']),
                              ),
                              _buildDetailItem(
                                'Son Guncelleme',
                                _formatDateTime(app['updated_at']),
                              ),
                              if (app['reviewed_at'] != null)
                                _buildDetailItem(
                                  'Inceleme Tarihi',
                                  _formatDateTime(app['reviewed_at']),
                                ),
                              if (app['rejection_reason'] != null)
                                _buildDetailItem(
                                  'Red Nedeni',
                                  app['rejection_reason'],
                                ),
                            ]),
                          ],
                        ),
                      ),

                      const SizedBox(width: 20),

                      // Right Column - Documents
                      Expanded(
                        flex: 1,
                        child: _buildDocumentVerificationCard(
                          app,
                          type,
                          docs,
                          requiredDocs,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Footer Actions
              if (isPending)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showRejectDialog(app, type);
                        },
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Basvuruyu Reddet'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _approveApplication(app, type);
                        },
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Basvuruyu Onayla'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard(String title, IconData icon, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value ?? '-',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleDetailCard(Map<String, dynamic> app, String type) {
    String vehicleType = '-';
    String brand = '-';
    String model = '-';
    String year = '-';
    String plate = '-';
    String color = '-';

    // Araç bilgilerini doğrudan partner_applications tablosundan oku
    vehicleType = app['vehicle_type'] ?? '-';
    brand = app['vehicle_brand'] ?? '-';
    model = app['vehicle_model'] ?? '-';
    year = app['vehicle_year']?.toString() ?? '-';
    plate = app['vehicle_plate'] ?? '-';
    color = app['vehicle_color'] ?? '-';

    return _buildDetailCard('Arac Bilgileri', Icons.directions_car, [
      _buildDetailItem('Arac Tipi', _getVehicleTypeName(vehicleType)),
      _buildDetailItem('Marka', brand),
      _buildDetailItem('Model', model),
      _buildDetailItem('Model Yili', year),
      _buildDetailItem('Plaka', plate),
      _buildDetailItem('Renk', color),
    ]);
  }

  Widget _buildMerchantDetailCard(Map<String, dynamic> app) {
    return _buildDetailCard('Isletme Ayarlari', Icons.settings, [
      _buildDetailItem(
        'Isletme Tipi',
        _getBusinessTypeName(app['business_type']),
      ),
      _buildDetailItem('Teslimat Ucreti', '${app['delivery_fee'] ?? 0} TL'),
      _buildDetailItem(
        'Min. Siparis Tutari',
        '${app['minimum_order_amount'] ?? 0} TL',
      ),
      _buildDetailItem(
        'Tahmini Teslimat',
        '${app['estimated_delivery_time'] ?? 0} dakika',
      ),
      _buildDetailItem('Komisyon Orani', '%${app['commission_rate'] ?? 0}'),
      _buildDetailItem(
        'Calışma Saatleri',
        '${app['opening_time'] ?? '09:00'} - ${app['closing_time'] ?? '22:00'}',
      ),
    ]);
  }

  Widget _buildDocumentVerificationCard(
    Map<String, dynamic> app,
    String type,
    List docs,
    List<Map<String, String>> requiredDocs,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_copy, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Belge Dogrulama',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const Divider(height: 20),

          // Required Documents List
          ...requiredDocs.map((reqDoc) {
            final uploadedDoc = docs.firstWhere(
              (d) => d['document_type'] == reqDoc['type'],
              orElse: () => null,
            );

            final isUploaded = uploadedDoc != null;
            final status = uploadedDoc?['status'];

            return _buildDocumentVerificationItem(
              reqDoc,
              uploadedDoc,
              isUploaded,
              status,
              app,
              type,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDocumentVerificationItem(
    Map<String, String> reqDoc,
    Map<String, dynamic>? uploadedDoc,
    bool isUploaded,
    String? status,
    Map<String, dynamic> app,
    String type,
  ) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (!isUploaded) {
      statusColor = AppColors.error;
      statusIcon = Icons.cancel_outlined;
      statusText = 'Yuklenmedi';
    } else {
      switch (status) {
        case 'verified':
        case 'approved':
          statusColor = AppColors.success;
          statusIcon = Icons.check_circle;
          statusText = 'Onaylandi';
          break;
        case 'rejected':
          statusColor = AppColors.error;
          statusIcon = Icons.cancel;
          statusText = 'Reddedildi';
          break;
        default:
          statusColor = AppColors.warning;
          statusIcon = Icons.hourglass_empty;
          statusText = 'Bekliyor';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reqDoc['name'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  reqDoc['description'] ?? '',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
                if (uploadedDoc != null &&
                    uploadedDoc['document_number'] != null)
                  Text(
                    'Belge No: ${uploadedDoc['document_number']}',
                    style: const TextStyle(fontSize: 11),
                  ),
                if (uploadedDoc != null && uploadedDoc['expires_at'] != null)
                  Text(
                    'Gecerlilik: ${_formatDate(uploadedDoc['expires_at'])}',
                    style: TextStyle(
                      fontSize: 11,
                      color: _isExpired(uploadedDoc['expires_at'])
                          ? AppColors.error
                          : AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (isUploaded) ...[
            const SizedBox(width: 8),
            if (uploadedDoc?['document_url'] != null)
              IconButton(
                icon: const Icon(Icons.visibility, size: 18),
                onPressed: () => _viewDocument(uploadedDoc!),
                tooltip: 'Goruntule',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.info.withValues(alpha: 0.1),
                  foregroundColor: AppColors.info,
                ),
              ),
            if (status == 'pending') ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.check, size: 18),
                onPressed: () => _verifyDocument(uploadedDoc!, type),
                tooltip: 'Onayla',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.success.withValues(alpha: 0.1),
                  foregroundColor: AppColors.success,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => _rejectDocumentWithReason(uploadedDoc!, type),
                tooltip: 'Reddet',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.error.withValues(alpha: 0.1),
                  foregroundColor: AppColors.error,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _showDocumentsDialog(
    Map<String, dynamic> app,
    String type,
    List docs,
    List<Map<String, String>> requiredDocs,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.folder_copy),
            const SizedBox(width: 12),
            const Text('Belgeler'),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          height: 500,
          child: _buildDocumentVerificationCard(app, type, docs, requiredDocs),
        ),
      ),
    );
  }

  void _viewDocument(Map<String, dynamic> doc) {
    final url = doc['document_url'];
    if (url == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 800,
          height: 600,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _getDocumentTypeName(doc['document_type']),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stack) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error,
                          size: 64,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 16),
                        const Text('Belge yuklenemedi'),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            // Open in new tab
                          },
                          child: const Text('Yeni sekmede ac'),
                        ),
                      ],
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

  void _rejectDocumentWithReason(Map<String, dynamic> doc, String type) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Belgeyi Reddet'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_getDocumentTypeName(doc['document_type'])} belgesi reddedilecek.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Red nedeni',
                  hintText: 'Belgenin reddedilme sebebini yazin...',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _rejectDocument(doc, type, reasonController.text);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reddet'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String? status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case 'pending':
      case 'under_review':
        color = AppColors.warning;
        label = 'Bekliyor';
        icon = Icons.hourglass_empty;
        break;
      case 'approved':
      case 'verified':
      case 'active':
        color = AppColors.success;
        label = 'Onaylandi';
        icon = Icons.check_circle;
        break;
      case 'rejected':
        color = AppColors.error;
        label = 'Reddedildi';
        icon = Icons.cancel;
        break;
      case 'suspended':
        color = AppColors.error;
        label = 'Askiya Alindi';
        icon = Icons.block;
        break;
      default:
        color = AppColors.textMuted;
        label = status ?? '-';
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(Map<String, dynamic> app, String type) {
    final reasonController = TextEditingController();
    String selectedReason = 'Eksik belge';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Basvuruyu Reddet'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Red nedeni secin:'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      [
                        'Eksik belge',
                        'Gecersiz/suresi dolmus belge',
                        'Yanlis/tutarsiz bilgi',
                        'Yas siniri (21 yas alti)',
                        'Arac kriterlere uygun degil',
                        'Sabika kaydi sorunu',
                        'Psikoteknik uygun degil',
                        'Diger',
                      ].map((reason) {
                        final isSelected = selectedReason == reason;
                        return ChoiceChip(
                          label: Text(reason),
                          selected: isSelected,
                          onSelected: (selected) {
                            setDialogState(() => selectedReason = reason);
                          },
                          selectedColor: AppColors.error.withValues(alpha: 0.2),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Ek aciklama (opsiyonel)',
                    hintText: 'Basvuru sahibine gosterilecek detayli mesaj...',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Iptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final reason = reasonController.text.isNotEmpty
                    ? '$selectedReason: ${reasonController.text}'
                    : selectedReason;

                await _rejectApplication(app, type, reason);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Reddet'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveApplication(
    Map<String, dynamic> app,
    String type,
  ) async {
    final supabase = ref.read(supabaseProvider);

    try {
      if (type == 'taxi' || type == 'courier') {
        // Update application status
        await supabase
            .from('partner_applications')
            .update({
              'status': 'approved',
              'reviewed_at': DateTime.now().toIso8601String(),
            })
            .eq('id', app['id']);

        // Also update taxi_drivers table if taxi
        if (type == 'taxi' && app['user_id'] != null) {
          await supabase
              .from('taxi_drivers')
              .update({
                'status': 'approved',
                'is_verified': true,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('user_id', app['user_id']);
        }

        // Create partner record
        // Check if partner already exists to avoid duplicates if re-approving
        final existingPartner = await supabase
            .from('partners')
            .select()
            .eq('user_id', app['user_id'])
            .maybeSingle();

        if (existingPartner == null) {
          await supabase.from('partners').insert({
            'user_id': app['user_id'],
            'application_id': app['id'],
            'full_name': app['full_name'],
            'phone': app['phone'],
            'email': app['email'],
            'tc_no': app['tc_no'],
            'profile_photo_url': app['profile_photo_url'],
            'roles': [type], // 'taxi' or 'courier'
            'active_role': type,
            'vehicle_type': app['vehicle_type'],
            'vehicle_brand': app['vehicle_brand'],
            'vehicle_model': app['vehicle_model'],
            'vehicle_year': app['vehicle_year'],
            'vehicle_plate': app['vehicle_plate'],
            'vehicle_color': app['vehicle_color'],
            'status': 'active',
            'is_verified': true,
          });
        }
      } else if (type == 'merchant') {
        await supabase
            .from('merchants')
            .update({
              'is_approved':
                  true, // Changed from status='approved' to is_approved=true
              'is_open': true, // Automatically open upon approval? Maybe.
              // 'status': 'approved', // Table doesn't have status, logic relies on is_approved
              // 'approved_at': DateTime.now().toIso8601String(), // Table likely has created_at/updated_at.
              // 'is_verified': true, // Table doesn't have is_verified based on SQL.
            })
            .eq('id', app['id']);
      }

      _refreshAll();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Basvuru basariyla onaylandi'),
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

  Future<void> _rejectApplication(
    Map<String, dynamic> app,
    String type,
    String reason,
  ) async {
    final supabase = ref.read(supabaseProvider);

    try {
      if (type == 'taxi' || type == 'courier') {
        await supabase
            .from('partner_applications')
            .update({
              'status': 'rejected',
              'rejection_reason': reason,
              'reviewed_at': DateTime.now().toIso8601String(),
            })
            .eq('id', app['id']);

        // Also update taxi_drivers table if taxi
        if (type == 'taxi' && app['user_id'] != null) {
          await supabase
              .from('taxi_drivers')
              .update({
                'status': 'rejected',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('user_id', app['user_id']);
        }
      } else if (type == 'merchant') {
        await supabase
            .from('merchants')
            .update({'is_approved': false}) // Just ensure it remains false
            //.update({'status': 'rejected', 'rejection_reason': reason}) // Table lacks these
            .eq('id', app['id']);
      }

      _refreshAll();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Basvuru reddedildi'),
            backgroundColor: AppColors.error,
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

  Future<void> _verifyDocument(Map<String, dynamic> doc, String type) async {
    final supabase = ref.read(supabaseProvider);
    final table = (type == 'taxi' || type == 'courier')
        ? 'partner_documents'
        : 'merchant_documents';

    await supabase
        .from(table)
        .update({
          'status': 'approved', // Use 'approved' for all
          'verified_at': DateTime.now().toIso8601String(),
        })
        .eq('id', doc['id']);

    _refreshAll();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Belge onaylandi'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _rejectDocument(
    Map<String, dynamic> doc,
    String type,
    String reason,
  ) async {
    final supabase = ref.read(supabaseProvider);
    final table = (type == 'taxi' || type == 'courier')
        ? 'partner_documents'
        : 'merchant_documents';

    await supabase
        .from(table)
        .update({'status': 'rejected', 'rejection_reason': reason})
        .eq('id', doc['id']);

    _refreshAll();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Belge reddedildi'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _refreshAll() {
    ref.invalidate(partnerApplicationsProvider);
    ref.invalidate(merchantApplicationsProvider);
    ref.invalidate(couriersApplicationsProvider);
    ref.invalidate(realtorApplicationsProvider);
  }

  // Helper methods
  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  bool _isExpired(String? dateStr) {
    if (dateStr == null) return false;
    try {
      final date = DateTime.parse(dateStr);
      return date.isBefore(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  int _getTodayCount(List<Map<String, dynamic>> apps) {
    final today = DateTime.now();
    return apps.where((a) {
      try {
        final date = DateTime.parse(a['created_at']);
        return date.year == today.year &&
            date.month == today.month &&
            date.day == today.day;
      } catch (e) {
        return false;
      }
    }).length;
  }

  String? _getAvatarUrl(Map<String, dynamic> app, String type) {
    if (type == 'taxi') return app['avatar_url'];
    if (type == 'courier') return app['profile_photo_url'];
    return app['logo_url'];
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'taxi':
        return Icons.local_taxi;
      case 'courier':
        return Icons.delivery_dining;
      default:
        return Icons.store;
    }
  }

  String _getTypeName(String type) {
    switch (type) {
      case 'taxi':
        return 'Taksi Surucusu';
      case 'courier':
        return 'Kurye';
      default:
        return 'Isletme';
    }
  }

  String _getDisplayName(Map<String, dynamic> app, String type) {
    if (type == 'taxi') {
      return '${app['first_name'] ?? ''} ${app['last_name'] ?? ''}'.trim();
    }
    if (type == 'courier') return app['full_name'] ?? '';
    return app['business_name'] ?? '';
  }

  String? _getStatus(Map<String, dynamic> app, String type) {
    if (type == 'taxi' || type == 'courier') return app['status'];
    // For merchant, we might need to derive it if field misses, but caller might expect string.
    // In _buildMerchantApplicationsTab we handled boolean `is_approved`.
    // Here we can return string representation.
    if (type == 'merchant') {
      final isApproved = app['is_approved'] == true;
      return isApproved ? 'approved' : 'pending';
    }
    return app['status'];
  }

  String _getDocumentTypeName(String? type) {
    switch (type) {
      case 'license':
        return 'Surucu Belgesi';
      case 'id_card':
        return 'Kimlik';
      case 'registration':
        return 'Arac Ruhsati';
      case 'insurance':
        return 'Sigorta';
      case 'criminal_record':
        return 'Sabika Kaydi';
      case 'psychotechnical':
        return 'Psikoteknik';
      case 'src':
        return 'SRC Belgesi';
      case 'health_report':
        return 'Saglik Raporu';
      case 'taxi_license':
        return 'Taksi Ruhsati';
      case 'vehicle_inspection':
        return 'Muayene Belgesi';
      case 'photo':
        return 'Vesikalik';
      case 'tax_certificate':
        return 'Vergi Levhasi';
      case 'trade_registry':
        return 'Ticaret Sicil';
      case 'signature_circular':
        return 'Imza Sirkuleri';
      case 'business_license':
        return 'Isyeri Ruhsati';
      case 'health_certificate':
        return 'Hijyen Belgesi';
      case 'bank_account':
        return 'Banka Bilgisi';
      default:
        return type ?? 'Belge';
    }
  }

  String _getVehicleTypeName(String? type) {
    switch (type) {
      case 'motorcycle':
        return 'Motosiklet';
      case 'car':
        return 'Otomobil';
      case 'bicycle':
        return 'Bisiklet';
      case 'sedan':
        return 'Sedan';
      case 'suv':
        return 'SUV';
      case 'van':
        return 'Minivan';
      case 'standard':
        return 'Standart';
      case 'comfort':
        return 'Konfor';
      case 'xl':
        return 'XL';
      default:
        return type ?? '-';
    }
  }

  String _getBusinessTypeName(String? type) {
    switch (type) {
      case 'restaurant':
        return 'Restoran';
      case 'market':
        return 'Market';
      case 'pharmacy':
        return 'Eczane';
      case 'store':
        return 'Magaza';
      case 'cafe':
        return 'Kafe';
      case 'bakery':
        return 'Pastane/Firinl';
      default:
        return type ?? 'Diger';
    }
  }

  // ==================== GALERİCİLER (CAR DEALERS) ====================

  Widget _buildCarDealerApplicationsTab() {
    final dealersAsync = ref.watch(carDealerApplicationsProvider);

    return dealersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Hata: $err')),
      data: (dealers) {
        var filtered = dealers;
        if (_selectedStatus != 'all') {
          filtered = dealers
              .where((d) => d['status'] == _selectedStatus)
              .toList();
        }

        return _buildCarDealersList(filtered);
      },
    );
  }

  Widget _buildCarDealersList(List<Map<String, dynamic>> dealers) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${dealers.length} galerici basvurusu listeleniyor',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Excel\'e Aktar'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: dealers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.directions_car,
                              size: 64,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Bu kriterlere uygun galerici basvurusu bulunamadi',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: dealers.length,
                        itemBuilder: (context, index) {
                          return _buildCarDealerCard(dealers[index]);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCarDealerCard(Map<String, dynamic> dealer) {
    final status = dealer['status'] ?? 'pending';
    final isPending = status == 'pending';
    final dealerType = dealer['dealer_type'] ?? 'individual';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Icon(
                dealerType == 'dealer' ? Icons.store :
                dealerType == 'authorizedDealer' ? Icons.verified : Icons.person,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),

            // Bilgiler
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        dealer['owner_name'] ?? 'Galerici',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusBadge(status),
                      const SizedBox(width: 8),
                      _buildDealerTypeBadge(dealerType),
                      if (dealer['business_name'] != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            dealer['business_name'],
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.info,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.phone, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        dealer['phone'] ?? '-',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.location_on, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        '${dealer['city'] ?? '-'}${dealer['district'] != null ? ' / ${dealer['district']}' : ''}',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                      if (dealer['email'] != null) ...[
                        const SizedBox(width: 16),
                        Icon(Icons.email, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          dealer['email'],
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Aksiyonlar
            if (isPending) ...[
              IconButton(
                onPressed: () => _approveCarDealer(dealer),
                icon: const Icon(Icons.check_circle),
                color: AppColors.success,
                tooltip: 'Onayla',
              ),
              IconButton(
                onPressed: () => _rejectCarDealer(dealer),
                icon: const Icon(Icons.cancel),
                color: AppColors.error,
                tooltip: 'Reddet',
              ),
            ],
            IconButton(
              onPressed: () => _showCarDealerDetailDialog(dealer),
              icon: const Icon(Icons.info_outline),
              color: AppColors.info,
              tooltip: 'Detay',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDealerTypeBadge(String type) {
    Color color;
    String label;
    switch (type) {
      case 'dealer':
        color = AppColors.primary;
        label = 'Galeri';
        break;
      case 'authorizedDealer':
        color = AppColors.warning;
        label = 'Yetkili Bayi';
        break;
      default:
        color = AppColors.textMuted;
        label = 'Bireysel';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  void _approveCarDealer(Map<String, dynamic> dealer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Basvuruyu Onayla'),
        content: Text('"${dealer['owner_name']}" basvurusunu onaylamak istediginize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final supabase = ref.read(supabaseProvider);

        // Başvuruyu onayla
        await supabase
            .from('car_dealer_applications')
            .update({
              'status': 'approved',
              'approved_at': DateTime.now().toIso8601String(),
            })
            .eq('id', dealer['id']);

        // car_dealers tablosuna ekle
        await supabase.from('car_dealers').insert({
          'user_id': dealer['user_id'],
          'dealer_type': dealer['dealer_type'],
          'owner_name': dealer['owner_name'],
          'business_name': dealer['business_name'],
          'phone': dealer['phone'],
          'email': dealer['email'],
          'tax_number': dealer['tax_number'],
          'city': dealer['city'],
          'district': dealer['district'],
          'address': dealer['address'],
          'status': 'active',
        });

        ref.invalidate(carDealerApplicationsProvider);
        ref.read(notificationServiceProvider.notifier).refreshCounts();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Basvuru onaylandi'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  void _rejectCarDealer(Map<String, dynamic> dealer) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Basvuruyu Reddet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"${dealer['owner_name']}" basvurusunu reddetmek istediginize emin misiniz?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Red Sebebi (opsiyonel)',
                hintText: 'Neden reddedildigini aciklayin',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reddet'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final supabase = ref.read(supabaseProvider);
        await supabase
            .from('car_dealer_applications')
            .update({
              'status': 'rejected',
              'rejection_reason': reasonController.text.isEmpty ? null : reasonController.text,
              'rejected_at': DateTime.now().toIso8601String(),
            })
            .eq('id', dealer['id']);

        ref.invalidate(carDealerApplicationsProvider);
        ref.read(notificationServiceProvider.notifier).refreshCounts();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Basvuru reddedildi'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  void _showCarDealerDetailDialog(Map<String, dynamic> dealer) {
    final status = dealer['status'] ?? 'pending';
    final isPending = status == 'pending';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary,
                      child: const Icon(Icons.directions_car, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dealer['owner_name'] ?? 'Galerici',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (dealer['business_name'] != null)
                            Text(
                              dealer['business_name'],
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(status),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildDetailRow('Satici Tipi', _getDealerTypeLabel(dealer['dealer_type'])),
                    _buildDetailRow('Telefon', dealer['phone'] ?? '-'),
                    _buildDetailRow('E-posta', dealer['email'] ?? '-'),
                    _buildDetailRow('Vergi No', dealer['tax_number'] ?? '-'),
                    _buildDetailRow('Sehir', dealer['city'] ?? '-'),
                    _buildDetailRow('Ilce', dealer['district'] ?? '-'),
                    _buildDetailRow('Adres', dealer['address'] ?? '-'),
                    if (dealer['rejection_reason'] != null)
                      _buildDetailRow('Red Sebebi', dealer['rejection_reason']),
                  ],
                ),
              ),

              // Actions
              if (isPending)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _rejectCarDealer(dealer);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                          ),
                          child: const Text('Reddet'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _approveCarDealer(dealer);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                          ),
                          child: const Text('Onayla'),
                        ),
                      ),
                    ],
                  ),
                ),

              // Close button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Kapat'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: AppColors.textMuted)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  String _getDealerTypeLabel(String? type) {
    switch (type) {
      case 'dealer':
        return 'Galeri';
      case 'authorizedDealer':
        return 'Yetkili Bayi';
      default:
        return 'Bireysel';
    }
  }
}
