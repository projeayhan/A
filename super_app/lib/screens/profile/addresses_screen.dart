import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/address_provider.dart';
import '../../core/utils/app_dialogs.dart';

class AddressesScreen extends ConsumerStatefulWidget {
  const AddressesScreen({super.key});

  @override
  ConsumerState<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends ConsumerState<AddressesScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final addressState = ref.watch(addressProvider);
    final addresses = addressState.addresses;
    final selectedAddress = addressState.selectedAddress;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[200]!),
            ),
            child: Icon(Icons.arrow_back_ios_new, size: 16, color: isDark ? Colors.white : Colors.grey[800]),
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Adreslerim',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
        centerTitle: true,
      ),
      body: addresses.isEmpty ? _buildEmptyState(isDark) : _buildAddressList(isDark, addresses, selectedAddress),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAddressSheet(isDark),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_location_alt, color: Colors.white),
        label: const Text('Yeni Adres', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_off_outlined, size: 60, color: Color(0xFF10B981)),
          ),
          const SizedBox(height: 24),
          Text(
            'Henüz adres eklenmemiş',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Teslimat için adres ekleyin',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressList(bool isDark, List<UserAddress> addresses, UserAddress? selectedAddress) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: addresses.length,
      itemBuilder: (context, index) {
        final address = addresses[index];
        final isSelected = selectedAddress?.id == address.id;
        return GestureDetector(
          onTap: () {
            if (!isSelected) {
              _setAsDefault(address);
            }
          },
          child: _buildAddressCard(address, isDark, isSelected),
        );
      },
    );
  }

  Widget _buildAddressCard(UserAddress address, bool isDark, bool isSelected) {
    IconData typeIcon;
    Color typeColor;

    switch (address.type) {
      case 'home':
        typeIcon = Icons.home_outlined;
        typeColor = const Color(0xFF3B82F6);
        break;
      case 'work':
        typeIcon = Icons.work_outline;
        typeColor = const Color(0xFF8B5CF6);
        break;
      default:
        typeIcon = Icons.location_on_outlined;
        typeColor = const Color(0xFF10B981);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isSelected
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            address.title,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1F2937),
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Varsayılan',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        address.fullAddress,
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.grey[400]),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _showEditAddressSheet(address, isDark);
                        break;
                      case 'default':
                        _setAsDefault(address);
                        break;
                      case 'delete':
                        _showDeleteDialog(address);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 20),
                          SizedBox(width: 12),
                          Text('Düzenle'),
                        ],
                      ),
                    ),
                    if (!isSelected)
                      const PopupMenuItem(
                        value: 'default',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline, size: 20),
                            SizedBox(width: 12),
                            Text('Varsayılan Yap'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          SizedBox(width: 12),
                          Text('Sil', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Details
          if (address.floor != null || address.apartment != null || address.directions != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800]!.withValues(alpha: 0.5) : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  if (address.floor != null || address.apartment != null)
                    Row(
                      children: [
                        if (address.floor != null) ...[
                          Icon(Icons.stairs_outlined, size: 16, color: Colors.grey[500]),
                          const SizedBox(width: 6),
                          Text(
                            'Kat: ${address.floor}',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 16),
                        ],
                        if (address.apartment != null) ...[
                          Icon(Icons.door_front_door_outlined, size: 16, color: Colors.grey[500]),
                          const SizedBox(width: 6),
                          Text(
                            'Daire: ${address.apartment}',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                        ],
                      ],
                    ),
                  if (address.directions != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            address.directions!,
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showAddAddressSheet(bool isDark) {
    _showAddressForm(isDark, null);
  }

  void _showEditAddressSheet(UserAddress address, bool isDark) {
    _showAddressForm(isDark, address);
  }

  void _showAddressForm(bool isDark, UserAddress? existingAddress) {
    final titleController = TextEditingController(text: existingAddress?.title ?? '');
    final shortAddressController = TextEditingController(text: existingAddress?.shortAddress ?? '');
    final addressController = TextEditingController(text: existingAddress?.fullAddress ?? '');
    final floorController = TextEditingController(text: existingAddress?.floor ?? '');
    final apartmentController = TextEditingController(text: existingAddress?.apartment ?? '');
    final directionsController = TextEditingController(text: existingAddress?.directions ?? '');
    String selectedType = existingAddress?.type ?? 'home';
    double? latitude = existingAddress?.latitude;
    double? longitude = existingAddress?.longitude;
    bool isLoadingLocation = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Text(
                      existingAddress != null ? 'Adresi Düzenle' : 'Yeni Adres Ekle',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Address Type
                      Text(
                        'Adres Türü',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildTypeChip('home', 'Ev', Icons.home_outlined, const Color(0xFF3B82F6), selectedType, isDark, (type) {
                            setModalState(() => selectedType = type);
                          }),
                          const SizedBox(width: 10),
                          _buildTypeChip('work', 'İş', Icons.work_outline, const Color(0xFF8B5CF6), selectedType, isDark, (type) {
                            setModalState(() => selectedType = type);
                          }),
                          const SizedBox(width: 10),
                          _buildTypeChip('other', 'Diğer', Icons.location_on_outlined, const Color(0xFF10B981), selectedType, isDark, (type) {
                            setModalState(() => selectedType = type);
                          }),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Title
                      _buildFormField(
                        controller: titleController,
                        label: 'Adres Başlığı',
                        hint: 'Örn: Ev, İş, Annemin Evi',
                        icon: Icons.label_outline,
                        isDark: isDark,
                      ),

                      const SizedBox(height: 16),

                      // Short Address (for dropdown display)
                      _buildFormField(
                        controller: shortAddressController,
                        label: 'Kısa Adres',
                        hint: 'Örn: Kadıköy, İstanbul',
                        icon: Icons.short_text,
                        isDark: isDark,
                      ),

                      const SizedBox(height: 16),

                      // Full Address
                      _buildFormField(
                        controller: addressController,
                        label: 'Açık Adres',
                        hint: 'Mahalle, sokak, bina no, ilçe, il',
                        icon: Icons.location_on_outlined,
                        isDark: isDark,
                        maxLines: 2,
                      ),

                      const SizedBox(height: 16),

                      // Floor & Apartment
                      Row(
                        children: [
                          Expanded(
                            child: _buildFormField(
                              controller: floorController,
                              label: 'Kat',
                              hint: 'Örn: 3',
                              icon: Icons.stairs_outlined,
                              isDark: isDark,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildFormField(
                              controller: apartmentController,
                              label: 'Daire',
                              hint: 'Örn: 12',
                              icon: Icons.door_front_door_outlined,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Directions
                      _buildFormField(
                        controller: directionsController,
                        label: 'Adres Tarifi (Opsiyonel)',
                        hint: 'Kurye için ek bilgiler...',
                        icon: Icons.info_outline,
                        isDark: isDark,
                        maxLines: 2,
                      ),

                      const SizedBox(height: 16),

                      // Location Section
                      Text(
                        'Konum',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Location Status & Buttons
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: latitude != null
                                ? const Color(0xFF10B981).withValues(alpha: 0.5)
                                : (isDark ? Colors.grey[700]! : Colors.grey[200]!),
                            width: latitude != null ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Location Status
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: latitude != null
                                        ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                        : Colors.grey.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    latitude != null ? Icons.check_circle : Icons.location_off,
                                    color: latitude != null ? const Color(0xFF10B981) : Colors.grey,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        latitude != null ? 'Konum Alındı' : 'Konum Gerekli',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: latitude != null
                                              ? const Color(0xFF10B981)
                                              : (isDark ? Colors.white : Colors.grey[800]),
                                        ),
                                      ),
                                      Text(
                                        latitude != null
                                            ? '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}'
                                            : 'Kurye navigasyonu için konum gerekli',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Buttons Row
                            Row(
                              children: [
                                // GPS Button
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: isLoadingLocation
                                        ? null
                                        : () async {
                                            setModalState(() => isLoadingLocation = true);
                                            try {
                                              // Check permission
                                              LocationPermission permission = await Geolocator.checkPermission();
                                              if (permission == LocationPermission.denied) {
                                                permission = await Geolocator.requestPermission();
                                              }
                                              if (permission == LocationPermission.deniedForever) {
                                                if (context.mounted) {
                                                  await AppDialogs.showWarning(context, 'Konum izni gerekli. Ayarlardan izin verin.');
                                                }
                                                return;
                                              }

                                              // Get current position
                                              final position = await Geolocator.getCurrentPosition(
                                                locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
                                              );

                                              setModalState(() {
                                                latitude = position.latitude;
                                                longitude = position.longitude;
                                              });

                                              // Try to get address from coordinates
                                              try {
                                                final placemarks = await placemarkFromCoordinates(
                                                  position.latitude,
                                                  position.longitude,
                                                );
                                                if (placemarks.isNotEmpty) {
                                                  final place = placemarks.first;
                                                  final fullAddr = [
                                                    place.street,
                                                    place.subLocality,
                                                    place.locality,
                                                    place.administrativeArea,
                                                  ].where((s) => s != null && s.isNotEmpty).join(', ');

                                                  if (addressController.text.isEmpty) {
                                                    addressController.text = fullAddr;
                                                  }
                                                  if (shortAddressController.text.isEmpty) {
                                                    final shortParts = <String>[];
                                                    if (place.subLocality != null && place.subLocality!.isNotEmpty) {
                                                      shortParts.add(place.subLocality!);
                                                    } else if (place.locality != null && place.locality!.isNotEmpty) {
                                                      shortParts.add(place.locality!);
                                                    }
                                                    if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
                                                      shortParts.add(place.administrativeArea!);
                                                    }
                                                    shortAddressController.text = shortParts.join(', ');
                                                  }
                                                }
                                              } catch (e) {
                                                debugPrint('Geocoding error: $e');
                                              }

                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Konum alındı!'),
                                                    backgroundColor: Color(0xFF10B981),
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                await AppDialogs.showError(context, 'Konum alınamadı: $e');
                                              }
                                            } finally {
                                              setModalState(() => isLoadingLocation = false);
                                            }
                                          },
                                    icon: isLoadingLocation
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.my_location, size: 18),
                                    label: Text(isLoadingLocation ? 'Alınıyor...' : 'Konumumu Bul'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Geocode from Address Button
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: isLoadingLocation || addressController.text.isEmpty
                                        ? null
                                        : () async {
                                            setModalState(() => isLoadingLocation = true);
                                            try {
                                              final locations = await locationFromAddress(addressController.text);
                                              if (locations.isNotEmpty) {
                                                setModalState(() {
                                                  latitude = locations.first.latitude;
                                                  longitude = locations.first.longitude;
                                                });
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Adres konumu bulundu!'),
                                                      backgroundColor: Color(0xFF10B981),
                                                    ),
                                                  );
                                                }
                                              } else {
                                                if (context.mounted) {
                                                  await AppDialogs.showError(context, 'Adres bulunamadı');
                                                }
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                await AppDialogs.showError(context, 'Hata: $e');
                                              }
                                            } finally {
                                              setModalState(() => isLoadingLocation = false);
                                            }
                                          },
                                    icon: const Icon(Icons.search, size: 18),
                                    label: const Text('Adresten Bul'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      side: const BorderSide(color: AppColors.primary),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),

              // Save Button
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (titleController.text.isEmpty || addressController.text.isEmpty) {
                          await AppDialogs.showError(context, 'Başlık ve adres gerekli');
                          return;
                        }

                        if (latitude == null || longitude == null) {
                          await AppDialogs.showWarning(context, 'Kurye navigasyonu için konum gerekli. "Konumumu Bul" veya "Adresten Bul" butonunu kullanın.');
                          return;
                        }

                        final newAddress = UserAddress(
                          id: existingAddress?.id ?? '',
                          title: titleController.text,
                          shortAddress: shortAddressController.text.isNotEmpty
                              ? shortAddressController.text
                              : _extractShortAddress(addressController.text),
                          fullAddress: addressController.text,
                          type: selectedType,
                          floor: floorController.text.isNotEmpty ? floorController.text : null,
                          apartment: apartmentController.text.isNotEmpty ? apartmentController.text : null,
                          directions: directionsController.text.isNotEmpty ? directionsController.text : null,
                          latitude: latitude,
                          longitude: longitude,
                        );

                        bool success;
                        if (existingAddress != null) {
                          success = await ref.read(addressProvider.notifier).updateAddress(newAddress);
                        } else {
                          success = await ref.read(addressProvider.notifier).addAddress(newAddress);
                        }

                        if (!context.mounted) return;
                        Navigator.pop(context);
                        if (success) {
                          await AppDialogs.showSuccess(
                            context,
                            existingAddress != null ? 'Adres güncellendi' : 'Adres eklendi',
                          );
                        } else {
                          await AppDialogs.showError(context, 'Bir hata oluştu');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        existingAddress != null ? 'Değişiklikleri Kaydet' : 'Adresi Kaydet',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
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

  String _extractShortAddress(String fullAddress) {
    // Simple extraction - get last two comma-separated parts
    final parts = fullAddress.split(',').map((p) => p.trim()).toList();
    if (parts.length >= 2) {
      return '${parts[parts.length - 2]}, ${parts[parts.length - 1]}';
    }
    return fullAddress;
  }

  Widget _buildTypeChip(String type, String label, IconData icon, Color color, String selectedType, bool isDark, Function(String) onTap) {
    final isSelected = selectedType == type;
    return GestureDetector(
      onTap: () => onTap(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : (isDark ? Colors.grey[800] : Colors.grey[100]),
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? null : Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? Colors.white : color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(
            fontSize: 15,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(icon, color: Colors.grey[400], size: 22),
            ),
            filled: true,
            fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Future<void> _setAsDefault(UserAddress address) async {
    await ref.read(addressProvider.notifier).setDefaultAddress(address.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${address.title} varsayılan adres olarak ayarlandı'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _showDeleteDialog(UserAddress address) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 12),
            Text('Adresi Sil'),
          ],
        ),
        content: Text('${address.title} adresini silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await ref.read(addressProvider.notifier).deleteAddress(address.id);
              if (!context.mounted) return;
              Navigator.pop(context);
              if (success) {
                await AppDialogs.showSuccess(context, 'Adres silindi');
              } else {
                await AppDialogs.showError(context, 'Bir hata oluştu');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
