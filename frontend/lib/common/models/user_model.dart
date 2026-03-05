class User {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String role;
  final bool isActive;

  User({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    required this.role,
    required this.isActive,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['Id'] ?? '',
      fullName: json['FullName'] ?? '',
      email: json['Email'] ?? '',
      phone: json['Phone'],
      role: json['Role'] ?? 'customer',
      isActive: json['IsActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'FullName': fullName,
      'Email': email,
      'Phone': phone,
      'Role': role,
      'IsActive': isActive,
    };
  }
}
