class UserModel {
  const UserModel({
    required this.id,
    required this.phone,
    required this.name,
    required this.role,
    required this.trustScore,
    required this.isSuspended,
    this.avatarUrl,
  });

  final String id;
  final String phone;
  final String name;
  final String role; // 'citizen' | 'officer' | 'admin'
  final int trustScore;
  final bool isSuspended;
  final String? avatarUrl;

  bool get isCitizen => role == 'citizen';
  bool get isOfficer => role == 'officer';
  bool get isAdmin   => role == 'admin';

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id:          json['id'] as String,
        phone:       json['phone_number'] as String,
        name:        json['name'] as String,
        role:        json['role'] as String,
        trustScore:  json['trust_score'] as int? ?? 100,
        isSuspended: json['is_suspended'] as bool? ?? false,
        avatarUrl:   json['avatar_url'] as String?,
      );

  UserModel copyWith({
    String? name,
    String? avatarUrl,
    int? trustScore,
  }) =>
      UserModel(
        id:          id,
        phone:       phone,
        name:        name ?? this.name,
        role:        role,
        trustScore:  trustScore ?? this.trustScore,
        isSuspended: isSuspended,
        avatarUrl:   avatarUrl ?? this.avatarUrl,
      );
}
