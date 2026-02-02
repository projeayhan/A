// Premium Job Listings Models - International Standards
// Designed for a world-class job marketplace experience

import 'package:flutter/material.dart';

/// Job type enumeration
enum JobType {
  fullTime('Tam Zamanlı', Icons.work, Color(0xFF3B82F6)),
  partTime('Yarı Zamanlı', Icons.work_outline, Color(0xFF8B5CF6)),
  contract('Sözleşmeli', Icons.assignment, Color(0xFFF59E0B)),
  internship('Staj', Icons.school, Color(0xFF10B981)),
  freelance('Freelance', Icons.laptop_mac, Color(0xFFEC4899)),
  remote('Uzaktan', Icons.home_work, Color(0xFF06B6D4)),
  temporary('Geçici', Icons.timer, Color(0xFFEF4444));

  final String label;
  final IconData icon;
  final Color color;
  const JobType(this.label, this.icon, this.color);
}

/// Experience level enumeration
enum ExperienceLevel {
  entry('Giriş Seviye', '0-1 yıl', Icons.star_border),
  junior('Junior', '1-3 yıl', Icons.star_half),
  midLevel('Orta Seviye', '3-5 yıl', Icons.star),
  senior('Senior', '5-8 yıl', Icons.stars),
  lead('Lead/Manager', '8-10 yıl', Icons.military_tech),
  director('Direktör', '10+ yıl', Icons.workspace_premium),
  executive('Üst Düzey Yönetici', '15+ yıl', Icons.diamond);

  final String label;
  final String yearsRange;
  final IconData icon;
  const ExperienceLevel(this.label, this.yearsRange, this.icon);
}

/// Education level enumeration
enum EducationLevel {
  highSchool('Lise', Icons.school),
  associate('Ön Lisans', Icons.school),
  bachelor('Lisans', Icons.school),
  master('Yüksek Lisans', Icons.school),
  doctorate('Doktora', Icons.school),
  noRequirement('Önemli Değil', Icons.check_circle);

  final String label;
  final IconData icon;
  const EducationLevel(this.label, this.icon);
}

/// Work arrangement enumeration
enum WorkArrangement {
  onsite('Ofiste', Icons.business, Color(0xFF3B82F6)),
  remote('Uzaktan', Icons.home, Color(0xFF10B981)),
  hybrid('Hibrit', Icons.swap_horiz, Color(0xFF8B5CF6));

  final String label;
  final IconData icon;
  final Color color;
  const WorkArrangement(this.label, this.icon, this.color);
}

/// Job listing status
enum JobListingStatus {
  active('Aktif', Color(0xFF10B981), Icons.check_circle),
  pending('Onay Bekliyor', Color(0xFFF59E0B), Icons.hourglass_empty),
  closed('Kapatıldı', Color(0xFF6B7280), Icons.cancel),
  filled('Dolduruldu', Color(0xFF3B82F6), Icons.person_add),
  expired('Süresi Doldu', Color(0xFFEF4444), Icons.timer_off);

  final String label;
  final Color color;
  final IconData icon;
  const JobListingStatus(this.label, this.color, this.icon);
}

/// Job category model
class JobCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final List<String> subcategories;

  const JobCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.subcategories = const [],
  });

  static const List<JobCategory> allCategories = [
    JobCategory(
      id: 'tech',
      name: 'Teknoloji',
      icon: Icons.computer,
      color: Color(0xFF3B82F6),
      subcategories: ['Yazılım Geliştirme', 'Web Geliştirme', 'Mobil Geliştirme', 'DevOps', 'Siber Güvenlik', 'Veri Bilimi', 'Yapay Zeka', 'QA/Test'],
    ),
    JobCategory(
      id: 'marketing',
      name: 'Pazarlama',
      icon: Icons.campaign,
      color: Color(0xFFEC4899),
      subcategories: ['Dijital Pazarlama', 'Sosyal Medya', 'İçerik Pazarlama', 'SEO/SEM', 'Marka Yönetimi', 'Halkla İlişkiler'],
    ),
    JobCategory(
      id: 'sales',
      name: 'Satış',
      icon: Icons.trending_up,
      color: Color(0xFF10B981),
      subcategories: ['B2B Satış', 'B2C Satış', 'Hesap Yönetimi', 'Satış Geliştirme', 'Perakende Satış'],
    ),
    JobCategory(
      id: 'design',
      name: 'Tasarım',
      icon: Icons.palette,
      color: Color(0xFF8B5CF6),
      subcategories: ['UI/UX Tasarım', 'Grafik Tasarım', 'Ürün Tasarımı', '3D Tasarım', 'Motion Design'],
    ),
    JobCategory(
      id: 'finance',
      name: 'Finans',
      icon: Icons.account_balance,
      color: Color(0xFF059669),
      subcategories: ['Muhasebe', 'Finansal Analiz', 'Denetim', 'Vergi', 'Yatırım', 'Risk Yönetimi'],
    ),
    JobCategory(
      id: 'hr',
      name: 'İnsan Kaynakları',
      icon: Icons.people,
      color: Color(0xFFF59E0B),
      subcategories: ['İşe Alım', 'Eğitim & Gelişim', 'Bordro', 'Organizasyon Geliştirme', 'Çalışan İlişkileri'],
    ),
    JobCategory(
      id: 'operations',
      name: 'Operasyon',
      icon: Icons.settings,
      color: Color(0xFF6366F1),
      subcategories: ['Proje Yönetimi', 'Tedarik Zinciri', 'Lojistik', 'Kalite Güvence', 'Üretim'],
    ),
    JobCategory(
      id: 'customer_service',
      name: 'Müşteri Hizmetleri',
      icon: Icons.support_agent,
      color: Color(0xFF06B6D4),
      subcategories: ['Müşteri Desteği', 'Teknik Destek', 'Çağrı Merkezi', 'Müşteri Başarısı'],
    ),
    JobCategory(
      id: 'healthcare',
      name: 'Sağlık',
      icon: Icons.local_hospital,
      color: Color(0xFFEF4444),
      subcategories: ['Doktor', 'Hemşire', 'Eczacı', 'Fizyoterapist', 'Psikolog', 'Laborant'],
    ),
    JobCategory(
      id: 'education',
      name: 'Eğitim',
      icon: Icons.menu_book,
      color: Color(0xFF0EA5E9),
      subcategories: ['Öğretmen', 'Eğitim Danışmanı', 'Akademisyen', 'Eğitim Koordinatörü'],
    ),
    JobCategory(
      id: 'engineering',
      name: 'Mühendislik',
      icon: Icons.engineering,
      color: Color(0xFF84CC16),
      subcategories: ['Makine Mühendisi', 'Elektrik Mühendisi', 'İnşaat Mühendisi', 'Endüstri Mühendisi'],
    ),
    JobCategory(
      id: 'legal',
      name: 'Hukuk',
      icon: Icons.gavel,
      color: Color(0xFF78716C),
      subcategories: ['Avukat', 'Hukuk Danışmanı', 'Paralegal', 'Sözleşme Uzmanı'],
    ),
    JobCategory(
      id: 'media',
      name: 'Medya & İletişim',
      icon: Icons.videocam,
      color: Color(0xFFD946EF),
      subcategories: ['Gazetecilik', 'Video Prodüksiyon', 'Fotoğrafçılık', 'Yayıncılık'],
    ),
    JobCategory(
      id: 'hospitality',
      name: 'Turizm & Otelcilik',
      icon: Icons.hotel,
      color: Color(0xFFFB923C),
      subcategories: ['Otel Yönetimi', 'Tur Rehberliği', 'Restoran Yönetimi', 'Etkinlik Planlama'],
    ),
    JobCategory(
      id: 'other',
      name: 'Diğer',
      icon: Icons.more_horiz,
      color: Color(0xFF94A3B8),
      subcategories: [],
    ),
  ];

  static JobCategory getCategoryById(String id) {
    return allCategories.firstWhere(
      (c) => c.id == id,
      orElse: () => allCategories.last,
    );
  }
}

/// Benefit/Perk model
class JobBenefit {
  final String id;
  final String name;
  final IconData icon;
  final String category;

  const JobBenefit({
    required this.id,
    required this.name,
    required this.icon,
    required this.category,
  });

  static const Map<String, List<JobBenefit>> benefitsByCategory = {
    'Sağlık': [
      JobBenefit(id: 'health_insurance', name: 'Özel Sağlık Sigortası', icon: Icons.health_and_safety, category: 'Sağlık'),
      JobBenefit(id: 'dental', name: 'Diş Sigortası', icon: Icons.medical_services, category: 'Sağlık'),
      JobBenefit(id: 'gym', name: 'Spor Salonu Üyeliği', icon: Icons.fitness_center, category: 'Sağlık'),
      JobBenefit(id: 'mental_health', name: 'Psikolojik Destek', icon: Icons.psychology, category: 'Sağlık'),
    ],
    'Finansal': [
      JobBenefit(id: 'bonus', name: 'Performans Primi', icon: Icons.monetization_on, category: 'Finansal'),
      JobBenefit(id: 'stock_options', name: 'Hisse Senedi Opsiyonu', icon: Icons.trending_up, category: 'Finansal'),
      JobBenefit(id: 'retirement', name: 'Bireysel Emeklilik', icon: Icons.savings, category: 'Finansal'),
      JobBenefit(id: 'meal_card', name: 'Yemek Kartı', icon: Icons.restaurant, category: 'Finansal'),
      JobBenefit(id: 'fuel_card', name: 'Yakıt Kartı', icon: Icons.local_gas_station, category: 'Finansal'),
      JobBenefit(id: 'phone', name: 'Telefon/Hat', icon: Icons.phone_android, category: 'Finansal'),
    ],
    'İş-Yaşam Dengesi': [
      JobBenefit(id: 'flexible_hours', name: 'Esnek Çalışma Saatleri', icon: Icons.schedule, category: 'İş-Yaşam Dengesi'),
      JobBenefit(id: 'remote_work', name: 'Uzaktan Çalışma', icon: Icons.home_work, category: 'İş-Yaşam Dengesi'),
      JobBenefit(id: 'paid_leave', name: 'Ücretli İzin', icon: Icons.beach_access, category: 'İş-Yaşam Dengesi'),
      JobBenefit(id: 'parental_leave', name: 'Ebeveyn İzni', icon: Icons.child_care, category: 'İş-Yaşam Dengesi'),
      JobBenefit(id: 'sabbatical', name: 'Sabbatical İzni', icon: Icons.flight_takeoff, category: 'İş-Yaşam Dengesi'),
    ],
    'Gelişim': [
      JobBenefit(id: 'training', name: 'Eğitim Desteği', icon: Icons.school, category: 'Gelişim'),
      JobBenefit(id: 'certification', name: 'Sertifika Desteği', icon: Icons.card_membership, category: 'Gelişim'),
      JobBenefit(id: 'conference', name: 'Konferans Katılımı', icon: Icons.groups, category: 'Gelişim'),
      JobBenefit(id: 'mentorship', name: 'Mentorluk Programı', icon: Icons.people, category: 'Gelişim'),
      JobBenefit(id: 'books', name: 'Kitap/Kaynak Desteği', icon: Icons.menu_book, category: 'Gelişim'),
    ],
    'Ofis': [
      JobBenefit(id: 'free_lunch', name: 'Ücretsiz Yemek', icon: Icons.lunch_dining, category: 'Ofis'),
      JobBenefit(id: 'snacks', name: 'Atıştırmalık & İçecek', icon: Icons.local_cafe, category: 'Ofis'),
      JobBenefit(id: 'game_room', name: 'Oyun Odası', icon: Icons.sports_esports, category: 'Ofis'),
      JobBenefit(id: 'pet_friendly', name: 'Evcil Hayvan Dostu', icon: Icons.pets, category: 'Ofis'),
      JobBenefit(id: 'parking', name: 'Otopark', icon: Icons.local_parking, category: 'Ofis'),
      JobBenefit(id: 'shuttle', name: 'Servis', icon: Icons.directions_bus, category: 'Ofis'),
    ],
  };

  static List<JobBenefit> get allBenefits =>
      benefitsByCategory.values.expand((list) => list).toList();
}

/// Skill/Requirement model
class JobSkill {
  final String id;
  final String name;
  final String category;
  final bool isPopular;

  const JobSkill({
    required this.id,
    required this.name,
    required this.category,
    this.isPopular = false,
  });

  static const List<JobSkill> popularSkills = [
    // Tech
    JobSkill(id: 'javascript', name: 'JavaScript', category: 'Programlama', isPopular: true),
    JobSkill(id: 'python', name: 'Python', category: 'Programlama', isPopular: true),
    JobSkill(id: 'java', name: 'Java', category: 'Programlama', isPopular: true),
    JobSkill(id: 'react', name: 'React', category: 'Framework', isPopular: true),
    JobSkill(id: 'flutter', name: 'Flutter', category: 'Framework', isPopular: true),
    JobSkill(id: 'nodejs', name: 'Node.js', category: 'Backend', isPopular: true),
    JobSkill(id: 'sql', name: 'SQL', category: 'Veritabanı', isPopular: true),
    JobSkill(id: 'aws', name: 'AWS', category: 'Cloud', isPopular: true),

    // Soft Skills
    JobSkill(id: 'communication', name: 'İletişim', category: 'Soft Skill', isPopular: true),
    JobSkill(id: 'leadership', name: 'Liderlik', category: 'Soft Skill', isPopular: true),
    JobSkill(id: 'teamwork', name: 'Takım Çalışması', category: 'Soft Skill', isPopular: true),
    JobSkill(id: 'problem_solving', name: 'Problem Çözme', category: 'Soft Skill', isPopular: true),

    // Languages
    JobSkill(id: 'english', name: 'İngilizce', category: 'Dil', isPopular: true),
    JobSkill(id: 'german', name: 'Almanca', category: 'Dil', isPopular: true),

    // Tools
    JobSkill(id: 'excel', name: 'Excel', category: 'Araç', isPopular: true),
    JobSkill(id: 'figma', name: 'Figma', category: 'Tasarım', isPopular: true),
    JobSkill(id: 'photoshop', name: 'Photoshop', category: 'Tasarım', isPopular: true),
    JobSkill(id: 'sap', name: 'SAP', category: 'ERP', isPopular: true),
  ];
}

/// Company model
class Company {
  final String id;
  final String name;
  final String? logoUrl;
  final String? website;
  final String industry;
  final String size;
  final String? description;
  final String? location;
  final double rating;
  final int reviewCount;
  final bool isVerified;
  final DateTime foundedYear;
  final List<String> benefits;
  final String? culture;

  const Company({
    required this.id,
    required this.name,
    this.logoUrl,
    this.website,
    required this.industry,
    required this.size,
    this.description,
    this.location,
    this.rating = 0,
    this.reviewCount = 0,
    this.isVerified = false,
    required this.foundedYear,
    this.benefits = const [],
    this.culture,
  });

  static const List<String> companySizes = [
    '1-10 çalışan',
    '11-50 çalışan',
    '51-200 çalışan',
    '201-500 çalışan',
    '501-1000 çalışan',
    '1001-5000 çalışan',
    '5000+ çalışan',
  ];
}

/// Employer/Recruiter model
class JobPoster {
  final String id;
  final String name;
  final String? title;
  final String phone;
  final String? email;
  final String? imageUrl;
  final Company? company;
  final bool isVerified;
  final DateTime memberSince;
  final int activeListings;
  final int totalHires;
  final double responseRate;
  final String? responseTime;

  const JobPoster({
    required this.id,
    required this.name,
    this.title,
    required this.phone,
    this.email,
    this.imageUrl,
    this.company,
    this.isVerified = false,
    required this.memberSince,
    this.activeListings = 0,
    this.totalHires = 0,
    this.responseRate = 0,
    this.responseTime,
  });

  String get displayName => company?.name ?? name;

  String get membershipDuration {
    final years = DateTime.now().difference(memberSince).inDays ~/ 365;
    if (years > 0) return '$years yıldır üye';
    final months = DateTime.now().difference(memberSince).inDays ~/ 30;
    if (months > 0) return '$months aydır üye';
    return 'Yeni üye';
  }
}

/// Salary model
class SalaryRange {
  final double? min;
  final double? max;
  final String currency;
  final SalaryPeriod period;
  final bool isNegotiable;
  final bool isHidden;

  const SalaryRange({
    this.min,
    this.max,
    this.currency = 'TL',
    this.period = SalaryPeriod.monthly,
    this.isNegotiable = false,
    this.isHidden = false,
  });

  String get formatted {
    if (isHidden) return 'Görüşülür';
    if (min == null && max == null) return 'Belirtilmemiş';

    String formatNum(double num) {
      if (num >= 1000) {
        return '${(num / 1000).toStringAsFixed(0)}K';
      }
      return num.toStringAsFixed(0);
    }

    if (min != null && max != null) {
      return '${formatNum(min!)} - ${formatNum(max!)} $currency/${period.shortLabel}';
    } else if (min != null) {
      return '${formatNum(min!)}+ $currency/${period.shortLabel}';
    } else {
      return '${formatNum(max!)} $currency/${period.shortLabel}\'e kadar';
    }
  }

  String get fullFormatted {
    if (isHidden) return 'Maaş: Görüşülür';
    if (min == null && max == null) return 'Maaş belirtilmemiş';

    String formatNum(double num) {
      final formatted = num.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      );
      return formatted;
    }

    if (min != null && max != null) {
      return '${formatNum(min!)} - ${formatNum(max!)} $currency / ${period.label}';
    } else if (min != null) {
      return '${formatNum(min!)}+ $currency / ${period.label}';
    } else {
      return '${formatNum(max!)} $currency\'ye kadar / ${period.label}';
    }
  }
}

enum SalaryPeriod {
  hourly('Saatlik', 'saat'),
  daily('Günlük', 'gün'),
  weekly('Haftalık', 'hafta'),
  monthly('Aylık', 'ay'),
  yearly('Yıllık', 'yıl');

  final String label;
  final String shortLabel;
  const SalaryPeriod(this.label, this.shortLabel);
}

/// Main job listing model
class JobListing {
  final String id;
  final String title;
  final String description;
  final JobCategory category;
  final String? subcategory;
  final JobType jobType;
  final WorkArrangement workArrangement;
  final ExperienceLevel experienceLevel;
  final EducationLevel educationLevel;
  final SalaryRange salary;
  final JobListingStatus status;
  final JobPoster poster;
  final Company? company;
  final String city;
  final String? district;
  final String? address;
  final List<String> requiredSkills;
  final List<String> preferredSkills;
  final List<String> responsibilities;
  final List<String> qualifications;
  final List<String> benefitIds;
  final int? positions;
  final DateTime? deadline;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int viewCount;
  final int applicationCount;
  final int saveCount;
  final bool isFeatured;
  final bool isPremiumListing;
  final bool isUrgent;
  final String? externalLink;
  final double? latitude;
  final double? longitude;

  const JobListing({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.subcategory,
    required this.jobType,
    required this.workArrangement,
    required this.experienceLevel,
    required this.educationLevel,
    required this.salary,
    required this.status,
    required this.poster,
    this.company,
    required this.city,
    this.district,
    this.address,
    required this.requiredSkills,
    this.preferredSkills = const [],
    this.responsibilities = const [],
    this.qualifications = const [],
    this.benefitIds = const [],
    this.positions,
    this.deadline,
    required this.createdAt,
    this.updatedAt,
    this.viewCount = 0,
    this.applicationCount = 0,
    this.saveCount = 0,
    this.isFeatured = false,
    this.isPremiumListing = false,
    this.isUrgent = false,
    this.externalLink,
    this.latitude,
    this.longitude,
  });

  String get location => district != null ? '$district, $city' : city;

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays > 30) return '${diff.inDays ~/ 30} ay önce';
    if (diff.inDays > 0) return '${diff.inDays} gün önce';
    if (diff.inHours > 0) return '${diff.inHours} saat önce';
    return '${diff.inMinutes} dakika önce';
  }

  String get deadlineText {
    if (deadline == null) return '';
    final diff = deadline!.difference(DateTime.now());
    if (diff.isNegative) return 'Süre doldu';
    if (diff.inDays > 30) return '${diff.inDays ~/ 30} ay kaldı';
    if (diff.inDays > 0) return '${diff.inDays} gün kaldı';
    if (diff.inHours > 0) return '${diff.inHours} saat kaldı';
    return 'Son gün';
  }

  List<JobBenefit> get benefits {
    return benefitIds
        .map((id) => JobBenefit.allBenefits.firstWhere(
              (b) => b.id == id,
              orElse: () => JobBenefit(
                id: id,
                name: id,
                icon: Icons.check,
                category: 'Diğer',
              ),
            ))
        .toList();
  }

  String get companyName => company?.name ?? poster.name;
  String? get companyLogo => company?.logoUrl ?? poster.imageUrl;
}

/// Job application model
class JobApplication {
  final String id;
  final String jobId;
  final String applicantName;
  final String applicantEmail;
  final String? applicantPhone;
  final String? coverLetter;
  final String? resumeUrl;
  final List<String> portfolioLinks;
  final ApplicationStatus status;
  final DateTime appliedAt;
  final DateTime? reviewedAt;
  final String? notes;

  const JobApplication({
    required this.id,
    required this.jobId,
    required this.applicantName,
    required this.applicantEmail,
    this.applicantPhone,
    this.coverLetter,
    this.resumeUrl,
    this.portfolioLinks = const [],
    required this.status,
    required this.appliedAt,
    this.reviewedAt,
    this.notes,
  });
}

enum ApplicationStatus {
  pending('Beklemede', Color(0xFFF59E0B), Icons.hourglass_empty),
  reviewed('İncelendi', Color(0xFF3B82F6), Icons.visibility),
  shortlisted('Ön Eleme Geçti', Color(0xFF8B5CF6), Icons.star),
  interview('Mülakat', Color(0xFF06B6D4), Icons.groups),
  offered('Teklif Verildi', Color(0xFF10B981), Icons.handshake),
  hired('İşe Alındı', Color(0xFF059669), Icons.celebration),
  rejected('Reddedildi', Color(0xFFEF4444), Icons.cancel);

  final String label;
  final Color color;
  final IconData icon;
  const ApplicationStatus(this.label, this.color, this.icon);
}

/// Search/Filter model
class JobSearchFilter {
  final String? query;
  final List<String>? categoryIds;
  final List<JobType>? jobTypes;
  final List<WorkArrangement>? workArrangements;
  final List<ExperienceLevel>? experienceLevels;
  final List<EducationLevel>? educationLevels;
  final double? minSalary;
  final double? maxSalary;
  final String? city;
  final String? district;
  final List<String>? requiredSkills;
  final List<String>? requiredBenefits;
  final bool? isUrgent;
  final bool? hasRemoteOption;
  final DateTime? postedAfter;
  final JobSortOption sortBy;

  const JobSearchFilter({
    this.query,
    this.categoryIds,
    this.jobTypes,
    this.workArrangements,
    this.experienceLevels,
    this.educationLevels,
    this.minSalary,
    this.maxSalary,
    this.city,
    this.district,
    this.requiredSkills,
    this.requiredBenefits,
    this.isUrgent,
    this.hasRemoteOption,
    this.postedAfter,
    this.sortBy = JobSortOption.newest,
  });

  JobSearchFilter copyWith({
    String? query,
    List<String>? categoryIds,
    List<JobType>? jobTypes,
    List<WorkArrangement>? workArrangements,
    List<ExperienceLevel>? experienceLevels,
    List<EducationLevel>? educationLevels,
    double? minSalary,
    double? maxSalary,
    String? city,
    String? district,
    List<String>? requiredSkills,
    List<String>? requiredBenefits,
    bool? isUrgent,
    bool? hasRemoteOption,
    DateTime? postedAfter,
    JobSortOption? sortBy,
  }) {
    return JobSearchFilter(
      query: query ?? this.query,
      categoryIds: categoryIds ?? this.categoryIds,
      jobTypes: jobTypes ?? this.jobTypes,
      workArrangements: workArrangements ?? this.workArrangements,
      experienceLevels: experienceLevels ?? this.experienceLevels,
      educationLevels: educationLevels ?? this.educationLevels,
      minSalary: minSalary ?? this.minSalary,
      maxSalary: maxSalary ?? this.maxSalary,
      city: city ?? this.city,
      district: district ?? this.district,
      requiredSkills: requiredSkills ?? this.requiredSkills,
      requiredBenefits: requiredBenefits ?? this.requiredBenefits,
      isUrgent: isUrgent ?? this.isUrgent,
      hasRemoteOption: hasRemoteOption ?? this.hasRemoteOption,
      postedAfter: postedAfter ?? this.postedAfter,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  int get activeFilterCount {
    int count = 0;
    if (categoryIds?.isNotEmpty ?? false) count++;
    if (jobTypes?.isNotEmpty ?? false) count++;
    if (workArrangements?.isNotEmpty ?? false) count++;
    if (experienceLevels?.isNotEmpty ?? false) count++;
    if (educationLevels?.isNotEmpty ?? false) count++;
    if (minSalary != null || maxSalary != null) count++;
    if (city != null) count++;
    if (requiredSkills?.isNotEmpty ?? false) count++;
    if (requiredBenefits?.isNotEmpty ?? false) count++;
    if (isUrgent == true) count++;
    if (hasRemoteOption == true) count++;
    if (postedAfter != null) count++;
    return count;
  }
}

/// Sort options
enum JobSortOption {
  newest('En Yeni', Icons.access_time),
  oldest('En Eski', Icons.history),
  salaryHigh('Maaş (Yüksek-Düşük)', Icons.trending_up),
  salaryLow('Maaş (Düşük-Yüksek)', Icons.trending_down),
  mostViewed('En Çok Görüntülenen', Icons.visibility),
  deadline('Son Başvuru Tarihi', Icons.timer);

  final String label;
  final IconData icon;
  const JobSortOption(this.label, this.icon);
}

/// Theme colors for jobs module
class JobsColors {
  // Primary - Deep Teal (Professional, Trust)
  static const Color primary = Color(0xFF0F766E);
  static const Color primaryDark = Color(0xFF115E59);
  static const Color primaryLight = Color(0xFF14B8A6);

  // Secondary - Indigo (Innovation, Career)
  static const Color secondary = Color(0xFF4F46E5);
  static const Color secondaryDark = Color(0xFF4338CA);
  static const Color secondaryLight = Color(0xFF6366F1);

  // Accent - Orange (Action, Apply)
  static const Color accent = Color(0xFFF97316);
  static const Color accentLight = Color(0xFFFB923C);

  // Success - Green
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFF34D399);

  // Warning - Amber
  static const Color warning = Color(0xFFF59E0B);

  // Error - Red
  static const Color error = Color(0xFFEF4444);

  // Gradients
  static const List<Color> primaryGradient = [
    Color(0xFF0F766E),
    Color(0xFF14B8A6),
  ];

  static const List<Color> premiumGradient = [
    Color(0xFF1E1B4B),
    Color(0xFF312E81),
  ];

  static const List<Color> urgentGradient = [
    Color(0xFFDC2626),
    Color(0xFFF97316),
  ];

  static const List<Color> featuredGradient = [
    Color(0xFFF59E0B),
    Color(0xFFD97706),
  ];

  static const List<Color> techGradient = [
    Color(0xFF3B82F6),
    Color(0xFF06B6D4),
  ];

  // ============ LIGHT MODE ============
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textTertiaryLight = Color(0xFF94A3B8);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color dividerLight = Color(0xFFF1F5F9);

  // ============ DARK MODE ============
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color cardDark = Color(0xFF334155);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textTertiaryDark = Color(0xFF64748B);
  static const Color borderDark = Color(0xFF334155);
  static const Color dividerDark = Color(0xFF1E293B);

  // Helper methods
  static Color background(bool isDark) => isDark ? backgroundDark : backgroundLight;
  static Color surface(bool isDark) => isDark ? surfaceDark : surfaceLight;
  static Color card(bool isDark) => isDark ? cardDark : cardLight;
  static Color textPrimary(bool isDark) => isDark ? textPrimaryDark : textPrimaryLight;
  static Color textSecondary(bool isDark) => isDark ? textSecondaryDark : textSecondaryLight;
  static Color textTertiary(bool isDark) => isDark ? textTertiaryDark : textTertiaryLight;
  static Color border(bool isDark) => isDark ? borderDark : borderLight;
  static Color divider(bool isDark) => isDark ? dividerDark : dividerLight;
}

/// Demo data
class JobsDemoData {
  static final List<Company> companies = [
    Company(
      id: 'company_1',
      name: 'TechFlow',
      logoUrl: 'https://images.unsplash.com/photo-1614680376593-902f74cf0d41?w=200',
      website: 'https://techflow.com',
      industry: 'Teknoloji',
      size: '201-500 çalışan',
      description: 'Yenilikçi yazılım çözümleri sunan teknoloji şirketi',
      location: 'İstanbul, Maslak',
      rating: 4.7,
      reviewCount: 234,
      isVerified: true,
      foundedYear: DateTime(2015),
      benefits: ['health_insurance', 'flexible_hours', 'remote_work', 'training', 'meal_card'],
      culture: 'Yenilikçi, dinamik ve çalışan odaklı',
    ),
    Company(
      id: 'company_2',
      name: 'FinanceHub',
      logoUrl: 'https://images.unsplash.com/photo-1560472354-b33ff0c44a43?w=200',
      website: 'https://financehub.com.tr',
      industry: 'Finans',
      size: '501-1000 çalışan',
      description: 'Dijital bankacılık ve fintech çözümleri',
      location: 'İstanbul, Levent',
      rating: 4.5,
      reviewCount: 456,
      isVerified: true,
      foundedYear: DateTime(2010),
      benefits: ['health_insurance', 'bonus', 'stock_options', 'gym', 'shuttle'],
      culture: 'Kurumsal ve profesyonel',
    ),
    Company(
      id: 'company_3',
      name: 'CreativeStudio',
      logoUrl: 'https://images.unsplash.com/photo-1572044162444-ad60f128bdea?w=200',
      website: 'https://creativestudio.co',
      industry: 'Tasarım & Medya',
      size: '51-200 çalışan',
      description: 'Dijital tasarım ve marka deneyimi ajansı',
      location: 'İstanbul, Kadıköy',
      rating: 4.8,
      reviewCount: 89,
      isVerified: true,
      foundedYear: DateTime(2018),
      benefits: ['flexible_hours', 'remote_work', 'free_lunch', 'game_room', 'training'],
      culture: 'Yaratıcı ve rahat çalışma ortamı',
    ),
    Company(
      id: 'company_4',
      name: 'HealthPlus',
      logoUrl: 'https://images.unsplash.com/photo-1505751172876-fa1923c5c528?w=200',
      website: 'https://healthplus.com.tr',
      industry: 'Sağlık',
      size: '1001-5000 çalışan',
      description: 'Özel sağlık hizmetleri grubu',
      location: 'İstanbul',
      rating: 4.3,
      reviewCount: 678,
      isVerified: true,
      foundedYear: DateTime(2005),
      benefits: ['health_insurance', 'dental', 'paid_leave', 'retirement', 'parking'],
      culture: 'İnsan odaklı ve destekleyici',
    ),
  ];

  static final List<JobPoster> posters = [
    JobPoster(
      id: 'poster_1',
      name: 'Ayşe Kaya',
      title: 'İK Müdürü',
      phone: '+90 532 111 22 33',
      email: 'ayse.kaya@techflow.com',
      imageUrl: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=200',
      company: companies[0],
      isVerified: true,
      memberSince: DateTime(2020, 3, 15),
      activeListings: 8,
      totalHires: 45,
      responseRate: 95,
      responseTime: '2 saat içinde',
    ),
    JobPoster(
      id: 'poster_2',
      name: 'Mehmet Demir',
      title: 'Yetenek Kazanımı Uzmanı',
      phone: '+90 533 444 55 66',
      email: 'mehmet.demir@financehub.com',
      imageUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200',
      company: companies[1],
      isVerified: true,
      memberSince: DateTime(2019, 6, 1),
      activeListings: 12,
      totalHires: 89,
      responseRate: 98,
      responseTime: '1 saat içinde',
    ),
    JobPoster(
      id: 'poster_3',
      name: 'Zeynep Yılmaz',
      title: 'Kurucu Ortak',
      phone: '+90 535 777 88 99',
      email: 'zeynep@creativestudio.co',
      imageUrl: 'https://images.unsplash.com/photo-1580489944761-15a19d654956?w=200',
      company: companies[2],
      isVerified: true,
      memberSince: DateTime(2018, 9, 10),
      activeListings: 5,
      totalHires: 23,
      responseRate: 92,
      responseTime: '4 saat içinde',
    ),
  ];

  static List<JobListing> get listings => [
    JobListing(
      id: 'job_1',
      title: 'Senior Flutter Developer',
      description: '''TechFlow olarak büyüyen ekibimize katılacak deneyimli bir Flutter Developer arıyoruz!

## Sorumluluklar
• Mobil uygulamalarımızın Flutter ile geliştirilmesi ve bakımı
• Clean Architecture prensiplerine uygun kod yazılması
• State management çözümlerinin implementasyonu (BLoC, Riverpod)
• CI/CD pipeline'larının kurulumu ve yönetimi
• Junior developer'lara mentorluk yapılması
• Code review süreçlerine aktif katılım

## Aranan Nitelikler
• En az 4 yıl Flutter deneyimi
• Dart programlama dilinde ileri düzey bilgi
• State management pattern'lerine hakim
• RESTful API entegrasyonu deneyimi
• Git versiyon kontrol sistemi kullanımı
• İyi derecede İngilizce

## Tercih Sebebi
• Firebase deneyimi
• Native iOS/Android bilgisi
• CI/CD araçları deneyimi (Codemagic, Bitrise)
• Open source katkı deneyimi''',
      category: JobCategory.allCategories[0],
      subcategory: 'Mobil Geliştirme',
      jobType: JobType.fullTime,
      workArrangement: WorkArrangement.hybrid,
      experienceLevel: ExperienceLevel.senior,
      educationLevel: EducationLevel.bachelor,
      salary: const SalaryRange(min: 80000, max: 120000, period: SalaryPeriod.monthly),
      status: JobListingStatus.active,
      poster: posters[0],
      company: companies[0],
      city: 'İstanbul',
      district: 'Maslak',
      requiredSkills: ['flutter', 'dart', 'mobile', 'git'],
      preferredSkills: ['firebase', 'ios', 'android', 'ci/cd'],
      responsibilities: [
        'Mobil uygulamaların Flutter ile geliştirilmesi',
        'Clean Architecture prensiplerine uygun kod yazılması',
        'Code review süreçlerine katılım',
        'Junior developer\'lara mentorluk',
      ],
      qualifications: [
        'En az 4 yıl Flutter deneyimi',
        'Dart programlama dilinde ileri düzey bilgi',
        'State management pattern\'lerine hakimiyet',
        'İyi derecede İngilizce',
      ],
      benefitIds: ['health_insurance', 'flexible_hours', 'remote_work', 'training', 'meal_card', 'bonus'],
      positions: 2,
      deadline: DateTime.now().add(const Duration(days: 30)),
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      viewCount: 1250,
      applicationCount: 45,
      saveCount: 89,
      isFeatured: true,
      isPremiumListing: true,
      isUrgent: false,
    ),
    JobListing(
      id: 'job_2',
      title: 'UI/UX Designer',
      description: '''CreativeStudio'nun tasarım ekibine katılacak yaratıcı bir UI/UX Designer arıyoruz!

## Ne Yapacaksınız?
• Kullanıcı araştırmaları ve persona oluşturma
• Wireframe, mockup ve prototip tasarımı
• Tasarım sistemleri ve component library oluşturma
• Geliştirme ekibi ile yakın çalışma
• A/B testleri ve kullanılabilirlik testleri

## Aradığımız Özellikler
• 3+ yıl UI/UX tasarım deneyimi
• Figma, Sketch veya Adobe XD'de yetkinlik
• Kullanıcı araştırma metodolojileri bilgisi
• Güçlü portfolio
• İletişim becerileri''',
      category: JobCategory.allCategories[3],
      subcategory: 'UI/UX Tasarım',
      jobType: JobType.fullTime,
      workArrangement: WorkArrangement.remote,
      experienceLevel: ExperienceLevel.midLevel,
      educationLevel: EducationLevel.bachelor,
      salary: const SalaryRange(min: 50000, max: 75000, period: SalaryPeriod.monthly),
      status: JobListingStatus.active,
      poster: posters[2],
      company: companies[2],
      city: 'İstanbul',
      district: 'Kadıköy',
      requiredSkills: ['figma', 'ui/ux', 'prototyping', 'user research'],
      preferredSkills: ['motion design', 'illustration', 'html/css'],
      responsibilities: [
        'Kullanıcı araştırmaları yapma',
        'Wireframe ve prototip tasarımı',
        'Tasarım sistemleri oluşturma',
        'Geliştirme ekibi ile işbirliği',
      ],
      qualifications: [
        '3+ yıl UI/UX tasarım deneyimi',
        'Figma veya Sketch yetkinliği',
        'Güçlü portfolio',
      ],
      benefitIds: ['flexible_hours', 'remote_work', 'training', 'conference', 'books'],
      positions: 1,
      deadline: DateTime.now().add(const Duration(days: 21)),
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      viewCount: 890,
      applicationCount: 67,
      saveCount: 123,
      isFeatured: true,
      isPremiumListing: false,
      isUrgent: true,
    ),
    JobListing(
      id: 'job_3',
      title: 'Finansal Analist',
      description: '''FinanceHub bünyesinde çalışacak Finansal Analist arıyoruz.

## Görev Tanımı
• Finansal raporlama ve analiz
• Bütçe planlama ve takip
• Yatırım analizleri
• Yönetim raporlaması
• Risk değerlendirmesi

## Gereklilikler
• Finans, Ekonomi veya İşletme lisans derecesi
• 2-4 yıl finans deneyimi
• Excel ve finansal modelleme becerisi
• SAP veya Oracle deneyimi tercih sebebi
• CFA başlamış olmak avantaj''',
      category: JobCategory.allCategories[4],
      subcategory: 'Finansal Analiz',
      jobType: JobType.fullTime,
      workArrangement: WorkArrangement.onsite,
      experienceLevel: ExperienceLevel.midLevel,
      educationLevel: EducationLevel.bachelor,
      salary: const SalaryRange(min: 45000, max: 65000, period: SalaryPeriod.monthly),
      status: JobListingStatus.active,
      poster: posters[1],
      company: companies[1],
      city: 'İstanbul',
      district: 'Levent',
      requiredSkills: ['excel', 'financial modeling', 'reporting', 'sql'],
      preferredSkills: ['sap', 'python', 'power bi'],
      responsibilities: [
        'Finansal raporlama ve analiz',
        'Bütçe planlama',
        'Yatırım analizleri',
      ],
      qualifications: [
        'Finans, Ekonomi veya İşletme lisans derecesi',
        '2-4 yıl finans deneyimi',
        'Excel yetkinliği',
      ],
      benefitIds: ['health_insurance', 'bonus', 'retirement', 'meal_card', 'shuttle'],
      positions: 1,
      deadline: DateTime.now().add(const Duration(days: 14)),
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      viewCount: 456,
      applicationCount: 23,
      saveCount: 45,
      isFeatured: false,
      isPremiumListing: false,
      isUrgent: false,
    ),
    JobListing(
      id: 'job_4',
      title: 'Dijital Pazarlama Uzmanı',
      description: '''Dijital pazarlama stratejilerimizi yönetecek deneyimli bir uzman arıyoruz.

## Sorumluluklar
• Dijital pazarlama stratejisi geliştirme
• SEO/SEM kampanyaları yönetimi
• Sosyal medya yönetimi
• Performance marketing
• Analitik ve raporlama

## Aranan Nitelikler
• 3+ yıl dijital pazarlama deneyimi
• Google Ads ve Facebook Ads sertifikası
• Google Analytics deneyimi
• A/B test ve optimizasyon deneyimi''',
      category: JobCategory.allCategories[1],
      subcategory: 'Dijital Pazarlama',
      jobType: JobType.fullTime,
      workArrangement: WorkArrangement.hybrid,
      experienceLevel: ExperienceLevel.midLevel,
      educationLevel: EducationLevel.bachelor,
      salary: const SalaryRange(min: 40000, max: 55000, period: SalaryPeriod.monthly),
      status: JobListingStatus.active,
      poster: posters[0],
      company: companies[0],
      city: 'İstanbul',
      district: 'Maslak',
      requiredSkills: ['google ads', 'facebook ads', 'seo', 'analytics'],
      preferredSkills: ['hubspot', 'mailchimp', 'tableau'],
      responsibilities: [
        'Dijital pazarlama stratejisi geliştirme',
        'Kampanya yönetimi',
        'Performans analizi',
      ],
      qualifications: [
        '3+ yıl dijital pazarlama deneyimi',
        'Google ve Facebook Ads sertifikası',
        'Analytics deneyimi',
      ],
      benefitIds: ['health_insurance', 'flexible_hours', 'training', 'meal_card'],
      positions: 1,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      viewCount: 678,
      applicationCount: 34,
      saveCount: 56,
      isFeatured: false,
      isPremiumListing: false,
      isUrgent: false,
    ),
    JobListing(
      id: 'job_5',
      title: 'Backend Developer (Node.js)',
      description: '''Backend geliştirme ekibimize katılacak deneyimli bir Node.js Developer arıyoruz.

## Sorumluluklar
• RESTful API geliştirme
• Microservices mimarisi
• Veritabanı tasarımı ve optimizasyonu
• AWS/Cloud servisleri entegrasyonu
• Performans optimizasyonu

## Gereklilikler
• 3+ yıl Node.js deneyimi
• TypeScript bilgisi
• PostgreSQL/MongoDB deneyimi
• Docker ve Kubernetes bilgisi
• AWS servisleri deneyimi''',
      category: JobCategory.allCategories[0],
      subcategory: 'Web Geliştirme',
      jobType: JobType.fullTime,
      workArrangement: WorkArrangement.remote,
      experienceLevel: ExperienceLevel.midLevel,
      educationLevel: EducationLevel.bachelor,
      salary: const SalaryRange(min: 60000, max: 90000, period: SalaryPeriod.monthly),
      status: JobListingStatus.active,
      poster: posters[0],
      company: companies[0],
      city: 'İstanbul',
      requiredSkills: ['nodejs', 'typescript', 'postgresql', 'docker'],
      preferredSkills: ['kubernetes', 'aws', 'redis', 'graphql'],
      responsibilities: [
        'RESTful API geliştirme',
        'Microservices mimarisi tasarımı',
        'Veritabanı optimizasyonu',
      ],
      qualifications: [
        '3+ yıl Node.js deneyimi',
        'TypeScript bilgisi',
        'Cloud servisleri deneyimi',
      ],
      benefitIds: ['health_insurance', 'remote_work', 'stock_options', 'training', 'conference'],
      positions: 3,
      deadline: DateTime.now().add(const Duration(days: 45)),
      createdAt: DateTime.now().subtract(const Duration(hours: 12)),
      viewCount: 1567,
      applicationCount: 89,
      saveCount: 234,
      isFeatured: true,
      isPremiumListing: true,
      isUrgent: true,
    ),
    JobListing(
      id: 'job_6',
      title: 'İnsan Kaynakları Uzmanı',
      description: '''İK ekibimizi güçlendirecek bir İnsan Kaynakları Uzmanı arıyoruz.

## Görevler
• İşe alım süreçleri yönetimi
• Onboarding programları
• Performans yönetimi
• Çalışan ilişkileri
• İK politikaları geliştirme

## Gereklilikler
• İK veya ilgili alanda lisans derecesi
• 2+ yıl İK deneyimi
• İK yazılımları deneyimi
• İyi iletişim becerileri''',
      category: JobCategory.allCategories[5],
      subcategory: 'İşe Alım',
      jobType: JobType.fullTime,
      workArrangement: WorkArrangement.onsite,
      experienceLevel: ExperienceLevel.junior,
      educationLevel: EducationLevel.bachelor,
      salary: const SalaryRange(min: 30000, max: 40000, period: SalaryPeriod.monthly),
      status: JobListingStatus.active,
      poster: posters[1],
      company: companies[1],
      city: 'İstanbul',
      district: 'Levent',
      requiredSkills: ['recruitment', 'communication', 'hr software'],
      preferredSkills: ['performance management', 'training'],
      responsibilities: [
        'İşe alım süreçleri',
        'Onboarding programları',
        'Çalışan ilişkileri',
      ],
      qualifications: [
        'İK alanında lisans derecesi',
        '2+ yıl İK deneyimi',
        'İyi iletişim becerileri',
      ],
      benefitIds: ['health_insurance', 'paid_leave', 'training', 'shuttle'],
      positions: 1,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      viewCount: 345,
      applicationCount: 56,
      saveCount: 67,
      isFeatured: false,
      isPremiumListing: false,
      isUrgent: false,
    ),
    JobListing(
      id: 'job_7',
      title: 'Stajyer - Yazılım Geliştirme',
      description: '''Yazılım geliştirme ekibimizde staj yapacak yetenekli öğrenciler arıyoruz!

## Neler Öğreneceksiniz?
• Modern web teknolojileri
• Agile metodolojiler
• Profesyonel yazılım geliştirme süreçleri
• Takım çalışması

## Aranan Özellikler
• Bilgisayar Mühendisliği veya ilgili bölüm öğrencisi
• Temel programlama bilgisi
• Öğrenmeye açık
• Takım çalışmasına yatkın''',
      category: JobCategory.allCategories[0],
      subcategory: 'Yazılım Geliştirme',
      jobType: JobType.internship,
      workArrangement: WorkArrangement.hybrid,
      experienceLevel: ExperienceLevel.entry,
      educationLevel: EducationLevel.bachelor,
      salary: const SalaryRange(min: 12000, max: 15000, period: SalaryPeriod.monthly),
      status: JobListingStatus.active,
      poster: posters[0],
      company: companies[0],
      city: 'İstanbul',
      district: 'Maslak',
      requiredSkills: ['programming basics', 'teamwork', 'english'],
      preferredSkills: ['javascript', 'python', 'git'],
      responsibilities: [
        'Geliştirme projelerine destek',
        'Test ve dokümantasyon',
        'Takım toplantılarına katılım',
      ],
      qualifications: [
        'Bilgisayar Mühendisliği öğrencisi',
        'Temel programlama bilgisi',
        'Öğrenmeye açık',
      ],
      benefitIds: ['meal_card', 'training', 'mentorship'],
      positions: 5,
      deadline: DateTime.now().add(const Duration(days: 60)),
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      viewCount: 2345,
      applicationCount: 234,
      saveCount: 456,
      isFeatured: false,
      isPremiumListing: false,
      isUrgent: false,
    ),
    JobListing(
      id: 'job_8',
      title: 'Product Manager',
      description: '''Ürün yönetimi ekibimize katılacak deneyimli bir Product Manager arıyoruz.

## Sorumluluklar
• Ürün vizyonu ve roadmap oluşturma
• Kullanıcı araştırmaları
• Geliştirme ekibi ile koordinasyon
• KPI takibi ve analiz
• Stakeholder yönetimi

## Gereklilikler
• 5+ yıl ürün yönetimi deneyimi
• Teknik arka plan (tercihen)
• Data-driven karar alma
• Güçlü iletişim becerileri''',
      category: JobCategory.allCategories[6],
      subcategory: 'Proje Yönetimi',
      jobType: JobType.fullTime,
      workArrangement: WorkArrangement.hybrid,
      experienceLevel: ExperienceLevel.senior,
      educationLevel: EducationLevel.bachelor,
      salary: const SalaryRange(min: 90000, max: 130000, period: SalaryPeriod.monthly),
      status: JobListingStatus.active,
      poster: posters[0],
      company: companies[0],
      city: 'İstanbul',
      district: 'Maslak',
      requiredSkills: ['product management', 'agile', 'data analysis', 'communication'],
      preferredSkills: ['technical background', 'sql', 'a/b testing'],
      responsibilities: [
        'Ürün vizyonu oluşturma',
        'Roadmap yönetimi',
        'KPI takibi',
      ],
      qualifications: [
        '5+ yıl ürün yönetimi deneyimi',
        'Data-driven karar alma',
        'Güçlü iletişim',
      ],
      benefitIds: ['health_insurance', 'stock_options', 'flexible_hours', 'remote_work', 'bonus', 'conference'],
      positions: 1,
      deadline: DateTime.now().add(const Duration(days: 30)),
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
      viewCount: 1890,
      applicationCount: 78,
      saveCount: 167,
      isFeatured: true,
      isPremiumListing: true,
      isUrgent: false,
    ),
  ];

  static List<JobListing> get featuredListings =>
      listings.where((l) => l.isFeatured).toList();

  static List<JobListing> get urgentListings =>
      listings.where((l) => l.isUrgent).toList();

  static List<JobListing> get premiumListings =>
      listings.where((l) => l.isPremiumListing).toList();

  static List<JobListing> getListingsByCategory(String categoryId) =>
      listings.where((l) => l.category.id == categoryId).toList();

  static List<JobListing> getListingsByType(JobType type) =>
      listings.where((l) => l.jobType == type).toList();
}
