import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';

// ─── Provider ────────────────────────────────────────────────────────────────

final bannerPackagesAdminProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final data = await supabase
      .from('banner_packages')
      .select()
      .order('sort_order', ascending: true);
  return List<Map<String, dynamic>>.from(data);
});

// ─── Screen ──────────────────────────────────────────────────────────────────

class BannerPackagesScreen extends ConsumerWidget {
  const BannerPackagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packagesAsync = ref.watch(bannerPackagesAdminProvider);
    final currencyFormat =
        NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Banner Paketleri',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Reklam paketlerini yönetin',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 14)),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () =>
                      _showPackageDialog(context, ref, package: null),
                  icon: const Icon(Icons.add),
                  label: const Text('Yeni Paket'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: packagesAsync.when(
                data: (packages) => packages.isEmpty
                    ? const Center(
                        child: Text('Henüz paket yok',
                            style: TextStyle(color: AppColors.textMuted)))
                    : _PackageTable(
                        packages: packages,
                        currencyFormat: currencyFormat,
                        onRefresh: () =>
                            ref.invalidate(bannerPackagesAdminProvider),
                        onEdit: (pkg) =>
                            _showPackageDialog(context, ref, package: pkg),
                      ),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                    child: Text('Hata: $e',
                        style:
                            const TextStyle(color: AppColors.error))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPackageDialog(BuildContext context, WidgetRef ref,
      {required Map<String, dynamic>? package}) {
    showDialog(
      context: context,
      builder: (_) => _PackageDialog(
        package: package,
        onSaved: () => ref.invalidate(bannerPackagesAdminProvider),
      ),
    );
  }
}

// ─── Table ───────────────────────────────────────────────────────────────────

class _PackageTable extends StatelessWidget {
  final List<Map<String, dynamic>> packages;
  final NumberFormat currencyFormat;
  final VoidCallback onRefresh;
  final void Function(Map<String, dynamic>) onEdit;

  const _PackageTable({
    required this.packages,
    required this.currencyFormat,
    required this.onRefresh,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                SizedBox(width: 40, child: Text('Sıra', style: _headerStyle)),
                Expanded(flex: 3, child: Text('Paket Adı', style: _headerStyle)),
                Expanded(flex: 4, child: Text('Açıklama', style: _headerStyle)),
                SizedBox(width: 100, child: Text('Süre', style: _headerStyle)),
                SizedBox(width: 100, child: Text('Fiyat', style: _headerStyle)),
                SizedBox(width: 80, child: Text('Durum', style: _headerStyle)),
                SizedBox(width: 80, child: Text('İşlem', style: _headerStyle)),
              ],
            ),
          ),
          // Rows
          Expanded(
            child: ListView.separated(
              itemCount: packages.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: AppColors.surfaceLight),
              itemBuilder: (context, i) {
                final pkg = packages[i];
                final isActive = pkg['is_active'] as bool? ?? true;
                final price = (pkg['price'] as num).toDouble();
                final days = pkg['duration_days'] as int;

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${pkg['sort_order'] ?? '-'}',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 13),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          pkg['name'] as String? ?? '-',
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          pkg['description'] as String? ?? '-',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text('$days gün',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          currencyFormat.format(price),
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: _StatusToggle(
                          isActive: isActive,
                          onToggle: () => _toggleActive(context, pkg, !isActive),
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: IconButton(
                          onPressed: () => onEdit(pkg),
                          icon: const Icon(Icons.edit_outlined,
                              size: 18, color: AppColors.textMuted),
                          tooltip: 'Düzenle',
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive(
      BuildContext context, Map<String, dynamic> pkg, bool newValue) async {
    try {
      final supabase = SupabaseService.client;
      await supabase
          .from('banner_packages')
          .update({'is_active': newValue})
          .eq('id', pkg['id']);
      onRefresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  static const _headerStyle = TextStyle(
      color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600);
}

// ─── Status Toggle ────────────────────────────────────────────────────────────

class _StatusToggle extends StatelessWidget {
  final bool isActive;
  final VoidCallback onToggle;

  const _StatusToggle({required this.isActive, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: (isActive ? AppColors.success : AppColors.textMuted)
              .withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          isActive ? 'Aktif' : 'Pasif',
          style: TextStyle(
              color: isActive ? AppColors.success : AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ─── Dialog ──────────────────────────────────────────────────────────────────

class _PackageDialog extends StatefulWidget {
  final Map<String, dynamic>? package;
  final VoidCallback onSaved;

  const _PackageDialog({required this.package, required this.onSaved});

  @override
  State<_PackageDialog> createState() => _PackageDialogState();
}

class _PackageDialogState extends State<_PackageDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _daysCtrl = TextEditingController();
  final _sortCtrl = TextEditingController();
  bool _isActive = true;
  bool _loading = false;

  bool get _isEdit => widget.package != null;

  @override
  void initState() {
    super.initState();
    final pkg = widget.package;
    if (pkg != null) {
      _nameCtrl.text = pkg['name'] as String? ?? '';
      _descCtrl.text = pkg['description'] as String? ?? '';
      _priceCtrl.text = (pkg['price'] as num?)?.toString() ?? '';
      _daysCtrl.text = (pkg['duration_days'] as int?)?.toString() ?? '';
      _sortCtrl.text = (pkg['sort_order'] as int?)?.toString() ?? '';
      _isActive = pkg['is_active'] as bool? ?? true;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _daysCtrl.dispose();
    _sortCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim());
    final days = int.tryParse(_daysCtrl.text.trim());

    if (name.isEmpty || price == null || days == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Ad, fiyat ve süre zorunludur'),
            backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _loading = true);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final supabase = SupabaseService.client;
      final data = {
        'name': name,
        'description': _descCtrl.text.trim(),
        'price': price,
        'duration_days': days,
        'sort_order': int.tryParse(_sortCtrl.text.trim()) ?? 99,
        'is_active': _isActive,
      };

      if (_isEdit) {
        await supabase
            .from('banner_packages')
            .update(data)
            .eq('id', widget.package!['id']);
      } else {
        await supabase.from('banner_packages').insert(data);
      }

      nav.pop();
      messenger.showSnackBar(
        SnackBar(
            content: Text(_isEdit ? 'Paket güncellendi' : 'Paket oluşturuldu'),
            backgroundColor: AppColors.success),
      );
      widget.onSaved();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(
        _isEdit ? 'Paketi Düzenle' : 'Yeni Paket',
        style: const TextStyle(color: AppColors.textPrimary),
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_nameCtrl, 'Paket Adı *'),
              const SizedBox(height: 12),
              _field(_descCtrl, 'Açıklama', maxLines: 2),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _field(_priceCtrl, 'Fiyat (₺) *', isNumber: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_daysCtrl, 'Süre (gün) *', isNumber: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_sortCtrl, 'Sıra', isNumber: true)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Aktif',
                      style: TextStyle(color: AppColors.textPrimary)),
                  const Spacer(),
                  Switch(
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                    activeThumbColor: AppColors.success,
                  ),
                ],
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
        ElevatedButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_isEdit ? 'Güncelle' : 'Oluştur'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {int maxLines = 1, bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textMuted),
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.surfaceLight),
        ),
      ),
    );
  }
}
