import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:flutter/foundation.dart';
import '../appwrite_config.dart';
import '../models/task_model.dart';
import 'notification_service.dart';

class TaskService extends ChangeNotifier {
  final String databaseId = AppwriteConfig.databaseId;
  final String tasksCollectionId = 'tasks';
  final Databases databases;
  final NotificationService _notificationService = NotificationService.instance;
  List<TaskModel> _tasks = [];
  bool _isLoading = false;
  String? _error;

  TaskService([Databases? db]) : databases = db ?? Databases(Client()
      .setEndpoint(AppwriteConfig.endpoint)
      .setProject(AppwriteConfig.projectId)
      .setSelfSigned());

  List<TaskModel> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Mendapatkan semua tugas personal pengguna
  Future<List<TaskModel>> getPersonalTasks(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('=== MENGAMBIL TUGAS PERSONAL ===');
      debugPrint('User ID: $userId');
      
      final response = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: tasksCollectionId,
        queries: [
          Query.equal('created_by', userId),
          Query.equal('task_type', 'personal'),
          Query.orderDesc('created_at'),
        ],
      );

      debugPrint('Jumlah tugas ditemukan: ${response.documents.length}');
      
      _tasks = response.documents.map((doc) {
        debugPrint('Task ID: ${doc.$id}, Title: ${doc.data['title']}');
        return TaskModel.fromMap({
          ...doc.data,
          'id': doc.$id,
        });
      }).toList();
      
      _isLoading = false;
      notifyListeners();
      return _tasks;
    } catch (e) {
      _isLoading = false;
      _error = 'Gagal memuat tugas: $e';
      debugPrint('=== ERROR SAAT MENGAMBIL TUGAS PERSONAL ===');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error detail: $e');
      
      if (e is AppwriteException) {
        debugPrint('Appwrite error code: ${e.code}');
        debugPrint('Appwrite error type: ${e.type}');
        debugPrint('Appwrite error message: ${e.message}');
      }
      
      notifyListeners();
      return [];
    }
  }

  // Mendapatkan tugas tim
  Future<List<TaskModel>> getTeamTasks(String teamId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('=== MENGAMBIL TUGAS TIM ===');
      debugPrint('Team ID: $teamId');
      
      final response = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: tasksCollectionId,
        queries: [
          Query.equal('team_id', teamId),
          Query.equal('task_type', 'team'),
          Query.orderDesc('created_at'),
        ],
      );

      debugPrint('Jumlah tugas tim ditemukan: ${response.documents.length}');
      
      _tasks = response.documents.map((doc) {
        debugPrint('Task ID: ${doc.$id}, Title: ${doc.data['title']}');
        return TaskModel.fromMap({
          ...doc.data,
          'id': doc.$id,
        });
      }).toList();
      
      _isLoading = false;
      notifyListeners();
      return _tasks;
    } catch (e) {
      _isLoading = false;
      _error = 'Gagal memuat tugas tim: $e';
      debugPrint('=== ERROR SAAT MENGAMBIL TUGAS TIM ===');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error detail: $e');
      
      if (e is AppwriteException) {
        debugPrint('Appwrite error code: ${e.code}');
        debugPrint('Appwrite error type: ${e.type}');
        debugPrint('Appwrite error message: ${e.message}');
      }
      
      notifyListeners();
      return [];
    }
  }

  // Mendapatkan tugas yang ditugaskan kepada pengguna
  Future<List<TaskModel>> getAssignedTasks(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: tasksCollectionId,
        queries: [
          Query.equal('assigned_to', userId),
          Query.orderDesc('created_at'),
        ],
      );

      _tasks = response.documents.map((doc) {
        return TaskModel.fromMap({
          ...doc.data,
          'id': doc.$id,
        });
      }).toList();
      
      _isLoading = false;
      notifyListeners();
      return _tasks;
    } catch (e) {
      _isLoading = false;
      _error = 'Gagal memuat tugas yang ditugaskan: $e';
      notifyListeners();
      return [];
    }
  }

  // Membuat tugas baru
  Future<TaskModel?> createTask(TaskModel task) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('=== MEMBUAT TUGAS BARU ===');
      debugPrint('Task ID: ${task.id}');
      debugPrint('Task Title: ${task.title}');
      debugPrint('Task Type: ${task.taskType.name}');
      debugPrint('Created By: ${task.createdBy}');
      debugPrint('Assigned To: ${task.assignedTo}');
      debugPrint('Due Date: ${task.dueDate}');
      debugPrint('Execution Time: ${task.executionTime}');
      debugPrint('Priority: ${task.priority?.name}');
      
      final response = await databases.createDocument(
        databaseId: databaseId,
        collectionId: tasksCollectionId,
        documentId: ID.unique(),
        data: {
          'title': task.title,
          'description': task.description,
          'created_by': task.createdBy,
          'assigned_to': task.assignedTo,
          'team_id': task.teamId ?? '',
          'task_type': task.taskType == TaskType.personal ? 'personal' : 'team',
          'due_date': task.dueDate.toIso8601String(),
          'execution_time': task.executionTime,
          'status': task.status.index.toString(),
          'priority': task.priority != null ? task.priority!.name.toLowerCase() : 'medium',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
      );

      debugPrint('Dokumen berhasil dibuat dengan ID: ${response.$id}');

      final newTask = TaskModel.fromMap({
        ...response.data,
        'id': response.$id,
      });

      _tasks.insert(0, newTask);
      _isLoading = false;
      notifyListeners();
      
      // Jadwalkan notifikasi untuk tugas baru
      try {
        await _notificationService.scheduleTaskNotification(newTask);
        debugPrint('Notifikasi berhasil dijadwalkan');
      } catch (notifError) {
        debugPrint('Error saat menjadwalkan notifikasi: $notifError');
        // Lanjutkan meskipun notifikasi gagal dijadwalkan
      }
      
      return newTask;
    } catch (e) {
      _isLoading = false;
      debugPrint('=== ERROR SAAT MEMBUAT TUGAS ===');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error detail: $e');
      
      if (e is AppwriteException) {
        debugPrint('Appwrite error code: ${e.code}');
        debugPrint('Appwrite error type: ${e.type}');
        debugPrint('Appwrite error message: ${e.message}');
      }
      
      _error = 'Gagal membuat tugas: $e';
      notifyListeners();
      return null;
    }
  }

  // Mengupdate tugas
  Future<TaskModel?> updateTask(TaskModel task) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('=== MENGUPDATE TUGAS ===');
      debugPrint('Task ID: ${task.id}');
      debugPrint('Task Title: ${task.title}');
      debugPrint('Task Type: ${task.taskType.name}');
      debugPrint('Due Date: ${task.dueDate}');
      debugPrint('Execution Time: ${task.executionTime}');
      debugPrint('Priority: ${task.priority?.name}');
      debugPrint('Status: ${task.status.name}');
      
      // Konversi data ke format yang sesuai dengan database
      final Map<String, dynamic> data = {
        'title': task.title,
        'description': task.description,
        'created_by': task.createdBy,
        'assigned_to': task.assignedTo,
        'team_id': task.teamId ?? '',
        'task_type': task.taskType == TaskType.personal ? 'personal' : 'team',
        'due_date': task.dueDate.toIso8601String(),
        'execution_time': task.executionTime,
        'status': task.status.index.toString(),
        'priority': task.priority != null ? task.priority!.name.toLowerCase() : 'medium',
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      if (task.completedAt != null) {
        data['completed_at'] = task.completedAt!.toIso8601String();
      }
      
      debugPrint('Mengirim update ke database dengan data: $data');
      final response = await databases.updateDocument(
        databaseId: databaseId,
        collectionId: tasksCollectionId,
        documentId: task.id,
        data: data,
      );
      debugPrint('Update berhasil dikirim ke database');

      final updatedTask = TaskModel.fromMap({
        ...response.data,
        'id': response.$id,
      });

      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = updatedTask;
      }
      
      _isLoading = false;
      notifyListeners();
      
      // Update notifikasi untuk tugas yang diperbarui
      try {
        await _notificationService.cancelTaskNotifications(task);
        await _notificationService.scheduleTaskNotification(updatedTask);
        debugPrint('Notifikasi berhasil diperbarui');
      } catch (notifError) {
        debugPrint('Error saat memperbarui notifikasi: $notifError');
        // Lanjutkan meskipun notifikasi gagal diperbarui
      }
      
      return updatedTask;
    } catch (e) {
      _isLoading = false;
      debugPrint('=== ERROR SAAT MENGUPDATE TUGAS ===');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error detail: $e');
      
      if (e is AppwriteException) {
        debugPrint('Appwrite error code: ${e.code}');
        debugPrint('Appwrite error type: ${e.type}');
        debugPrint('Appwrite error message: ${e.message}');
      }
      
      _error = 'Gagal mengupdate tugas: $e';
      notifyListeners();
      return null;
    }
  }

  // Mendapatkan tugas berdasarkan ID
  Future<TaskModel> getTaskById(String taskId) async {
    debugPrint('=== MENGAMBIL TUGAS BERDASARKAN ID ===');
    debugPrint('Task ID: $taskId');
    
    try {
      final response = await databases.getDocument(
        databaseId: databaseId,
        collectionId: tasksCollectionId,
        documentId: taskId,
      );
      
      debugPrint('Berhasil mendapatkan tugas dengan ID: ${response.$id}');
      
      return TaskModel.fromMap({
        ...response.data,
        'id': response.$id,
      });
    } catch (e) {
      debugPrint('=== ERROR SAAT MENGAMBIL TUGAS BERDASARKAN ID ===');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error detail: $e');
      
      if (e is AppwriteException) {
        debugPrint('Appwrite error code: ${e.code}');
        debugPrint('Appwrite error type: ${e.type}');
        debugPrint('Appwrite error message: ${e.message}');
      }
      
      throw Exception('Gagal mengambil tugas: $e');
    }
  }

  // Mengubah status tugas
  Future<bool> updateTaskStatus(String taskId, TaskStatus newStatus) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('=== MENGUBAH STATUS TUGAS ===');
      debugPrint('Task ID: $taskId');
      debugPrint('New Status: ${newStatus.name}');
      
      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index == -1) {
        debugPrint('Tugas tidak ditemukan di daftar lokal');
        _isLoading = false;
        _error = 'Tugas tidak ditemukan';
        notifyListeners();
        return false;
      }

      final task = _tasks[index];
      final DateTime? completedAt = newStatus == TaskStatus.completed ? DateTime.now() : null;
      
      final updatedTask = task.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
        completedAt: completedAt,
      );

      debugPrint('Mengirim update ke database...');
      await databases.updateDocument(
        databaseId: databaseId,
        collectionId: tasksCollectionId,
        documentId: taskId,
        data: {
          'status': newStatus.index.toString(), // Konversi ke string untuk menghindari masalah tipe data
          'updated_at': DateTime.now().toIso8601String(),
          if (completedAt != null) 'completed_at': completedAt.toIso8601String(),
        },
      );
      debugPrint('Update berhasil dikirim ke database');

      _tasks[index] = updatedTask;
      _isLoading = false;
      notifyListeners();
      
      // Jika tugas selesai atau dibatalkan, batalkan notifikasinya
      if (newStatus == TaskStatus.completed || newStatus == TaskStatus.cancelled) {
        debugPrint('Membatalkan notifikasi untuk tugas yang ${newStatus.name}');
        await _notificationService.cancelTaskNotifications(updatedTask);
      }
      
      return true;
    } catch (e) {
      _isLoading = false;
      debugPrint('=== ERROR SAAT MENGUBAH STATUS TUGAS ===');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error detail: $e');
      
      if (e is AppwriteException) {
        debugPrint('Appwrite error code: ${e.code}');
        debugPrint('Appwrite error type: ${e.type}');
        debugPrint('Appwrite error message: ${e.message}');
      }
      
      _error = 'Gagal mengupdate status tugas: $e';
      notifyListeners();
      return false;
    }
  }

  // Menghapus tugas
  Future<bool> deleteTask(String taskId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        final task = _tasks[index];
        await _notificationService.cancelTaskNotifications(task);
      }

      await databases.deleteDocument(
        databaseId: databaseId,
        collectionId: tasksCollectionId,
        documentId: taskId,
      );

      _tasks.removeWhere((task) => task.id == taskId);
      _isLoading = false;
      notifyListeners();
      
      return true;
    } catch (e) {
      _isLoading = false;
      _error = 'Gagal menghapus tugas: $e';
      notifyListeners();
      return false;
    }
  }
} 