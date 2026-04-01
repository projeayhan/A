import 'package:flutter/material.dart';

/// Veri bulunmayan tab içerikleri için boş durum ekranı
class PlaceholderTabScreen extends StatelessWidget {
  final String tabName;
  final String sectorName;

  const PlaceholderTabScreen({
    super.key,
    required this.tabName,
    required this.sectorName,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            '$sectorName - $tabName',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Bu sekme için henüz veri bulunmuyor',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
