class UserModel {
  final int id;
  final String username;
  final String email;
  final List<String> roles;
  final String accessToken;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.roles,
    required this.accessToken,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      username: json['username'] as String,
      email: json['email'] as String? ?? '',
      roles:
          (json['roles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      accessToken: json['accessToken'] as String,
    );
  }

  bool get isAdmin => roles.contains('ROLE_ADMIN');
  bool get isManager => roles.contains('ROLE_MANAGER');
  bool get isStaff => roles.contains('ROLE_STAFF');
  bool get isCustomer => roles.contains('ROLE_CUSTOMER');
}
