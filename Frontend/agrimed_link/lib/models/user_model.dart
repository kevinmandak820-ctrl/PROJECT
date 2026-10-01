class UserModel {
  final String id;
  final String email;
  final String role;
  final String? name;
  final String? phoneNumber;

  const UserModel({
    required this.id,
    required this.email,
    required this.role,
    this.name,
    this.phoneNumber,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      name: json['name'] as String?,
      phoneNumber: json['phone_number'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'role': role,
    'name': name,
    'phone_number': phoneNumber,
  };

  /// Display name: prefer name, fall back to email prefix
  String get displayName =>
      (name != null && name!.isNotEmpty) ? name! : email.split('@').first;
}
