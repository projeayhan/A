import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/jobs/job_models.dart';
import '../../models/jobs/job_data_models.dart';
import '../../services/jobs_service.dart';
import '../../core/utils/app_dialogs.dart';

class AddJobListingScreen extends StatefulWidget {
  final JobListingData? editingListing;

  const AddJobListingScreen({super.key, this.editingListing});

  @override
  State<AddJobListingScreen> createState() => _AddJobListingScreenState();
}

class _AddJobListingScreenState extends State<AddJobListingScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _progressController;
  late AnimationController _stepAnimationController;

  int _currentStep = 0;
  final int _totalSteps = 5;

  // Form Controllers
  final _formKey = GlobalKey<FormState>();

  // Step 1: Basic Info
  final _titleController = TextEditingController();
  JobCategory? _selectedCategory;
  String? _selectedSubcategory;
  JobType? _selectedJobType;
  WorkArrangement? _selectedWorkArrangement;

  // Step 2: Requirements
  ExperienceLevel? _selectedExperienceLevel;
  EducationLevel? _selectedEducationLevel;
  final List<String> _manualSkills = []; // Manuel girilen yetenekler
  final _skillInputController = TextEditingController();

  // Step 3: Location & Salary
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _addressController = TextEditingController();
  final _minSalaryController = TextEditingController();
  final _maxSalaryController = TextEditingController();
  SalaryPeriod _salaryPeriod = SalaryPeriod.monthly;
  bool _isSalaryHidden = false;
  bool _isSalaryNegotiable = false;

  // Step 4: Benefits
  final List<String> _manualBenefits = []; // Manuel girilen yan haklar
  final _benefitInputController = TextEditingController();

  // Step 5: Description
  final _descriptionController = TextEditingController();
  final _responsibilitiesController = TextEditingController();
  final _qualificationsController = TextEditingController();
  int _positions = 1;
  DateTime? _deadline;

  // Submission state
  bool _isSubmitting = false;

  // Düzenleme modu
  bool get _isEditMode => widget.editingListing != null;
  String? get _editingListingId => widget.editingListing?.id;

  // Database data
  bool _isLoadingData = true;
  List<JobCategoryData> _dbCategories = [];
  JobCategoryData? _selectedDbCategory;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _stepAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _stepAnimationController.forward();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final jobsService = JobsService.instance;
      final categories = await jobsService.getCategories();

      if (mounted) {
        setState(() {
          _dbCategories = categories;
        });

        // Düzenleme modundaysa mevcut verileri doldur
        if (_isEditMode) {
          await _populateEditingData();
        }

        if (mounted) {
          setState(() => _isLoadingData = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        _showError('Veriler yüklenirken hata oluştu');
      }
    }
  }

  Future<void> _populateEditingData() async {
    final listing = widget.editingListing;
    if (listing == null) return;

    setState(() {
      // Step 1: Basic Info
      _titleController.text = listing.title;
      _selectedDbCategory = _dbCategories.firstWhere(
        (c) => c.id == listing.categoryId,
        orElse: () => _dbCategories.first,
      );
      _selectedSubcategory = listing.subcategory;

      // Job type mapping
      _selectedJobType = JobType.values.firstWhere(
        (t) => t.name == listing.jobType || t.toString().split('.').last == listing.jobType,
        orElse: () => JobType.fullTime,
      );

      // Work arrangement mapping
      _selectedWorkArrangement = WorkArrangement.values.firstWhere(
        (w) => w.name == listing.workArrangement || w.toString().split('.').last == listing.workArrangement,
        orElse: () => WorkArrangement.onsite,
      );

      // Step 2: Requirements
      _selectedExperienceLevel = ExperienceLevel.values.firstWhere(
        (e) => e.name == listing.experienceLevel || e.toString().split('.').last == listing.experienceLevel,
        orElse: () => ExperienceLevel.midLevel,
      );

      _selectedEducationLevel = EducationLevel.values.firstWhere(
        (e) => e.name == listing.educationLevel || e.toString().split('.').last == listing.educationLevel,
        orElse: () => EducationLevel.noRequirement,
      );

      // Step 3: Location & Salary
      _cityController.text = listing.city;
      _districtController.text = listing.district ?? '';
      _addressController.text = listing.address ?? '';

      if (listing.salaryMin != null) {
        _minSalaryController.text = listing.salaryMin!.toStringAsFixed(0);
      }
      if (listing.salaryMax != null) {
        _maxSalaryController.text = listing.salaryMax!.toStringAsFixed(0);
      }

      _salaryPeriod = SalaryPeriod.values.firstWhere(
        (p) => p.name == listing.salaryPeriod || p.toString().split('.').last == listing.salaryPeriod,
        orElse: () => SalaryPeriod.monthly,
      );
      _isSalaryHidden = listing.isSalaryHidden;
      _isSalaryNegotiable = listing.isSalaryNegotiable;

      // Step 2: Required Skills
      _manualSkills.clear();
      _manualSkills.addAll(listing.requiredSkills);

      // Step 5: Description
      _descriptionController.text = listing.description;
      _responsibilitiesController.text = listing.responsibilities.join('\n');
      _qualificationsController.text = listing.qualifications.join('\n');
      _positions = listing.positions;
      _deadline = listing.deadline;
    });

    // Manuel benefits'leri yükle
    setState(() {
      _manualBenefits.clear();
      _manualBenefits.addAll(listing.manualBenefits);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    _stepAnimationController.dispose();
    _titleController.dispose();
    _skillInputController.dispose();
    _benefitInputController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _addressController.dispose();
    _minSalaryController.dispose();
    _maxSalaryController.dispose();
    _descriptionController.dispose();
    _responsibilitiesController.dispose();
    _qualificationsController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _stepAnimationController.reverse().then((_) {
        setState(() => _currentStep++);
        _pageController.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
        );
        _stepAnimationController.forward();
      });
    } else {
      _submitListing();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _stepAnimationController.reverse().then((_) {
        setState(() => _currentStep--);
        _pageController.previousPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
        );
        _stepAnimationController.forward();
      });
    }
  }

  // Convert camelCase enum name to snake_case for database
  String _toSnakeCase(String input) {
    return input.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    );
  }

  // Convert text to list (split by newlines, filter empty lines)
  List<String> _textToList(String text) {
    final lines = text.split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    // If no newlines, return as single-item list
    return lines.isEmpty ? [text] : lines;
  }

  Future<void> _submitListing() async {
    // Validate required fields
    if (_titleController.text.isEmpty) {
      _showError('İlan başlığı zorunludur');
      return;
    }
    if (_selectedDbCategory == null && _selectedCategory == null) {
      _showError('Kategori seçimi zorunludur');
      return;
    }
    if (_selectedJobType == null) {
      _showError('Çalışma şekli seçimi zorunludur');
      return;
    }
    if (_descriptionController.text.isEmpty) {
      _showError('İlan açıklaması zorunludur');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final jobsService = JobsService.instance;

      // Build listing data - use database category if available
      final categoryId = _selectedDbCategory?.id ?? _selectedCategory?.id;
      final data = <String, dynamic>{
        'title': _titleController.text.trim(),
        'category_id': categoryId,
        'subcategory': _selectedSubcategory,
        'job_type': _toSnakeCase(_selectedJobType!.name),
        'work_arrangement': _selectedWorkArrangement != null ? _toSnakeCase(_selectedWorkArrangement!.name) : null,
        'experience_level': _selectedExperienceLevel != null ? _toSnakeCase(_selectedExperienceLevel!.name) : null,
        'education_level': _selectedEducationLevel != null ? _toSnakeCase(_selectedEducationLevel!.name) : null,
        'city': _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : null,
        'district': _districtController.text.trim().isNotEmpty ? _districtController.text.trim() : null,
        'address': _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
        'salary_min': double.tryParse(_minSalaryController.text),
        'salary_max': double.tryParse(_maxSalaryController.text),
        'salary_period': _toSnakeCase(_salaryPeriod.name),
        'is_salary_hidden': _isSalaryHidden,
        'is_salary_negotiable': _isSalaryNegotiable,
        'description': _descriptionController.text.trim(),
        'responsibilities': _responsibilitiesController.text.trim().isNotEmpty
            ? _textToList(_responsibilitiesController.text.trim())
            : null,
        'qualifications': _qualificationsController.text.trim().isNotEmpty
            ? _textToList(_qualificationsController.text.trim())
            : null,
        'positions': _positions,
        'deadline': _deadline?.toIso8601String(),
        'required_skills': _manualSkills.isNotEmpty ? _manualSkills : null,
        'manual_benefits': _manualBenefits.isNotEmpty ? _manualBenefits : null,
      };

      String listingId;

      if (_isEditMode) {
        // Düzenleme modu: mevcut ilanı güncelle
        data['status'] = 'pending'; // Tekrar moderasyona gönder
        final success = await jobsService.updateListing(_editingListingId!, data);

        if (!success) {
          _showError('İlan güncellenirken bir hata oluştu');
          setState(() => _isSubmitting = false);
          return;
        }
        listingId = _editingListingId!;

        // Mevcut skill ve benefit'leri temizle ve yeniden kaydet
        // (basitlik için her zaman yeniden kaydediyoruz)
      } else {
        // Yeni ilan oluştur
        final listing = await jobsService.createListing(data);

        if (listing == null) {
          _showError('İlan oluşturulurken bir hata oluştu');
          setState(() => _isSubmitting = false);
          return;
        }
        listingId = listing.id;
      }

      // Moderasyonu çağır ve sonucu bekle
      final moderationResult = await jobsService.moderateListing(listingId);

      setState(() => _isSubmitting = false);

      // Sonuca göre dialog göster
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => _buildModerationResultDialog(
            dialogContext,
            moderationResult,
            isEdit: _isEditMode,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showError('Bir hata oluştu: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    AppDialogs.showError(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: JobsColors.background(isDark),
        body: SafeArea(
          child: _isLoadingData
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    _buildHeader(isDark),
                    _buildProgressIndicator(isDark),
                    Expanded(
                      child: Form(
                        key: _formKey,
                        child: PageView(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildStep1BasicInfo(isDark),
                            _buildStep2Requirements(isDark),
                            _buildStep3LocationSalary(isDark),
                            _buildStep4Benefits(isDark),
                            _buildStep5Description(isDark),
                          ],
                        ),
                      ),
                    ),
                    _buildBottomNavigation(isDark),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final stepTitles = [
      'Temel Bilgiler',
      'Gereksinimler',
      'Konum & Maaş',
      'Yan Haklar',
      'Açıklama',
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: JobsColors.surface(isDark),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.close,
                color: JobsColors.textPrimary(isDark),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditMode ? 'İlanı Düzenle' : 'Yeni İş İlanı',
                  style: TextStyle(
                    color: JobsColors.textPrimary(isDark),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stepTitles[_currentStep],
                  style: TextStyle(
                    color: JobsColors.textSecondary(isDark),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: JobsColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_currentStep + 1}/$_totalSteps',
              style: const TextStyle(
                color: JobsColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(_totalSteps, (index) {
          final isCompleted = index < _currentStep;
          final isActive = index == _currentStep;

          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 8 : 0),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 4,
                    decoration: BoxDecoration(
                      color: isCompleted || isActive
                          ? JobsColors.primary
                          : JobsColors.border(isDark),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? JobsColors.success
                          : isActive
                              ? JobsColors.primary
                              : JobsColors.surface(isDark),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCompleted || isActive
                            ? Colors.transparent
                            : JobsColors.border(isDark),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: isActive
                                    ? Colors.white
                                    : JobsColors.textSecondary(isDark),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStep1BasicInfo(bool isDark) {
    return FadeTransition(
      opacity: _stepAnimationController,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _stepAnimationController,
          curve: Curves.easeOutCubic,
        )),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(isDark, 'İlan Başlığı', true),
              const SizedBox(height: 12),
              _buildTextField(
                isDark,
                'Örn: Senior Flutter Developer',
                controller: _titleController,
              ),
              const SizedBox(height: 24),

              _buildSectionTitle(isDark, 'Kategori', true),
              const SizedBox(height: 12),
              _buildCategorySelector(isDark),
              const SizedBox(height: 24),

              if (_selectedCategory != null && _selectedCategory!.subcategories.isNotEmpty) ...[
                _buildSectionTitle(isDark, 'Alt Kategori', false),
                const SizedBox(height: 12),
                _buildSubcategorySelector(isDark),
                const SizedBox(height: 24),
              ],

              _buildSectionTitle(isDark, 'Çalışma Şekli', true),
              const SizedBox(height: 12),
              _buildJobTypeSelector(isDark),
              const SizedBox(height: 24),

              _buildSectionTitle(isDark, 'Çalışma Modeli', true),
              const SizedBox(height: 12),
              _buildWorkArrangementSelector(isDark),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep2Requirements(bool isDark) {
    return FadeTransition(
      opacity: _stepAnimationController,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(isDark, 'Deneyim Seviyesi', true),
            const SizedBox(height: 12),
            _buildExperienceLevelSelector(isDark),
            const SizedBox(height: 24),

            _buildSectionTitle(isDark, 'Eğitim Seviyesi', true),
            const SizedBox(height: 12),
            _buildEducationLevelSelector(isDark),
            const SizedBox(height: 24),

            _buildSectionTitle(isDark, 'Gerekli Yetenekler', true),
            const SizedBox(height: 12),
            _buildSkillsSelector(isDark),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3LocationSalary(bool isDark) {
    return FadeTransition(
      opacity: _stepAnimationController,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(isDark, 'Şehir', true),
            const SizedBox(height: 12),
            _buildTextField(isDark, 'Örn: İstanbul', controller: _cityController),
            const SizedBox(height: 24),

            _buildSectionTitle(isDark, 'İlçe', false),
            const SizedBox(height: 12),
            _buildTextField(isDark, 'Örn: Maslak', controller: _districtController),
            const SizedBox(height: 24),

            _buildSectionTitle(isDark, 'Adres', false),
            const SizedBox(height: 12),
            _buildTextField(isDark, 'Tam adres (opsiyonel)', controller: _addressController, maxLines: 2),
            const SizedBox(height: 24),

            _buildSectionTitle(isDark, 'Maaş Aralığı', false),
            const SizedBox(height: 12),
            _buildSalaryInputs(isDark),
            const SizedBox(height: 16),
            _buildSalaryOptions(isDark),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStep4Benefits(bool isDark) {
    return FadeTransition(
      opacity: _stepAnimationController,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sunulan yan hakları girin',
              style: TextStyle(
                color: JobsColors.textSecondary(isDark),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),

            // Yan hak sayısı badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: JobsColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_manualBenefits.length} yan hak eklendi',
                style: const TextStyle(
                  color: JobsColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Input alanı ve ekleme butonu
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: JobsColors.surface(isDark),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: JobsColors.border(isDark)),
                    ),
                    child: TextField(
                      controller: _benefitInputController,
                      style: TextStyle(color: JobsColors.textPrimary(isDark)),
                      decoration: InputDecoration(
                        hintText: 'Yan hak girin (örn: Yemek kartı, Servis)',
                        hintStyle: TextStyle(color: JobsColors.textTertiary(isDark)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      onSubmitted: (_) => _addBenefit(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _addBenefit,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: JobsColors.primaryGradient,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Eklenen yan haklar
            if (_manualBenefits.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _manualBenefits.map((benefit) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: JobsColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: JobsColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.card_giftcard,
                          size: 16,
                          color: JobsColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          benefit,
                          style: TextStyle(
                            color: JobsColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() => _manualBenefits.remove(benefit));
                            HapticFeedback.lightImpact();
                          },
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: JobsColors.primary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

            if (_manualBenefits.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: JobsColors.surface(isDark),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: JobsColors.border(isDark),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: JobsColors.textTertiary(isDark),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Sunduğunuz yan hakları ekleyin (örn: SGK, Yemek, Prim)',
                        style: TextStyle(
                          color: JobsColors.textTertiary(isDark),
                          fontSize: 13,
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
    );
  }

  void _addBenefit() {
    final benefit = _benefitInputController.text.trim();
    if (benefit.isNotEmpty && !_manualBenefits.contains(benefit)) {
      setState(() {
        _manualBenefits.add(benefit);
        _benefitInputController.clear();
      });
      HapticFeedback.selectionClick();
    }
  }

  Widget _buildStep5Description(bool isDark) {
    return FadeTransition(
      opacity: _stepAnimationController,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(isDark, 'İlan Açıklaması', true),
            const SizedBox(height: 12),
            _buildTextField(
              isDark,
              'Pozisyon hakkında detaylı bilgi verin...',
              controller: _descriptionController,
              maxLines: 6,
            ),
            const SizedBox(height: 24),

            _buildSectionTitle(isDark, 'Sorumluluklar', false),
            const SizedBox(height: 12),
            _buildTextField(
              isDark,
              'Her satıra bir sorumluluk yazın...',
              controller: _responsibilitiesController,
              maxLines: 4,
            ),
            const SizedBox(height: 24),

            _buildSectionTitle(isDark, 'Aranan Nitelikler', false),
            const SizedBox(height: 12),
            _buildTextField(
              isDark,
              'Her satıra bir nitelik yazın...',
              controller: _qualificationsController,
              maxLines: 4,
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(isDark, 'Açık Pozisyon Sayısı', false),
                      const SizedBox(height: 12),
                      _buildPositionCounter(isDark),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(isDark, 'Son Başvuru Tarihi', false),
                      const SizedBox(height: 12),
                      _buildDeadlinePicker(isDark),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation(bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: 16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: JobsColors.card(isDark),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: GestureDetector(
                onTap: _previousStep,
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    border: Border.all(color: JobsColors.border(isDark)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_back,
                          color: JobsColors.textSecondary(isDark),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Geri',
                          style: TextStyle(
                            color: JobsColors.textSecondary(isDark),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: _currentStep == 0 ? 1 : 2,
            child: GestureDetector(
              onTap: _isSubmitting ? null : _nextStep,
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isSubmitting
                        ? [Colors.grey, Colors.grey]
                        : JobsColors.primaryGradient,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _isSubmitting
                      ? null
                      : [
                          BoxShadow(
                            color: JobsColors.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Center(
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currentStep == _totalSteps - 1
                                  ? (_isEditMode ? 'İlanı Güncelle' : 'İlanı Yayınla')
                                  : 'Devam Et',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _currentStep == _totalSteps - 1
                                  ? (_isEditMode ? Icons.save : Icons.publish)
                                  : Icons.arrow_forward,
                              color: Colors.white,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widgets
  Widget _buildSectionTitle(bool isDark, String title, bool isRequired) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: JobsColors.textPrimary(isDark),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (isRequired)
          const Text(
            ' *',
            style: TextStyle(
              color: JobsColors.accent,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  Widget _buildTextField(
    bool isDark,
    String hint, {
    TextEditingController? controller,
    Function(String)? onChanged,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: JobsColors.surface(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: JobsColors.border(isDark)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(
          color: JobsColors.textPrimary(isDark),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: JobsColors.textTertiary(isDark),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          suffixText: suffix,
          suffixStyle: TextStyle(
            color: JobsColors.textSecondary(isDark),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector(bool isDark) {
    // Use database categories if available, otherwise fall back to hardcoded
    if (_dbCategories.isNotEmpty) {
      return SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _dbCategories.length,
          itemBuilder: (context, index) {
            final category = _dbCategories[index];
            final isSelected = _selectedDbCategory?.id == category.id;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDbCategory = category;
                  _selectedCategory = null;
                  _selectedSubcategory = null;
                });
                HapticFeedback.selectionClick();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 90,
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? category.colorValue
                      : JobsColors.card(isDark),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? category.colorValue
                        : JobsColors.border(isDark),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      category.iconData,
                      size: 28,
                      color: isSelected
                          ? Colors.white
                          : category.colorValue,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      category.name,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : JobsColors.textPrimary(isDark),
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    // Fallback to hardcoded categories
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: JobCategory.allCategories.length,
        itemBuilder: (context, index) {
          final category = JobCategory.allCategories[index];
          final isSelected = _selectedCategory?.id == category.id;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = category;
                _selectedDbCategory = null;
                _selectedSubcategory = null;
              });
              HapticFeedback.selectionClick();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 90,
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? category.color
                    : JobsColors.card(isDark),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? category.color
                      : JobsColors.border(isDark),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    category.icon,
                    size: 28,
                    color: isSelected
                        ? Colors.white
                        : category.color,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    category.name,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : JobsColors.textPrimary(isDark),
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubcategorySelector(bool isDark) {
    if (_selectedCategory == null) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _selectedCategory!.subcategories.map((sub) {
        final isSelected = _selectedSubcategory == sub;
        return GestureDetector(
          onTap: () {
            setState(() => _selectedSubcategory = sub);
            HapticFeedback.selectionClick();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? JobsColors.primary
                  : JobsColors.card(isDark),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? JobsColors.primary
                    : JobsColors.border(isDark),
              ),
            ),
            child: Text(
              sub,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : JobsColors.textPrimary(isDark),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildJobTypeSelector(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: JobType.values.map((type) {
        final isSelected = _selectedJobType == type;
        return GestureDetector(
          onTap: () {
            setState(() => _selectedJobType = type);
            HapticFeedback.selectionClick();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? type.color : JobsColors.card(isDark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? type.color : JobsColors.border(isDark),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  type.icon,
                  size: 18,
                  color: isSelected
                      ? Colors.white
                      : JobsColors.textSecondary(isDark),
                ),
                const SizedBox(width: 8),
                Text(
                  type.label,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : JobsColors.textPrimary(isDark),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWorkArrangementSelector(bool isDark) {
    return Row(
      children: WorkArrangement.values.map((type) {
        final isSelected = _selectedWorkArrangement == type;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedWorkArrangement = type);
              HapticFeedback.selectionClick();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(
                right: type != WorkArrangement.values.last ? 12 : 0,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? type.color
                    : JobsColors.card(isDark),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? type.color
                      : JobsColors.border(isDark),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    type.icon,
                    size: 28,
                    color: isSelected
                        ? Colors.white
                        : type.color,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    type.label,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : JobsColors.textPrimary(isDark),
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExperienceLevelSelector(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ExperienceLevel.values.map((level) {
        final isSelected = _selectedExperienceLevel == level;
        return GestureDetector(
          onTap: () {
            setState(() => _selectedExperienceLevel = level);
            HapticFeedback.selectionClick();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? JobsColors.primary
                  : JobsColors.card(isDark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? JobsColors.primary
                    : JobsColors.border(isDark),
              ),
            ),
            child: Column(
              children: [
                Text(
                  level.label,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : JobsColors.textPrimary(isDark),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                Text(
                  level.yearsRange,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.8)
                        : JobsColors.textTertiary(isDark),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEducationLevelSelector(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: EducationLevel.values.map((level) {
        final isSelected = _selectedEducationLevel == level;
        return GestureDetector(
          onTap: () {
            setState(() => _selectedEducationLevel = level);
            HapticFeedback.selectionClick();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? JobsColors.primary
                  : JobsColors.card(isDark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? JobsColors.primary
                    : JobsColors.border(isDark),
              ),
            ),
            child: Text(
              level.label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : JobsColors.textPrimary(isDark),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSkillsSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Yetenek sayısı badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: JobsColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${_manualSkills.length} yetenek eklendi',
            style: const TextStyle(
              color: JobsColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Input alanı ve ekleme butonu
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: JobsColors.surface(isDark),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: JobsColors.border(isDark)),
                ),
                child: TextField(
                  controller: _skillInputController,
                  style: TextStyle(color: JobsColors.textPrimary(isDark)),
                  decoration: InputDecoration(
                    hintText: 'Yetenek girin (örn: Flutter, Excel)',
                    hintStyle: TextStyle(color: JobsColors.textTertiary(isDark)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  onSubmitted: (_) => _addSkill(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _addSkill,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: JobsColors.primaryGradient,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Eklenen yetenekler
        if (_manualSkills.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _manualSkills.map((skill) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: JobsColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: JobsColors.secondary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      skill,
                      style: TextStyle(
                        color: JobsColors.secondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() => _manualSkills.remove(skill));
                        HapticFeedback.lightImpact();
                      },
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: JobsColors.secondary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

        if (_manualSkills.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: JobsColors.surface(isDark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: JobsColors.border(isDark),
                style: BorderStyle.solid,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: JobsColors.textTertiary(isDark),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pozisyon için gerekli yetenekleri ekleyin',
                  style: TextStyle(
                    color: JobsColors.textTertiary(isDark),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _addSkill() {
    final skill = _skillInputController.text.trim();
    if (skill.isNotEmpty && !_manualSkills.contains(skill)) {
      setState(() {
        _manualSkills.add(skill);
        _skillInputController.clear();
      });
      HapticFeedback.selectionClick();
    }
  }

  Widget _buildSalaryInputs(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildTextField(
            isDark,
            'Min',
            controller: _minSalaryController,
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTextField(
            isDark,
            'Max',
            controller: _maxSalaryController,
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: JobsColors.surface(isDark),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: JobsColors.border(isDark)),
          ),
          child: DropdownButton<SalaryPeriod>(
            value: _salaryPeriod,
            underline: const SizedBox(),
            dropdownColor: JobsColors.card(isDark),
            items: SalaryPeriod.values.map((period) {
              return DropdownMenuItem(
                value: period,
                child: Text(
                  period.label,
                  style: TextStyle(color: JobsColors.textPrimary(isDark)),
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _salaryPeriod = value);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSalaryOptions(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildCheckOption(
            isDark,
            'Maaşı Gizle',
            _isSalaryHidden,
            (value) => setState(() => _isSalaryHidden = value),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCheckOption(
            isDark,
            'Pazarlık Olur',
            _isSalaryNegotiable,
            (value) => setState(() => _isSalaryNegotiable = value),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckOption(
    bool isDark,
    String title,
    bool value,
    Function(bool) onChanged,
  ) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: value
              ? JobsColors.primary.withValues(alpha: 0.1)
              : JobsColors.card(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value
                ? JobsColors.primary
                : JobsColors.border(isDark),
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: value ? JobsColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: value
                      ? JobsColors.primary
                      : JobsColors.border(isDark),
                  width: 2,
                ),
              ),
              child: value
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 14,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: value
                      ? JobsColors.primary
                      : JobsColors.textPrimary(isDark),
                  fontWeight: value ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPositionCounter(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: JobsColors.card(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: JobsColors.border(isDark)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              if (_positions > 1) {
                setState(() => _positions--);
                HapticFeedback.selectionClick();
              }
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: JobsColors.surface(isDark),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.remove,
                color: _positions > 1
                    ? JobsColors.textPrimary(isDark)
                    : JobsColors.textTertiary(isDark),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Text(
            '$_positions',
            style: TextStyle(
              color: JobsColors.textPrimary(isDark),
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 20),
          GestureDetector(
            onTap: () {
              if (_positions < 100) {
                setState(() => _positions++);
                HapticFeedback.selectionClick();
              }
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: JobsColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeadlinePicker(bool isDark) {
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now().add(const Duration(days: 30)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (date != null) {
          setState(() => _deadline = date);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: JobsColors.card(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: JobsColors.border(isDark)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              color: JobsColors.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              _deadline != null
                  ? '${_deadline!.day}/${_deadline!.month}/${_deadline!.year}'
                  : 'Seç',
              style: TextStyle(
                color: JobsColors.textPrimary(isDark),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModerationResultDialog(BuildContext dialogContext, ModerationResult? result, {bool isEdit = false}) {
    final isDark = Theme.of(dialogContext).brightness == Brightness.dark;

    // Moderasyon sonucuna göre içerik belirle
    final isApproved = result?.result == 'approved';
    final isRejected = result?.result == 'rejected';
    final isPending = result == null || result.result == 'manual_review' || result.result == 'pending';

    // Renkler ve ikonlar
    Color primaryColor;
    IconData icon;
    String title;
    String message;
    List<Color> gradientColors;

    if (isApproved) {
      primaryColor = JobsColors.success;
      icon = Icons.check_circle;
      title = isEdit ? 'İlan Güncellendi!' : 'İlanınız Yayında!';
      message = isEdit
          ? 'Tebrikler! İş ilanınız başarıyla güncellendi ve yayına alındı.'
          : 'Tebrikler! İş ilanınız başarıyla onaylandı ve yayına alındı.';
      gradientColors = [const Color(0xFF10B981), const Color(0xFF059669)];
    } else if (isRejected) {
      primaryColor = JobsColors.error;
      icon = Icons.cancel;
      title = isEdit ? 'Güncelleme Reddedildi' : 'İlan Reddedildi';
      message = result?.reason ?? 'İlanınız politikalarımıza uygun bulunmadı.';
      gradientColors = [const Color(0xFFEF4444), const Color(0xFFDC2626)];
    } else {
      primaryColor = JobsColors.warning;
      icon = Icons.hourglass_top;
      title = 'İncelemeye Alındı';
      message = isEdit
          ? 'İlanınız güncellendi ve inceleme sürecine alındı. Kısa süre içinde sonuçlanacak.'
          : 'İlanınız oluşturuldu ve inceleme sürecine alındı. Kısa süre içinde sonuçlanacak.';
      gradientColors = [const Color(0xFFF59E0B), const Color(0xFFD97706)];
    }

    return Dialog(
      backgroundColor: JobsColors.card(isDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // İkon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradientColors),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 24),

            // Başlık
            Text(
              title,
              style: TextStyle(
                color: JobsColors.textPrimary(isDark),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Mesaj
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: JobsColors.textSecondary(isDark),
                fontSize: 14,
                height: 1.4,
              ),
            ),

            // Reddedildiyse flag'leri göster
            if (isRejected && result != null && result.flags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber, size: 16, color: primaryColor),
                        const SizedBox(width: 6),
                        Text(
                          'Sorunlar',
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...result.flags.map((flag) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              flag,
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Buton
            GestureDetector(
              onTap: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  isRejected ? 'Anladım' : 'Tamam',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
