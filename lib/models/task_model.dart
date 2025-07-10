import 'package:uuid/uuid.dart';

enum TaskStatus {
  pending,
  inProgress,
  completed,
  cancelled
}

enum TaskType {
  personal,
  team
}

enum TaskPriority {
  low,
  medium,
  high
}

extension TaskStatusExtension on TaskStatus {
  String get name {
    switch (this) {
      case TaskStatus.pending:
        return 'Menunggu';
      case TaskStatus.inProgress:
        return 'Dalam Proses';
      case TaskStatus.completed:
        return 'Selesai';
      case TaskStatus.cancelled:
        return 'Dibatalkan';
    }
  }
  
  String get color {
    switch (this) {
      case TaskStatus.pending:
        return '#FFA500'; // Orange
      case TaskStatus.inProgress:
        return '#1E90FF'; // Blue
      case TaskStatus.completed:
        return '#32CD32'; // Green
      case TaskStatus.cancelled:
        return '#FF6347'; // Red
    }
  }
}

extension TaskTypeExtension on TaskType {
  String get name {
    switch (this) {
      case TaskType.personal:
        return 'Personal';
      case TaskType.team:
        return 'Tim';
    }
  }
}

extension TaskPriorityExtension on TaskPriority {
  String get name {
    switch (this) {
      case TaskPriority.low:
        return 'Rendah';
      case TaskPriority.medium:
        return 'Sedang';
      case TaskPriority.high:
        return 'Tinggi';
    }
  }
  
  String get color {
    switch (this) {
      case TaskPriority.low:
        return '#32CD32'; // Green
      case TaskPriority.medium:
        return '#FFA500'; // Orange
      case TaskPriority.high:
        return '#FF6347'; // Red
    }
  }
}

class TaskModel {
  final String id;
  final String title;
  final String description;
  final String createdBy;
  final String assignedTo;
  final String? teamId;
  final DateTime dueDate;
  final String? executionTime; // Format: "HH:MM"
  final TaskStatus status;
  final TaskPriority? priority;
  final TaskType taskType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  TaskModel({
    String? id,
    required this.title,
    required this.description,
    required this.createdBy,
    required this.assignedTo,
    this.teamId,
    required this.dueDate,
    this.executionTime,
    this.status = TaskStatus.pending,
    this.priority = TaskPriority.medium,
    required this.taskType,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.completedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'created_by': createdBy,
      'assigned_to': assignedTo,
      'team_id': teamId,
      'due_date': dueDate.toIso8601String(),
      'execution_time': executionTime,
      'status': status.index,
      'priority': priority?.index,
      'task_type': taskType.index,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  factory TaskModel.empty() {
    return TaskModel(
      id: '',
      title: '',
      description: '',
      createdBy: '',
      assignedTo: '',
      dueDate: DateTime.now(),
      taskType: TaskType.personal,
    );
  }

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          print('Error parsing date: $e');
          return null;
        }
      }
      return null;
    }

    // Handle status yang bisa berupa int atau string
    TaskStatus parseStatus(dynamic value) {
      if (value == null) return TaskStatus.pending;
      if (value is int) return TaskStatus.values[value];
      if (value is String) {
        try {
          // Coba parse sebagai int
          final intValue = int.tryParse(value);
          if (intValue != null) {
            return TaskStatus.values[intValue];
          }
          // Jika bukan int, coba match dengan nama status
          final lowerValue = value.toLowerCase();
          if (lowerValue == 'pending') return TaskStatus.pending;
          if (lowerValue == 'inprogress' || lowerValue == 'in_progress') return TaskStatus.inProgress;
          if (lowerValue == 'completed') return TaskStatus.completed;
          if (lowerValue == 'cancelled') return TaskStatus.cancelled;
        } catch (e) {
          print('Error parsing status: $e');
        }
      }
      return TaskStatus.pending;
    }

    // Handle task_type yang bisa berupa int atau string
    TaskType parseTaskType(dynamic value, String? teamId) {
      if (value == null) return teamId != null ? TaskType.team : TaskType.personal;
      if (value is int) return TaskType.values[value];
      if (value is String) {
        final lowerValue = value.toLowerCase();
        if (lowerValue == 'team') return TaskType.team;
        if (lowerValue == 'personal') return TaskType.personal;
      }
      return teamId != null ? TaskType.team : TaskType.personal;
    }

    // Handle priority yang bisa berupa int atau string
    TaskPriority parsePriority(dynamic value) {
      if (value == null) return TaskPriority.medium;
      if (value is int) return TaskPriority.values[value];
      if (value is String) {
        final lowerValue = value.toLowerCase();
        if (lowerValue == 'low') return TaskPriority.low;
        if (lowerValue == 'medium') return TaskPriority.medium;
        if (lowerValue == 'high') return TaskPriority.high;
      }
      return TaskPriority.medium;
    }

    return TaskModel(
      id: map['id'] ?? map['\$id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      createdBy: map['created_by'] ?? '',
      assignedTo: map['assigned_to'] ?? '',
      teamId: map['team_id'],
      dueDate: parseDateTime(map['due_date']) ?? DateTime.now().add(const Duration(days: 7)),
      executionTime: map['execution_time'],
      status: parseStatus(map['status']),
      priority: parsePriority(map['priority']),
      taskType: parseTaskType(map['task_type'], map['team_id']),
      createdAt: parseDateTime(map['created_at']) ?? DateTime.now(),
      updatedAt: parseDateTime(map['updated_at']) ?? DateTime.now(),
      completedAt: parseDateTime(map['completed_at']),
    );
  }

  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    String? createdBy,
    String? assignedTo,
    String? teamId,
    DateTime? dueDate,
    String? executionTime,
    TaskStatus? status,
    TaskPriority? priority,
    TaskType? taskType,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      assignedTo: assignedTo ?? this.assignedTo,
      teamId: teamId ?? this.teamId,
      dueDate: dueDate ?? this.dueDate,
      executionTime: executionTime ?? this.executionTime,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      taskType: taskType ?? this.taskType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}