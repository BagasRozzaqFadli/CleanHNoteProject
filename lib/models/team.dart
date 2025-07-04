class Team {
  final String id;
  final String teamName;
  final String leaderId;
  final String invitationCode;
  final DateTime createdAt;
  final int? memberCount;

  Team({
    required this.id,
    required this.teamName,
    required this.leaderId,
    required this.invitationCode,
    required this.createdAt,
    this.memberCount,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['\$id'] ?? json['id'] ?? '',
      teamName: json['team_name'] ?? '',
      leaderId: json['leader_id'] ?? '',
      invitationCode: json['invitation_code'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      memberCount: json['memberCount'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'team_name': teamName,
      'leader_id': leaderId,
      'invitation_code': invitationCode,
      'created_at': createdAt.toIso8601String(),
      'memberCount': memberCount,
    };
  }
} 