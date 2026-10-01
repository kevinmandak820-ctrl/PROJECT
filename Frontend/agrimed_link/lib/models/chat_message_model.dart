class ChatMessageModel {
  final String id;
  final String senderId;
  final String? senderName;
  final String? senderRole;
  final String? recipientId;
  final String? communityId;
  final String content;
  final String? attachmentUrl;
  final bool isRead;
  final DateTime createdAt;

  const ChatMessageModel({
    required this.id,
    required this.senderId,
    this.senderName,
    this.senderRole,
    this.recipientId,
    this.communityId,
    required this.content,
    this.attachmentUrl,
    this.isRead = false,
    required this.createdAt,
  });

  bool isMine(String currentUserId) => senderId == currentUserId;

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    String? sName;
    String? sRole;
    if (json['sender'] is Map) {
      sName = json['sender']['name'] ?? json['sender']['email'];
      sRole = json['sender']['role'];
    }

    return ChatMessageModel(
      id: json['id']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      senderName: sName ?? json['senderName']?.toString(),
      senderRole: sRole ?? json['senderRole']?.toString() ?? 'farmer',
      recipientId: json['recipientId']?.toString(),
      communityId: json['communityId']?.toString(),
      content: json['content']?.toString() ?? '',
      attachmentUrl: json['attachmentUrl']?.toString(),
      isRead: json['isRead'] == true,
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'senderName': senderName,
    'senderRole': senderRole,
    'recipientId': recipientId,
    'communityId': communityId,
    'content': content,
    'attachmentUrl': attachmentUrl,
    'isRead': isRead,
    'createdAt': createdAt.toIso8601String(),
  };
}
