class TeamMember {
  final String id;
  final String userId;
  final String teamId;
  final String role; // 'leader', 'member'
  final DateTime joinedAt;

  TeamMember({
    required this.id,
    required this.userId,
    required this.teamId,
    required this.role,
    required this.joinedAt,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      id: json['\$id'] ?? json['id'] ?? '',
      userId: json['user_id'] ?? '',
      teamId: json['team_id'] ?? '',
      role: json['role'] ?? 'member',
      joinedAt: DateTime.tryParse(json['joined_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'team_id': teamId,
      'role': role,
      'joined_at': joinedAt.toIso8601String(),
    };
  }
}
