import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/business_proxy_service.dart';
import '../../../core/services/storage_service.dart';

class CarSalesOpsPanel extends ConsumerStatefulWidget {
  final String businessId;
  final Map<String, dynamic> data;
  const CarSalesOpsPanel({super.key, required this.businessId, required this.data});

  @override
  ConsumerState<CarSalesOpsPanel> createState() => _CarSalesOpsPanelState();
}

class _CarSalesOpsPanelState extends ConsumerState<CarSalesOpsPanel> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _listings = [];
  List<Map<String, dynamic>> _contactRequests = [];
  List<Map<String, dynamic>> _brands = [];
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
        service.getCarListings(widget.businessId),
        service.getContactRequests(widget.businessId),
        service.getCarBrands(),
      ]);
      setState(() { _listings = results[0]; _contactRequests = results[1]; _brands = results[2]; _isLoading = false; });
    } catch (e) {
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
            Tab(text: 'İlanlar (${_listings.length})'),
            Tab(text: 'İletişim Talepleri (${_contactRequests.length})'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildListingsTab(isDark),
              _buildContactRequestsTab(isDark),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // ─── Listings Tab (CRUD) ───
  // ═══════════════════════════════════════════

  Widget _buildListingsTab(bool isDark) {
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
                onPressed: () => _showListingDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Yeni İlan'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              ),
            ],
          ),
        ),
        Expanded(
          child: _listings.isEmpty
              ? Center(child: Text('Araç ilanı yok', style: TextStyle(color: textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _listings.length,
                  itemBuilder: (ctx, i) {
                    final c = _listings[i];
                    return Card(
                      color: cardColor,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderColor)),
                      child: ListTile(
                        leading: c['images'] != null && (c['images'] as List).isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network((c['images'] as List).first.toString(), width: 50, height: 40, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.directions_car, size: 24)),
                              )
                            : null,
                        title: Text('${c['brand'] ?? ''} ${c['model'] ?? ''} ${c['year'] ?? ''}', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                        subtitle: Text('₺${_formatPrice(c['price'])} • ${c['mileage'] != null ? '${c['mileage']} km' : '-'} • ${c['fuel_type'] ?? '-'}', style: TextStyle(color: textMuted, fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PopupMenuButton<String>(
                              onSelected: (s) async {
                                await ref.read(businessProxyServiceProvider).updateCarListingStatus(c['id'], s, dealerId: widget.businessId);
                                _loadData();
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'active', child: Text('Aktif')),
                                const PopupMenuItem(value: 'inactive', child: Text('Pasif')),
                                const PopupMenuItem(value: 'sold', child: Text('Satıldı')),
                              ],
                              child: _statusBadge(c['status'] ?? 'active'),
                            ),
                            IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: () => _showListingDialog(existing: c), tooltip: 'Düzenle'),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 16, color: AppColors.error),
                              onPressed: () => _showDeleteDialog(c),
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

  void _showListingDialog({Map<String, dynamic>? existing}) {
    final brandCtrl = TextEditingController(text: existing?['brand'] ?? '');
    final modelCtrl = TextEditingController(text: existing?['model'] ?? '');
    final yearCtrl = TextEditingController(text: existing?['year']?.toString() ?? '');
    final mileageCtrl = TextEditingController(text: existing?['mileage']?.toString() ?? '');
    final plateCtrl = TextEditingController(text: existing?['plate'] ?? '');
    final priceCtrl = TextEditingController(text: existing?['price']?.toString() ?? '');
    final descCtrl = TextEditingController(text: existing?['description'] ?? '');
    final cityCtrl = TextEditingController(text: existing?['city'] ?? '');
    final districtCtrl = TextEditingController(text: existing?['district'] ?? '');
    String bodyType = existing?['body_type'] ?? 'sedan';
    String fuelType = existing?['fuel_type'] ?? 'gasoline';
    String transmission = existing?['transmission'] ?? 'automatic';
    String condition = existing?['condition'] ?? 'good';
    Uint8List? imageBytes;
    String? imageName;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: Text(existing != null ? 'İlan Düzenle' : 'Yeni Araç İlanı'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Brand - from DB or manual
                  _brands.isNotEmpty
                      ? Autocomplete<String>(
                          optionsBuilder: (v) => _brands.map((b) => b['name'] as String).where((n) => n.toLowerCase().contains(v.text.toLowerCase())),
                          initialValue: TextEditingValue(text: brandCtrl.text),
                          onSelected: (v) => brandCtrl.text = v,
                          fieldViewBuilder: (ctx, ctrl, fn, onSub) {
                            ctrl.text = brandCtrl.text;
                            return TextField(controller: ctrl, focusNode: fn, decoration: const InputDecoration(labelText: 'Marka *'));
                          },
                        )
                      : TextField(controller: brandCtrl, decoration: const InputDecoration(labelText: 'Marka *')),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(controller: modelCtrl, decoration: const InputDecoration(labelText: 'Model *'))),
                    const SizedBox(width: 12),
                    SizedBox(width: 80, child: TextField(controller: yearCtrl, decoration: const InputDecoration(labelText: 'Yıl'), keyboardType: TextInputType.number)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(controller: mileageCtrl, decoration: const InputDecoration(labelText: 'Kilometre'), keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: plateCtrl, decoration: const InputDecoration(labelText: 'Plaka'))),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: bodyType,
                        decoration: const InputDecoration(labelText: 'Kasa Tipi'),
                        items: const [
                          DropdownMenuItem(value: 'sedan', child: Text('Sedan')),
                          DropdownMenuItem(value: 'hatchback', child: Text('Hatchback')),
                          DropdownMenuItem(value: 'suv', child: Text('SUV')),
                          DropdownMenuItem(value: 'pickup', child: Text('Pickup')),
                          DropdownMenuItem(value: 'van', child: Text('Van')),
                          DropdownMenuItem(value: 'coupe', child: Text('Coupe')),
                          DropdownMenuItem(value: 'convertible', child: Text('Cabrio')),
                        ],
                        onChanged: (v) => ss(() => bodyType = v ?? 'sedan'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: fuelType,
                        decoration: const InputDecoration(labelText: 'Yakıt'),
                        items: const [
                          DropdownMenuItem(value: 'gasoline', child: Text('Benzin')),
                          DropdownMenuItem(value: 'diesel', child: Text('Dizel')),
                          DropdownMenuItem(value: 'hybrid', child: Text('Hibrit')),
                          DropdownMenuItem(value: 'electric', child: Text('Elektrik')),
                          DropdownMenuItem(value: 'lpg', child: Text('LPG')),
                        ],
                        onChanged: (v) => ss(() => fuelType = v ?? 'gasoline'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: transmission,
                        decoration: const InputDecoration(labelText: 'Vites'),
                        items: const [
                          DropdownMenuItem(value: 'automatic', child: Text('Otomatik')),
                          DropdownMenuItem(value: 'manual', child: Text('Manuel')),
                        ],
                        onChanged: (v) => ss(() => transmission = v ?? 'automatic'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: condition,
                        decoration: const InputDecoration(labelText: 'Durum'),
                        items: const [
                          DropdownMenuItem(value: 'new', child: Text('Sıfır')),
                          DropdownMenuItem(value: 'like_new', child: Text('Az Kullanılmış')),
                          DropdownMenuItem(value: 'good', child: Text('İyi')),
                          DropdownMenuItem(value: 'fair', child: Text('Orta')),
                          DropdownMenuItem(value: 'damaged', child: Text('Hasarlı')),
                        ],
                        onChanged: (v) => ss(() => condition = v ?? 'good'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Fiyat (₺) *'), keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Açıklama'), maxLines: 2),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(controller: cityCtrl, decoration: const InputDecoration(labelText: 'Şehir'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: districtCtrl, decoration: const InputDecoration(labelText: 'İlçe'))),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    if (imageName != null)
                      Text('Seçilen: $imageName', style: const TextStyle(fontSize: 11))
                    else
                      const Text('Görsel seçilmedi', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () async {
                        final result = await ref.read(storageServiceProvider).pickImage();
                        if (result != null) ss(() { imageBytes = result.bytes; imageName = result.name; });
                      },
                      icon: const Icon(Icons.upload, size: 16),
                      label: const Text('Görsel'),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                if (brandCtrl.text.isEmpty || modelCtrl.text.isEmpty || priceCtrl.text.isEmpty) return;
                ss(() => isSaving = true);
                try {
                  List<String> images = existing?['images'] != null ? List<String>.from(existing!['images']) : [];
                  if (imageBytes != null && imageName != null) {
                    final url = await ref.read(storageServiceProvider).uploadImage('car_listings', imageBytes!, imageName!);
                    images.add(url);
                  }

                  final data = {
                    'brand': brandCtrl.text,
                    'model': modelCtrl.text,
                    'year': int.tryParse(yearCtrl.text),
                    'mileage': int.tryParse(mileageCtrl.text),
                    'plate': plateCtrl.text.isEmpty ? null : plateCtrl.text,
                    'body_type': bodyType,
                    'fuel_type': fuelType,
                    'transmission': transmission,
                    'condition': condition,
                    'price': double.tryParse(priceCtrl.text) ?? 0,
                    'description': descCtrl.text.isEmpty ? null : descCtrl.text,
                    'city': cityCtrl.text.isEmpty ? null : cityCtrl.text,
                    'district': districtCtrl.text.isEmpty ? null : districtCtrl.text,
                    'images': images,
                  };

                  final service = ref.read(businessProxyServiceProvider);
                  if (existing != null) {
                    await service.updateCarListingFull(existing['id'], data, dealerId: widget.businessId);
                  } else {
                    await service.createCarListing(widget.businessId, data);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadData();
                } catch (e) {
                  ss(() => isSaving = false);
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error));
                }
              },
              child: isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(existing != null ? 'Güncelle' : 'Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> listing) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('İlanı Sil'),
        content: Text('${listing['brand']} ${listing['model']} silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(businessProxyServiceProvider).deleteCarListing(listing['id'], dealerId: widget.businessId);
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
  // ─── Contact Requests Tab ───
  // ═══════════════════════════════════════════

  Widget _buildContactRequestsTab(bool isDark) {
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final cardColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);
    final df = DateFormat('dd.MM.yyyy HH:mm');

    if (_contactRequests.isEmpty) return Center(child: Text('İletişim talebi yok', style: TextStyle(color: textMuted)));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _contactRequests.length,
      itemBuilder: (ctx, i) {
        final r = _contactRequests[i];
        final date = DateTime.tryParse(r['created_at'] ?? '');
        final listing = r['car_listings'];

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
                          Text('${r['customer_name'] ?? '-'} • ${r['customer_phone'] ?? '-'}', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                          if (listing != null) Text('${listing['brand']} ${listing['model']} ${listing['year']}', style: TextStyle(color: textMuted, fontSize: 12)),
                          if (date != null) Text(df.format(date.toLocal()), style: TextStyle(color: textMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (s) async {
                        await ref.read(businessProxyServiceProvider).updateContactRequestStatus(r['id'], s, dealerId: widget.businessId);
                        _loadData();
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'pending', child: Text('Beklemede')),
                        const PopupMenuItem(value: 'contacted', child: Text('İletişime Geçildi')),
                        const PopupMenuItem(value: 'interested', child: Text('İlgileniyor')),
                        const PopupMenuItem(value: 'converted', child: Text('Dönüştürüldü')),
                        const PopupMenuItem(value: 'not_interested', child: Text('İlgilenmiyor')),
                      ],
                      child: _statusBadge(r['status'] ?? 'pending'),
                    ),
                  ],
                ),
                if (r['message'] != null) ...[
                  const SizedBox(height: 8),
                  Text(r['message'], style: TextStyle(color: textMuted, fontSize: 12)),
                ],
                if (r['notes'] != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(4)),
                    child: Text('Not: ${r['notes']}', style: TextStyle(color: textPrimary, fontSize: 11, fontStyle: FontStyle.italic)),
                  ),
                ],
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _showAddNoteDialog(r),
                  icon: const Icon(Icons.note_add, size: 14),
                  label: const Text('Not Ekle', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddNoteDialog(Map<String, dynamic> request) {
    final noteCtrl = TextEditingController(text: request['notes'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Not Ekle'),
        content: TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Not'), maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(businessProxyServiceProvider).updateContactRequestStatus(
                request['id'], request['status'] ?? 'pending', notes: noteCtrl.text, dealerId: widget.businessId,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              _loadData();
            },
            child: const Text('Kaydet'),
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
      case 'pending': color = AppColors.warning; label = 'Beklemede'; break;
      case 'contacted': color = AppColors.info; label = 'İletişim Geçildi'; break;
      case 'interested': color = AppColors.primary; label = 'İlgileniyor'; break;
      case 'converted': color = AppColors.success; label = 'Dönüştürüldü'; break;
      case 'not_interested': color = AppColors.error; label = 'İlgilenmiyor'; break;
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
