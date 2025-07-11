class TeamTask {
  final String id;
  final String teamId;
  final String title;
  final String description;
  final String assignedTo;
  final String createdBy;
  final DateTime createdAt;
  final DateTime dueDate;
  final String status; // 'pending', 'in_progress', 'completed'
  final String? completionProof; // URL to image

  TeamTask({
    required this.id,
    required this.teamId,
    required this.title,
    required this.description,
    required this.assignedTo,
    required this.createdBy,
    required this.createdAt,
    required this.dueDate,
    required this.status,
    this.completionProof,
  });

  factory TeamTask.fromJson(Map<String, dynamic> json) {
    return TeamTask(
      id: json['\$id'] ?? json['id'] ?? '',
      teamId: json['team_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      assignedTo: json['assigned_to'] ?? '',
      createdBy: json['created_by'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      dueDate: DateTime.tryParse(json['due_date'] ?? '') ?? DateTime.now().add(const Duration(days: 7)),
      status: json['status'] ?? 'pending',
      completionProof: json['completion_proof'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'team_id': teamId,
      'title': title,
      'description': description,
      'assigned_to': assignedTo,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'due_date': dueDate.toIso8601String(),
      'status': status,
      'completion_proof': completionProof,
    };
  }

  TeamTask copyWith({
    String? id,
    String? teamId,
    String? title,
    String? description,
    String? assignedTo,
    String? createdBy,
    DateTime? createdAt,
    DateTime? dueDate,
    String? status,
    String? completionProof,
  }) {
    return TeamTask(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      title: title ?? this.title,
      description: description ?? this.description,
      assignedTo: assignedTo ?? this.assignedTo,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      completionProof: completionProof ?? this.completionProof,
    );
  }
}
