/// İş İlanları Data Modelleri - Supabase Entegrasyonu
/// Bu dosya veritabanından gelen verileri temsil eder

import 'package:flutter/material.dart';

// ==================== KATEGORİ ====================

class JobCategoryData {
  final String id;
  final String name;
  final String? icon;
  final String? color;
  final int sortOrder;
  final bool isActive;
  final DateTime? createdAt;

  const JobCategoryData({
    required this.id,
    required this.name,
    this.icon,
    this.color,
    this.sortOrder = 0,
    this.isActive = true,
    this.createdAt,
  });

  factory JobCategoryData.fromJson(Map<String, dynamic> json) {
    return JobCategoryData(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'color': color,
    'sort_order': sortOrder,
    'is_active': isActive,
  };

  Color get colorValue {
    if (color == null) return const Color(0xFF3B82F6);
    return Color(int.parse(color!.replaceFirst('#', '0xFF')));
  }

  IconData get iconData {
    // Icon mapping
    const iconMap = {
      'computer': Icons.computer,
      'campaign': Icons.campaign,
      'trending_up': Icons.trending_up,
      'palette': Icons.palette,
      'account_balance': Icons.account_balance,
      'people': Icons.people,
      'settings': Icons.settings,
      'support_agent': Icons.support_agent,
      'local_hospital': Icons.local_hospital,
      'menu_book': Icons.menu_book,
      'engineering': Icons.engineering,
      'gavel': Icons.gavel,
      'videocam': Icons.videocam,
      'hotel': Icons.hotel,
      'more_horiz': Icons.more_horiz,
    };
    return iconMap[icon] ?? Icons.work;
  }
}

class JobSubcategoryData {
  final String id;
  final String categoryId;
  final String name;
  final int sortOrder;
  final bool isActive;

  const JobSubcategoryData({
    required this.id,
    required this.categoryId,
    required this.name,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory JobSubcategoryData.fromJson(Map<String, dynamic> json) {
    return JobSubcategoryData(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      name: json['name'] as String,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

// ==================== YETENEK ====================

class JobSkillData {
  final String id;
  final String name;
  final String? category;
  final bool isPopular;
  final int usageCount;
  final bool isRequired;

  const JobSkillData({
    required this.id,
    required this.name,
    this.category,
    this.isPopular = false,
    this.usageCount = 0,
    this.isRequired = true,
  });

  factory JobSkillData.fromJson(Map<String, dynamic> json) {
    return JobSkillData(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String?,
      isPopular: json['is_popular'] as bool? ?? false,
      usageCount: json['usage_count'] as int? ?? 0,
    );
  }

  JobSkillData copyWith({bool? isRequired}) {
    return JobSkillData(
      id: id,
      name: name,
      category: category,
      isPopular: isPopular,
      usageCount: usageCount,
      isRequired: isRequired ?? this.isRequired,
    );
  }
}

// ==================== YAN HAK ====================

class JobBenefitData {
  final String id;
  final String name;
  final String? icon;
  final String? category;
  final int sortOrder;

  const JobBenefitData({
    required this.id,
    required this.name,
    this.icon,
    this.category,
    this.sortOrder = 0,
  });

  factory JobBenefitData.fromJson(Map<String, dynamic> json) {
    return JobBenefitData(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      category: json['category'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  IconData get iconData {
    const iconMap = {
      'health_and_safety': Icons.health_and_safety,
      'medical_services': Icons.medical_services,
      'fitness_center': Icons.fitness_center,
      'psychology': Icons.psychology,
      'monetization_on': Icons.monetization_on,
      'savings': Icons.savings,
      'restaurant': Icons.restaurant,
      'local_gas_station': Icons.local_gas_station,
      'phone_android': Icons.phone_android,
      'schedule': Icons.schedule,
      'home_work': Icons.home_work,
      'beach_access': Icons.beach_access,
      'child_care': Icons.child_care,
      'flight_takeoff': Icons.flight_takeoff,
      'school': Icons.school,
      'card_membership': Icons.card_membership,
      'groups': Icons.groups,
      'menu_book': Icons.menu_book,
      'lunch_dining': Icons.lunch_dining,
      'local_cafe': Icons.local_cafe,
      'sports_esports': Icons.sports_esports,
      'pets': Icons.pets,
      'local_parking': Icons.local_parking,
      'directions_bus': Icons.directions_bus,
    };
    return iconMap[icon] ?? Icons.check_circle;
  }
}

// ==================== ŞİRKET ====================

class CompanyData {
  final String id;
  final String? userId;
  final String name;
  final String? logoUrl;
  final String? coverUrl;
  final String? website;
  final String? email;
  final String? phone;
  final String? industry;
  final String? size;
  final String? description;
  final String? culture;
  final int? foundedYear;
  final String? city;
  final String? district;
  final String? address;
  final double? latitude;
  final double? longitude;
  final double rating;
  final int reviewCount;
  final int activeListings;
  final int totalHires;
  final bool isVerified;
  final bool isPremium;
  final String status;
  final DateTime? createdAt;

  const CompanyData({
    required this.id,
    this.userId,
    required this.name,
    this.logoUrl,
    this.coverUrl,
    this.website,
    this.email,
    this.phone,
    this.industry,
    this.size,
    this.description,
    this.culture,
    this.foundedYear,
    this.city,
    this.district,
    this.address,
    this.latitude,
    this.longitude,
    this.rating = 0,
    this.reviewCount = 0,
    this.activeListings = 0,
    this.totalHires = 0,
    this.isVerified = false,
    this.isPremium = false,
    this.status = 'pending',
    this.createdAt,
  });

  factory CompanyData.fromJson(Map<String, dynamic> json) {
    return CompanyData(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      name: json['name'] as String,
      logoUrl: json['logo_url'] as String?,
      coverUrl: json['cover_url'] as String?,
      website: json['website'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      industry: json['industry'] as String?,
      size: json['size'] as String?,
      description: json['description'] as String?,
      culture: json['culture'] as String?,
      foundedYear: json['founded_year'] as int?,
      city: json['city'] as String?,
      district: json['district'] as String?,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: json['review_count'] as int? ?? 0,
      activeListings: json['active_listings'] as int? ?? 0,
      totalHires: json['total_hires'] as int? ?? 0,
      isVerified: json['is_verified'] as bool? ?? false,
      isPremium: json['is_premium'] as bool? ?? false,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }
}

// ==================== İŞVEREN/POSTER ====================

class JobPosterData {
  final String id;
  final String userId;
  final String? companyId;
  final String name;
  final String? title;
  final String? phone;
  final String? email;
  final String? imageUrl;
  final int activeListings;
  final int totalHires;
  final int responseRate;
  final String? avgResponseTime;
  final bool isVerified;
  final String status;
  final DateTime? createdAt;
  final CompanyData? company;

  const JobPosterData({
    required this.id,
    required this.userId,
    this.companyId,
    required this.name,
    this.title,
    this.phone,
    this.email,
    this.imageUrl,
    this.activeListings = 0,
    this.totalHires = 0,
    this.responseRate = 0,
    this.avgResponseTime,
    this.isVerified = false,
    this.status = 'active',
    this.createdAt,
    this.company,
  });

  factory JobPosterData.fromJson(Map<String, dynamic> json) {
    return JobPosterData(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      companyId: json['company_id'] as String?,
      name: json['name'] as String,
      title: json['title'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      imageUrl: json['image_url'] as String?,
      activeListings: json['active_listings'] as int? ?? 0,
      totalHires: json['total_hires'] as int? ?? 0,
      responseRate: json['response_rate'] as int? ?? 0,
      avgResponseTime: json['avg_response_time'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      company: json['company'] != null
          ? CompanyData.fromJson(json['company'] as Map<String, dynamic>)
          : null,
    );
  }

  String get displayName => company?.name ?? name;
}

// ==================== İŞ İLANI ====================

class JobListingData {
  final String id;
  final String userId;
  final String? posterId;
  final String? companyId;

  // Temel bilgiler
  final String title;
  final String description;
  final String? categoryId;
  final String? subcategory;

  // İş detayları
  final String jobType;
  final String workArrangement;
  final String experienceLevel;
  final String educationLevel;

  // Maaş
  final double? salaryMin;
  final double? salaryMax;
  final String salaryCurrency;
  final String salaryPeriod;
  final bool isSalaryHidden;
  final bool isSalaryNegotiable;

  // Konum
  final String city;
  final String? district;
  final String? address;
  final double? latitude;
  final double? longitude;

  // Ek bilgiler
  final int positions;
  final List<String> responsibilities;
  final List<String> qualifications;
  final List<String> requiredSkills;
  final List<String> manualBenefits;
  final String? externalLink;

  // Tarihler
  final DateTime? deadline;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? expiresAt;

  // İstatistikler
  final int viewCount;
  final int applicationCount;
  final int favoriteCount;
  final int shareCount;

  // Durum ve öne çıkarma
  final String status;
  final bool isFeatured;
  final bool isPremium;
  final bool isUrgent;
  final DateTime? featuredUntil;
  final DateTime? premiumUntil;

  // İlişkili veriler
  final JobPosterData? poster;
  final CompanyData? company;

  const JobListingData({
    required this.id,
    required this.userId,
    this.posterId,
    this.companyId,
    required this.title,
    required this.description,
    this.categoryId,
    this.subcategory,
    required this.jobType,
    required this.workArrangement,
    required this.experienceLevel,
    required this.educationLevel,
    this.salaryMin,
    this.salaryMax,
    this.salaryCurrency = 'TRY',
    this.salaryPeriod = 'monthly',
    this.isSalaryHidden = false,
    this.isSalaryNegotiable = false,
    required this.city,
    this.district,
    this.address,
    this.latitude,
    this.longitude,
    this.positions = 1,
    this.responsibilities = const [],
    this.qualifications = const [],
    this.requiredSkills = const [],
    this.manualBenefits = const [],
    this.externalLink,
    this.deadline,
    this.publishedAt,
    required this.createdAt,
    this.updatedAt,
    this.expiresAt,
    this.viewCount = 0,
    this.applicationCount = 0,
    this.favoriteCount = 0,
    this.shareCount = 0,
    this.status = 'pending',
    this.isFeatured = false,
    this.isPremium = false,
    this.isUrgent = false,
    this.featuredUntil,
    this.premiumUntil,
    this.poster,
    this.company,
  });

  factory JobListingData.fromJson(Map<String, dynamic> json) {
    return JobListingData(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      posterId: json['poster_id'] as String?,
      companyId: json['company_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String,
      categoryId: json['category_id'] as String?,
      subcategory: json['subcategory'] as String?,
      jobType: json['job_type'] as String? ?? 'full_time',
      workArrangement: json['work_arrangement'] as String? ?? 'onsite',
      experienceLevel: json['experience_level'] as String? ?? 'mid_level',
      educationLevel: json['education_level'] as String? ?? 'no_requirement',
      salaryMin: (json['salary_min'] as num?)?.toDouble(),
      salaryMax: (json['salary_max'] as num?)?.toDouble(),
      salaryCurrency: json['salary_currency'] as String? ?? 'TRY',
      salaryPeriod: json['salary_period'] as String? ?? 'monthly',
      isSalaryHidden: json['is_salary_hidden'] as bool? ?? false,
      isSalaryNegotiable: json['is_salary_negotiable'] as bool? ?? false,
      city: json['city'] as String,
      district: json['district'] as String?,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      positions: json['positions'] as int? ?? 1,
      responsibilities: (json['responsibilities'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      qualifications: (json['qualifications'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      requiredSkills: (json['required_skills'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      manualBenefits: (json['manual_benefits'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      externalLink: json['external_link'] as String?,
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'] as String)
          : null,
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      viewCount: json['view_count'] as int? ?? 0,
      applicationCount: json['application_count'] as int? ?? 0,
      favoriteCount: json['favorite_count'] as int? ?? 0,
      shareCount: json['share_count'] as int? ?? 0,
      status: json['status'] as String? ?? 'pending',
      isFeatured: json['is_featured'] as bool? ?? false,
      isPremium: json['is_premium'] as bool? ?? false,
      isUrgent: json['is_urgent'] as bool? ?? false,
      featuredUntil: json['featured_until'] != null
          ? DateTime.parse(json['featured_until'] as String)
          : null,
      premiumUntil: json['premium_until'] != null
          ? DateTime.parse(json['premium_until'] as String)
          : null,
      poster: json['poster'] != null
          ? JobPosterData.fromJson(json['poster'] as Map<String, dynamic>)
          : null,
      company: json['company'] != null
          ? CompanyData.fromJson(json['company'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'category_id': categoryId,
    'subcategory': subcategory,
    'job_type': jobType,
    'work_arrangement': workArrangement,
    'experience_level': experienceLevel,
    'education_level': educationLevel,
    'salary_min': salaryMin,
    'salary_max': salaryMax,
    'salary_currency': salaryCurrency,
    'salary_period': salaryPeriod,
    'is_salary_hidden': isSalaryHidden,
    'is_salary_negotiable': isSalaryNegotiable,
    'city': city,
    'district': district,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'positions': positions,
    'responsibilities': responsibilities,
    'qualifications': qualifications,
    'external_link': externalLink,
    'deadline': deadline?.toIso8601String(),
  };

  // Helper getters
  String get location => district != null ? '$district, $city' : city;

  String get companyName => company?.name ?? poster?.name ?? 'Şirket';

  String? get companyLogo => company?.logoUrl ?? poster?.imageUrl;

  String get salaryFormatted {
    if (isSalaryHidden) return 'Görüşülür';
    if (salaryMin == null && salaryMax == null) return 'Belirtilmemiş';

    String formatNum(double num) {
      if (num >= 1000) {
        return '${(num / 1000).toStringAsFixed(0)}K';
      }
      return num.toStringAsFixed(0);
    }

    final periodLabel = {
      'hourly': 'saat',
      'daily': 'gün',
      'weekly': 'hafta',
      'monthly': 'ay',
      'yearly': 'yıl',
    }[salaryPeriod] ?? 'ay';

    if (salaryMin != null && salaryMax != null) {
      return '${formatNum(salaryMin!)} - ${formatNum(salaryMax!)} $salaryCurrency/$periodLabel';
    } else if (salaryMin != null) {
      return '${formatNum(salaryMin!)}+ $salaryCurrency/$periodLabel';
    } else {
      return '${formatNum(salaryMax!)} $salaryCurrency/$periodLabel\'e kadar';
    }
  }

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

  // Job type labels
  String get jobTypeLabel {
    const labels = {
      'full_time': 'Tam Zamanlı',
      'part_time': 'Yarı Zamanlı',
      'contract': 'Sözleşmeli',
      'internship': 'Staj',
      'freelance': 'Freelance',
      'remote': 'Uzaktan',
      'temporary': 'Geçici',
    };
    return labels[jobType] ?? jobType;
  }

  String get workArrangementLabel {
    const labels = {
      'onsite': 'Ofiste',
      'remote': 'Uzaktan',
      'hybrid': 'Hibrit',
    };
    return labels[workArrangement] ?? workArrangement;
  }

  String get experienceLevelLabel {
    const labels = {
      'entry': 'Giriş Seviye',
      'junior': 'Junior',
      'mid_level': 'Orta Seviye',
      'senior': 'Senior',
      'lead': 'Lead/Manager',
      'director': 'Direktör',
      'executive': 'Üst Düzey',
    };
    return labels[experienceLevel] ?? experienceLevel;
  }

  String get educationLevelLabel {
    const labels = {
      'high_school': 'Lise',
      'associate': 'Ön Lisans',
      'bachelor': 'Lisans',
      'master': 'Yüksek Lisans',
      'doctorate': 'Doktora',
      'no_requirement': 'Önemli Değil',
    };
    return labels[educationLevel] ?? educationLevel;
  }

  Color get jobTypeColor {
    const colors = {
      'full_time': Color(0xFF3B82F6),
      'part_time': Color(0xFF8B5CF6),
      'contract': Color(0xFFF59E0B),
      'internship': Color(0xFF10B981),
      'freelance': Color(0xFFEC4899),
      'remote': Color(0xFF06B6D4),
      'temporary': Color(0xFFEF4444),
    };
    return colors[jobType] ?? const Color(0xFF3B82F6);
  }

  Color get workArrangementColor {
    const colors = {
      'onsite': Color(0xFF3B82F6),
      'remote': Color(0xFF10B981),
      'hybrid': Color(0xFF8B5CF6),
    };
    return colors[workArrangement] ?? const Color(0xFF3B82F6);
  }

  IconData get jobTypeIcon {
    const icons = {
      'full_time': Icons.work,
      'part_time': Icons.work_outline,
      'contract': Icons.assignment,
      'internship': Icons.school,
      'freelance': Icons.laptop_mac,
      'remote': Icons.home_work,
      'temporary': Icons.timer,
    };
    return icons[jobType] ?? Icons.work;
  }

  IconData get workArrangementIcon {
    const icons = {
      'onsite': Icons.business,
      'remote': Icons.home,
      'hybrid': Icons.swap_horiz,
    };
    return icons[workArrangement] ?? Icons.business;
  }
}

// ==================== BAŞVURU ====================

class JobApplicationData {
  final String id;
  final String listingId;
  final String userId;
  final String? posterId;
  final String applicantName;
  final String applicantEmail;
  final String? applicantPhone;
  final String? coverLetter;
  final String? resumeUrl;
  final List<String> portfolioLinks;
  final String status;
  final String? notes;
  final DateTime appliedAt;
  final DateTime? reviewedAt;
  final DateTime? updatedAt;
  final JobListingData? listing;

  const JobApplicationData({
    required this.id,
    required this.listingId,
    required this.userId,
    this.posterId,
    required this.applicantName,
    required this.applicantEmail,
    this.applicantPhone,
    this.coverLetter,
    this.resumeUrl,
    this.portfolioLinks = const [],
    this.status = 'pending',
    this.notes,
    required this.appliedAt,
    this.reviewedAt,
    this.updatedAt,
    this.listing,
  });

  factory JobApplicationData.fromJson(Map<String, dynamic> json) {
    return JobApplicationData(
      id: json['id'] as String,
      listingId: json['listing_id'] as String,
      userId: json['user_id'] as String,
      posterId: json['poster_id'] as String?,
      applicantName: json['applicant_name'] as String,
      applicantEmail: json['applicant_email'] as String,
      applicantPhone: json['applicant_phone'] as String?,
      coverLetter: json['cover_letter'] as String?,
      resumeUrl: json['resume_url'] as String?,
      portfolioLinks: (json['portfolio_links'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      status: json['status'] as String? ?? 'pending',
      notes: json['notes'] as String?,
      appliedAt: DateTime.parse(json['applied_at'] as String),
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      listing: json['listing'] != null
          ? JobListingData.fromJson(json['listing'] as Map<String, dynamic>)
          : null,
    );
  }

  String get statusLabel {
    const labels = {
      'pending': 'Beklemede',
      'reviewed': 'İncelendi',
      'shortlisted': 'Ön Eleme Geçti',
      'interview': 'Mülakat',
      'offered': 'Teklif Verildi',
      'hired': 'İşe Alındı',
      'rejected': 'Reddedildi',
    };
    return labels[status] ?? status;
  }

  Color get statusColor {
    const colors = {
      'pending': Color(0xFFF59E0B),
      'reviewed': Color(0xFF3B82F6),
      'shortlisted': Color(0xFF8B5CF6),
      'interview': Color(0xFF06B6D4),
      'offered': Color(0xFF10B981),
      'hired': Color(0xFF059669),
      'rejected': Color(0xFFEF4444),
    };
    return colors[status] ?? const Color(0xFF6B7280);
  }

  IconData get statusIcon {
    const icons = {
      'pending': Icons.hourglass_empty,
      'reviewed': Icons.visibility,
      'shortlisted': Icons.star,
      'interview': Icons.groups,
      'offered': Icons.handshake,
      'hired': Icons.celebration,
      'rejected': Icons.cancel,
    };
    return icons[status] ?? Icons.help_outline;
  }
}

// ==================== PROMOSYON ====================

class JobPromotionPrice {
  final String id;
  final String promotionType;
  final int durationDays;
  final double price;
  final double? discountedPrice;
  final Map<String, dynamic>? benefits;
  final bool isActive;

  const JobPromotionPrice({
    required this.id,
    required this.promotionType,
    required this.durationDays,
    required this.price,
    this.discountedPrice,
    this.benefits,
    this.isActive = true,
  });

  factory JobPromotionPrice.fromJson(Map<String, dynamic> json) {
    return JobPromotionPrice(
      id: json['id'] as String,
      promotionType: json['promotion_type'] as String,
      durationDays: json['duration_days'] as int,
      price: (json['price'] as num).toDouble(),
      discountedPrice: (json['discounted_price'] as num?)?.toDouble(),
      benefits: json['benefits'] as Map<String, dynamic>?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  double get effectivePrice => discountedPrice ?? price;

  String get promotionTypeLabel {
    const labels = {
      'featured': 'Öne Çıkarma',
      'premium': 'Premium',
      'urgent': 'Acil',
    };
    return labels[promotionType] ?? promotionType;
  }

  String get durationLabel => '$durationDays gün';
}
