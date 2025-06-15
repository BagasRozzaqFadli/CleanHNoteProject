import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../appwrite_config.dart';
import '../models/task_model.dart';
import 'notification_service.dart';

class TaskSchedule {
  final String id;
  final String taskId;
  final String userId;
  final String? teamId;
  final DateTime executionDate;
  final String timeSlot; // Format: "HH:MM-HH:MM" (contoh: "09:00-10:00")
  final DateTime? reminderTime;
  final String status; // scheduled, in_progress, completed, cancelled
  final DateTime createdAt;

  TaskSchedule({
    String? id,
    required this.taskId,
    required this.userId,
    this.teamId,
    required this.executionDate,
    required this.timeSlot,
    this.reminderTime,
    this.status = 'scheduled',
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'user_id': userId,
      'team_id': teamId,
      'execution_date': executionDate.toIso8601String(),
      'time_slot': timeSlot,
      'reminder_time': reminderTime?.toIso8601String(),
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory TaskSchedule.fromMap(Map<String, dynamic> map) {
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

    return TaskSchedule(
      id: map['id'] ?? map['\$id'] ?? '',
      taskId: map['task_id'] ?? '',
      userId: map['user_id'] ?? '',
      teamId: map['team_id'],
      executionDate: parseDateTime(map['execution_date']) ?? DateTime.now(),
      timeSlot: map['time_slot'] ?? '09:00-10:00',
      reminderTime: parseDateTime(map['reminder_time']),
      status: map['status'] ?? 'scheduled',
      createdAt: parseDateTime(map['created_at']) ?? DateTime.now(),
    );
  }
}

class TaskScheduleService extends ChangeNotifier {
  final String databaseId = AppwriteConfig.databaseId;
  final String schedulesCollectionId = 'task_schedules';
  final Databases databases;
  final NotificationService _notificationService = NotificationService.instance;
  List<TaskSchedule> _schedules = [];
  bool _isLoading = false;
  String? _error;

  TaskScheduleService([Databases? db]) : databases = db ?? Databases(Client()
      .setEndpoint(AppwriteConfig.endpoint)
      .setProject(AppwriteConfig.projectId)
      .setSelfSigned());

  List<TaskSchedule> get schedules => _schedules;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Mendapatkan jadwal tugas untuk pengguna
  Future<List<TaskSchedule>> getUserSchedules(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: schedulesCollectionId,
        queries: [
          Query.equal('user_id', userId),
          Query.orderDesc('execution_date'),
        ],
      );

      _schedules = response.documents.map((doc) {
        return TaskSchedule.fromMap({
          ...doc.data,
          'id': doc.$id,
        });
      }).toList();
      
      _isLoading = false;
      notifyListeners();
      return _schedules;
    } catch (e) {
      _isLoading = false;
      _error = 'Gagal memuat jadwal: $e';
      notifyListeners();
      return [];
    }
  }

  // Mendapatkan jadwal tugas untuk tim
  Future<List<TaskSchedule>> getTeamSchedules(String teamId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: schedulesCollectionId,
        queries: [
          Query.equal('team_id', teamId),
          Query.orderDesc('execution_date'),
        ],
      );

      _schedules = response.documents.map((doc) {
        return TaskSchedule.fromMap({
          ...doc.data,
          'id': doc.$id,
        });
      }).toList();
      
      _isLoading = false;
      notifyListeners();
      return _schedules;
    } catch (e) {
      _isLoading = false;
      _error = 'Gagal memuat jadwal tim: $e';
      notifyListeners();
      return [];
    }
  }

  // Mendapatkan jadwal untuk tugas tertentu
  Future<List<TaskSchedule>> getTaskSchedules(String taskId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: schedulesCollectionId,
        queries: [
          Query.equal('task_id', taskId),
          Query.orderDesc('execution_date'),
        ],
      );

      _schedules = response.documents.map((doc) {
        return TaskSchedule.fromMap({
          ...doc.data,
          'id': doc.$id,
        });
      }).toList();
      
      _isLoading = false;
      notifyListeners();
      return _schedules;
    } catch (e) {
      _isLoading = false;
      _error = 'Gagal memuat jadwal tugas: $e';
      notifyListeners();
      return [];
    }
  }

  // Membuat jadwal tugas baru
  Future<TaskSchedule?> createSchedule(TaskSchedule schedule) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await databases.createDocument(
        databaseId: databaseId,
        collectionId: schedulesCollectionId,
        documentId: schedule.id,
        data: schedule.toMap(),
      );

      final newSchedule = TaskSchedule.fromMap({
        ...response.data,
        'id': response.$id,
      });

      _schedules.insert(0, newSchedule);
      _isLoading = false;
      notifyListeners();
      
      // Jadwalkan notifikasi untuk jadwal baru
      await _scheduleNotification(newSchedule);
      
      return newSchedule;
    } catch (e) {
      _isLoading = false;
      _error = 'Gagal membuat jadwal: $e';
      notifyListeners();
      return null;
    }
  }

  // Mengupdate status jadwal
  Future<bool> updateScheduleStatus(String scheduleId, String newStatus) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await databases.updateDocument(
        databaseId: databaseId,
        collectionId: schedulesCollectionId,
        documentId: scheduleId,
        data: {
          'status': newStatus,
        },
      );

      final index = _schedules.indexWhere((s) => s.id == scheduleId);
      if (index != -1) {
        final updated = TaskSchedule.fromMap({
          ..._schedules[index].toMap(),
          'status': newStatus,
        });
        _schedules[index] = updated;
      }
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = 'Gagal mengupdate status jadwal: $e';
      notifyListeners();
      return false;
    }
  }

  // Menghapus jadwal
  Future<bool> deleteSchedule(String scheduleId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await databases.deleteDocument(
        databaseId: databaseId,
        collectionId: schedulesCollectionId,
        documentId: scheduleId,
      );

      _schedules.removeWhere((schedule) => schedule.id == scheduleId);
      _isLoading = false;
      notifyListeners();
      
      return true;
    } catch (e) {
      _isLoading = false;
      _error = 'Gagal menghapus jadwal: $e';
      notifyListeners();
      return false;
    }
  }

  // Jadwalkan notifikasi untuk jadwal
  Future<void> _scheduleNotification(TaskSchedule schedule) async {
    // Implementasi penjadwalan notifikasi untuk jadwal tugas
    // Ini akan diimplementasikan sesuai kebutuhan
  }
}
