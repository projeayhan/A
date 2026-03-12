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

class _AddJobListingScreenState extends State<AddJobListingScreen> {
  // İlan türü
  ListingType _listingType = ListingType.hiring;

  // Form Controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _minSalaryController = TextEditingController();
  final _maxSalaryController = TextEditingController();
  final _responsibilitiesController = TextEditingController();
  final _qualificationsController = TextEditingController();
  final _skillInputController = TextEditingController();
  final _benefitInputController = TextEditingController();

  // Seçimler
  JobCategoryData? _selectedDbCategory;
  JobCategory? _selectedCategory;
  String? _selectedSubcategory;
  JobType? _selectedJobType;
  WorkArrangement? _selectedWorkArrangement;
  ExperienceLevel? _selectedExperienceLevel;
  EducationLevel? _selectedEducationLevel;
  SalaryPeriod _salaryPeriod = SalaryPeriod.monthly;
  bool _isSalaryHidden = false;
  bool _isSalaryNegotiable = false;

  // Listeler
  final List<String> _manualSkills = [];
  final List<String> _manualBenefits = [];

  // Ek alanlar
  int _positions = 1;
  DateTime? _deadline;

  // Detaylar açık/kapalı
  bool _detailsExpanded = false;

  // State
  bool _isSubmitting = false;
  bool _isLoadingData = true;
  List<JobCategoryData> _dbCategories = [];

  // Düzenleme
  bool get _isEditMode => widget.editingListing != null;
  String? get _editingListingId => widget.editingListing?.id;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final categories = await JobsService.instance.getCategories();
      if (mounted) {
        setState(() => _dbCategories = categories);
        if (_isEditMode) await _populateEditingData();
        if (mounted) setState(() => _isLoadingData = false);
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
      _listingType = ListingType.fromDb(listing.listingType);
      _titleController.text = listing.title;
      _descriptionController.text = listing.description;
      _cityController.text = listing.city;
      _districtController.text = listing.district ?? '';

      _selectedDbCategory = _dbCategories.firstWhere(
        (c) => c.id == listing.categoryId,
        orElse: () => _dbCategories.first,
      );
      _selectedSubcategory = listing.subcategory;

      _selectedJobType = JobType.values.firstWhere(
        (t) => t.name == listing.jobType || t.toString().split('.').last == listing.jobType,
        orElse: () => JobType.fullTime,
      );
      _selectedWorkArrangement = WorkArrangement.values.firstWhere(
        (w) => w.name == listing.workArrangement || w.toString().split('.').last == listing.workArrangement,
        orElse: () => WorkArrangement.onsite,
      );
      _selectedExperienceLevel = ExperienceLevel.values.firstWhere(
        (e) => e.name == listing.experienceLevel || e.toString().split('.').last == listing.experienceLevel,
        orElse: () => ExperienceLevel.midLevel,
      );
      _selectedEducationLevel = EducationLevel.values.firstWhere(
        (e) => e.name == listing.educationLevel || e.toString().split('.').last == listing.educationLevel,
        orElse: () => EducationLevel.noRequirement,
      );

      if (listing.salaryMin != null) _minSalaryController.text = listing.salaryMin!.toStringAsFixed(0);
      if (listing.salaryMax != null) _maxSalaryController.text = listing.salaryMax!.toStringAsFixed(0);
      _salaryPeriod = SalaryPeriod.values.firstWhere(
        (p) => p.name == listing.salaryPeriod || p.toString().split('.').last == listing.salaryPeriod,
        orElse: () => SalaryPeriod.monthly,
      );
      _isSalaryHidden = listing.isSalaryHidden;
      _isSalaryNegotiable = listing.isSalaryNegotiable;

      _manualSkills.clear();
      _manualSkills.addAll(listing.requiredSkills);
      _manualBenefits.clear();
      _manualBenefits.addAll(listing.manualBenefits);

      _responsibilitiesController.text = listing.responsibilities.join('\n');
      _qualificationsController.text = listing.qualifications.join('\n');
      _positions = listing.positions;
      _deadline = listing.deadline;

      // Düzenleme modunda detayları aç
      _detailsExpanded = true;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _minSalaryController.dispose();
    _maxSalaryController.dispose();
    _responsibilitiesController.dispose();
    _qualificationsController.dispose();
    _skillInputController.dispose();
    _benefitInputController.dispose();
    super.dispose();
  }

  String _toSnakeCase(String input) {
    return input.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    );
  }

  List<String> _textToList(String text) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    return lines.isEmpty ? [text] : lines;
  }

  Future<void> _submitListing() async {
    if (_titleController.text.isEmpty) {
      _showError('İlan başlığı zorunludur');
      return;
    }
    if (_selectedDbCategory == null && _selectedCategory == null) {
      _showError('Kategori seçimi zorunludur');
      return;
    }
    if (_descriptionController.text.isEmpty) {
      _showError('Açıklama zorunludur');
      return;
    }
    if (_cityController.text.isEmpty) {
      _showError('Şehir zorunludur');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final jobsService = JobsService.instance;
      final categoryId = _selectedDbCategory?.id ?? _selectedCategory?.id;

      final data = <String, dynamic>{
        'listing_type': _listingType.dbValue,
        'title': _titleController.text.trim(),
        'category_id': categoryId,
        'subcategory': _selectedSubcategory,
        'description': _descriptionController.text.trim(),
        'city': _cityController.text.trim(),
        'district': _districtController.text.trim().isNotEmpty ? _districtController.text.trim() : null,
        'job_type': _selectedJobType != null ? _toSnakeCase(_selectedJobType!.name) : 'full_time',
        'work_arrangement': _selectedWorkArrangement != null ? _toSnakeCase(_selectedWorkArrangement!.name) : null,
        'experience_level': _selectedExperienceLevel != null ? _toSnakeCase(_selectedExperienceLevel!.name) : null,
        'education_level': _selectedEducationLevel != null ? _toSnakeCase(_selectedEducationLevel!.name) : null,
        'salary_min': double.tryParse(_minSalaryController.text),
        'salary_max': double.tryParse(_maxSalaryController.text),
        'salary_period': _toSnakeCase(_salaryPeriod.name),
        'is_salary_hidden': _isSalaryHidden,
        'is_salary_negotiable': _isSalaryNegotiable,
        'required_skills': _manualSkills.isNotEmpty ? _manualSkills : null,
        'manual_benefits': _manualBenefits.isNotEmpty ? _manualBenefits : null,
        'responsibilities': _responsibilitiesController.text.trim().isNotEmpty
            ? _textToList(_responsibilitiesController.text.trim()) : null,
        'qualifications': _qualificationsController.text.trim().isNotEmpty
            ? _textToList(_qualificationsController.text.trim()) : null,
        'positions': _positions,
        'deadline': _deadline?.toIso8601String(),
      };

      String listingId;

      if (_isEditMode) {
        data['status'] = 'pending';
        final success = await jobsService.updateListing(_editingListingId!, data);
        if (!success) {
          _showError('İlan güncellenirken bir hata oluştu');
          setState(() => _isSubmitting = false);
          return;
        }
        listingId = _editingListingId!;
      } else {
        final listing = await jobsService.createListing(data);
        if (listing == null) {
          _showError('İlan oluşturulurken bir hata oluştu');
          setState(() => _isSubmitting = false);
          return;
        }
        listingId = listing.id;
      }

      final moderationResult = await jobsService.moderateListing(listingId);
      setState(() => _isSubmitting = false);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => _buildModerationResultDialog(ctx, moderationResult, isEdit: _isEditMode),
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
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // İlan Türü Toggle
                            _buildListingTypeToggle(isDark),
                            const SizedBox(height: 20),

                            // İlan Başlığı
                            _buildSectionTitle(isDark, 'İlan Başlığı', true),
                            const SizedBox(height: 8),
                            _buildTextField(isDark,
                              _listingType == ListingType.hiring
                                  ? 'Örn: Senior Flutter Developer'
                                  : 'Örn: Deneyimli Aşçı İş Arıyor',
                              controller: _titleController),
                            const SizedBox(height: 20),

                            // Kategori
                            _buildSectionTitle(isDark, 'Kategori', true),
                            const SizedBox(height: 8),
                            _buildCategorySelector(isDark),
                            const SizedBox(height: 20),

                            // Açıklama
                            _buildSectionTitle(isDark, 'Açıklama', true),
                            const SizedBox(height: 8),
                            _buildTextField(isDark,
                              _listingType == ListingType.hiring
                                  ? 'Pozisyon hakkında detaylı bilgi verin...'
                                  : 'Kendinizi tanıtın, deneyimlerinizi yazın...',
                              controller: _descriptionController, maxLines: 4),
                            const SizedBox(height: 20),

                            // Şehir
                            _buildSectionTitle(isDark, 'Şehir', true),
                            const SizedBox(height: 8),
                            _buildTextField(isDark, 'Örn: İstanbul', controller: _cityController),
                            const SizedBox(height: 20),

                            // Pozisyon Sayısı & Son Başvuru
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildSectionTitle(isDark, 'Pozisyon Sayısı', false),
                                      const SizedBox(height: 8),
                                      _buildPositionCounter(isDark),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildSectionTitle(isDark, 'Son Başvuru', false),
                                      const SizedBox(height: 8),
                                      _buildDeadlinePicker(isDark),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Detaylar (Opsiyonel) - ExpansionTile
                            _buildDetailsSection(isDark),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        bottomNavigationBar: _isLoadingData ? null : _buildSubmitButton(isDark),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: JobsColors.surface(isDark),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.close, color: JobsColors.textPrimary(isDark)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _isEditMode ? 'İlanı Düzenle' : 'Yeni İş İlanı',
              style: TextStyle(
                color: JobsColors.textPrimary(isDark),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListingTypeToggle(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: JobsColors.surface(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: JobsColors.border(isDark)),
      ),
      child: Row(
        children: ListingType.values.map((type) {
          final isSelected = _listingType == type;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _listingType = type);
                HapticFeedback.selectionClick();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? type.color : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(type.icon, size: 18,
                      color: isSelected ? Colors.white : JobsColors.textSecondary(isDark)),
                    const SizedBox(width: 6),
                    Text(
                      type.label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : JobsColors.textSecondary(isDark),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDetailsSection(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: JobsColors.surface(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: JobsColors.border(isDark)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _detailsExpanded,
          onExpansionChanged: (v) => setState(() => _detailsExpanded = v),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Icon(Icons.tune, size: 20, color: JobsColors.primary),
              const SizedBox(width: 10),
              Text('Detaylar (opsiyonel)',
                style: TextStyle(
                  color: JobsColors.textPrimary(isDark),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                )),
            ],
          ),
          children: [
            const SizedBox(height: 8),

            // İlçe
            _buildSectionTitle(isDark, 'İlçe', false),
            const SizedBox(height: 8),
            _buildTextField(isDark, 'Örn: Maslak', controller: _districtController),
            const SizedBox(height: 16),

            // Çalışma Şekli
            _buildSectionTitle(isDark, 'Çalışma Şekli', false),
            const SizedBox(height: 8),
            _buildJobTypeSelector(isDark),
            const SizedBox(height: 16),

            // Çalışma Modeli
            _buildSectionTitle(isDark, 'Çalışma Modeli', false),
            const SizedBox(height: 8),
            _buildWorkArrangementSelector(isDark),
            const SizedBox(height: 16),

            // Maaş
            _buildSectionTitle(isDark,
              _listingType == ListingType.hiring ? 'Maaş Aralığı' : 'Beklenen Maaş',
              false),
            const SizedBox(height: 8),
            _buildSalaryInputs(isDark),
            const SizedBox(height: 8),
            _buildSalaryOptions(isDark),
            const SizedBox(height: 16),

            // Deneyim Seviyesi
            _buildSectionTitle(isDark, 'Deneyim Seviyesi', false),
            const SizedBox(height: 8),
            _buildExperienceLevelSelector(isDark),
            const SizedBox(height: 16),

            // Eğitim Seviyesi
            _buildSectionTitle(isDark, 'Eğitim Seviyesi', false),
            const SizedBox(height: 8),
            _buildEducationLevelSelector(isDark),
            const SizedBox(height: 16),

            // Yetenekler
            _buildSectionTitle(isDark, 'Yetenekler', false),
            const SizedBox(height: 8),
            _buildSkillsInput(isDark),
            const SizedBox(height: 16),

            // Sadece işveren modunda: yan haklar, sorumluluklar, nitelikler, pozisyon, deadline
            if (_listingType == ListingType.hiring) ...[
              _buildSectionTitle(isDark, 'Yan Haklar', false),
              const SizedBox(height: 8),
              _buildBenefitsInput(isDark),
              const SizedBox(height: 16),

              _buildSectionTitle(isDark, 'Sorumluluklar', false),
              const SizedBox(height: 8),
              _buildTextField(isDark, 'Her satıra bir sorumluluk yazın...',
                controller: _responsibilitiesController, maxLines: 3),
              const SizedBox(height: 16),

              _buildSectionTitle(isDark, 'Aranan Nitelikler', false),
              const SizedBox(height: 8),
              _buildTextField(isDark, 'Her satıra bir nitelik yazın...',
                controller: _qualificationsController, maxLines: 3),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton(bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 12,
        bottom: 12 + MediaQuery.of(context).padding.bottom,
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
      child: GestureDetector(
        onTap: _isSubmitting ? null : _submitListing,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isSubmitting
                  ? [Colors.grey, Colors.grey]
                  : [_listingType.color, _listingType.color.withValues(alpha: 0.8)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: _isSubmitting ? null : [
              BoxShadow(
                color: _listingType.color.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: _isSubmitting
                ? const SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isEditMode ? 'İlanı Güncelle' : 'İlanı Yayınla',
                        style: const TextStyle(
                          color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _isEditMode ? Icons.save : Icons.publish,
                        color: Colors.white,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ===================== HELPER WIDGETS =====================

  Widget _buildSectionTitle(bool isDark, String title, bool isRequired) {
    return Row(
      children: [
        Text(title,
          style: TextStyle(
            color: JobsColors.textPrimary(isDark),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          )),
        if (isRequired)
          const Text(' *',
            style: TextStyle(color: JobsColors.accent, fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildTextField(bool isDark, String hint, {
    TextEditingController? controller,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: JobsColors.surface(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: JobsColors.border(isDark)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(color: JobsColors.textPrimary(isDark)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: JobsColors.textTertiary(isDark)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildCategorySelector(bool isDark) {
    final categories = _dbCategories.isNotEmpty ? _dbCategories : <JobCategoryData>[];
    if (categories.isNotEmpty) {
      return SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];
            final isSelected = _selectedDbCategory?.id == cat.id;
            return GestureDetector(
              onTap: () {
                setState(() { _selectedDbCategory = cat; _selectedCategory = null; _selectedSubcategory = null; });
                HapticFeedback.selectionClick();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 90,
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? cat.colorValue : JobsColors.card(isDark),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? cat.colorValue : JobsColors.border(isDark),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(cat.iconData, size: 28,
                      color: isSelected ? Colors.white : cat.colorValue),
                    const SizedBox(height: 8),
                    Text(cat.name,
                      style: TextStyle(
                        color: isSelected ? Colors.white : JobsColors.textPrimary(isDark),
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    // Fallback: hardcoded categories
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: JobCategory.allCategories.length,
        itemBuilder: (context, index) {
          final cat = JobCategory.allCategories[index];
          final isSelected = _selectedCategory?.id == cat.id;
          return GestureDetector(
            onTap: () {
              setState(() { _selectedCategory = cat; _selectedDbCategory = null; _selectedSubcategory = null; });
              HapticFeedback.selectionClick();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 90,
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? cat.color : JobsColors.card(isDark),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? cat.color : JobsColors.border(isDark),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(cat.icon, size: 28, color: isSelected ? Colors.white : cat.color),
                  const SizedBox(height: 8),
                  Text(cat.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : JobsColors.textPrimary(isDark),
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildJobTypeSelector(bool isDark) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: JobType.values.map((type) {
        final isSelected = _selectedJobType == type;
        return GestureDetector(
          onTap: () { setState(() => _selectedJobType = type); HapticFeedback.selectionClick(); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? type.color : JobsColors.card(isDark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? type.color : JobsColors.border(isDark)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(type.icon, size: 16, color: isSelected ? Colors.white : JobsColors.textSecondary(isDark)),
                const SizedBox(width: 6),
                Text(type.label, style: TextStyle(
                  color: isSelected ? Colors.white : JobsColors.textPrimary(isDark),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, fontSize: 13)),
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
            onTap: () { setState(() => _selectedWorkArrangement = type); HapticFeedback.selectionClick(); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: type != WorkArrangement.values.last ? 10 : 0),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? type.color : JobsColors.card(isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? type.color : JobsColors.border(isDark)),
              ),
              child: Column(
                children: [
                  Icon(type.icon, size: 24, color: isSelected ? Colors.white : type.color),
                  const SizedBox(height: 6),
                  Text(type.label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? Colors.white : JobsColors.textPrimary(isDark),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, fontSize: 12)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSalaryInputs(bool isDark) {
    return Row(
      children: [
        Expanded(child: _buildTextField(isDark, 'Min', controller: _minSalaryController, keyboardType: TextInputType.number)),
        const SizedBox(width: 10),
        Expanded(child: _buildTextField(isDark, 'Max', controller: _maxSalaryController, keyboardType: TextInputType.number)),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: JobsColors.surface(isDark),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: JobsColors.border(isDark)),
          ),
          child: DropdownButton<SalaryPeriod>(
            value: _salaryPeriod,
            underline: const SizedBox(),
            dropdownColor: JobsColors.card(isDark),
            items: SalaryPeriod.values.map((p) => DropdownMenuItem(
              value: p,
              child: Text(p.label, style: TextStyle(color: JobsColors.textPrimary(isDark), fontSize: 13)),
            )).toList(),
            onChanged: (v) { if (v != null) setState(() => _salaryPeriod = v); },
          ),
        ),
      ],
    );
  }

  Widget _buildSalaryOptions(bool isDark) {
    return Row(
      children: [
        Expanded(child: _buildCheckOption(isDark, 'Maaşı Gizle', _isSalaryHidden, (v) => setState(() => _isSalaryHidden = v))),
        const SizedBox(width: 10),
        Expanded(child: _buildCheckOption(isDark, 'Pazarlık Olur', _isSalaryNegotiable, (v) => setState(() => _isSalaryNegotiable = v))),
      ],
    );
  }

  Widget _buildCheckOption(bool isDark, String title, bool value, Function(bool) onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: value ? JobsColors.primary.withValues(alpha: 0.1) : JobsColors.card(isDark),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: value ? JobsColors.primary : JobsColors.border(isDark)),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20, height: 20,
              decoration: BoxDecoration(
                color: value ? JobsColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: value ? JobsColors.primary : JobsColors.border(isDark), width: 2),
              ),
              child: value ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: TextStyle(
              color: value ? JobsColors.primary : JobsColors.textPrimary(isDark),
              fontWeight: value ? FontWeight.w600 : FontWeight.normal, fontSize: 13))),
          ],
        ),
      ),
    );
  }

  Widget _buildExperienceLevelSelector(bool isDark) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: ExperienceLevel.values.map((level) {
        final isSelected = _selectedExperienceLevel == level;
        return GestureDetector(
          onTap: () { setState(() => _selectedExperienceLevel = level); HapticFeedback.selectionClick(); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? JobsColors.primary : JobsColors.card(isDark),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isSelected ? JobsColors.primary : JobsColors.border(isDark)),
            ),
            child: Column(
              children: [
                Text(level.label, style: TextStyle(
                  color: isSelected ? Colors.white : JobsColors.textPrimary(isDark),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, fontSize: 13)),
                Text(level.yearsRange, style: TextStyle(
                  color: isSelected ? Colors.white.withValues(alpha: 0.8) : JobsColors.textTertiary(isDark),
                  fontSize: 11)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEducationLevelSelector(bool isDark) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: EducationLevel.values.map((level) {
        final isSelected = _selectedEducationLevel == level;
        return GestureDetector(
          onTap: () { setState(() => _selectedEducationLevel = level); HapticFeedback.selectionClick(); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? JobsColors.primary : JobsColors.card(isDark),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isSelected ? JobsColors.primary : JobsColors.border(isDark)),
            ),
            child: Text(level.label, style: TextStyle(
              color: isSelected ? Colors.white : JobsColors.textPrimary(isDark),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSkillsInput(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextField(isDark, 'Yetenek girin (örn: Flutter, Excel)',
                controller: _skillInputController),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _addSkill,
              child: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: JobsColors.primaryGradient),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 24),
              ),
            ),
          ],
        ),
        if (_manualSkills.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _manualSkills.map((skill) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: JobsColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: JobsColors.secondary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(skill, style: TextStyle(color: JobsColors.secondary, fontWeight: FontWeight.w500, fontSize: 13)),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () { setState(() => _manualSkills.remove(skill)); HapticFeedback.lightImpact(); },
                    child: Icon(Icons.close, size: 16, color: JobsColors.secondary),
                  ),
                ],
              ),
            )).toList(),
          ),
        ],
      ],
    );
  }

  void _addSkill() {
    final skill = _skillInputController.text.trim();
    if (skill.isNotEmpty && !_manualSkills.contains(skill)) {
      setState(() { _manualSkills.add(skill); _skillInputController.clear(); });
      HapticFeedback.selectionClick();
    }
  }

  Widget _buildBenefitsInput(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextField(isDark, 'Yan hak girin (örn: Yemek kartı)',
                controller: _benefitInputController),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _addBenefit,
              child: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: JobsColors.primaryGradient),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 24),
              ),
            ),
          ],
        ),
        if (_manualBenefits.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _manualBenefits.map((b) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: JobsColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: JobsColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.card_giftcard, size: 14, color: JobsColors.primary),
                  const SizedBox(width: 4),
                  Text(b, style: TextStyle(color: JobsColors.primary, fontWeight: FontWeight.w500, fontSize: 13)),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () { setState(() => _manualBenefits.remove(b)); HapticFeedback.lightImpact(); },
                    child: Icon(Icons.close, size: 16, color: JobsColors.primary),
                  ),
                ],
              ),
            )).toList(),
          ),
        ],
      ],
    );
  }

  void _addBenefit() {
    final b = _benefitInputController.text.trim();
    if (b.isNotEmpty && !_manualBenefits.contains(b)) {
      setState(() { _manualBenefits.add(b); _benefitInputController.clear(); });
      HapticFeedback.selectionClick();
    }
  }

  Widget _buildPositionCounter(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: JobsColors.card(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: JobsColors.border(isDark)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () { if (_positions > 1) { setState(() => _positions--); HapticFeedback.selectionClick(); } },
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: JobsColors.surface(isDark), shape: BoxShape.circle),
              child: Icon(Icons.remove, color: _positions > 1 ? JobsColors.textPrimary(isDark) : JobsColors.textTertiary(isDark), size: 18),
            ),
          ),
          const SizedBox(width: 16),
          Text('$_positions', style: TextStyle(color: JobsColors.textPrimary(isDark), fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () { if (_positions < 100) { setState(() => _positions++); HapticFeedback.selectionClick(); } },
            child: Container(
              width: 32, height: 32,
              decoration: const BoxDecoration(color: JobsColors.primary, shape: BoxShape.circle),
              child: const Icon(Icons.add, color: Colors.white, size: 18),
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
        if (date != null) setState(() => _deadline = date);
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: JobsColors.card(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: JobsColors.border(isDark)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, color: JobsColors.primary, size: 18),
            const SizedBox(width: 6),
            Text(
              _deadline != null ? '${_deadline!.day}/${_deadline!.month}/${_deadline!.year}' : 'Seç',
              style: TextStyle(color: JobsColors.textPrimary(isDark), fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModerationResultDialog(BuildContext dialogContext, ModerationResult? result, {bool isEdit = false}) {
    final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
    final isApproved = result?.result == 'approved';
    final isRejected = result?.result == 'rejected';

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
          ? 'İş ilanınız başarıyla güncellendi ve yayına alındı.'
          : 'İş ilanınız başarıyla onaylandı ve yayına alındı.';
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
          ? 'İlanınız güncellendi ve inceleme sürecine alındı.'
          : 'İlanınız oluşturuldu ve inceleme sürecine alındı.';
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
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(gradient: LinearGradient(colors: gradientColors), shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 24),
            Text(title, style: TextStyle(color: JobsColors.textPrimary(isDark), fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center,
              style: TextStyle(color: JobsColors.textSecondary(isDark), fontSize: 14, height: 1.4)),

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
                    Row(children: [
                      Icon(Icons.warning_amber, size: 16, color: primaryColor),
                      const SizedBox(width: 6),
                      Text('Sorunlar', style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 8),
                    ...result.flags.map((flag) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(margin: const EdgeInsets.only(top: 6), width: 5, height: 5,
                          decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(flag, style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54, fontSize: 13))),
                      ]),
                    )),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            GestureDetector(
              onTap: () { Navigator.of(dialogContext).pop(); Navigator.of(context).pop(); },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(isRejected ? 'Anladım' : 'Tamam',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
