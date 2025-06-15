class TeamNotification {
  final String id;
  final String teamId;
  final String userId;
  final String title;
  final String message;
  final String type; // 'task_assigned', 'task_completed', 'team_invitation'
  final String? relatedEntityId; // ID tugas atau undangan
  final bool isRead;
  final DateTime createdAt;

  TeamNotification({
    required this.id,
    required this.teamId,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.relatedEntityId,
    required this.isRead,
    required this.createdAt,
  });

  factory TeamNotification.fromJson(Map<String, dynamic> json) {
    return TeamNotification(
      id: json['\$id'] ?? json['id'] ?? '',
      teamId: json['team_id'] ?? '',
      userId: json['user_id'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? '',
      relatedEntityId: json['related_entity_id'],
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'team_id': teamId,
      'user_id': userId,
      'title': title,
      'message': message,
      'type': type,
      'related_entity_id': relatedEntityId,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  TeamNotification copyWith({
    String? id,
    String? teamId,
    String? userId,
    String? title,
    String? message,
    String? type,
    String? relatedEntityId,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return TeamNotification(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      relatedEntityId: relatedEntityId ?? this.relatedEntityId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
} 