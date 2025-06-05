class TeamMember {
  final String id;
  final String userId;
  final String teamId;
  final String role;
  final DateTime joinedAt;
  String? name; // Nama user (diisi dari user service)
  String? email; // Email user (diisi dari user service)

  TeamMember({
    required this.id,
    required this.userId,
    required this.teamId,
    required this.role,
    required this.joinedAt,
    this.name,
    this.email,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      id: json['\$id'] ?? '',
      userId: json['user_id'] ?? '',
      teamId: json['team_id'] ?? '',
      role: json['role'] ?? '',
      joinedAt: DateTime.tryParse(json['joined_at'] ?? '') ?? DateTime.now(),
      name: json['name'],
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'team_id': teamId,
      'role': role,
      'joined_at': joinedAt.toIso8601String(),
      if (name != null) 'name': name,
      if (email != null) 'email': email,
    };
  }
} 