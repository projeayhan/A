/// Araç Satış Mesajlaşma Modelleri

// ==================== CHAT MESSAGE ====================

/// Mesaj tipi
enum MessageType {
  text,
  image,
  file,
  system;

  static MessageType fromString(String? value) {
    return MessageType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MessageType.text,
    );
  }
}

/// Chat mesajı modeli
class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final MessageType messageType;
  final String? mediaUrl;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.messageType = MessageType.text,
    this.mediaUrl,
    this.isRead = false,
    this.readAt,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String? ?? '',
      messageType: MessageType.fromString(json['message_type'] as String?),
      mediaUrl: json['media_url'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'message_type': messageType.name,
      'media_url': mediaUrl,
      'is_read': isRead,
      'read_at': readAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? content,
    MessageType? messageType,
    String? mediaUrl,
    bool? isRead,
    DateTime? readAt,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// ==================== CONVERSATION ====================

/// Konuşma durumu
enum ConversationStatus {
  active,
  archived,
  blocked;

  static ConversationStatus fromString(String? value) {
    return ConversationStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ConversationStatus.active,
    );
  }
}

/// Konuşma modeli
class CarConversation {
  final String id;
  final String? listingId;
  final String buyerId;
  final String sellerId;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;
  final int buyerUnreadCount;
  final int sellerUnreadCount;
  final ConversationStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  // İlişkili veriler
  final CarListingInfo? listing;
  final UserProfile? buyerProfile;
  final UserProfile? sellerProfile;

  CarConversation({
    required this.id,
    this.listingId,
    required this.buyerId,
    required this.sellerId,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageSenderId,
    this.buyerUnreadCount = 0,
    this.sellerUnreadCount = 0,
    this.status = ConversationStatus.active,
    required this.createdAt,
    required this.updatedAt,
    this.listing,
    this.buyerProfile,
    this.sellerProfile,
  });

  factory CarConversation.fromJson(Map<String, dynamic> json) {
    return CarConversation(
      id: json['id'] as String,
      listingId: json['listing_id'] as String?,
      buyerId: json['buyer_id'] as String,
      sellerId: json['seller_id'] as String,
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      lastMessageSenderId: json['last_message_sender_id'] as String?,
      buyerUnreadCount: json['buyer_unread_count'] as int? ?? 0,
      sellerUnreadCount: json['seller_unread_count'] as int? ?? 0,
      status: ConversationStatus.fromString(json['status'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      listing: json['car_listings'] != null
          ? CarListingInfo.fromJson(json['car_listings'] as Map<String, dynamic>)
          : null,
      buyerProfile: json['buyer_profile'] != null
          ? UserProfile.fromJson(json['buyer_profile'] as Map<String, dynamic>)
          : null,
      sellerProfile: json['seller_profile'] != null
          ? UserProfile.fromJson(json['seller_profile'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Kullanıcıya göre okunmamış mesaj sayısı
  int getUnreadCount(String currentUserId) {
    if (currentUserId == buyerId) {
      return buyerUnreadCount;
    } else if (currentUserId == sellerId) {
      return sellerUnreadCount;
    }
    return 0;
  }

  /// Karşı tarafın profili
  UserProfile? getOtherUserProfile(String currentUserId) {
    if (currentUserId == buyerId) {
      return sellerProfile;
    } else {
      return buyerProfile;
    }
  }

  /// Kullanıcının satıcı olup olmadığı
  bool isSeller(String currentUserId) => currentUserId == sellerId;
}

// ==================== LISTING INFO ====================

/// İlan özet bilgisi (konuşma listesinde göstermek için)
class CarListingInfo {
  final String id;
  final String title;
  final String? brandName;
  final String? modelName;
  final int? year;
  final double? price;
  final List<String> images;
  final String? city;

  CarListingInfo({
    required this.id,
    required this.title,
    this.brandName,
    this.modelName,
    this.year,
    this.price,
    this.images = const [],
    this.city,
  });

  factory CarListingInfo.fromJson(Map<String, dynamic> json) {
    List<String> imageList = [];
    if (json['images'] != null) {
      if (json['images'] is List) {
        imageList = (json['images'] as List).map((e) => e.toString()).toList();
      }
    }

    return CarListingInfo(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      brandName: json['brand_name'] as String?,
      modelName: json['model_name'] as String?,
      year: json['year'] as int?,
      price: (json['price'] as num?)?.toDouble(),
      images: imageList,
      city: json['city'] as String?,
    );
  }

  String? get firstImage => images.isNotEmpty ? images.first : null;

  String get displayTitle {
    if (brandName != null && modelName != null) {
      return '$brandName $modelName${year != null ? ' ($year)' : ''}';
    }
    return title;
  }
}

// ==================== USER PROFILE ====================

/// Kullanıcı profil bilgisi
class UserProfile {
  final String id;
  final String? fullName;
  final String? avatarUrl;
  final String? phone;

  UserProfile({
    required this.id,
    this.fullName,
    this.avatarUrl,
    this.phone,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? json['owner_name'] as String?,
      avatarUrl: json['avatar_url'] as String? ?? json['logo_url'] as String?,
      phone: json['phone'] as String?,
    );
  }

  String get displayName => fullName ?? 'Kullanıcı';

  String get initials {
    if (fullName == null || fullName!.isEmpty) return '?';
    final parts = fullName!.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName![0].toUpperCase();
  }
}
