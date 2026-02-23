class SupportAgent {
  final String id;
  final String userId;
  final String fullName;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String permissionLevel;
  final String status;
  final int maxConcurrentChats;
  final int activeChatCount;
  final List<String> specializations;
  final DateTime? shiftStart;
  final DateTime? shiftEnd;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastActiveAt;

  SupportAgent({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    this.phone,
    this.avatarUrl,
    required this.permissionLevel,
    required this.status,
    this.maxConcurrentChats = 5,
    this.activeChatCount = 0,
    this.specializations = const [],
    this.shiftStart,
    this.shiftEnd,
    required this.createdAt,
    required this.updatedAt,
    this.lastActiveAt,
  });

  factory SupportAgent.fromJson(Map<String, dynamic> json) {
    return SupportAgent(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      permissionLevel: json['permission_level'] as String? ?? 'L1',
      status: json['status'] as String? ?? 'offline',
      maxConcurrentChats: json['max_concurrent_chats'] as int? ?? 5,
      activeChatCount: json['active_chat_count'] as int? ?? 0,
      specializations: (json['specializations'] as List<dynamic>?)?.cast<String>() ?? [],
      shiftStart: json['shift_start'] != null ? DateTime.parse(json['shift_start'] as String) : null,
      shiftEnd: json['shift_end'] != null ? DateTime.parse(json['shift_end'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lastActiveAt: json['last_active_at'] != null ? DateTime.parse(json['last_active_at'] as String) : null,
    );
  }

  bool hasPermission(String action) {
    const permissionHierarchy = ['L1', 'L2', 'supervisor', 'manager'];
    final currentIndex = permissionHierarchy.indexOf(permissionLevel);

    switch (action) {
      case 'view_tickets':
      case 'reply_tickets':
      case 'create_tickets':
      case 'view_customer_360':
        return currentIndex >= 0; // L1+
      case 'change_order_status':
      case 'edit_menu_products':
      case 'merge_tickets':
      case 'edit_knowledge_base':
        return currentIndex >= 1; // L2+
      case 'assign_tickets':
      case 'view_all_metrics':
      case 'manage_canned_responses':
      case 'manage_macros':
      case 'change_business_settings':
      case 'view_audit_logs':
        return currentIndex >= 2; // supervisor+
      default:
        return currentIndex >= 3; // manager
    }
  }

  bool get isOnline => status == 'online';
  bool get isBusy => status == 'busy';
  bool get isOnBreak => status == 'break';
  bool get isOffline => status == 'offline';
  bool get isL1 => permissionLevel == 'L1';
  bool get isL2 => permissionLevel == 'L2';
  bool get isSupervisor => permissionLevel == 'supervisor';
  bool get isManager => permissionLevel == 'manager';

  String get permissionLevelDisplay {
    switch (permissionLevel) {
      case 'L1': return 'Seviye 1';
      case 'L2': return 'Seviye 2';
      case 'supervisor': return 'Supervisor';
      case 'manager': return 'Yönetici';
      default: return permissionLevel;
    }
  }

  String get statusDisplay {
    switch (status) {
      case 'online': return 'Çevrimiçi';
      case 'busy': return 'Meşgul';
      case 'break': return 'Mola';
      case 'offline': return 'Çevrimdışı';
      default: return status;
    }
  }
}

class SupportTicket {
  final String id;
  final int ticketNumber;
  final String? customerUserId;
  final String? customerName;
  final String? customerPhone;
  final String? assignedAgentId;
  final String serviceType;
  final String? category;
  final String? subcategory;
  final String status;
  final String priority;
  final String subject;
  final String? description;
  final DateTime? slaDueAt;
  final DateTime? firstResponseAt;
  final DateTime? resolvedAt;
  final DateTime? closedAt;
  final String? relatedOrderId;
  final String? relatedRideId;
  final String? relatedBookingId;
  final String? relatedListingId;
  final String? relatedMerchantId;
  final String? mergedIntoTicketId;
  final bool isMerged;
  final int? satisfactionRating;
  final int customerRiskScore;
  final List<String> tags;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Joined fields
  final String? assignedAgentName;

  SupportTicket({
    required this.id,
    required this.ticketNumber,
    this.customerUserId,
    this.customerName,
    this.customerPhone,
    this.assignedAgentId,
    required this.serviceType,
    this.category,
    this.subcategory,
    required this.status,
    required this.priority,
    required this.subject,
    this.description,
    this.slaDueAt,
    this.firstResponseAt,
    this.resolvedAt,
    this.closedAt,
    this.relatedOrderId,
    this.relatedRideId,
    this.relatedBookingId,
    this.relatedListingId,
    this.relatedMerchantId,
    this.mergedIntoTicketId,
    this.isMerged = false,
    this.satisfactionRating,
    this.customerRiskScore = 0,
    this.tags = const [],
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
    this.assignedAgentName,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    final agent = json['support_agents'] as Map<String, dynamic>?;
    return SupportTicket(
      id: json['id'] as String,
      ticketNumber: json['ticket_number'] as int? ?? 0,
      customerUserId: json['customer_user_id'] as String?,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      assignedAgentId: json['assigned_agent_id'] as String?,
      serviceType: json['service_type'] as String,
      category: json['category'] as String?,
      subcategory: json['subcategory'] as String?,
      status: json['status'] as String? ?? 'open',
      priority: json['priority'] as String? ?? 'normal',
      subject: json['subject'] as String,
      description: json['description'] as String?,
      slaDueAt: json['sla_due_at'] != null ? DateTime.parse(json['sla_due_at'] as String) : null,
      firstResponseAt: json['first_response_at'] != null ? DateTime.parse(json['first_response_at'] as String) : null,
      resolvedAt: json['resolved_at'] != null ? DateTime.parse(json['resolved_at'] as String) : null,
      closedAt: json['closed_at'] != null ? DateTime.parse(json['closed_at'] as String) : null,
      relatedOrderId: json['related_order_id'] as String?,
      relatedRideId: json['related_ride_id'] as String?,
      relatedBookingId: json['related_booking_id'] as String?,
      relatedListingId: json['related_listing_id'] as String?,
      relatedMerchantId: json['related_merchant_id'] as String?,
      mergedIntoTicketId: json['merged_into_ticket_id'] as String?,
      isMerged: json['is_merged'] as bool? ?? false,
      satisfactionRating: json['satisfaction_rating'] as int?,
      customerRiskScore: json['customer_risk_score'] as int? ?? 0,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      assignedAgentName: agent?['full_name'] as String?,
    );
  }

  String get serviceTypeDisplay {
    switch (serviceType) {
      case 'food': return 'Yemek';
      case 'market': return 'Market';
      case 'store': return 'Mağaza';
      case 'taxi': return 'Taksi';
      case 'rental': return 'Araç Kiralama';
      case 'emlak': return 'Emlak';
      case 'car_sales': return 'Araç Satış';
      case 'job_listings': return 'İş İlanları';
      case 'general': return 'Genel';
      case 'account': return 'Hesap';
      default: return serviceType;
    }
  }

  String get statusDisplay {
    switch (status) {
      case 'open': return 'Açık';
      case 'assigned': return 'Atanmış';
      case 'pending': return 'Beklemede';
      case 'waiting_customer': return 'Müşteri Bekleniyor';
      case 'resolved': return 'Çözüldü';
      case 'closed': return 'Kapalı';
      default: return status;
    }
  }

  String get priorityDisplay {
    switch (priority) {
      case 'low': return 'Düşük';
      case 'normal': return 'Normal';
      case 'high': return 'Yüksek';
      case 'urgent': return 'Acil';
      default: return priority;
    }
  }

  bool get isOpen => status == 'open' || status == 'assigned' || status == 'pending' || status == 'waiting_customer';
  bool get isClosed => status == 'resolved' || status == 'closed';
  bool get isSlaBreached => slaDueAt != null && DateTime.now().isAfter(slaDueAt!) && isOpen;
}

class TicketMessage {
  final String id;
  final String ticketId;
  final String senderType;
  final String? senderId;
  final String? senderName;
  final String message;
  final String messageType;
  final String? whisperTargetId;
  final String? attachmentUrl;
  final String? attachmentType;
  final bool isRead;
  final DateTime? readAt;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  TicketMessage({
    required this.id,
    required this.ticketId,
    required this.senderType,
    this.senderId,
    this.senderName,
    required this.message,
    this.messageType = 'text',
    this.whisperTargetId,
    this.attachmentUrl,
    this.attachmentType,
    this.isRead = false,
    this.readAt,
    this.metadata = const {},
    required this.createdAt,
  });

  factory TicketMessage.fromJson(Map<String, dynamic> json) {
    return TicketMessage(
      id: json['id'] as String,
      ticketId: json['ticket_id'] as String,
      senderType: json['sender_type'] as String,
      senderId: json['sender_id'] as String?,
      senderName: json['sender_name'] as String?,
      message: json['message'] as String,
      messageType: json['message_type'] as String? ?? 'text',
      whisperTargetId: json['whisper_target_id'] as String?,
      attachmentUrl: json['attachment_url'] as String?,
      attachmentType: json['attachment_type'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at'] as String) : null,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isAgent => senderType == 'agent';
  bool get isCustomer => senderType == 'customer';
  bool get isSystem => senderType == 'system';
  bool get isWhisper => senderType == 'whisper' || messageType == 'whisper';
  bool get isInternalNote => messageType == 'internal_note';
}

class InternalNote {
  final String id;
  final String targetType;
  final String targetId;
  final String agentId;
  final String? agentName;
  final String note;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  InternalNote({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.agentId,
    this.agentName,
    required this.note,
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InternalNote.fromJson(Map<String, dynamic> json) {
    return InternalNote(
      id: json['id'] as String,
      targetType: json['target_type'] as String,
      targetId: json['target_id'] as String,
      agentId: json['agent_id'] as String,
      agentName: json['agent_name'] as String?,
      note: json['note'] as String,
      isPinned: json['is_pinned'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class AgentActionLog {
  final String id;
  final String agentId;
  final String? agentName;
  final String actionType;
  final String actionDescription;
  final String? targetType;
  final String? targetId;
  final String? targetName;
  final String? ticketId;
  final String? businessId;
  final String? businessType;
  final Map<String, dynamic>? oldData;
  final Map<String, dynamic>? newData;
  final DateTime createdAt;

  AgentActionLog({
    required this.id,
    required this.agentId,
    this.agentName,
    required this.actionType,
    required this.actionDescription,
    this.targetType,
    this.targetId,
    this.targetName,
    this.ticketId,
    this.businessId,
    this.businessType,
    this.oldData,
    this.newData,
    required this.createdAt,
  });

  factory AgentActionLog.fromJson(Map<String, dynamic> json) {
    return AgentActionLog(
      id: json['id'] as String,
      agentId: json['agent_id'] as String,
      agentName: json['agent_name'] as String?,
      actionType: json['action_type'] as String,
      actionDescription: json['action_description'] as String,
      targetType: json['target_type'] as String?,
      targetId: json['target_id'] as String?,
      targetName: json['target_name'] as String?,
      ticketId: json['ticket_id'] as String?,
      businessId: json['business_id'] as String?,
      businessType: json['business_type'] as String?,
      oldData: json['old_data'] as Map<String, dynamic>?,
      newData: json['new_data'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
