import 'package:flutter/material.dart';

/// Address data model for delivery address selector
class DeliveryAddressData {
  final String id;
  final String title;
  final String fullAddress;
  final String shortAddress;
  final String type; // 'home', 'work', 'other'

  const DeliveryAddressData({
    required this.id,
    required this.title,
    required this.fullAddress,
    this.shortAddress = '',
    this.type = 'other',
  });
}

/// Reusable delivery address card widget.
/// Displays selected address with edit button.
class DeliveryAddressCard extends StatelessWidget {
  final DeliveryAddressData? selectedAddress;
  final VoidCallback onEdit;
  final Color primaryColor;
  final bool isDark;
  final String headerLabel;

  const DeliveryAddressCard({
    super.key,
    this.selectedAddress,
    required this.onEdit,
    required this.primaryColor,
    this.isDark = false,
    this.headerLabel = 'Teslimat Adresi',
  });

  @override
  Widget build(BuildContext context) {
    final addressTitle = selectedAddress?.title ?? 'Adres Seç';
    final addressLine1 = selectedAddress?.fullAddress ?? 'Teslimat adresi seçin';
    final addressLine2 = selectedAddress?.shortAddress ?? '';
    final addressType = selectedAddress?.type ?? 'other';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[700]!.withValues(alpha: 0.5) : Colors.grey[100]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildIcon(),
          const SizedBox(width: 12),
          Expanded(
            child: _buildAddressInfo(addressTitle, addressLine1, addressLine2, addressType),
          ),
          _buildEditButton(),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isDark
            ? primaryColor.withValues(alpha: 0.2)
            : primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.location_on,
        color: primaryColor,
        size: 24,
      ),
    );
  }

  Widget _buildAddressInfo(String title, String line1, String line2, String type) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              headerLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[400] : Colors.grey[500],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF166534).withValues(alpha: 0.3)
                    : const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                type == 'home' ? 'Ev' : (type == 'work' ? 'İş' : title),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          line1,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.grey[900],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (line2.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            line2,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[500],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEditButton() {
    return GestureDetector(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[700] : Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.edit_outlined,
          size: 20,
          color: isDark ? Colors.grey[300] : Colors.grey[600],
        ),
      ),
    );
  }
}

/// Bottom sheet for selecting delivery address
class DeliveryAddressBottomSheet extends StatelessWidget {
  final List<DeliveryAddressData> addresses;
  final String? selectedAddressId;
  final ValueChanged<DeliveryAddressData> onAddressSelected;
  final VoidCallback? onAddNew;
  final Color primaryColor;
  final bool isDark;
  final String title;

  const DeliveryAddressBottomSheet({
    super.key,
    required this.addresses,
    this.selectedAddressId,
    required this.onAddressSelected,
    this.onAddNew,
    required this.primaryColor,
    this.isDark = false,
    this.title = 'Teslimat Adresi Seç',
  });

  static Future<void> show({
    required BuildContext context,
    required List<DeliveryAddressData> addresses,
    String? selectedAddressId,
    required ValueChanged<DeliveryAddressData> onAddressSelected,
    VoidCallback? onAddNew,
    required Color primaryColor,
    bool isDark = false,
    String title = 'Teslimat Adresi Seç',
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DeliveryAddressBottomSheet(
        addresses: addresses,
        selectedAddressId: selectedAddressId,
        onAddressSelected: (address) {
          onAddressSelected(address);
          Navigator.pop(ctx);
        },
        onAddNew: onAddNew != null
            ? () {
                Navigator.pop(ctx);
                onAddNew();
              }
            : null,
        primaryColor: primaryColor,
        isDark: isDark,
        title: title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          _buildHeader(context),
          const Divider(height: 1),
          _buildAddressList(context),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.grey[900],
            ),
          ),
          const Spacer(),
          if (onAddNew != null)
            TextButton(
              onPressed: onAddNew,
              child: Text(
                'Yeni Ekle',
                style: TextStyle(color: primaryColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddressList(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.all(12),
      itemCount: addresses.length,
      itemBuilder: (context, index) {
        final address = addresses[index];
        final isSelected = selectedAddressId == address.id;

        return _AddressListItem(
          address: address,
          isSelected: isSelected,
          primaryColor: primaryColor,
          isDark: isDark,
          onTap: () => onAddressSelected(address),
        );
      },
    );
  }
}

class _AddressListItem extends StatelessWidget {
  final DeliveryAddressData address;
  final bool isSelected;
  final Color primaryColor;
  final bool isDark;
  final VoidCallback onTap;

  const _AddressListItem({
    required this.address,
    required this.isSelected,
    required this.primaryColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.1)
              : (isDark ? Colors.grey[800] : Colors.grey[50]),
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: primaryColor, width: 2) : null,
        ),
        child: Row(
          children: [
            _buildIcon(),
            const SizedBox(width: 12),
            Expanded(child: _buildContent()),
            if (isSelected) Icon(Icons.check_circle, color: primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        address.type == 'home'
            ? Icons.home
            : (address.type == 'work' ? Icons.work : Icons.location_on),
        color: primaryColor,
        size: 20,
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          address.title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.grey[900],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          address.fullAddress,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[500],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
