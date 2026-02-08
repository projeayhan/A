import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/communication_service.dart';
import '../../core/utils/app_dialogs.dart';

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
    } else if (mounted) {
      await AppDialogs.showError(context, 'Kişi eklenemedi');
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

  void _showAddContactSheet(bool isDark) {
    if (_contacts.length >= 5) {
      AppDialogs.showError(context, 'En fazla 5 acil durum kişisi ekleyebilirsiniz');
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
            color: isDark ? AppColors.surfaceDark : Colors.white,
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
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
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
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Name field
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

                  // Phone field
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

                  // Relationship selector
                  Text(
                    'Yakınlık',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.grey[700],
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
                            setSheetState(
                                () => selectedRelationship = rel);
                          }
                        },
                        selectedColor:
                            const Color(0xFFEF4444).withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? const Color(0xFFEF4444)
                              : (isDark ? Colors.white70 : Colors.grey[700]),
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Add button
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
                        backgroundColor: const Color(0xFFEF4444),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
              ),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              size: 16,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Acil Durum Kişileri',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
              ? _buildEmptyState(isDark)
              : _buildContactList(isDark),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddContactSheet(isDark),
        backgroundColor: const Color(0xFFEF4444),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text(
          'Kişi Ekle',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emergency_outlined,
                size: 60,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Henüz acil durum kişisi eklenmedi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'SOS butonuna bastığınızda bu kişilere\notomatik acil durum mesajı gönderilir',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: _contacts.length + 1, // +1 for info card
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildInfoCard(isDark);
        }
        final contact = _contacts[index - 1];
        return _buildContactCard(contact, isDark);
      },
    );
  }

  Widget _buildInfoCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFEF4444), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'SOS butonuna bastığınızda bu kişilere WhatsApp üzerinden konum ve sürücü bilgileriniz gönderilir.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.grey[700],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(EmergencyContact contact, bool isDark) {
    IconData relIcon;
    Color relColor;

    switch (contact.relationship) {
      case 'Anne':
      case 'Baba':
        relIcon = Icons.family_restroom;
        relColor = const Color(0xFF3B82F6);
        break;
      case 'Eş':
        relIcon = Icons.favorite;
        relColor = const Color(0xFFEC4899);
        break;
      case 'Kardeş':
        relIcon = Icons.people;
        relColor = const Color(0xFF8B5CF6);
        break;
      case 'Arkadaş':
        relIcon = Icons.person;
        relColor = const Color(0xFF10B981);
        break;
      default:
        relIcon = Icons.person_outline;
        relColor = const Color(0xFF6B7280);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: relColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(relIcon, color: relColor, size: 24),
        ),
        title: Text(
          contact.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              contact.phone,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            if (contact.relationship != null)
              Text(
                contact.relationship!,
                style: TextStyle(
                  fontSize: 12,
                  color: relColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: Colors.red[300]),
          onPressed: () => _removeContact(contact.phone),
        ),
      ),
    );
  }
}
