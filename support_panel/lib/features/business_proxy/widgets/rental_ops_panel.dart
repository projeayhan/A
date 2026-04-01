import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/business_proxy_service.dart';
import '../../../core/services/storage_service.dart';
import 'package:support_panel/core/services/log_service.dart';

class RentalOpsPanel extends ConsumerStatefulWidget {
  final String businessId;
  final Map<String, dynamic> data;
  const RentalOpsPanel({super.key, required this.businessId, required this.data});

  @override
  ConsumerState<RentalOpsPanel> createState() => _RentalOpsPanelState();
}

class _RentalOpsPanelState extends ConsumerState<RentalOpsPanel> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _locations = [];
  List<Map<String, dynamic>> _packages = [];
  List<Map<String, dynamic>> _services = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
    _loadData();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _loadData() async {
    final service = ref.read(businessProxyServiceProvider);
    try {
      final results = await Future.wait([
        service.getRentalBookings(widget.businessId),
        service.getRentalVehicles(widget.businessId),
        service.getRentalLocations(widget.businessId),
        service.getRentalPackages(widget.businessId),
        service.getRentalServices(widget.businessId),
      ]);
      setState(() {
        _bookings = results[0]; _vehicles = results[1]; _locations = results[2];
        _packages = results[3]; _services = results[4]; _isLoading = false;
      });
    } catch (e, st) {
      LogService.error('Failed to load rental data', error: e, stackTrace: st, source: 'RentalOpsPanel:_loadData');
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
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'Rezervasyonlar (${_bookings.length})'),
            Tab(text: 'Araçlar (${_vehicles.length})'),
            Tab(text: 'Lokasyonlar (${_locations.length})'),
            Tab(text: 'Paketler (${_packages.length})'),
            Tab(text: 'Ek Hizmetler (${_services.length})'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildBookingsTab(isDark),
              _buildVehiclesTab(isDark),
              _buildLocationsTab(isDark),
              _buildPackagesTab(isDark),
              _buildServicesTab(isDark),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // ─── Bookings Tab ───
  // ═══════════════════════════════════════════

  Widget _buildBookingsTab(bool isDark) {
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final cardColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);
    final df = DateFormat('dd.MM.yyyy');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            ElevatedButton.icon(
              onPressed: () => _showBookingDialog(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Manuel Rezervasyon'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ]),
        ),
        Expanded(
          child: _bookings.isEmpty
              ? Center(child: Text('Rezervasyon yok', style: TextStyle(color: textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _bookings.length,
                  itemBuilder: (ctx, i) {
                    final b = _bookings[i];
                    final pickup = DateTime.tryParse(b['pickup_date'] ?? '');
                    final dropoff = DateTime.tryParse(b['dropoff_date'] ?? '');
                    return Card(
                      color: cardColor,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderColor)),
                      child: ListTile(
                        title: Text(
                          '${b['customer_name'] ?? b['vehicle_name'] ?? '-'} • ₺${b['total_price'] ?? 0}',
                          style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          '${pickup != null ? df.format(pickup) : '-'} → ${dropoff != null ? df.format(dropoff) : '-'}',
                          style: TextStyle(color: textMuted, fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PopupMenuButton<String>(
                              onSelected: (s) async {
                                if (s == 'cancelled') {
                                  _showCancelBookingDialog(b['id']);
                                } else {
                                  await ref.read(businessProxyServiceProvider).updateBookingStatus(b['id'], s, companyId: widget.businessId);
                                  _loadData();
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'pending', child: Text('Beklemede')),
                                const PopupMenuItem(value: 'confirmed', child: Text('Onaylandı')),
                                const PopupMenuItem(value: 'active', child: Text('Aktif')),
                                const PopupMenuItem(value: 'completed', child: Text('Tamamlandı')),
                                const PopupMenuItem(value: 'cancelled', child: Text('İptal')),
                              ],
                              child: _statusBadge(b['status'] ?? 'pending'),
                            ),
                            IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: () => _showBookingDialog(existing: b), tooltip: 'Düzenle'),
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

  void _showBookingDialog({Map<String, dynamic>? existing}) {
    final nameCtrl = TextEditingController(text: existing?['customer_name'] ?? '');
    final phoneCtrl = TextEditingController(text: existing?['customer_phone'] ?? '');
    final emailCtrl = TextEditingController(text: existing?['customer_email'] ?? '');
    final totalCtrl = TextEditingController(text: existing?['total_price']?.toString() ?? '');
    final depositCtrl = TextEditingController(text: existing?['deposit']?.toString() ?? '');
    final notesCtrl = TextEditingController(text: existing?['notes'] ?? '');
    String? selectedVehicleId = existing?['vehicle_id'];
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: Text(existing != null ? 'Rezervasyon Düzenle' : 'Manuel Rezervasyon'),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (_vehicles.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: selectedVehicleId,
                    decoration: const InputDecoration(labelText: 'Araç'),
                    items: _vehicles.map((v) => DropdownMenuItem(
                      value: v['id'] as String,
                      child: Text('${v['brand']} ${v['model']} - ${v['plate'] ?? ''}'),
                    )).toList(),
                    onChanged: (v) => ss(() => selectedVehicleId = v),
                  ),
                const SizedBox(height: 12),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Müşteri Adı *')),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Telefon *'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email'))),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: totalCtrl, decoration: const InputDecoration(labelText: 'Toplam Tutar (₺)'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: depositCtrl, decoration: const InputDecoration(labelText: 'Depozito (₺)'), keyboardType: TextInputType.number)),
                ]),
                const SizedBox(height: 12),
                TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notlar'), maxLines: 2),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) return;
                ss(() => isSaving = true);
                try {
                  final data = {
                    'vehicle_id': selectedVehicleId,
                    'customer_name': nameCtrl.text,
                    'customer_phone': phoneCtrl.text,
                    'customer_email': emailCtrl.text.isEmpty ? null : emailCtrl.text,
                    'total_price': double.tryParse(totalCtrl.text),
                    'deposit': double.tryParse(depositCtrl.text),
                    'notes': notesCtrl.text.isEmpty ? null : notesCtrl.text,
                  };
                  final service = ref.read(businessProxyServiceProvider);
                  if (existing != null) {
                    await service.updateBookingFull(existing['id'], data, companyId: widget.businessId);
                  } else {
                    await service.createManualBooking(widget.businessId, data);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadData();
                } catch (e, st) {
                  LogService.error('Failed to save booking', error: e, stackTrace: st, source: 'RentalOpsPanel:saveBooking');
                  ss(() => isSaving = false);
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error));
                }
              },
              child: isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(existing != null ? 'Güncelle' : 'Oluştur'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelBookingDialog(String bookingId) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rezervasyonu İptal Et'),
        content: TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'İptal Sebebi'), maxLines: 2),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(businessProxyServiceProvider).cancelBooking(bookingId, reasonCtrl.text, companyId: widget.businessId);
              if (ctx.mounted) Navigator.pop(ctx);
              _loadData();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('İptal Et'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ─── Vehicles Tab (CRUD) ───
  // ═══════════════════════════════════════════

  Widget _buildVehiclesTab(bool isDark) {
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final cardColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            ElevatedButton.icon(
              onPressed: () => _showVehicleDialog(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Yeni Araç'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ]),
        ),
        Expanded(
          child: _vehicles.isEmpty
              ? Center(child: Text('Araç yok', style: TextStyle(color: textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _vehicles.length,
                  itemBuilder: (ctx, i) {
                    final v = _vehicles[i];
                    return Card(
                      color: cardColor,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderColor)),
                      child: ListTile(
                        title: Text('${v['brand'] ?? ''} ${v['model'] ?? ''} ${v['year'] ?? ''}', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                        subtitle: Text('₺${v['daily_price'] ?? 0}/gün • ${v['plate'] ?? '-'} • ${v['category'] ?? '-'}', style: TextStyle(color: textMuted, fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PopupMenuButton<String>(
                              onSelected: (s) async {
                                await ref.read(businessProxyServiceProvider).updateRentalVehicleFull(v['id'], {'status': s}, companyId: widget.businessId);
                                _loadData();
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'available', child: Text('Müsait')),
                                const PopupMenuItem(value: 'rented', child: Text('Kirada')),
                                const PopupMenuItem(value: 'maintenance', child: Text('Bakımda')),
                                const PopupMenuItem(value: 'inactive', child: Text('Pasif')),
                              ],
                              child: _statusBadge(v['status'] ?? 'available'),
                            ),
                            IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: () => _showVehicleDialog(existing: v), tooltip: 'Düzenle'),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 16, color: AppColors.error),
                              onPressed: () => _showDeleteDialog('Aracı Sil', '${v['brand']} ${v['model']}', () async {
                                await ref.read(businessProxyServiceProvider).deleteRentalVehicle(v['id'], companyId: widget.businessId);
                                _loadData();
                              }),
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

  void _showVehicleDialog({Map<String, dynamic>? existing}) {
    final brandCtrl = TextEditingController(text: existing?['brand'] ?? '');
    final modelCtrl = TextEditingController(text: existing?['model'] ?? '');
    final yearCtrl = TextEditingController(text: existing?['year']?.toString() ?? '');
    final plateCtrl = TextEditingController(text: existing?['plate'] ?? '');
    final dailyCtrl = TextEditingController(text: existing?['daily_price']?.toString() ?? '');
    final weeklyCtrl = TextEditingController(text: existing?['weekly_price']?.toString() ?? '');
    final monthlyCtrl = TextEditingController(text: existing?['monthly_price']?.toString() ?? '');
    final depositCtrl = TextEditingController(text: existing?['deposit_amount']?.toString() ?? '');
    final seatsCtrl = TextEditingController(text: existing?['seats']?.toString() ?? '5');
    String category = existing?['category'] ?? 'economy';
    String fuelType = existing?['fuel_type'] ?? 'gasoline';
    String transmission = existing?['transmission'] ?? 'automatic';
    Uint8List? imageBytes;
    String? imageName;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: Text(existing != null ? 'Araç Düzenle' : 'Yeni Araç'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Expanded(child: TextField(controller: brandCtrl, decoration: const InputDecoration(labelText: 'Marka *'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: modelCtrl, decoration: const InputDecoration(labelText: 'Model *'))),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  SizedBox(width: 80, child: TextField(controller: yearCtrl, decoration: const InputDecoration(labelText: 'Yıl'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: plateCtrl, decoration: const InputDecoration(labelText: 'Plaka'))),
                  const SizedBox(width: 12),
                  SizedBox(width: 60, child: TextField(controller: seatsCtrl, decoration: const InputDecoration(labelText: 'Koltuk'), keyboardType: TextInputType.number)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    items: const [
                      DropdownMenuItem(value: 'economy', child: Text('Ekonomi')),
                      DropdownMenuItem(value: 'compact', child: Text('Kompakt')),
                      DropdownMenuItem(value: 'midsize', child: Text('Orta')),
                      DropdownMenuItem(value: 'fullsize', child: Text('Büyük')),
                      DropdownMenuItem(value: 'suv', child: Text('SUV')),
                      DropdownMenuItem(value: 'luxury', child: Text('Lüks')),
                      DropdownMenuItem(value: 'van', child: Text('Van')),
                    ],
                    onChanged: (v) => ss(() => category = v ?? 'economy'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: DropdownButtonFormField<String>(
                    initialValue: fuelType,
                    decoration: const InputDecoration(labelText: 'Yakıt'),
                    items: const [
                      DropdownMenuItem(value: 'gasoline', child: Text('Benzin')),
                      DropdownMenuItem(value: 'diesel', child: Text('Dizel')),
                      DropdownMenuItem(value: 'hybrid', child: Text('Hibrit')),
                      DropdownMenuItem(value: 'electric', child: Text('Elektrik')),
                    ],
                    onChanged: (v) => ss(() => fuelType = v ?? 'gasoline'),
                  )),
                ]),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: transmission,
                  decoration: const InputDecoration(labelText: 'Vites'),
                  items: const [
                    DropdownMenuItem(value: 'automatic', child: Text('Otomatik')),
                    DropdownMenuItem(value: 'manual', child: Text('Manuel')),
                  ],
                  onChanged: (v) => ss(() => transmission = v ?? 'automatic'),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: dailyCtrl, decoration: const InputDecoration(labelText: 'Günlük (₺) *'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: weeklyCtrl, decoration: const InputDecoration(labelText: 'Haftalık (₺)'), keyboardType: TextInputType.number)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: monthlyCtrl, decoration: const InputDecoration(labelText: 'Aylık (₺)'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: depositCtrl, decoration: const InputDecoration(labelText: 'Depozito (₺)'), keyboardType: TextInputType.number)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  if (imageName != null) Text('Seçilen: $imageName', style: const TextStyle(fontSize: 11)) else const Text('Görsel seçilmedi', style: TextStyle(fontSize: 11, color: Colors.grey)),
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
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                if (brandCtrl.text.isEmpty || modelCtrl.text.isEmpty || dailyCtrl.text.isEmpty) return;
                ss(() => isSaving = true);
                try {
                  String? imageUrl = existing?['image_url'];
                  if (imageBytes != null && imageName != null) {
                    imageUrl = await ref.read(storageServiceProvider).uploadImage('rental_cars', imageBytes!, imageName!);
                  }
                  final data = {
                    'brand': brandCtrl.text,
                    'model': modelCtrl.text,
                    'year': int.tryParse(yearCtrl.text),
                    'plate': plateCtrl.text.isEmpty ? null : plateCtrl.text,
                    'category': category,
                    'fuel_type': fuelType,
                    'transmission': transmission,
                    'seats': int.tryParse(seatsCtrl.text) ?? 5,
                    'daily_price': double.tryParse(dailyCtrl.text) ?? 0,
                    'weekly_price': double.tryParse(weeklyCtrl.text),
                    'monthly_price': double.tryParse(monthlyCtrl.text),
                    'deposit_amount': double.tryParse(depositCtrl.text),
                    'image_url': imageUrl,
                  };
                  final service = ref.read(businessProxyServiceProvider);
                  if (existing != null) {
                    await service.updateRentalVehicleFull(existing['id'], data, companyId: widget.businessId);
                  } else {
                    await service.createRentalVehicle(widget.businessId, data);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadData();
                } catch (e, st) {
                  LogService.error('Failed to save vehicle', error: e, stackTrace: st, source: 'RentalOpsPanel:saveVehicle');
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

  // ═══════════════════════════════════════════
  // ─── Locations Tab (CRUD) ───
  // ═══════════════════════════════════════════

  Widget _buildLocationsTab(bool isDark) {
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final cardColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            ElevatedButton.icon(
              onPressed: () => _showLocationDialog(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Yeni Lokasyon'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ]),
        ),
        Expanded(
          child: _locations.isEmpty
              ? Center(child: Text('Lokasyon yok', style: TextStyle(color: textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _locations.length,
                  itemBuilder: (ctx, i) {
                    final l = _locations[i];
                    final isActive = l['is_active'] ?? true;
                    return Card(
                      color: cardColor,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderColor)),
                      child: ListTile(
                        leading: Icon(l['is_airport'] == true ? Icons.flight : Icons.location_on, color: AppColors.primary, size: 20),
                        title: Text(l['name'] ?? '-', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                        subtitle: Text('${l['city'] ?? '-'} • ${l['address'] ?? '-'}', style: TextStyle(color: textMuted, fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: isActive,
                              activeThumbColor: AppColors.success,
                              onChanged: (v) async {
                                await ref.read(businessProxyServiceProvider).toggleLocationActive(l['id'], v, companyId: widget.businessId);
                                _loadData();
                              },
                            ),
                            IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: () => _showLocationDialog(existing: l), tooltip: 'Düzenle'),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 16, color: AppColors.error),
                              onPressed: () => _showDeleteDialog('Lokasyonu Sil', l['name'] ?? '-', () async {
                                await ref.read(businessProxyServiceProvider).deleteRentalLocation(l['id'], companyId: widget.businessId);
                                _loadData();
                              }),
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

  void _showLocationDialog({Map<String, dynamic>? existing}) {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final cityCtrl = TextEditingController(text: existing?['city'] ?? '');
    final addressCtrl = TextEditingController(text: existing?['address'] ?? '');
    final phoneCtrl = TextEditingController(text: existing?['phone'] ?? '');
    final emailCtrl = TextEditingController(text: existing?['email'] ?? '');
    final latCtrl = TextEditingController(text: existing?['latitude']?.toString() ?? '');
    final lngCtrl = TextEditingController(text: existing?['longitude']?.toString() ?? '');
    bool isAirport = existing?['is_airport'] ?? false;
    bool isActive = existing?['is_active'] ?? true;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: Text(existing != null ? 'Lokasyon Düzenle' : 'Yeni Lokasyon'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'İsim *')),
                const SizedBox(height: 12),
                TextField(controller: cityCtrl, decoration: const InputDecoration(labelText: 'Şehir *')),
                const SizedBox(height: 12),
                TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Adres'), maxLines: 2),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Telefon'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email'))),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: latCtrl, decoration: const InputDecoration(labelText: 'Enlem'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: lngCtrl, decoration: const InputDecoration(labelText: 'Boylam'), keyboardType: TextInputType.number)),
                ]),
                const SizedBox(height: 8),
                SwitchListTile(title: const Text('Havalimanı', style: TextStyle(fontSize: 13)), value: isAirport, onChanged: (v) => ss(() => isAirport = v), dense: true, contentPadding: EdgeInsets.zero),
                SwitchListTile(title: const Text('Aktif', style: TextStyle(fontSize: 13)), value: isActive, onChanged: (v) => ss(() => isActive = v), dense: true, contentPadding: EdgeInsets.zero),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                if (nameCtrl.text.isEmpty || cityCtrl.text.isEmpty) return;
                ss(() => isSaving = true);
                try {
                  final data = {
                    'name': nameCtrl.text,
                    'city': cityCtrl.text,
                    'address': addressCtrl.text.isEmpty ? null : addressCtrl.text,
                    'phone': phoneCtrl.text.isEmpty ? null : phoneCtrl.text,
                    'email': emailCtrl.text.isEmpty ? null : emailCtrl.text,
                    'latitude': double.tryParse(latCtrl.text),
                    'longitude': double.tryParse(lngCtrl.text),
                    'is_airport': isAirport,
                    'is_active': isActive,
                  };
                  final service = ref.read(businessProxyServiceProvider);
                  if (existing != null) {
                    await service.updateRentalLocation(existing['id'], data, companyId: widget.businessId);
                  } else {
                    await service.createRentalLocation(widget.businessId, data);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadData();
                } catch (e, st) {
                  LogService.error('Failed to save location', error: e, stackTrace: st, source: 'RentalOpsPanel:saveLocation');
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

  // ═══════════════════════════════════════════
  // ─── Packages Tab ───
  // ═══════════════════════════════════════════

  Widget _buildPackagesTab(bool isDark) {
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final cardColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);

    if (_packages.isEmpty) return Center(child: Text('Paket yok', style: TextStyle(color: textMuted)));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _packages.length,
      itemBuilder: (ctx, i) {
        final p = _packages[i];
        final isActive = p['is_active'] ?? true;
        return Card(
          color: cardColor,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderColor)),
          child: ListTile(
            title: Text(p['name'] ?? '-', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
            subtitle: Text('₺${p['daily_price'] ?? 0}/gün • ${p['description'] ?? ''}', style: TextStyle(color: textMuted, fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: isActive,
                  activeThumbColor: AppColors.success,
                  onChanged: (v) async {
                    await ref.read(businessProxyServiceProvider).togglePackageActive(p['id'], v, companyId: widget.businessId);
                    _loadData();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 16),
                  onPressed: () => _showPackageEditDialog(p),
                  tooltip: 'Düzenle',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPackageEditDialog(Map<String, dynamic> pkg) {
    final priceCtrl = TextEditingController(text: pkg['daily_price']?.toString() ?? '');
    final descCtrl = TextEditingController(text: pkg['description'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${pkg['name']} Düzenle'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Günlük Fiyat (₺)'), keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Açıklama'), maxLines: 2),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(businessProxyServiceProvider).updateRentalPackage(pkg['id'], {
                'daily_price': double.tryParse(priceCtrl.text),
                'description': descCtrl.text.isEmpty ? null : descCtrl.text,
              }, companyId: widget.businessId);
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
  // ─── Services Tab (CRUD) ───
  // ═══════════════════════════════════════════

  Widget _buildServicesTab(bool isDark) {
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textMuted = isDark ? AppColors.textMuted : AppColors.lightTextMuted;
    final cardColor = isDark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            ElevatedButton.icon(
              onPressed: () => _showServiceDialog(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Yeni Hizmet'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ]),
        ),
        Expanded(
          child: _services.isEmpty
              ? Center(child: Text('Ek hizmet yok', style: TextStyle(color: textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _services.length,
                  itemBuilder: (ctx, i) {
                    final s = _services[i];
                    return Card(
                      color: cardColor,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderColor)),
                      child: ListTile(
                        title: Text(s['name'] ?? '-', style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                        subtitle: Text('₺${s['price'] ?? 0} / ${s['price_type'] ?? 'günlük'}', style: TextStyle(color: textMuted, fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: () => _showServiceDialog(existing: s), tooltip: 'Düzenle'),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 16, color: AppColors.error),
                              onPressed: () => _showDeleteDialog('Hizmeti Sil', s['name'] ?? '-', () async {
                                await ref.read(businessProxyServiceProvider).deleteRentalService(s['id'], companyId: widget.businessId);
                                _loadData();
                              }),
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

  void _showServiceDialog({Map<String, dynamic>? existing}) {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final descCtrl = TextEditingController(text: existing?['description'] ?? '');
    final priceCtrl = TextEditingController(text: existing?['price']?.toString() ?? '');
    String priceType = existing?['price_type'] ?? 'daily';
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: Text(existing != null ? 'Hizmet Düzenle' : 'Yeni Ek Hizmet'),
          content: SizedBox(
            width: 350,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'İsim *')),
              const SizedBox(height: 12),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Açıklama')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Fiyat (₺) *'), keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: DropdownButtonFormField<String>(
                  initialValue: priceType,
                  decoration: const InputDecoration(labelText: 'Fiyat Tipi'),
                  items: const [
                    DropdownMenuItem(value: 'daily', child: Text('Günlük')),
                    DropdownMenuItem(value: 'per_rental', child: Text('Kiralama Başı')),
                    DropdownMenuItem(value: 'per_km', child: Text('KM Başı')),
                  ],
                  onChanged: (v) => ss(() => priceType = v ?? 'daily'),
                )),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty) return;
                ss(() => isSaving = true);
                try {
                  final data = {
                    'name': nameCtrl.text,
                    'description': descCtrl.text.isEmpty ? null : descCtrl.text,
                    'price': double.tryParse(priceCtrl.text) ?? 0,
                    'price_type': priceType,
                  };
                  final service = ref.read(businessProxyServiceProvider);
                  if (existing != null) {
                    await service.updateRentalService(existing['id'], data, companyId: widget.businessId);
                  } else {
                    await service.createRentalService(widget.businessId, data);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadData();
                } catch (e, st) {
                  LogService.error('Failed to save service', error: e, stackTrace: st, source: 'RentalOpsPanel:saveService');
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

  // ═══════════════════════════════════════════
  // ─── Helpers ───
  // ═══════════════════════════════════════════

  void _showDeleteDialog(String title, String itemName, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text('$itemName silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); onConfirm(); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'available': color = AppColors.success; label = 'Müsait'; break;
      case 'rented': color = AppColors.warning; label = 'Kirada'; break;
      case 'maintenance': color = AppColors.info; label = 'Bakımda'; break;
      case 'inactive': color = AppColors.textMuted; label = 'Pasif'; break;
      case 'pending': color = AppColors.warning; label = 'Beklemede'; break;
      case 'confirmed': color = AppColors.success; label = 'Onaylandı'; break;
      case 'active': color = AppColors.primary; label = 'Aktif'; break;
      case 'completed': color = AppColors.info; label = 'Tamamlandı'; break;
      case 'cancelled': color = AppColors.error; label = 'İptal'; break;
      default: color = AppColors.textMuted; label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
