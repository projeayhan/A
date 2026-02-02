import 'package:flutter/material.dart';
import 'job_models.dart';
import 'job_data_models.dart';

/// JobListingData'dan UI modeline dönüşüm extension'ı
extension JobListingDataToUI on JobListingData {
  /// JobListingData'yı JobListing UI modeline dönüştürür
  JobListing toUIModel() {
    return JobListing(
      id: id,
      title: title,
      description: description,
      category: _findCategory(categoryId),
      subcategory: subcategory,
      jobType: _parseJobType(jobType),
      workArrangement: _parseWorkArrangement(workArrangement),
      experienceLevel: _parseExperienceLevel(experienceLevel),
      educationLevel: _parseEducationLevel(educationLevel),
      salary: SalaryRange(
        min: salaryMin,
        max: salaryMax,
        currency: salaryCurrency,
        period: _parseSalaryPeriod(salaryPeriod),
        isNegotiable: isSalaryNegotiable,
        isHidden: isSalaryHidden,
      ),
      status: _parseStatus(status),
      poster: _createPoster(),
      company: company != null ? _createCompany(company!) : null,
      city: city,
      district: district,
      address: address,
      requiredSkills: [],
      preferredSkills: [],
      responsibilities: responsibilities,
      qualifications: qualifications,
      benefitIds: [],
      positions: positions,
      deadline: deadline,
      createdAt: createdAt,
      updatedAt: updatedAt,
      viewCount: viewCount,
      applicationCount: applicationCount,
      saveCount: favoriteCount,
      isFeatured: isFeatured,
      isPremiumListing: isPremium,
      isUrgent: isUrgent,
      externalLink: externalLink,
      latitude: latitude,
      longitude: longitude,
    );
  }

  JobCategory _findCategory(String? categoryId) {
    if (categoryId == null) {
      return JobCategory.allCategories.first;
    }
    return JobCategory.allCategories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => JobCategory.allCategories.first,
    );
  }

  JobType _parseJobType(String type) {
    const mapping = {
      'full_time': JobType.fullTime,
      'part_time': JobType.partTime,
      'contract': JobType.contract,
      'internship': JobType.internship,
      'freelance': JobType.freelance,
      'remote': JobType.remote,
      'temporary': JobType.temporary,
    };
    return mapping[type] ?? JobType.fullTime;
  }

  WorkArrangement _parseWorkArrangement(String arrangement) {
    const mapping = {
      'onsite': WorkArrangement.onsite,
      'remote': WorkArrangement.remote,
      'hybrid': WorkArrangement.hybrid,
    };
    return mapping[arrangement] ?? WorkArrangement.onsite;
  }

  ExperienceLevel _parseExperienceLevel(String level) {
    const mapping = {
      'entry': ExperienceLevel.entry,
      'junior': ExperienceLevel.junior,
      'mid_level': ExperienceLevel.midLevel,
      'senior': ExperienceLevel.senior,
      'lead': ExperienceLevel.lead,
      'director': ExperienceLevel.director,
      'executive': ExperienceLevel.executive,
    };
    return mapping[level] ?? ExperienceLevel.midLevel;
  }

  EducationLevel _parseEducationLevel(String level) {
    const mapping = {
      'high_school': EducationLevel.highSchool,
      'associate': EducationLevel.associate,
      'bachelor': EducationLevel.bachelor,
      'master': EducationLevel.master,
      'doctorate': EducationLevel.doctorate,
      'no_requirement': EducationLevel.noRequirement,
    };
    return mapping[level] ?? EducationLevel.noRequirement;
  }

  SalaryPeriod _parseSalaryPeriod(String period) {
    const mapping = {
      'hourly': SalaryPeriod.hourly,
      'daily': SalaryPeriod.daily,
      'weekly': SalaryPeriod.weekly,
      'monthly': SalaryPeriod.monthly,
      'yearly': SalaryPeriod.yearly,
    };
    return mapping[period] ?? SalaryPeriod.monthly;
  }

  JobListingStatus _parseStatus(String status) {
    const mapping = {
      'pending': JobListingStatus.pending,
      'active': JobListingStatus.active,
      'closed': JobListingStatus.closed,
      'filled': JobListingStatus.filled,
      'expired': JobListingStatus.expired,
    };
    return mapping[status] ?? JobListingStatus.active;
  }

  JobPoster _createPoster() {
    if (poster != null) {
      return JobPoster(
        id: poster!.id,
        name: poster!.name,
        title: poster!.title,
        phone: poster!.phone ?? '',
        email: poster!.email,
        imageUrl: poster!.imageUrl,
        company: poster!.company != null ? _createCompany(poster!.company!) : null,
        isVerified: poster!.isVerified,
        memberSince: poster!.createdAt ?? DateTime.now(),
        activeListings: poster!.activeListings,
        totalHires: poster!.totalHires,
        responseRate: poster!.responseRate.toDouble(),
        responseTime: poster!.avgResponseTime,
      );
    }

    // Fallback poster
    return JobPoster(
      id: 'unknown',
      name: companyName,
      phone: '',
      memberSince: createdAt,
    );
  }

  Company _createCompany(CompanyData data) {
    return Company(
      id: data.id,
      name: data.name,
      logoUrl: data.logoUrl,
      website: data.website,
      industry: data.industry ?? 'Teknoloji',
      size: data.size ?? '1-10 çalışan',
      description: data.description,
      location: data.city,
      rating: data.rating,
      reviewCount: data.reviewCount,
      isVerified: data.isVerified,
      foundedYear: DateTime(data.foundedYear ?? 2020),
      benefits: [],
      culture: data.culture,
    );
  }
}

/// Liste dönüşümü için extension
extension JobListingDataListToUI on List<JobListingData> {
  List<JobListing> toUIModels() {
    return map((data) => data.toUIModel()).toList();
  }
}

/// JobCategoryData'dan UI modeline dönüşüm
extension JobCategoryDataToUI on JobCategoryData {
  JobCategory toUIModel() {
    return JobCategory(
      id: id,
      name: name,
      icon: iconData,
      color: colorValue,
      subcategories: [], // Alt kategoriler ayrı sorgulanacak
    );
  }
}

/// Liste dönüşümü için extension
extension JobCategoryDataListToUI on List<JobCategoryData> {
  List<JobCategory> toUIModels() {
    return map((data) => data.toUIModel()).toList();
  }
}
