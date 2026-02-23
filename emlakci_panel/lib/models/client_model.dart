/// Realtor Client (CRM) Model
/// DB Table: realtor_clients

/// Client status enum
enum ClientStatus {
  potential('Potansiyel'),
  active('Aktif'),
  closed('Kapandı'),
  lost('Kayıp');

  final String label;
  const ClientStatus(this.label);

  static ClientStatus fromString(String? value) {
    return ClientStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ClientStatus.potential,
    );
  }
}

class RealtorClient {
  final String id;
  final String realtorId;
  final String? userId;
  final String name;
  final String? phone;
  final String? email;
  final String? lookingFor;
  final String? propertyType;
  final double? budgetMin;
  final double? budgetMax;
  final List<String> preferredCities;
  final List<String> preferredDistricts;
  final ClientStatus status;
  final String? source;
  final String? notes;
  final DateTime? lastContactAt;
  final DateTime? nextFollowupAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const RealtorClient({
    required this.id,
    required this.realtorId,
    this.userId,
    required this.name,
    this.phone,
    this.email,
    this.lookingFor,
    this.propertyType,
    this.budgetMin,
    this.budgetMax,
    this.preferredCities = const [],
    this.preferredDistricts = const [],
    this.status = ClientStatus.potential,
    this.source,
    this.notes,
    this.lastContactAt,
    this.nextFollowupAt,
    required this.createdAt,
    this.updatedAt,
  });

  factory RealtorClient.fromJson(Map<String, dynamic> json) {
    return RealtorClient(
      id: json['id'] as String,
      realtorId: json['realtor_id'] as String,
      userId: json['user_id'] as String?,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      lookingFor: json['looking_for'] as String?,
      propertyType: json['property_type'] as String?,
      budgetMin: (json['budget_min'] as num?)?.toDouble(),
      budgetMax: (json['budget_max'] as num?)?.toDouble(),
      preferredCities: (json['preferred_cities'] as List<dynamic>?)
              ?.cast<String>() ??
          [],
      preferredDistricts: (json['preferred_districts'] as List<dynamic>?)
              ?.cast<String>() ??
          [],
      status: ClientStatus.fromString(json['status'] as String?),
      source: json['source'] as String?,
      notes: json['notes'] as String?,
      lastContactAt: json['last_contact_at'] != null
          ? DateTime.parse(json['last_contact_at'] as String)
          : null,
      nextFollowupAt: json['next_followup_at'] != null
          ? DateTime.parse(json['next_followup_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Convert to JSON for insert/update (excludes id, created_at, updated_at)
  Map<String, dynamic> toJson() {
    return {
      'realtor_id': realtorId,
      if (userId != null) 'user_id': userId,
      'name': name,
      'phone': phone,
      'email': email,
      'looking_for': lookingFor,
      'property_type': propertyType,
      'budget_min': budgetMin,
      'budget_max': budgetMax,
      'preferred_cities': preferredCities,
      'preferred_districts': preferredDistricts,
      'status': status.name,
      'source': source,
      'notes': notes,
      if (lastContactAt != null)
        'last_contact_at': lastContactAt!.toIso8601String(),
      if (nextFollowupAt != null)
        'next_followup_at': nextFollowupAt!.toIso8601String(),
    };
  }

  RealtorClient copyWith({
    String? id,
    String? realtorId,
    String? userId,
    String? name,
    String? phone,
    String? email,
    String? lookingFor,
    String? propertyType,
    double? budgetMin,
    double? budgetMax,
    List<String>? preferredCities,
    List<String>? preferredDistricts,
    ClientStatus? status,
    String? source,
    String? notes,
    DateTime? lastContactAt,
    DateTime? nextFollowupAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RealtorClient(
      id: id ?? this.id,
      realtorId: realtorId ?? this.realtorId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      lookingFor: lookingFor ?? this.lookingFor,
      propertyType: propertyType ?? this.propertyType,
      budgetMin: budgetMin ?? this.budgetMin,
      budgetMax: budgetMax ?? this.budgetMax,
      preferredCities: preferredCities ?? this.preferredCities,
      preferredDistricts: preferredDistricts ?? this.preferredDistricts,
      status: status ?? this.status,
      source: source ?? this.source,
      notes: notes ?? this.notes,
      lastContactAt: lastContactAt ?? this.lastContactAt,
      nextFollowupAt: nextFollowupAt ?? this.nextFollowupAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Formatted budget range string
  String get formattedBudget {
    if (budgetMin == null && budgetMax == null) return 'Belirtilmemiş';
    if (budgetMin != null && budgetMax != null) {
      return '${_formatPrice(budgetMin!)} - ${_formatPrice(budgetMax!)}';
    }
    if (budgetMin != null) return '${_formatPrice(budgetMin!)}+';
    return '${_formatPrice(budgetMax!)} altı';
  }

  static String _formatPrice(double price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M TL';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K TL';
    }
    return '${price.toStringAsFixed(0)} TL';
  }

  /// Whether follow-up is due (today or past)
  bool get isFollowupDue {
    if (nextFollowupAt == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final followup = DateTime(
      nextFollowupAt!.year,
      nextFollowupAt!.month,
      nextFollowupAt!.day,
    );
    return !followup.isAfter(today);
  }
}
