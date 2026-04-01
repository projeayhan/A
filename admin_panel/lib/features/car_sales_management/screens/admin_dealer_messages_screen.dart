import 'package:flutter/material.dart';
import '../../merchant_management/screens/admin_messages_screen.dart';

/// Galeri mesajları ekranı - Generic AdminMessagesScreen'i sarar
class AdminDealerMessagesScreen extends StatelessWidget {
  final String dealerId;
  const AdminDealerMessagesScreen({super.key, required this.dealerId});

  @override
  Widget build(BuildContext context) {
    return AdminMessagesScreen(
      entityType: 'car_dealers',
      entityId: dealerId,
    );
  }
}
