import 'package:supabase_flutter/supabase_flutter.dart';

/// Randevu durumu
enum AppointmentStatus {
  pending('Beklemede'),
  confirmed('Onaylandı'),
  cancelled('İptal Edildi'),
  completed('Tamamlandı');

  final String label;
  const AppointmentStatus(this.label);
}

/// Randevu modeli
class Appointment {
  final String id;
  final String propertyId;
  final String requesterId;
  final String ownerId;
  final DateTime appointmentDate;
  final String appointmentTime;
  final AppointmentStatus status;
  final String? note;
  final String? responseNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  // İlişkili veriler
  final Map<String, dynamic>? property;
  final Map<String, dynamic>? requesterProfile;
  final Map<String, dynamic>? ownerProfile;

  const Appointment({
    required this.id,
    required this.propertyId,
    required this.requesterId,
    required this.ownerId,
    required this.appointmentDate,
    required this.appointmentTime,
    this.status = AppointmentStatus.pending,
    this.note,
    this.responseNote,
    required this.createdAt,
    required this.updatedAt,
    this.property,
    this.requesterProfile,
    this.ownerProfile,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'] as String,
      propertyId: json['property_id'] as String,
      requesterId: json['requester_id'] as String,
      ownerId: json['owner_id'] as String,
      appointmentDate: DateTime.parse(json['appointment_date'] as String),
      appointmentTime: json['appointment_time'] as String,
      status: AppointmentStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => AppointmentStatus.pending,
      ),
      note: json['note'] as String?,
      responseNote: json['response_note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      property: json['properties'] as Map<String, dynamic>?,
      requesterProfile: json['requester_profile'] as Map<String, dynamic>?,
      ownerProfile: json['owner_profile'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'property_id': propertyId,
      'requester_id': requesterId,
      'owner_id': ownerId,
      'appointment_date': appointmentDate.toIso8601String().split('T').first,
      'appointment_time': appointmentTime,
      'status': status.name,
      'note': note,
    };
  }

  /// İlan başlığını al
  String? get propertyTitle => property?['title'] as String?;

  /// İlan resmini al
  String? get propertyImage {
    final images = property?['images'] as List<dynamic>?;
    return images?.isNotEmpty == true ? images!.first as String : null;
  }

  /// Formatlanmış tarih
  String get formattedDate {
    final months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    return '${appointmentDate.day} ${months[appointmentDate.month - 1]} ${appointmentDate.year}';
  }

  /// Formatlanmış saat
  String get formattedTime => appointmentTime.substring(0, 5);
}

/// Randevu servisi
class AppointmentService {
  static final AppointmentService _instance = AppointmentService._internal();
  factory AppointmentService() => _instance;
  AppointmentService._internal();

  SupabaseClient get _client => Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;

  // ==================== RANDEVU OLUŞTURMA ====================

  /// Yeni randevu oluştur
  Future<Appointment?> createAppointment({
    required String propertyId,
    required String ownerId,
    required DateTime date,
    required String time,
    String? note,
  }) async {
    if (_userId == null) {
      throw Exception('Kullanıcı oturumu bulunamadı');
    }

    final response = await _client
        .from('appointments')
        .insert({
          'property_id': propertyId,
          'requester_id': _userId,
          'owner_id': ownerId,
          'appointment_date': date.toIso8601String().split('T').first,
          'appointment_time': time,
          'note': note,
          'status': 'pending',
        })
        .select('''
          *,
          properties:property_id (id, title, images, price, city, district)
        ''')
        .single();

    return Appointment.fromJson(response);
  }

  // ==================== RANDEVU SORGULAMA ====================

  /// Kullanıcının gönderdiği randevu taleplerini getir
  Future<List<Appointment>> getSentAppointments({AppointmentStatus? status}) async {
    if (_userId == null) return [];

    var query = _client
        .from('appointments')
        .select('''
          *,
          properties:property_id (id, title, images, price, city, district)
        ''')
        .eq('requester_id', _userId!);

    if (status != null) {
      query = query.eq('status', status.name);
    }

    final response = await query.order('appointment_date', ascending: true);
    return (response as List).map((json) => Appointment.fromJson(json)).toList();
  }

  /// Kullanıcının aldığı randevu taleplerini getir (ilan sahibi olarak)
  Future<List<Appointment>> getReceivedAppointments({AppointmentStatus? status}) async {
    if (_userId == null) return [];

    var query = _client
        .from('appointments')
        .select('''
          *,
          properties:property_id (id, title, images, price, city, district)
        ''')
        .eq('owner_id', _userId!);

    if (status != null) {
      query = query.eq('status', status.name);
    }

    final response = await query.order('appointment_date', ascending: true);
    return (response as List).map((json) => Appointment.fromJson(json)).toList();
  }

  /// Belirli bir ilan için randevuları getir
  Future<List<Appointment>> getPropertyAppointments(String propertyId) async {
    if (_userId == null) return [];

    final response = await _client
        .from('appointments')
        .select('''
          *,
          properties:property_id (id, title, images, price, city, district)
        ''')
        .eq('property_id', propertyId)
        .or('requester_id.eq.$_userId,owner_id.eq.$_userId')
        .order('appointment_date', ascending: true);

    return (response as List).map((json) => Appointment.fromJson(json)).toList();
  }

  /// Bekleyen randevu sayısını getir
  Future<int> getPendingAppointmentsCount() async {
    if (_userId == null) return 0;

    final response = await _client
        .from('appointments')
        .select('id')
        .eq('owner_id', _userId!)
        .eq('status', 'pending');

    return (response as List).length;
  }

  // ==================== RANDEVU GÜNCELLEME ====================

  /// Randevuyu onayla
  Future<bool> confirmAppointment(String appointmentId, {String? responseNote}) async {
    if (_userId == null) return false;

    try {
      await _client
          .from('appointments')
          .update({
            'status': 'confirmed',
            'response_note': responseNote,
          })
          .eq('id', appointmentId)
          .eq('owner_id', _userId!);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Randevuyu iptal et
  Future<bool> cancelAppointment(String appointmentId, {String? reason}) async {
    if (_userId == null) return false;

    try {
      await _client
          .from('appointments')
          .update({
            'status': 'cancelled',
            'response_note': reason,
          })
          .eq('id', appointmentId)
          .or('requester_id.eq.$_userId,owner_id.eq.$_userId');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Randevuyu tamamlandı olarak işaretle
  Future<bool> completeAppointment(String appointmentId) async {
    if (_userId == null) return false;

    try {
      await _client
          .from('appointments')
          .update({'status': 'completed'})
          .eq('id', appointmentId)
          .eq('owner_id', _userId!);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Randevuyu sil
  Future<bool> deleteAppointment(String appointmentId) async {
    if (_userId == null) return false;

    try {
      await _client
          .from('appointments')
          .delete()
          .eq('id', appointmentId)
          .eq('requester_id', _userId!);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== YARDIMCI METODLAR ====================

  /// Belirli bir tarih için müsait saatleri getir
  Future<List<String>> getAvailableTimeSlots(String propertyId, DateTime date) async {
    // Tüm saatler
    final allSlots = [
      '09:00', '10:00', '11:00', '12:00', '13:00',
      '14:00', '15:00', '16:00', '17:00', '18:00'
    ];

    // O gün için mevcut randevuları al
    final response = await _client
        .from('appointments')
        .select('appointment_time')
        .eq('property_id', propertyId)
        .eq('appointment_date', date.toIso8601String().split('T').first)
        .inFilter('status', ['pending', 'confirmed']);

    final bookedSlots = (response as List)
        .map((r) => (r['appointment_time'] as String).substring(0, 5))
        .toSet();

    // Dolu saatleri çıkar
    return allSlots.where((slot) => !bookedSlots.contains(slot)).toList();
  }

  /// Randevunun geçerli olup olmadığını kontrol et
  bool isValidAppointmentDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final appointmentDay = DateTime(date.year, date.month, date.day);

    // Geçmiş tarih kontrolü
    if (appointmentDay.isBefore(today)) return false;

    // 30 gün ilerisi kontrolü
    if (appointmentDay.difference(today).inDays > 30) return false;

    return true;
  }
}
