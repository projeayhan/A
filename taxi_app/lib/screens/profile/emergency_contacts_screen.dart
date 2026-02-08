import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/communication_service.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  List<EmergencyContact> _contacts = [];
  bool _isLoading = true;

  static const _relationships = [
    'Anne',
    'Baba',
    'Eş',
    'Kardeş',
    'Arkadaş',
    'Diğer',
  ];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    try {
      final contacts = await CommunicationService.getEmergencyContacts();
      if (mounted) {
        setState(() {
          _contacts = contacts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addContact(EmergencyContact contact) async {
    final success = await CommunicationService.addEmergencyContact(contact);
    if (success && mounted) {
      await _loadContacts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Acil durum kişisi eklendi'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    }
  }

  Future<void> _removeContact(String phone) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kişiyi Sil'),
        content:
            const Text('Bu acil durum kişisini silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await CommunicationService.removeEmergencyContact(phone);
      if (success && mounted) {
        await _loadContacts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kişi silindi'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
      }
    }
  }

  void _showAddContactSheet() {
    if (_contacts.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('En fazla 5 acil durum kişisi ekleyebilirsiniz'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    String selectedRelationship = _relationships[0];
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Acil Durum Kişisi Ekle',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Ad Soyad',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Ad soyad gerekli' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: 'Telefon Numarası',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      hintText: '05XX XXX XX XX',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Telefon numarası gerekli';
                      }
                      final digits = v.replaceAll(RegExp(r'[^\d]'), '');
                      if (digits.length < 10) {
                        return 'Geçerli bir telefon numarası girin';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Yakınlık',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _relationships.map((rel) {
                      final isSelected = selectedRelationship == rel;
                      return ChoiceChip(
                        label: Text(rel),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setSheetState(() => selectedRelationship = rel);
                          }
                        },
                        selectedColor: AppColors.secondary.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppColors.secondary
                              : AppColors.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          final contact = EmergencyContact(
                            name: nameController.text.trim(),
                            phone: phoneController.text.trim(),
                            relationship: selectedRelationship,
                          );
                          Navigator.pop(ctx);
                          _addContact(contact);
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Kişi Ekle'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Acil Durum Kişileri'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
              ? _buildEmptyState()
              : _buildContactList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddContactSheet,
        backgroundColor: AppColors.error,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text(
          'Kişi Ekle',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.emergency_outlined,
                size: 50,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Henüz acil durum kişisi eklenmedi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'SOS butonuna bastığınızda bu kişilere\notomatik acil durum mesajı gönderilir',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _contacts.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return _buildInfoCard();
        final contact = _contacts[index - 1];
        return _buildContactCard(contact);
      },
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'SOS butonuna bastığınızda bu kişilere WhatsApp üzerinden konum bilgileriniz gönderilir.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(EmergencyContact contact) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.person, color: AppColors.secondary, size: 24),
        ),
        title: Text(
          contact.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(contact.phone,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            if (contact.relationship != null)
              Text(
                contact.relationship!,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: AppColors.error),
          onPressed: () => _removeContact(contact.phone),
        ),
      ),
    );
  }
}
