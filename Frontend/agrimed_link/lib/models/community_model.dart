class CommunityModel {
  final String id;
  final String name;
  final String description;
  final String category;
  final String icon;
  final String creatorId;
  final String? creatorName;
  final int membersCount;
  final bool isJoined;
  final DateTime? createdAt;

  const CommunityModel({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.icon = 'groups',
    required this.creatorId,
    this.creatorName,
    this.membersCount = 1,
    this.isJoined = false,
    this.createdAt,
  });

  factory CommunityModel.fromJson(Map<String, dynamic> json) {
    String? cName;
    if (json['creator'] is Map) {
      cName = json['creator']['name'] ?? json['creator']['email'];
    }

    return CommunityModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      icon: json['icon']?.toString() ?? 'groups',
      creatorId: json['creatorId']?.toString() ?? '',
      creatorName: cName,
      membersCount: (json['membersCount'] is num) ? (json['membersCount'] as num).toInt() : 1,
      isJoined: json['isJoined'] == true,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'category': category,
    'icon': icon,
    'creatorId': creatorId,
    'creatorName': creatorName,
    'membersCount': membersCount,
    'isJoined': isJoined,
    'createdAt': createdAt?.toIso8601String(),
  };

  CommunityModel copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    String? icon,
    String? creatorId,
    String? creatorName,
    int? membersCount,
    bool? isJoined,
    DateTime? createdAt,
  }) {
    return CommunityModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      membersCount: membersCount ?? this.membersCount,
      isJoined: isJoined ?? this.isJoined,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
