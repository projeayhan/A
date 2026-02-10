import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_dialogs.dart';
import '../../models/rental/rental_models.dart';
import '../../services/location_service.dart';

/// Shows the location picker bottom sheet with office locations and
/// the "Adrese Teslim" custom address option.
void showRentalLocationPicker({
  required BuildContext context,
  required bool isPickup,
  required List<RentalLocation> locations,
  required void Function(RentalLocation location) onLocationSelected,
  required VoidCallback onCustomAddressTap,
}) {
  final theme = Theme.of(context);

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              isPickup ? 'Alis Noktasi Secin' : 'Teslim Noktasi Secin',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),

          // Adrese Teslim Secenegi
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: InkWell(
              onTap: () {
                Navigator.pop(context);
                onCustomAddressTap();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.1),
                      AppColors.primary.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.home_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Adrese Teslim',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isPickup
                                ? 'Araci adresinizden teslim alin'
                                : 'Araci adresinize teslim edelim',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: theme.colorScheme.primary,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Ayirici
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(child: Divider(color: theme.dividerColor)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'veya ofis lokasyonu secin',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: theme.dividerColor)),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: locations.length,
              itemBuilder: (context, index) {
                final location = locations[index];
                return ListTile(
                  onTap: () {
                    onLocationSelected(location);
                    Navigator.pop(context);
                  },
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: location.isAirport
                          ? AppColors.info
                              .withValues(alpha: 0.1)
                          : AppColors.success
                              .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      location.isAirport
                          ? Icons.flight
                          : Icons.location_on,
                      color: location.isAirport
                          ? AppColors.info
                          : AppColors.success,
                    ),
                  ),
                  title: Text(
                    location.name,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    location.address,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  trailing: location.is24Hours
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '7/24',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        )
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

/// Shows the custom address options dialog (GPS, saved addresses, manual entry).
void showCustomAddressDialog({
  required BuildContext context,
  required bool isPickup,
  required void Function() onUseCurrentLocation,
  required void Function() onShowSavedAddresses,
  required void Function() onManualEntry,
}) {
  final theme = Theme.of(context);

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Baslik
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.home_outlined,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPickup ? 'Alis Adresi' : 'Teslim Adresi',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'Adres secim yontinizi belirleyin',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Secenek 1: Konumumu Kullan
                  _buildAddressOptionCard(
                    theme: theme,
                    icon: Icons.my_location,
                    iconColor: AppColors.success,
                    title: 'Konumumu Kullan',
                    subtitle:
                        'GPS ile mevcut konumunuzu otomatik alin',
                    onTap: () {
                      Navigator.pop(context);
                      onUseCurrentLocation();
                    },
                  ),

                  const SizedBox(height: 12),

                  // Secenek 2: Kayitli Adreslerim
                  _buildAddressOptionCard(
                    theme: theme,
                    icon: Icons.bookmark_outline,
                    iconColor: AppColors.warning,
                    title: 'Kayitli Adreslerim',
                    subtitle:
                        'Daha once kaydettiginiz adreslerden secin',
                    onTap: () {
                      Navigator.pop(context);
                      onShowSavedAddresses();
                    },
                  ),

                  const SizedBox(height: 12),

                  // Secenek 3: Yeni Adres Gir
                  _buildAddressOptionCard(
                    theme: theme,
                    icon: Icons.edit_location_alt_outlined,
                    iconColor: AppColors.primary,
                    title: 'Yeni Adres Gir',
                    subtitle: 'Adresi manuel olarak yazin',
                    onTap: () {
                      Navigator.pop(context);
                      onManualEntry();
                    },
                  ),

                  const SizedBox(height: 20),

                  // Bilgi notu
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.amber.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Adrese teslim hizmeti icin ek ucret uygulanabilir.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildAddressOptionCard({
  required ThemeData theme,
  required IconData icon,
  required Color iconColor,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
}) {
  return Card(
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 1,
    shadowColor: Colors.black.withValues(alpha: 0.04),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: theme.colorScheme.onSurfaceVariant,
              size: 16,
            ),
          ],
        ),
      ),
    ),
  );
}

Widget buildAddressTypeChip(
  ThemeData theme,
  String type,
  IconData icon,
  String label,
  String selectedType,
  Function(String) onSelect,
) {
  final isSelected = selectedType == type;
  return InkWell(
    onTap: () => onSelect(type),
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primary
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected
                ? Colors.white
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isSelected
                  ? Colors.white
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Gets the current location via GPS and returns the address through callback.
Future<void> getCurrentLocationAddress({
  required BuildContext context,
  required bool isPickup,
  required void Function(String address) onAddressFound,
  required void Function(bool isPickup) onShowManualEntry,
}) async {
  final theme = Theme.of(context);

  // Loading dialog goster
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              const Text('Konum aliniyor...'),
            ],
          ),
        ),
      ),
    ),
  );

  try {
    // Konum izni kontrolu
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (context.mounted) Navigator.pop(context);
        _showLocationError(context, 'Konum izni reddedildi', onShowManualEntry);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) Navigator.pop(context);
      _showLocationError(
          context,
          'Konum izni kalici olarak reddedildi. Ayarlardan izin verin.',
          onShowManualEntry);
      return;
    }

    // Konum al
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );

    // Koordinatlari adrese cevir
    String? address;

    if (kIsWeb) {
      // Web platformunda LocationService kullan (Google Geocoding API)
      address = await LocationService().getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );
    } else {
      // Mobilde geocoding paketi kullan
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          address = formatPlacemark(placemarks.first);
        }
      } catch (e) {
        debugPrint('Geocoding error: $e');
        // Fallback to LocationService
        address = await LocationService().getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );
      }
    }

    if (context.mounted) Navigator.pop(context); // Loading'i kapat

    if (!context.mounted) return;

    if (address != null && address.isNotEmpty) {
      onAddressFound(address);
    } else {
      _showLocationError(context, 'Adres bilgisi alinamadi', onShowManualEntry);
    }
  } catch (e) {
    if (context.mounted) Navigator.pop(context);
    if (!context.mounted) return;
    _showLocationError(
        context, 'Konum alinamadi: ${e.toString()}', onShowManualEntry);
  }
}

String formatPlacemark(Placemark place) {
  final parts = <String>[];

  if (place.street != null && place.street!.isNotEmpty) {
    parts.add(place.street!);
  }
  if (place.subLocality != null && place.subLocality!.isNotEmpty) {
    parts.add(place.subLocality!);
  }
  if (place.locality != null && place.locality!.isNotEmpty) {
    parts.add(place.locality!);
  }
  if (place.subAdministrativeArea != null &&
      place.subAdministrativeArea!.isNotEmpty) {
    parts.add(place.subAdministrativeArea!);
  }
  if (place.administrativeArea != null &&
      place.administrativeArea!.isNotEmpty) {
    parts.add(place.administrativeArea!);
  }

  return parts.join(', ');
}

void _showLocationError(
  BuildContext context,
  String message,
  void Function(bool isPickup) onShowManualEntry,
) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: AppColors.error,
      action: SnackBarAction(
        label: 'Manuel Gir',
        textColor: Colors.white,
        onPressed: () => onShowManualEntry(true),
      ),
    ),
  );
}

/// Shows the address confirmation dialog after GPS location is found.
void showAddressConfirmDialog({
  required BuildContext context,
  required bool isPickup,
  required String address,
  required void Function({
    required bool isPickup,
    required String address,
    required String note,
  }) onConfirm,
  required void Function(bool isPickup) onEdit,
}) {
  final theme = Theme.of(context);
  final noteController = TextEditingController();

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Basari ikonu
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:
                          AppColors.success.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: AppColors.success,
                      size: 40,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Center(
                  child: Text(
                    'Konum Bulundu',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Bulunan adres
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          address,
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Adres tarifi
                TextField(
                  controller: noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Adres Tarifi (Opsiyonel)',
                    hintText: 'Orn: Mavi binanin onu, 3. kat',
                    prefixIcon: const Icon(Icons.note_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Butonlar
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          onEdit(isPickup);
                        },
                        style: OutlinedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Duzenle'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          onConfirm(
                            isPickup: isPickup,
                            address: address,
                            note: noteController.text.trim(),
                          );
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Onayla',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Shows the saved addresses dialog.
void showSavedAddressesDialog({
  required BuildContext context,
  required bool isPickup,
  required void Function({
    required bool isPickup,
    required String address,
    required String note,
  }) onAddressSelected,
  required void Function(bool isPickup, {bool saveAddress}) onShowManualEntry,
}) async {
  // Kullanicinin kayitli adreslerini cek (saved_locations tablosundan)
  List<Map<String, dynamic>> savedAddresses = [];

  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      final response = await Supabase.instance.client
          .from('saved_locations')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('is_default', ascending: false)
          .order('sort_order', ascending: true);

      savedAddresses = List<Map<String, dynamic>>.from(response);
    }
  } catch (e) {
    debugPrint('Error loading saved addresses: $e');
  }

  if (!context.mounted) return;

  final theme = Theme.of(context);

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Kayitli Adreslerim',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onShowManualEntry(isPickup,
                        saveAddress: true);
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Yeni Ekle'),
                ),
              ],
            ),
          ),
          Expanded(
            child: savedAddresses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bookmark_border,
                          size: 64,
                          color: theme.dividerColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Kayitli adresiniz yok',
                          style: TextStyle(
                            fontSize: 16,
                            color:
                                theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            onShowManualEntry(isPickup,
                                saveAddress: true);
                          },
                          child: const Text('Yeni Adres Ekle'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: savedAddresses.length,
                    itemBuilder: (context, index) {
                      final addr = savedAddresses[index];
                      final isDefault =
                          addr['is_default'] == true;
                      final addressType =
                          addr['type'] ?? 'other';

                      IconData typeIcon;
                      switch (addressType) {
                        case 'home':
                          typeIcon = Icons.home;
                          break;
                        case 'work':
                          typeIcon = Icons.work;
                          break;
                        default:
                          typeIcon = Icons.location_on;
                      }

                      // Tam adresi olustur
                      final fullAddress =
                          buildFullAddress(addr);
                      final directions =
                          addr['directions'] ?? '';

                      return ListTile(
                        onTap: () {
                          onAddressSelected(
                            isPickup: isPickup,
                            address: fullAddress,
                            note: directions,
                          );
                          Navigator.pop(context);
                        },
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(10),
                          ),
                          child: Icon(
                            typeIcon,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                addr['name'] ??
                                    addr['title'] ??
                                    'Adres',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow:
                                    TextOverflow.ellipsis,
                              ),
                            ),
                            if (isDefault) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme
                                      .colorScheme.primary,
                                  borderRadius:
                                      BorderRadius.circular(
                                          4),
                                ),
                                child: const Text(
                                  'Varsayilan',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          fullAddress,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: theme.colorScheme
                              .onSurfaceVariant,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}

/// Shows the manual address entry dialog.
void showManualAddressDialog({
  required BuildContext context,
  required bool isPickup,
  required String currentAddress,
  required String currentNote,
  bool saveAddress = false,
  required void Function({
    required bool isPickup,
    required String address,
    required String note,
  }) onAddressConfirmed,
}) {
  final theme = Theme.of(context);
  final addressController = TextEditingController(
    text: currentAddress,
  );
  final noteController = TextEditingController(
    text: currentNote,
  );
  final titleController = TextEditingController();
  bool shouldSave = saveAddress;
  String selectedType = 'home';

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16)),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    isPickup ? 'Alis Adresi' : 'Teslim Adresi',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Adres girisi
                  TextField(
                    controller: addressController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Acik Adres *',
                      hintText:
                          'Mahalle, Cadde/Sokak, No, Ilce/Il',
                      prefixIcon:
                          const Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Adres tarifi
                  TextField(
                    controller: noteController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Adres Tarifi (Opsiyonel)',
                      hintText: 'Bina rengi, kat, kapi no vs.',
                      prefixIcon:
                          const Icon(Icons.note_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Adresi kaydet secenegi
                  InkWell(
                    onTap: () {
                      setDialogState(
                          () => shouldSave = !shouldSave);
                    },
                    child: Row(
                      children: [
                        Checkbox(
                          value: shouldSave,
                          onChanged: (v) {
                            setDialogState(
                                () => shouldSave = v ?? false);
                          },
                          activeColor:
                              theme.colorScheme.primary,
                        ),
                        Text(
                          'Bu adresi kaydet',
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Kaydetme secenekleri
                  if (shouldSave) ...[
                    const SizedBox(height: 12),

                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Adres Basligi',
                        hintText: 'Orn: Evim, Is Yerim',
                        prefixIcon:
                            const Icon(Icons.label_outline),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Adres tipi secimi
                    Row(
                      children: [
                        buildAddressTypeChip(
                          theme,
                          'home',
                          Icons.home,
                          'Ev',
                          selectedType,
                          (type) => setDialogState(
                              () => selectedType = type),
                        ),
                        const SizedBox(width: 8),
                        buildAddressTypeChip(
                          theme,
                          'work',
                          Icons.work,
                          'Is',
                          selectedType,
                          (type) => setDialogState(
                              () => selectedType = type),
                        ),
                        const SizedBox(width: 8),
                        buildAddressTypeChip(
                          theme,
                          'other',
                          Icons.location_on,
                          'Diger',
                          selectedType,
                          (type) => setDialogState(
                              () => selectedType = type),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Butonlar
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(
                                    vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Iptal'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (addressController.text
                                .trim()
                                .isEmpty) {
                              AppDialogs.showWarning(context,
                                  'Lutfen adres girin');
                              return;
                            }

                            final address = addressController
                                .text
                                .trim();
                            final note =
                                noteController.text.trim();

                            // Adresi kaydet
                            if (shouldSave) {
                              await saveAddressToDatabase(
                                title: titleController.text
                                        .trim()
                                        .isEmpty
                                    ? (selectedType == 'home'
                                        ? 'Evim'
                                        : selectedType ==
                                                'work'
                                            ? 'Is Yerim'
                                            : 'Adresim')
                                    : titleController.text
                                        .trim(),
                                address: address,
                                notes: note,
                                addressType: selectedType,
                              );
                            }

                            if (!context.mounted) return;

                            onAddressConfirmed(
                              isPickup: isPickup,
                              address: address,
                              note: note,
                            );
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                theme.colorScheme.primary,
                            padding:
                                const EdgeInsets.symmetric(
                                    vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Kaydet',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// saved_locations tablosundan tam adres olustur
String buildFullAddress(Map<String, dynamic> addr) {
  final parts = <String>[];

  if (addr['address'] != null &&
      addr['address'].toString().isNotEmpty) {
    parts.add(addr['address'].toString());
  }
  if (addr['address_details'] != null &&
      addr['address_details'].toString().isNotEmpty) {
    parts.add(addr['address_details'].toString());
  }
  if (addr['floor'] != null &&
      addr['floor'].toString().isNotEmpty) {
    parts.add('Kat: ${addr['floor']}');
  }
  if (addr['apartment'] != null &&
      addr['apartment'].toString().isNotEmpty) {
    parts.add('Daire: ${addr['apartment']}');
  }

  return parts.join(', ');
}

Future<void> saveAddressToDatabase({
  required String title,
  required String address,
  required String notes,
  required String addressType,
}) async {
  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // saved_locations tablosuna kaydet (ana uygulama ile uyumlu)
    await Supabase.instance.client.from('saved_locations').insert({
      'user_id': userId,
      'name': title,
      'address': address,
      'directions': notes,
      'type': addressType,
      'is_default': false,
      'is_active': true,
      'sort_order': 0,
    });
  } catch (e) {
    debugPrint('Error saving address: $e');
  }
}
