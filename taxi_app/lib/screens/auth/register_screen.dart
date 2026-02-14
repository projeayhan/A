import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentPage = 0;

  // Personal Info
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _tcNoController = TextEditingController();

  // Vehicle Info
  final _vehicleBrandController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  final _vehicleYearController = TextEditingController();
  String _selectedVehicleType = 'standard';

  bool _obscurePassword = true;
  bool _isLoading = false;

  final Map<String, Map<String, String>> _vehicleTypes = {
    'standard': {
      'label': 'Standart',
      'description': '4 kişilik sedan araçlar (Corolla, Civic vb.)',
      'icon': '🚗',
    },
    'comfort': {
      'label': 'Konfor',
      'description': 'Premium markalar (Mercedes, BMW, Audi)',
      'icon': '🚘',
    },
    'xl': {
      'label': 'XL',
      'description': '6+ kişilik araçlar, minibüsler',
      'icon': '🚐',
    },
  };

  @override
  void dispose() {
    _pageController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _tcNoController.dispose();
    _vehicleBrandController.dispose();
    _vehicleModelController.dispose();
    _vehiclePlateController.dispose();
    _vehicleColorController.dispose();
    _vehicleYearController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage == 0) {
      // Validate first page
      if (_fullNameController.text.isEmpty ||
          _emailController.text.isEmpty ||
          _phoneController.text.isEmpty ||
          _passwordController.text.isEmpty ||
          _tcNoController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lütfen tüm alanları doldurun'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final year = int.tryParse(_vehicleYearController.text) ?? DateTime.now().year;

    final success = await ref.read(authProvider.notifier).signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _fullNameController.text.trim(),
          phone: _phoneController.text.trim(),
          tcNo: _tcNoController.text.trim(),
          vehicleBrand: _vehicleBrandController.text.trim(),
          vehicleModel: _vehicleModelController.text.trim(),
          vehiclePlate: _vehiclePlateController.text.trim().toUpperCase(),
          vehicleColor: _vehicleColorController.text.trim(),
          vehicleYear: year,
          vehicleType: _selectedVehicleType,
        );

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kayıt başarılı! E-posta adresinize gelen doğrulama linkine tıklayın.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );
      context.go('/login');
    } else if (!success && mounted) {
      final error = ref.read(authProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Kayıt başarısız'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Sürücü Kaydı'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentPage > 0) {
              _previousPage();
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Progress Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  _buildStepIndicator(0, 'Kişisel'),
                  Expanded(
                    child: Container(
                      height: 2,
                      color: _currentPage >= 1 ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  _buildStepIndicator(1, 'Araç'),
                ],
              ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildPersonalInfoPage(),
                  _buildVehicleInfoPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isActive = _currentPage >= step;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.surface,
            border: Border.all(
              color: isActive ? AppColors.primary : AppColors.border,
              width: 2,
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isActive && _currentPage > step
                ? Icon(Icons.check, size: 18, color: AppColors.secondary)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isActive ? AppColors.secondary : AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Kişisel Bilgiler',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Lütfen kişisel bilgilerinizi girin',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          TextFormField(
            controller: _fullNameController,
            decoration: const InputDecoration(
              labelText: 'Ad Soyad',
              prefixIcon: Icon(Icons.person_outline),
            ),
            textCapitalization: TextCapitalization.words,
            validator: (value) => value?.isEmpty ?? true ? 'Ad soyad gerekli' : null,
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'E-posta',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              if (value?.isEmpty ?? true) return 'E-posta gerekli';
              if (!value!.contains('@')) return 'Geçerli e-posta girin';
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Telefon',
              prefixIcon: Icon(Icons.phone_outlined),
              hintText: '5XX XXX XX XX',
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Telefon gerekli' : null,
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _tcNoController,
            keyboardType: TextInputType.number,
            maxLength: 11,
            decoration: const InputDecoration(
              labelText: 'TC Kimlik No',
              prefixIcon: Icon(Icons.badge_outlined),
              counterText: '',
            ),
            validator: (value) {
              if (value?.isEmpty ?? true) return 'TC Kimlik No gerekli';
              if (value!.length != 11) return 'TC Kimlik No 11 haneli olmalı';
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Şifre',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) {
              if (value?.isEmpty ?? true) return 'Şifre gerekli';
              if (value!.length < 6) return 'En az 6 karakter';
              return null;
            },
          ),
          const SizedBox(height: 32),

          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _nextPage,
              child: const Text('Devam Et'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Araç Bilgileri',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Aracınız hakkında bilgi girin',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          // Vehicle Type Selection
          Text(
            'Araç Kategorisi',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          ..._vehicleTypes.entries.map((entry) => _buildVehicleTypeOption(
            entry.key,
            entry.value['label']!,
            entry.value['description']!,
            entry.value['icon']!,
          )),

          // Warning Message
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 24),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Hatalı kategori beyanı; ücret iadesi, hesap askıya alma ve kalıcı üyelik iptali yaptırımlarına tabidir.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.warning.withValues(alpha: 0.9),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          TextFormField(
            controller: _vehicleBrandController,
            decoration: const InputDecoration(
              labelText: 'Araç Markası',
              prefixIcon: Icon(Icons.directions_car_outlined),
              hintText: 'Örn: Toyota',
            ),
            textCapitalization: TextCapitalization.words,
            validator: (value) => value?.isEmpty ?? true ? 'Marka gerekli' : null,
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _vehicleModelController,
            decoration: const InputDecoration(
              labelText: 'Model',
              prefixIcon: Icon(Icons.car_rental_outlined),
              hintText: 'Örn: Corolla',
            ),
            textCapitalization: TextCapitalization.words,
            validator: (value) => value?.isEmpty ?? true ? 'Model gerekli' : null,
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _vehicleYearController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: const InputDecoration(
                    labelText: 'Model Yılı',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                    counterText: '',
                    hintText: '2020',
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Yıl gerekli';
                    final year = int.tryParse(value!);
                    if (year == null || year < 2000 || year > DateTime.now().year + 1) {
                      return 'Geçerli yıl girin';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _vehicleColorController,
                  decoration: const InputDecoration(
                    labelText: 'Renk',
                    prefixIcon: Icon(Icons.palette_outlined),
                    hintText: 'Sarı',
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => value?.isEmpty ?? true ? 'Renk gerekli' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _vehiclePlateController,
            decoration: const InputDecoration(
              labelText: 'Plaka',
              prefixIcon: Icon(Icons.pin_outlined),
              hintText: '34 ABC 123',
            ),
            textCapitalization: TextCapitalization.characters,
            validator: (value) => value?.isEmpty ?? true ? 'Plaka gerekli' : null,
          ),
          const SizedBox(height: 32),

          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleRegister,
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.secondary,
                      ),
                    )
                  : const Text('Başvuru Gönder'),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Başvurunuz onaylandıktan sonra sürüş yapmaya başlayabilirsiniz.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleTypeOption(String value, String label, String description, String icon) {
    final isSelected = _selectedVehicleType == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedVehicleType = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: AppColors.primary, size: 24),
          ],
        ),
      ),
    );
  }
}
