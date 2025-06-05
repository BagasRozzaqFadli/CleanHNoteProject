class User {
  final String id;
  final String name;
  final String email;
  final String tenantId;
  final DateTime createdAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.tenantId,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['\$id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      tenantId: json['tenant_id'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'tenant_id': tenantId,
      'created_at': createdAt.toIso8601String(),
    };
  }
} 