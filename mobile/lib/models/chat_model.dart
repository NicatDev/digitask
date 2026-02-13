class ChatGroup {
  final int id;
  final String name;
  final String? image;
  final int ownerId;
  final bool isActive;
  final bool onlyOwnerCanSend;
  final DateTime createdAt;
  final int unreadCount;
  final String? lastMessage;
  final String? lastMessageSender;
  final DateTime? lastMessageAt;

  ChatGroup({
    required this.id,
    required this.name,
    this.image,
    required this.ownerId,
    this.isActive = true,
    this.onlyOwnerCanSend = false,
    required this.createdAt,
    this.unreadCount = 0,
    this.lastMessage,
    this.lastMessageSender,
    this.lastMessageAt,
  });

  factory ChatGroup.fromJson(Map<String, dynamic> json) {
    // Handle owner field which might be an int ID or a User object (Map)
    int ownerId = 0;
    if (json['owner'] != null) {
      if (json['owner'] is int) {
        ownerId = json['owner'];
      } else if (json['owner'] is Map) {
         ownerId = json['owner']['id'] ?? 0;
      }
    }

    return ChatGroup(
      id: json['id'],
      name: json['name'],
      image: json['image'],
      ownerId: ownerId,
      isActive: json['is_active'] ?? true,
      onlyOwnerCanSend: json['only_owner_can_send'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      unreadCount: json['unread_count'] ?? 0,
      lastMessage: json['last_message'] is Map ? json['last_message']['content'] :  null,
      lastMessageSender: json['last_message'] is Map ? json['last_message']['sender'] : null,
      lastMessageAt: json['last_message'] is Map && json['last_message']['created_at'] != null
          ? DateTime.parse(json['last_message']['created_at']) 
          : null,
    );
  }
}

class ChatMessage {
  final int id;
  final int groupId;
  final int senderId;
  final String senderName;
  final String? senderAvatar;
  final String content;
  final DateTime createdAt;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.content,
    required this.createdAt,
    this.isRead = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // 1. Parse Sender ID
    int parsedSenderId = 0;
    if (json['sender_id'] != null) {
      parsedSenderId = json['sender_id'];
    } else if (json['sender'] is int) {
      parsedSenderId = json['sender'];
    } else if (json['sender'] is Map) {
       parsedSenderId = json['sender']['id'] ?? 0;
    }

    // 2. Parse Sender Name
    String parsedSenderName = 'Unknown';
    if (json['sender'] is String) {
       parsedSenderName = json['sender']; // WebSocket sends name as 'sender'
    } else if (json['sender_name'] != null) {
       parsedSenderName = json['sender_name'];
    } else if (json['sender'] is Map) {
      final senderMap = json['sender'];
      final firstName = senderMap['first_name'] ?? '';
      final lastName = senderMap['last_name'] ?? '';
      parsedSenderName = '$firstName $lastName'.trim();
      if (parsedSenderName.isEmpty) parsedSenderName = senderMap['email'] ?? 'Unknown';
    }

    return ChatMessage(
      id: json['id'],
      groupId: json['group'] ?? 0, 
      senderId: parsedSenderId,
      senderName: parsedSenderName,
      senderAvatar: json['sender_avatar'], 
      content: json['content'] ?? '', // Handle null content safely
      createdAt: DateTime.parse(json['created_at']),
      isRead: json['is_read'] ?? false,
    );
  }
}
