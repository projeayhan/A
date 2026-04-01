import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/business_proxy_service.dart';
import '../../../core/services/storage_service.dart';
import 'package:support_panel/core/services/log_service.dart';

class EmlakOpsPanel extends ConsumerStatefulWidget {
  final String businessId;
  final Map<String, dynamic> data;
  const EmlakOpsPanel({super.key, required this.businessId, required this.data});

  @override
  ConsumerState<EmlakOpsPanel> createState() => _EmlakOpsPanelState();
}

class _EmlakOpsPanelState extends ConsumerState<EmlakOpsPanel> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _properties = [];
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _loadData() async {
    final service = ref.read(businessProxyServiceProvider);
    try {
      final results = await Future.wait([
        service.getProperties(widget.businessId),
        service.getPropertyAppointments(widget.businessId),
      ]);
      setState(() { _properties = results[0]; _appointments = results[1]; _isLoading = false; });
    } catch (e, st) {
      LogService.error('Failed to load emlak data', error: e, stackTrace: st, source: 'EmlakOpsPanel:_loadData');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: textMuted,
          tabs: [
            Tab(text: 'İlanlar (${_properties.length})'),
            Tab(text: 'Randevular (${_appointments.length})'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildPropertiesTab(isDark),
              _buildAppointmentsTab(isDark),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // ─── Properties Tab (CRUD) ───
  // ═══════════════════════════════════════════

  Widget _buildPropertiesTab(bool isDark) {
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final cardColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _showPropertyDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Yeni İlan'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              ),
            ],
          ),
        ),
        Expanded(
          child: _properties.isEmpty
              ? Center(child: Text('İlan yok', style: TextStyle(color: textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _properties.length,
                  itemBuilder: (ctx, i) {
                    final p = _properties[i];
                    return Card(
                      color: cardColor,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderColor)),
                      child: ListTile(
                        title: Text(p['title'] ?? '-', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                        subtitle: Text(
                          '₺${_formatPrice(p['price'])} • ${p['property_type'] ?? '-'} • ${p['city'] ?? ''} ${p['district'] ?? ''}',
                          style: TextStyle(color: textMuted, fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PopupMenuButton<String>(
                              onSelected: (s) async {
                                await ref.read(businessProxyServiceProvider).updatePropertyStatus(p['id'], s, realtorId: widget.businessId);
                                _loadData();
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'active', child: Text('Aktif')),
                                const PopupMenuItem(value: 'inactive', child: Text('Pasif')),
                                const PopupMenuItem(value: 'sold', child: Text('Satıldı')),
                                const PopupMenuItem(value: 'rented', child: Text('Kiralandı')),
                              ],
                              child: _statusBadge(p['status'] ?? 'active'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 16),
                              onPressed: () => _showPropertyDialog(existing: p),
                              tooltip: 'Düzenle',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 16, color: AppColors.error),
                              onPressed: () => _showDeleteDialog(p),
                              tooltip: 'Sil',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showPropertyDialog({Map<String, dynamic>? existing}) {
    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    final descCtrl = TextEditingController(text: existing?['description'] ?? '');
    final priceCtrl = TextEditingController(text: existing?['price']?.toString() ?? '');
    final areaCtrl = TextEditingController(text: existing?['area_sqm']?.toString() ?? '');
    final roomsCtrl = TextEditingController(text: existing?['rooms']?.toString() ?? '');
    final bathCtrl = TextEditingController(text: existing?['bathrooms']?.toString() ?? '');
    final floorCtrl = TextEditingController(text: existing?['floor']?.toString() ?? '');
    final totalFloorCtrl = TextEditingController(text: existing?['total_floors']?.toString() ?? '');
    final buildingAgeCtrl = TextEditingController(text: existing?['building_age']?.toString() ?? '');
    final cityCtrl = TextEditingController(text: existing?['city'] ?? '');
    final districtCtrl = TextEditingController(text: existing?['district'] ?? '');
    final addressCtrl = TextEditingController(text: existing?['address'] ?? '');
    String listingType = existing?['listing_type'] ?? 'sale';
    String propertyType = existing?['property_type'] ?? 'apartment';
    String currency = existing?['currency'] ?? 'TRY';
    Uint8List? imageBytes;
    String? imageName;
    bool isSaving = false;
    int step = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) {
          Widget stepContent;
          switch (step) {
            case 0: // Temel Bilgiler
              stepContent = Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  initialValue: listingType,
                  decoration: const InputDecoration(labelText: 'İlan Tipi'),
                  items: const [
                    DropdownMenuItem(value: 'sale', child: Text('Satılık')),
                    DropdownMenuItem(value: 'rent', child: Text('Kiralık')),
                  ],
                  onChanged: (v) => ss(() => listingType = v ?? 'sale'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: propertyType,
                  decoration: const InputDecoration(labelText: 'Emlak Tipi'),
                  items: const [
                    DropdownMenuItem(value: 'apartment', child: Text('Daire')),
                    DropdownMenuItem(value: 'house', child: Text('Müstakil Ev')),
                    DropdownMenuItem(value: 'villa', child: Text('Villa')),
                    DropdownMenuItem(value: 'land', child: Text('Arsa')),
                    DropdownMenuItem(value: 'office', child: Text('Ofis')),
                    DropdownMenuItem(value: 'shop', child: Text('Dükkan')),
                  ],
                  onChanged: (v) => ss(() => propertyType = v ?? 'apartment'),
                ),
                const SizedBox(height: 12),
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Başlık *')),
                const SizedBox(height: 12),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Açıklama'), maxLines: 3),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Fiyat *'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 100,
                    child: DropdownButtonFormField<String>(
                      initialValue: currency,
                      decoration: const InputDecoration(labelText: 'Birim'),
                      items: const [
                        DropdownMenuItem(value: 'TRY', child: Text('₺')),
                        DropdownMenuItem(value: 'USD', child: Text('\$')),
                        DropdownMenuItem(value: 'EUR', child: Text('€')),
                      ],
                      onChanged: (v) => ss(() => currency = v ?? 'TRY'),
                    ),
                  ),
                ]),
              ]);
              break;
            case 1: // Konum
              stepContent = Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: cityCtrl, decoration: const InputDecoration(labelText: 'Şehir *')),
                const SizedBox(height: 12),
                TextField(controller: districtCtrl, decoration: const InputDecoration(labelText: 'İlçe')),
                const SizedBox(height: 12),
                TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Adres'), maxLines: 2),
              ]);
              break;
            case 2: // Özellikler
              stepContent = Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Expanded(child: TextField(controller: areaCtrl, decoration: const InputDecoration(labelText: 'm²'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: roomsCtrl, decoration: const InputDecoration(labelText: 'Oda Sayısı'), keyboardType: TextInputType.number)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: bathCtrl, decoration: const InputDecoration(labelText: 'Banyo'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: buildingAgeCtrl, decoration: const InputDecoration(labelText: 'Bina Yaşı'), keyboardType: TextInputType.number)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: floorCtrl, decoration: const InputDecoration(labelText: 'Kat'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: totalFloorCtrl, decoration: const InputDecoration(labelText: 'Toplam Kat'), keyboardType: TextInputType.number)),
                ]),
              ]);
              break;
            default: // Görsel
              stepContent = Column(mainAxisSize: MainAxisSize.min, children: [
                if (imageBytes != null)
                  Container(
                    height: 120,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.surfaceLight)),
                    child: Center(child: Text('Seçilen: $imageName', style: const TextStyle(fontSize: 12))),
                  )
                else if (existing?['images'] != null && (existing!['images'] as List).isNotEmpty)
                  Wrap(
                    spacing: 8,
                    children: (existing['images'] as List).take(4).map((url) => ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(url.toString(), width: 80, height: 80, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
                    )).toList(),
                  ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await ref.read(storageServiceProvider).pickImage();
                    if (result != null) ss(() { imageBytes = result.bytes; imageName = result.name; });
                  },
                  icon: const Icon(Icons.upload, size: 16),
                  label: const Text('Görsel Yükle'),
                ),
              ]);
          }

          return AlertDialog(
            title: Text('${existing != null ? 'İlan Düzenle' : 'Yeni İlan'} (${step + 1}/4)'),
            content: SizedBox(width: 450, child: SingleChildScrollView(child: stepContent)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
              if (step > 0)
                TextButton(onPressed: () => ss(() => step--), child: const Text('Geri')),
              if (step < 3)
                ElevatedButton(onPressed: () => ss(() => step++), child: const Text('İleri')),
              if (step == 3)
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (titleCtrl.text.isEmpty || priceCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Başlık ve fiyat zorunludur')));
                      return;
                    }
                    ss(() => isSaving = true);
                    try {
                      List<String> images = existing?['images'] != null ? List<String>.from(existing!['images']) : [];
                      if (imageBytes != null && imageName != null) {
                        final url = await ref.read(storageServiceProvider).uploadImage('properties', imageBytes!, imageName!);
                        images.add(url);
                      }

                      final data = {
                        'title': titleCtrl.text,
                        'description': descCtrl.text.isEmpty ? null : descCtrl.text,
                        'listing_type': listingType,
                        'property_type': propertyType,
                        'price': double.tryParse(priceCtrl.text) ?? 0,
                        'currency': currency,
                        'city': cityCtrl.text.isEmpty ? null : cityCtrl.text,
                        'district': districtCtrl.text.isEmpty ? null : districtCtrl.text,
                        'address': addressCtrl.text.isEmpty ? null : addressCtrl.text,
                        'area_sqm': int.tryParse(areaCtrl.text),
                        'rooms': int.tryParse(roomsCtrl.text),
                        'bathrooms': int.tryParse(bathCtrl.text),
                        'floor': int.tryParse(floorCtrl.text),
                        'total_floors': int.tryParse(totalFloorCtrl.text),
                        'building_age': int.tryParse(buildingAgeCtrl.text),
                        'images': images,
                      };

                      final service = ref.read(businessProxyServiceProvider);
                      if (existing != null) {
                        await service.updatePropertyFull(existing['id'], data, realtorId: widget.businessId);
                      } else {
                        await service.createProperty(widget.businessId, data);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadData();
                    } catch (e, st) {
                      LogService.error('Failed to save property', error: e, stackTrace: st, source: 'EmlakOpsPanel:saveProperty');
                      ss(() => isSaving = false);
                      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error));
                    }
                  },
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(existing != null ? 'Güncelle' : 'Kaydet'),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> property) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('İlanı Sil'),
        content: Text('${property['title']} silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(businessProxyServiceProvider).deleteProperty(property['id'], realtorId: widget.businessId);
              _loadData();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ─── Appointments Tab ───
  // ═══════════════════════════════════════════

  Widget _buildAppointmentsTab(bool isDark) {
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final cardColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);
    final df = DateFormat('dd.MM.yyyy HH:mm');

    if (_appointments.isEmpty) return Center(child: Text('Randevu yok', style: TextStyle(color: textMuted)));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _appointments.length,
      itemBuilder: (ctx, i) {
        final a = _appointments[i];
        final date = DateTime.tryParse(a['appointment_date'] ?? '');
        final status = a['status'] ?? 'pending';
        final propertyTitle = a['properties']?['title'] ?? '-';

        return Card(
          color: cardColor,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderColor)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(propertyTitle, style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text(
                            '${a['customer_name'] ?? '-'} • ${date != null ? df.format(date.toLocal()) : '-'}',
                            style: TextStyle(color: textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    _statusBadge(status),
                  ],
                ),
                if (status == 'pending') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showAppointmentActionDialog(a['id'], 'confirm'),
                        icon: const Icon(Icons.check, size: 14),
                        label: const Text('Onayla', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _showAppointmentActionDialog(a['id'], 'cancel'),
                        icon: const Icon(Icons.close, size: 14, color: AppColors.error),
                        label: const Text('İptal Et', style: TextStyle(fontSize: 12, color: AppColors.error)),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                      ),
                    ],
                  ),
                ],
                if (status == 'confirmed') ...[
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await ref.read(businessProxyServiceProvider).completeAppointment(a['id'], realtorId: widget.businessId);
                      _loadData();
                    },
                    icon: const Icon(Icons.done_all, size: 14),
                    label: const Text('Tamamla', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.info, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAppointmentActionDialog(String appointmentId, String action) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(action == 'confirm' ? 'Randevuyu Onayla' : 'Randevuyu İptal Et'),
        content: TextField(
          controller: noteCtrl,
          decoration: InputDecoration(labelText: action == 'confirm' ? 'Not (opsiyonel)' : 'İptal Sebebi'),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () async {
              final service = ref.read(businessProxyServiceProvider);
              if (action == 'confirm') {
                await service.confirmAppointment(appointmentId, responseNote: noteCtrl.text.isEmpty ? null : noteCtrl.text, realtorId: widget.businessId);
              } else {
                await service.cancelAppointment(appointmentId, reason: noteCtrl.text.isEmpty ? null : noteCtrl.text, realtorId: widget.businessId);
              }
              if (ctx.mounted) Navigator.pop(ctx);
              _loadData();
            },
            style: ElevatedButton.styleFrom(backgroundColor: action == 'confirm' ? AppColors.success : AppColors.error),
            child: Text(action == 'confirm' ? 'Onayla' : 'İptal Et'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ─── Helpers ───
  // ═══════════════════════════════════════════

  Widget _statusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'active': color = AppColors.success; label = 'Aktif'; break;
      case 'inactive': color = AppColors.textMuted; label = 'Pasif'; break;
      case 'sold': color = AppColors.info; label = 'Satıldı'; break;
      case 'rented': color = AppColors.info; label = 'Kiralandı'; break;
      case 'pending': color = AppColors.warning; label = 'Beklemede'; break;
      case 'confirmed': color = AppColors.success; label = 'Onaylandı'; break;
      case 'cancelled': color = AppColors.error; label = 'İptal'; break;
      case 'completed': color = AppColors.info; label = 'Tamamlandı'; break;
      default: color = AppColors.textMuted; label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    final num p = price is num ? price : double.tryParse(price.toString()) ?? 0;
    if (p >= 1000000) return '${(p / 1000000).toStringAsFixed(1)}M';
    if (p >= 1000) return '${(p / 1000).toStringAsFixed(0)}K';
    return p.toStringAsFixed(0);
  }
}
