class TeamNotification {
  final String id;
  final String teamId;
  final String userId;
  final String title;
  final String message;
  final String notificationType; // 'task_assigned', 'task_completed', 'team_invitation'
  final String? taskId; // ID tugas
  final bool isRead;
  final DateTime createdAt;

  TeamNotification({
    required this.id,
    required this.teamId,
    required this.userId,
    required this.title,
    required this.message,
    required this.notificationType,
    this.taskId,
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
      notificationType: json['notification_type'] ?? '',
      taskId: json['task_id'],
      isRead: json['status'] == 'read',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'team_id': teamId,
      'user_id': userId,
      'title': title,
      'message': message,
      'notification_type': notificationType,
      'task_id': taskId,
      'status': isRead ? 'read' : 'unread',
      'created_at': createdAt.toIso8601String(),
    };
  }

  TeamNotification copyWith({
    String? id,
    String? teamId,
    String? userId,
    String? title,
    String? message,
    String? notificationType,
    String? taskId,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return TeamNotification(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      notificationType: notificationType ?? this.notificationType,
      taskId: taskId ?? this.taskId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}