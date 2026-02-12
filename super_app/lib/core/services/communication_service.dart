import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Güvenli İletişim Servisi (Müşteri Tarafı)
/// Müşteri-Sürücü arasındaki tüm iletişimi yönetir
class CommunicationService {
  static SupabaseClient get _client => SupabaseService.client;

  // ==================== SECURE CONTACT INFO ====================

  /// Güvenli sürücü bilgisi getir (müşteri için - maskelenmiş)
  static Future<SecureDriverInfo?> getSecureDriverInfo(String rideId) async {
    try {
      final response = await _client.rpc('get_secure_driver_info', params: {
        'p_ride_id': rideId,
        'p_customer_user_id': SupabaseService.currentUser?.id,
      });

      if (response != null && response is List && response.isNotEmpty) {
        return SecureDriverInfo.fromJson(response[0]);
      }
      return null;
    } catch (e) {
      debugPrint('getSecureDriverInfo error: $e');
      return null;
    }
  }

  // ==================== MESSAGING ====================

  /// Mesaj gönder
  static Future<String?> sendMessage({
    required String rideId,
    required String content,
    String messageType = 'text',
  }) async {
    try {
      final response = await _client.rpc('send_ride_message', params: {
        'p_ride_id': rideId,
        'p_content': content,
        'p_message_type': messageType,
      });

      return response as String?;
    } catch (e) {
      debugPrint('sendMessage error: $e');
      return null;
    }
  }

  /// Hazır mesaj gönder
  static Future<String?> sendQuickMessage({
    required String rideId,
    required String messageKey,
  }) async {
    return sendMessage(
      rideId: rideId,
      content: messageKey,
      messageType: 'quick_message',
    );
  }

  /// Konum paylaş
  static Future<String?> shareLocation({
    required String rideId,
    required double latitude,
    required double longitude,
  }) async {
    return sendMessage(
      rideId: rideId,
      content: '$latitude,$longitude',
      messageType: 'location',
    );
  }

  /// Yolculuk mesajlarını getir
  static Future<List<RideMessage>> getMessages(String rideId) async {
    try {
      final response = await _client
          .from('ride_communications')
          .select()
          .eq('ride_id', rideId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((e) => RideMessage.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('getMessages error: $e');
      return [];
    }
  }

  /// Mesajları okundu olarak işaretle
  static Future<bool> markMessagesAsRead(String rideId) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return false;

      await _client
          .from('ride_communications')
          .update({'is_read': true})
          .eq('ride_id', rideId)
          .neq('sender_id', userId);

      return true;
    } catch (e) {
      debugPrint('markMessagesAsRead error: $e');
      return false;
    }
  }

  /// Mesajlara abone ol (realtime)
  static RealtimeChannel subscribeToMessages(
    String rideId,
    void Function(RideMessage message) onNewMessage,
  ) {
    return _client
        .channel('ride_messages_$rideId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'ride_communications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ride_id',
            value: rideId,
          ),
          callback: (payload) {
            final message = RideMessage.fromJson(payload.newRecord);
            onNewMessage(message);
          },
        )
        .subscribe();
  }

  // ==================== CALLING ====================

  /// Arama başlat - telefon numarasını da döndürür
  static Future<CallInfo?> initiateCall(String rideId) async {
    try {
      final response = await _client.rpc('initiate_ride_call', params: {
        'p_ride_id': rideId,
      });

      if (response != null && response is Map) {
        return CallInfo(
          callId: response['call_id'] as String,
          channel: 'ride_call_$rideId',
          rideId: rideId,
          phoneNumber: response['phone'] as String?,
          callerType: response['caller_type'] as String?,
        );
      }
      return null;
    } catch (e) {
      debugPrint('initiateCall error: $e');
      return null;
    }
  }

  // ==================== QUICK MESSAGES ====================

  /// Hazır mesajları getir
  static Future<List<QuickMessage>> getQuickMessages() async {
    try {
      final response = await _client
          .from('quick_messages')
          .select()
          .or('user_type.eq.customer,user_type.eq.both')
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      return (response as List)
          .map((e) => QuickMessage.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('getQuickMessages error: $e');
      return [];
    }
  }

  // ==================== RIDE SHARING ====================

  /// Yolculuk paylaşım linki oluştur
  static Future<ShareLinkInfo?> createShareLink({
    required String rideId,
    String? recipientName,
    String? recipientPhone,
    int hoursValid = 24,
  }) async {
    try {
      final response = await _client.rpc('create_ride_share_link', params: {
        'p_ride_id': rideId,
        'p_recipient_name': recipientName,
        'p_recipient_phone': recipientPhone,
        'p_hours_valid': hoursValid,
      });

      if (response != null && response is List && response.isNotEmpty) {
        return ShareLinkInfo.fromJson(response[0]);
      }
      return null;
    } catch (e) {
      debugPrint('createShareLink error: $e');
      return null;
    }
  }

  /// Paylaşım linklerini getir
  static Future<List<ShareLinkInfo>> getShareLinks(String rideId) async {
    try {
      final response = await _client
          .from('ride_share_links')
          .select()
          .eq('ride_id', rideId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((e) => ShareLinkInfo.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('getShareLinks error: $e');
      return [];
    }
  }

  /// Paylaşım linkini deaktif et
  static Future<bool> deactivateShareLink(String linkId) async {
    try {
      await _client
          .from('ride_share_links')
          .update({'is_active': false})
          .eq('id', linkId);

      return true;
    } catch (e) {
      debugPrint('deactivateShareLink error: $e');
      return false;
    }
  }

  // ==================== EMERGENCY ====================

  /// Acil durum uyarısı oluştur
  static Future<String?> createEmergencyAlert({
    String? rideId,
    required String alertType, // 'sos', 'accident', 'threat', 'medical', 'other'
    required double latitude,
    required double longitude,
    String? description,
  }) async {
    try {
      final response = await _client.rpc('create_emergency_alert', params: {
        'p_ride_id': rideId,
        'p_alert_type': alertType,
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_description': description,
      });

      return response as String?;
    } catch (e) {
      debugPrint('createEmergencyAlert error: $e');
      return null;
    }
  }

  /// Acil durum kişilerini getir
  static Future<List<EmergencyContact>> getEmergencyContacts() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return [];

      final response = await _client
          .from('communication_preferences')
          .select('emergency_contacts')
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null && response['emergency_contacts'] != null) {
        final contacts = response['emergency_contacts'] as List;
        return contacts
            .map((e) => EmergencyContact.fromJson(e))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('getEmergencyContacts error: $e');
      return [];
    }
  }

  /// Acil durum kişisi ekle
  static Future<bool> addEmergencyContact(EmergencyContact contact) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return false;

      // Mevcut kişileri al
      final contacts = await getEmergencyContacts();
      contacts.add(contact);

      // Güncelle veya oluştur
      await _client
          .from('communication_preferences')
          .upsert({
            'user_id': userId,
            'emergency_contacts': contacts.map((e) => e.toJson()).toList(),
          });

      return true;
    } catch (e) {
      debugPrint('addEmergencyContact error: $e');
      return false;
    }
  }

  /// Acil durum kişisini kaldır
  static Future<bool> removeEmergencyContact(String phone) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return false;

      final contacts = await getEmergencyContacts();
      contacts.removeWhere((c) => c.phone == phone);

      await _client
          .from('communication_preferences')
          .update({
            'emergency_contacts': contacts.map((e) => e.toJson()).toList(),
          })
          .eq('user_id', userId);

      return true;
    } catch (e) {
      debugPrint('removeEmergencyContact error: $e');
      return false;
    }
  }

  // ==================== COMMUNICATION PREFERENCES ====================

  /// İletişim tercihlerini getir
  static Future<CommunicationPreferences?> getPreferences() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return null;

      final response = await _client
          .from('communication_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        return CommunicationPreferences.fromJson(response);
      }
      return null;
    } catch (e) {
      debugPrint('getPreferences error: $e');
      return null;
    }
  }

  /// İletişim tercihlerini güncelle
  static Future<bool> updatePreferences(CommunicationPreferences prefs) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return false;

      await _client
          .from('communication_preferences')
          .upsert({
            'user_id': userId,
            ...prefs.toJson(),
          });

      return true;
    } catch (e) {
      debugPrint('updatePreferences error: $e');
      return false;
    }
  }

  // ==================== SOS ====================

  /// Telefon numarasını WhatsApp formatına çevir (90XXXXXXXXXX)
  static String _normalizePhone(String phone) {
    String digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.startsWith('0')) {
      digits = '90${digits.substring(1)}';
    } else if (!digits.startsWith('90')) {
      digits = '90$digits';
    }
    return digits;
  }

  /// Acil durum kişilerine WhatsApp ile SOS mesajı gönder
  static Future<void> sendSosToEmergencyContacts({
    required BuildContext context,
    required String rideId,
    String? userName,
    String? driverName,
    String? vehicleInfo,
    String? vehiclePlate,
    double? latitude,
    double? longitude,
  }) async {
    // 1. Kişileri al
    final contacts = await getEmergencyContacts();
    if (contacts.isEmpty) {
      if (!context.mounted) return;
      final goToSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
              SizedBox(width: 8),
              Text('Acil Durum Kişisi Yok'),
            ],
          ),
          content: const Text(
            'SOS mesajı göndermek için önce acil durum kişisi eklemelisiniz.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
              ),
              child: const Text('Kişi Ekle'),
            ),
          ],
        ),
      );
      if (goToSettings == true && context.mounted) {
        Navigator.of(context).pushNamed('/settings/emergency-contacts');
      }
      return;
    }

    // 2. Onay dialogu
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.sos_rounded, color: Color(0xFFEF4444), size: 28),
            SizedBox(width: 8),
            Text('SOS Gönder'),
          ],
        ),
        content: Text(
          '${contacts.length} acil durum kişisine WhatsApp üzerinden konum ve sürücü bilgileriniz gönderilecek.\n\nDevam etmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('SOS Gönder'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 3. Canlı takip linki oluştur
    final link = await createShareLink(rideId: rideId);

    // 4. DB'ye acil durum kaydı yaz
    if (latitude != null && longitude != null) {
      await createEmergencyAlert(
        rideId: rideId,
        alertType: 'sos',
        latitude: latitude,
        longitude: longitude,
      );
    }

    // 5. Mesaj oluştur
    final trackingUrl = link?.shareUrl ?? '';
    final buffer = StringBuffer();
    buffer.writeln('\u{1F198} ACİL DURUM${userName != null ? ' - $userName' : ''}');
    buffer.writeln();
    buffer.writeln('Yolculuğum sırasında acil durum bildirdim.');
    if (trackingUrl.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('\u{1F4CD} Canlı konum takibi: $trackingUrl');
    }
    if (driverName != null) {
      buffer.writeln();
      buffer.writeln('\u{1F697} Sürücü: $driverName');
      if (vehicleInfo != null || vehiclePlate != null) {
        buffer.writeln('\u{1F698} Araç: ${vehicleInfo ?? ''} ${vehiclePlate != null ? '- $vehiclePlate' : ''}'.trim());
      }
    }
    buffer.writeln();
    buffer.writeln('Bu mesaj otomatik olarak gönderilmiştir.');

    final message = buffer.toString();
    final encodedMessage = Uri.encodeComponent(message);

    // 6. Her kişi için WhatsApp aç
    int sentCount = 0;
    for (final contact in contacts) {
      final normalizedPhone = _normalizePhone(contact.phone);
      final waUri = Uri.parse('https://wa.me/$normalizedPhone?text=$encodedMessage');

      try {
        final launched = await launchUrl(waUri, mode: LaunchMode.externalApplication);
        if (launched) {
          sentCount++;
          // Birden fazla kişi varsa araya kısa bekleme koy
          if (contacts.length > 1) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
        } else {
          // WhatsApp açılamazsa SMS dene
          final smsUri = Uri.parse('sms:${contact.phone}?body=$encodedMessage');
          await launchUrl(smsUri);
          sentCount++;
        }
      } catch (e) {
        debugPrint('SOS send error for ${contact.name}: $e');
      }
    }

    // 7. Sonuç bildirimi
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sentCount > 0
                ? '$sentCount kişiye SOS mesajı gönderildi'
                : 'Mesaj gönderilemedi',
          ),
          backgroundColor:
              sentCount > 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        ),
      );
    }
  }
}

// ==================== MODELS ====================

/// Güvenli sürücü bilgisi (müşteri görür)
class SecureDriverInfo {
  final String driverName;
  final String maskedPhone;
  final String vehiclePlate;
  final String vehicleBrand;
  final String vehicleModel;
  final String vehicleColor;
  final double rating;
  final bool canCall;
  final bool canMessage;

  const SecureDriverInfo({
    required this.driverName,
    required this.maskedPhone,
    required this.vehiclePlate,
    required this.vehicleBrand,
    required this.vehicleModel,
    required this.vehicleColor,
    required this.rating,
    required this.canCall,
    required this.canMessage,
  });

  factory SecureDriverInfo.fromJson(Map<String, dynamic> json) {
    return SecureDriverInfo(
      driverName: json['driver_name'] as String? ?? 'Sürücü',
      maskedPhone: json['masked_phone'] as String? ?? '***',
      vehiclePlate: json['vehicle_plate'] as String? ?? '',
      vehicleBrand: json['vehicle_brand'] as String? ?? '',
      vehicleModel: json['vehicle_model'] as String? ?? '',
      vehicleColor: json['vehicle_color'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      canCall: json['can_call'] as bool? ?? true,
      canMessage: json['can_message'] as bool? ?? true,
    );
  }

  String get vehicleInfo => '$vehicleBrand $vehicleModel'.trim();
  String get vehicleFullInfo => '$vehicleColor $vehicleBrand $vehicleModel'.trim();
}

/// Yolculuk mesajı
class RideMessage {
  final String id;
  final String rideId;
  final String senderType;
  final String senderId;
  final String messageType;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  const RideMessage({
    required this.id,
    required this.rideId,
    required this.senderType,
    required this.senderId,
    required this.messageType,
    required this.content,
    required this.isRead,
    required this.createdAt,
  });

  factory RideMessage.fromJson(Map<String, dynamic> json) {
    return RideMessage(
      id: json['id'] as String,
      rideId: json['ride_id'] as String,
      senderType: json['sender_type'] as String,
      senderId: json['sender_id'] as String,
      messageType: json['message_type'] as String? ?? 'text',
      content: json['content'] as String,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isFromDriver => senderType == 'driver';
  bool get isFromCustomer => senderType == 'customer';
  bool get isLocation => messageType == 'location';
  bool get isQuickMessage => messageType == 'quick_message';
  bool get isSystem => messageType == 'system';
}

/// Hazır mesaj
class QuickMessage {
  final String id;
  final String userType;
  final String messageTr;
  final String? messageEn;
  final int sortOrder;

  const QuickMessage({
    required this.id,
    required this.userType,
    required this.messageTr,
    this.messageEn,
    required this.sortOrder,
  });

  factory QuickMessage.fromJson(Map<String, dynamic> json) {
    return QuickMessage(
      id: json['id'] as String,
      userType: json['user_type'] as String,
      messageTr: json['message_tr'] as String,
      messageEn: json['message_en'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  String getMessage({String locale = 'tr'}) {
    if (locale == 'en' && messageEn != null) {
      return messageEn!;
    }
    return messageTr;
  }
}

/// Arama bilgisi
class CallInfo {
  final String callId;
  final String channel;
  final String rideId;
  final String? phoneNumber;
  final String? callerType;

  const CallInfo({
    required this.callId,
    required this.channel,
    required this.rideId,
    this.phoneNumber,
    this.callerType,
  });
}

/// Paylaşım linki bilgisi
class ShareLinkInfo {
  final String? id;
  final String shareToken;
  final String? shareUrl;
  final DateTime expiresAt;
  final String? recipientName;
  final String? recipientPhone;
  final int viewCount;
  final DateTime? lastViewedAt;

  const ShareLinkInfo({
    this.id,
    required this.shareToken,
    this.shareUrl,
    required this.expiresAt,
    this.recipientName,
    this.recipientPhone,
    this.viewCount = 0,
    this.lastViewedAt,
  });

  factory ShareLinkInfo.fromJson(Map<String, dynamic> json) {
    return ShareLinkInfo(
      id: json['id'] as String?,
      shareToken: json['share_token'] as String,
      shareUrl: json['share_url'] as String?,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : DateTime.now().add(const Duration(hours: 24)),
      recipientName: json['recipient_name'] as String?,
      recipientPhone: json['recipient_phone'] as String?,
      viewCount: json['view_count'] as int? ?? 0,
      lastViewedAt: json['last_viewed_at'] != null
          ? DateTime.parse(json['last_viewed_at'] as String)
          : null,
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Acil durum kişisi
class EmergencyContact {
  final String name;
  final String phone;
  final String? relationship;

  const EmergencyContact({
    required this.name,
    required this.phone,
    this.relationship,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name'] as String,
      phone: json['phone'] as String,
      relationship: json['relationship'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'relationship': relationship,
  };
}

/// İletişim tercihleri
class CommunicationPreferences {
  final bool allowCalls;
  final bool allowMessages;
  final bool sharePhoneWithDriver;
  final bool autoShareRideEnabled;

  const CommunicationPreferences({
    this.allowCalls = true,
    this.allowMessages = true,
    this.sharePhoneWithDriver = false,
    this.autoShareRideEnabled = false,
  });

  factory CommunicationPreferences.fromJson(Map<String, dynamic> json) {
    return CommunicationPreferences(
      allowCalls: json['allow_calls'] as bool? ?? true,
      allowMessages: json['allow_messages'] as bool? ?? true,
      sharePhoneWithDriver: json['share_phone_with_driver'] as bool? ?? false,
      autoShareRideEnabled: json['auto_share_ride_enabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'allow_calls': allowCalls,
    'allow_messages': allowMessages,
    'share_phone_with_driver': sharePhoneWithDriver,
    'auto_share_ride_enabled': autoShareRideEnabled,
  };

  CommunicationPreferences copyWith({
    bool? allowCalls,
    bool? allowMessages,
    bool? sharePhoneWithDriver,
    bool? autoShareRideEnabled,
  }) {
    return CommunicationPreferences(
      allowCalls: allowCalls ?? this.allowCalls,
      allowMessages: allowMessages ?? this.allowMessages,
      sharePhoneWithDriver: sharePhoneWithDriver ?? this.sharePhoneWithDriver,
      autoShareRideEnabled: autoShareRideEnabled ?? this.autoShareRideEnabled,
    );
  }
}
