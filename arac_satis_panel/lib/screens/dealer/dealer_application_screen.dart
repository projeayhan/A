import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/car_models.dart';
import '../../services/dealer_service.dart';

class DealerApplicationScreen extends ConsumerStatefulWidget {
  const DealerApplicationScreen({super.key});

  @override
  ConsumerState<DealerApplicationScreen> createState() => _DealerApplicationScreenState();
}

class _DealerApplicationScreenState extends ConsumerState<DealerApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ownerNameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _addressController = TextEditingController();

  DealerType _selectedDealerType = DealerType.individual;
  String? _selectedCity;
  String? _selectedDistrict;
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _cities = [
    'İstanbul', 'Ankara', 'İzmir', 'Bursa', 'Antalya', 'Adana', 'Konya',
    'Gaziantep', 'Mersin', 'Kayseri', 'Eskişehir', 'Diyarbakır', 'Samsun',
    'Denizli', 'Şanlıurfa', 'Malatya', 'Trabzon', 'Erzurum', 'Van', 'Batman',
  ];

  @override
  void dispose() {
    _ownerNameController.dispose();
    _businessNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _taxNumberController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCity == null) {
      setState(() => _errorMessage = 'Lütfen şehir seçin');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = DealerService();
      await service.submitApplication(
        ownerName: _ownerNameController.text.trim(),
        phone: _phoneController.text.trim(),
        city: _selectedCity!,
        dealerType: _selectedDealerType,
        businessName: _businessNameController.text.trim().isEmpty
            ? null
            : _businessNameController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        taxNumber: _taxNumberController.text.trim().isEmpty
            ? null
            : _taxNumberController.text.trim(),
        district: _selectedDistrict,
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
      );

      if (!mounted) return;
      _showSuccessDialog();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: CarSalesColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle, color: CarSalesColors.success),
            ),
            const SizedBox(width: 12),
            const Text('Başvuru Gönderildi'),
          ],
        ),
        content: const Text(
          'Başvurunuz başarıyla alındı. En kısa sürede incelenecek ve size bilgi verilecektir.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/login');
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CarSalesColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Satıcı Başvurusu'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const Text(
                    'Satıcı Ol',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: CarSalesColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Araç satışına başlamak için bilgilerinizi doldurun',
                    style: TextStyle(
                      fontSize: 16,
                      color: CarSalesColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Satıcı Tipi
                  const Text(
                    'Satıcı Tipi',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: CarSalesColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: DealerType.values.map((type) {
                      final isSelected = _selectedDealerType == type;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedDealerType = type),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? CarSalesColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? CarSalesColors.primary : CarSalesColors.borderLight,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                type == DealerType.individual
                                    ? Icons.person
                                    : type == DealerType.dealer
                                        ? Icons.store
                                        : Icons.verified,
                                color: isSelected ? Colors.white : CarSalesColors.textSecondaryLight,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                type.label,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : CarSalesColors.textPrimaryLight,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Ad Soyad
                  TextFormField(
                    controller: _ownerNameController,
                    decoration: const InputDecoration(
                      labelText: 'Ad Soyad *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ad soyad gerekli';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // İşletme Adı (opsiyonel)
                  if (_selectedDealerType != DealerType.individual) ...[
                    TextFormField(
                      controller: _businessNameController,
                      decoration: const InputDecoration(
                        labelText: 'İşletme / Galeri Adı',
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Telefon
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Telefon *',
                      prefixIcon: Icon(Icons.phone_outlined),
                      hintText: '05XX XXX XX XX',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Telefon gerekli';
                      }
                      if (value.length < 10) {
                        return 'Geçerli bir telefon numarası girin';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // E-posta
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-posta',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Vergi No (opsiyonel)
                  if (_selectedDealerType != DealerType.individual) ...[
                    TextFormField(
                      controller: _taxNumberController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Vergi Numarası',
                        prefixIcon: Icon(Icons.receipt_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Şehir
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCity,
                    decoration: const InputDecoration(
                      labelText: 'Şehir *',
                      prefixIcon: Icon(Icons.location_city_outlined),
                    ),
                    items: _cities
                        .map((city) => DropdownMenuItem(
                              value: city,
                              child: Text(city),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCity = value;
                        _selectedDistrict = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Adres
                  TextFormField(
                    controller: _addressController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Adres',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Hata mesajı
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: CarSalesColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: CarSalesColors.accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: CarSalesColors.accent),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Gönder butonu
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSubmit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Başvuruyu Gönder'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
