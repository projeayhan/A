import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emlakci_panel/core/services/log_service.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/payment_service.dart';

SupabaseClient get _supabase => Supabase.instance.client;

// ─── Providers ───────────────────────────────────────────────────────────────

final bannerPackagesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final data = await _supabase
      .from('banner_packages')
      .select()
      .eq('is_active', true)
      .order('sort_order');
  return List<Map<String, dynamic>>.from(data as List);
});

final myBannersProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final realtorId = _supabase.auth.currentUser?.id;
  if (realtorId == null) return [];
  final data = await _supabase
      .from('banners')
      .select('*, banner_packages(name, duration_days)')
      .eq('merchant_id', realtorId)
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(data as List);
});

// ─── Screen ──────────────────────────────────────────────────────────────────

class BannerAdsScreen extends ConsumerStatefulWidget {
  const BannerAdsScreen({super.key});

  @override
  ConsumerState<BannerAdsScreen> createState() => _BannerAdsScreenState();
}

class _BannerAdsScreenState extends ConsumerState<BannerAdsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Banner Reklamları',
                  style: TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Uygulamada banner reklam satın alın',
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabs: const [
                    Tab(text: 'Paketler'),
                    Tab(text: 'Bannerlarım'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _PackagesTab(
                  onPurchased: () {
                    ref.invalidate(myBannersProvider);
                    _tabController.animateTo(1);
                  },
                ),
                _MyBannersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Packages Tab ─────────────────────────────────────────────────────────────

class _PackagesTab extends ConsumerWidget {
  final VoidCallback onPurchased;
  const _PackagesTab({required this.onPurchased});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packagesAsync = ref.watch(bannerPackagesProvider);
    final currencyFormat = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 0,
    );

    return packagesAsync.when(
      data: (packages) => GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 350,
          mainAxisExtent: 220,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: packages.length,
        itemBuilder: (context, i) {
          final pkg = packages[i];
          return _PackageCard(
            package: pkg,
            currencyFormat: currencyFormat,
            onBuy: () => _showPurchaseDialog(context, ref, pkg),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(
        child: Text('Hata: $e', style: const TextStyle(color: AppColors.error)),
      ),
    );
  }

  void _showPurchaseDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> pkg,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _PurchaseDialog(package: pkg, onSuccess: onPurchased),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final Map<String, dynamic> package;
  final NumberFormat currencyFormat;
  final VoidCallback onBuy;

  const _PackageCard({
    required this.package,
    required this.currencyFormat,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final price = (package['price'] as num).toDouble();
    final days = package['duration_days'] as int;
    final isPremium = (package['name'] as String).toLowerCase().contains(
      'premium',
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPremium ? AppColors.primary : AppColors.borderDark,
          width: isPremium ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPremium)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'PREMIUM',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Text(
            package['name'] as String,
            style: const TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            package['description'] as String? ?? '',
            style: const TextStyle(
              color: AppColors.textMutedDark,
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                size: 14,
                color: AppColors.textMutedDark,
              ),
              const SizedBox(width: 4),
              Text(
                '$days gün',
                style: const TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onBuy,
              style: ElevatedButton.styleFrom(
                backgroundColor: isPremium
                    ? AppColors.primary
                    : AppColors.surfaceDark,
                foregroundColor: isPremium ? Colors.white : AppColors.primary,
                side: isPremium
                    ? null
                    : const BorderSide(color: AppColors.primary),
              ),
              child: Text(currencyFormat.format(price)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Purchase Dialog ──────────────────────────────────────────────────────────

class _PurchaseDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> package;
  final VoidCallback onSuccess;

  const _PurchaseDialog({required this.package, required this.onSuccess});

  @override
  ConsumerState<_PurchaseDialog> createState() => _PurchaseDialogState();
}

class _PurchaseDialogState extends ConsumerState<_PurchaseDialog> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _imageUrl;
  bool _loading = false;
  bool _uploading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
    );
    if (file == null) return;

    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last;
      final path = 'banners/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _supabase.storage
          .from('merchant-assets')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
          );
      final url = _supabase.storage.from('merchant-assets').getPublicUrl(path);
      setState(() => _imageUrl = url);
    } catch (e, st) {
      LogService.error('Failed to upload banner image', error: e, stackTrace: st, source: 'BannerAdsScreen:_pickAndUploadImage');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Görsel yüklenemedi: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Banner başlığı gerekli'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir görsel yükleyin'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    String? createdBannerId;
    try {
      final supabase = _supabase;
      final realtorId = supabase.auth.currentUser!.id;
      final price = (widget.package['price'] as num).toDouble();

      final banner = await supabase
          .from('banners')
          .insert({
            'title': _titleCtrl.text.trim(),
            'description': _descCtrl.text.trim(),
            'image_url': _imageUrl,
            'merchant_id': realtorId,
            'package_id': widget.package['id'],
            'status': 'pending_payment',
            'payment_status': 'pending',
            'amount_paid': price,
            'is_active': false,
          })
          .select()
          .single();
      createdBannerId = banner['id'] as String;

      // PaymentService üzerinden ödeme al (sağlayıcı bağımsız)
      final result = await activePaymentService.processPayment(
        amount: price,
        description: '${widget.package['name']} - Banner Reklam',
        metadata: {
          'type': 'banner',
          'banner_id': banner['id'] as String,
          'merchant_id': realtorId,
          'amount': price.toString(),
        },
      );

      if (result.isCancelled) {
        try {
          await _supabase.from('banners').delete().eq('id', createdBannerId);
        } catch (deleteErr, st) {
          LogService.error('Banner silme hatası', error: deleteErr, stackTrace: st, source: 'BannerAdsScreen:_submit');
        }
        if (_imageUrl != null) {
          try {
            final path = _imageUrl!.split('merchant-assets/').last;
            await _supabase.storage.from('merchant-assets').remove([path]);
          } catch (e, st) {
            LogService.error('Banner image cleanup failed', error: e, stackTrace: st, source: 'BannerAdsScreen:_submit');
          }
        }
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Ödeme iptal edildi'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }

      if (!result.success) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Ödeme hatası: ${result.errorMessage}'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      await supabase
          .from('banners')
          .update({'payment_status': 'completed', 'status': 'pending_approval'})
          .eq('id', banner['id']);

      nav.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Ödeme alındı! Bannerınız admin onayına gönderildi.'),
          backgroundColor: AppColors.success,
        ),
      );
      widget.onSuccess();
    } catch (e, st) {
      LogService.error('Failed to submit banner', error: e, stackTrace: st, source: 'BannerAdsScreen:_submit');
      messenger.showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = (widget.package['price'] as num).toDouble();
    final currencyFormat = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 0,
    );

    return AlertDialog(
      backgroundColor: AppColors.surfaceDark,
      title: Text(
        'Banner Satın Al: ${widget.package['name']}',
        style: const TextStyle(color: AppColors.textPrimaryDark),
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _uploading ? null : _pickAndUploadImage,
                child: Container(
                  width: double.infinity,
                  height: 140,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderDark),
                    image: _imageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(_imageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _imageUrl == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_uploading)
                              const CircularProgressIndicator()
                            else ...[
                              const Icon(
                                Icons.add_photo_alternate,
                                size: 40,
                                color: AppColors.textMutedDark,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Banner görseli yükle (önerilen: 1200x400)',
                                style: TextStyle(
                                  color: AppColors.textMutedDark,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        )
                      : Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: GestureDetector(
                              onTap: _pickAndUploadImage,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Banner Başlığı *',
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: AppColors.textPrimaryDark),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Açıklama (opsiyonel)',
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: AppColors.textPrimaryDark),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${widget.package['duration_days']} günlük banner',
                      style: const TextStyle(color: AppColors.textPrimaryDark),
                    ),
                    Text(
                      currencyFormat.format(price),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        ElevatedButton.icon(
          onPressed: _loading ? null : _submit,
          icon: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.payment),
          label: Text(_loading ? 'İşleniyor...' : 'Ödeme Yap'),
        ),
      ],
    );
  }
}

// ─── My Banners Tab ───────────────────────────────────────────────────────────

class _MyBannersTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannersAsync = ref.watch(myBannersProvider);

    return bannersAsync.when(
      data: (banners) {
        if (banners.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.campaign_outlined,
                  size: 64,
                  color: AppColors.textMutedDark,
                ),
                SizedBox(height: 16),
                Text(
                  'Henüz banner satın almadınız',
                  style: TextStyle(
                    color: AppColors.textMutedDark,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: banners.length,
          separatorBuilder: (context, i) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _BannerCard(banner: banners[i]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Hata: $e')),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final Map<String, dynamic> banner;

  const _BannerCard({required this.banner});

  Color _statusColor(String? status) {
    switch (status) {
      case 'active':
        return AppColors.success;
      case 'pending_approval':
        return AppColors.warning;
      case 'rejected':
        return AppColors.error;
      case 'expired':
        return AppColors.textMutedDark;
      default:
        return AppColors.textMutedDark;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'active':
        return 'Aktif';
      case 'pending_approval':
        return 'Onay Bekliyor';
      case 'pending_payment':
        return 'Ödeme Bekleniyor';
      case 'rejected':
        return 'Reddedildi';
      case 'expired':
        return 'Süresi Doldu';
      default:
        return status ?? '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = banner['status'] as String?;
    final title = banner['title'] as String? ?? '-';
    final imageUrl = banner['image_url'] as String?;
    final pkg = banner['banner_packages'] as Map<String, dynamic>?;
    final rejectionReason = banner['rejection_reason'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        children: [
          if (imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                width: 100,
                height: 60,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 100,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.backgroundDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.image_not_supported,
                color: AppColors.textMutedDark,
              ),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (pkg != null)
                  Text(
                    '${pkg['name']} · ${pkg['duration_days']} gün',
                    style: const TextStyle(
                      color: AppColors.textMutedDark,
                      fontSize: 12,
                    ),
                  ),
                if (rejectionReason != null && status == 'rejected')
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Red nedeni: $rejectionReason',
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _statusColor(status).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _statusLabel(status),
              style: TextStyle(
                color: _statusColor(status),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
