class ChatConversationModel {
  final String partnerId;
  final String partnerName;
  final String partnerEmail;
  final String partnerRole;
  final String? partnerPhoneNumber;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;

  const ChatConversationModel({
    required this.partnerId,
    required this.partnerName,
    required this.partnerEmail,
    required this.partnerRole,
    this.partnerPhoneNumber,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
  });

  factory ChatConversationModel.fromJson(Map<String, dynamic> json) {
    return ChatConversationModel(
      partnerId: json['partnerId']?.toString() ?? '',
      partnerName: json['partnerName']?.toString() ?? 'Agri User',
      partnerEmail: json['partnerEmail']?.toString() ?? '',
      partnerRole: json['partnerRole']?.toString() ?? 'farmer',
      partnerPhoneNumber: json['partnerPhoneNumber']?.toString(),
      lastMessage: json['lastMessage']?.toString() ?? '',
      lastMessageTime: json['lastMessageTime'] != null
          ? (DateTime.tryParse(json['lastMessageTime'].toString()) ?? DateTime.now())
          : DateTime.now(),
      unreadCount: (json['unreadCount'] is num) ? (json['unreadCount'] as num).toInt() : 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'partnerId': partnerId,
    'partnerName': partnerName,
    'partnerEmail': partnerEmail,
    'partnerRole': partnerRole,
    'partnerPhoneNumber': partnerPhoneNumber,
    'lastMessage': lastMessage,
    'lastMessageTime': lastMessageTime.toIso8601String(),
    'unreadCount': unreadCount,
  };
}
