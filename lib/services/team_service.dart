import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
import '../appwrite_config.dart';
import '../models/team_model.dart';
import '../models/team_notification.dart';

import 'package:appwrite/models.dart' as models;

class TeamService extends ChangeNotifier {
  final Client client = Client();
  late final Account account;
  late final Databases databases;
  late final Storage storage;
  
  List<TeamModel> _teams = [];
  List<TeamModel> get teams => _teams;
  
  List<Map<String, dynamic>> _teamTasks = [];
  List<Map<String, dynamic>> get teamTasks => _teamTasks;
  
  List<TeamNotification> _notifications = [];
  List<TeamNotification> get notifications => _notifications;
  List<TeamNotification> get unreadNotifications => 
      _notifications.where((notification) => !notification.isRead).toList();
  
  String? _currentUserId;
  String get currentUserId => _currentUserId ?? '';
  
  TeamService() {
    init();
  }
  
  void init() {
    client
        .setEndpoint(AppwriteConfig.endpoint)
        .setProject(AppwriteConfig.projectId)
        .setSelfSigned();
    
    account = Account(client);
    databases = Databases(client);
    storage = Storage(client);
  }
  
  // Metode untuk membuat kode undangan acak
  String _generateInvitationCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }
  
  Future<void> loadUserTeams() async {
    try {
      final userData = await account.get();
      _currentUserId = userData.$id;
      
      // Fetch teams created by user (as leader)
      final createdTeamsResponse = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'teams',
        queries: [
          Query.equal('leader_id', userData.$id),
        ],
      );
      
      // Fetch teams where user is a member (from team_members collection)
      final memberTeamsResponse = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'team_members',
        queries: [
          Query.equal('user_id', userData.$id),
        ],
      );
      
      // Collect team IDs where user is a member
      final List<String> memberTeamIds = [];
      for (var doc in memberTeamsResponse.documents) {
        memberTeamIds.add(doc.data['team_id']);
      }
      
      // Fetch those teams
      final List<models.Document> memberTeams = [];
      for (var teamId in memberTeamIds) {
        try {
          final teamDoc = await databases.getDocument(
            databaseId: AppwriteConfig.databaseId,
            collectionId: 'teams',
            documentId: teamId,
          );
          memberTeams.add(teamDoc);
        } catch (e) {
          print('Error fetching team $teamId: $e');
        }
      }
      
      // Combine and remove duplicates
      final allTeams = [
        ...createdTeamsResponse.documents,
        ...memberTeams,
      ];
      
      final uniqueTeams = <String, Map<String, dynamic>>{};
      for (var doc in allTeams) {
        // Tambahkan ID dokumen ke data
        final data = Map<String, dynamic>.from(doc.data);
        data['document_id'] = doc.$id;
        uniqueTeams[doc.$id] = data;
      }
      
      _teams = uniqueTeams.values
          .map((data) => TeamModel.fromMap(_convertToTeamModelFormat(data)))
          .toList();
      
      notifyListeners();
    } catch (e) {
      print('Error loading teams: $e');
    }
  }
  
  // Helper method to convert database format to TeamModel format
  Map<String, dynamic> _convertToTeamModelFormat(Map<String, dynamic> data) {
    return {
      'id': data['document_id'] ?? '', // Menggunakan document_id yang sudah ditambahkan
      'name': data['team_name'] ?? '',
      'description': data['description'] ?? '',
      'createdBy': data['leader_id'] ?? '',
      'members': [], // Anggota tim sekarang dikelola melalui koleksi team_members
      'maxMembers': 50, // Default max members
      'createdAt': data['created_at'] ?? DateTime.now().toIso8601String(),
    };
  }
  
  Future<TeamModel?> createTeam(String name, String description) async {
    try {
      final userData = await account.get();
      final teamId = const Uuid().v4();
      final invitationCode = _generateInvitationCode();
      
      // Buat dokumen tim tanpa field members_list yang tidak ada di skema
      final document = await databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'teams',
        documentId: teamId,
        data: {
          'team_name': name,
          'description': description,
          'leader_id': userData.$id,
          'invitation_code': invitationCode,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
      
      // Tambahkan pembuat sebagai anggota tim dengan peran leader
      final memberDocId = const Uuid().v4();
      await databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'team_members',
        documentId: memberDocId,
        data: {
          'user_id': userData.$id,
          'team_id': teamId,
          'role': 'leader',
          'joined_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
      
      final team = TeamModel(
        id: teamId,
        name: name,
        description: description,
        createdBy: userData.$id,
        members: [userData.$id],
        maxMembers: 50,
        createdAt: DateTime.now(),
      );
      
      _teams.add(team);
      notifyListeners();
      
      return team;
    } catch (e) {
      print('Error creating team: $e');
      return null;
    }
  }
  
  // Bergabung dengan tim menggunakan kode undangan
  Future<bool> joinTeamWithCode(String invitationCode) async {
    try {
      final userData = await account.get();
      
      // Cek apakah kode undangan valid
      final teamResponse = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'teams',
        queries: [
          Query.equal('invitation_code', invitationCode),
        ],
      );
      
      if (teamResponse.documents.isEmpty) {
        return false; // Kode undangan tidak valid
      }
      
      final teamData = teamResponse.documents.first;
      final String teamId = teamData.$id; // ID dokumen dari Appwrite
      
      // Cek apakah pengguna sudah menjadi anggota tim
      final memberCheck = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'team_members',
        queries: [
          Query.equal('team_id', teamId),
          Query.equal('user_id', userData.$id),
        ],
      );
      
      if (memberCheck.documents.isNotEmpty) {
        return false; // Pengguna sudah menjadi anggota tim
      }
      
      // Tambahkan sebagai anggota tim dengan peran member
      final memberDocId = const Uuid().v4();
      await databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'team_members',
        documentId: memberDocId,
        data: {
          'user_id': userData.$id,
          'team_id': teamId,
          'role': 'member',
          'joined_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
      
      // Buat notifikasi untuk leader tim
      final leaderId = teamData.data['leader_id'];
      final notificationId = const Uuid().v4();
      await databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'notifications',
        documentId: notificationId,
        data: {
          'team_id': teamId,
          'user_id': leaderId,
          'title': 'Anggota Baru',
          'message': '${userData.name} telah bergabung dengan tim Anda',
          'notification_type': 'team_joined',
          'status': 'unread',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
      
      // Reload tim pengguna
      await loadUserTeams();
      
      return true;
    } catch (e) {
      print('Error joining team: $e');
      return false;
    }
  }
  
  // Dapatkan kode undangan tim
  Future<String?> getTeamInvitationCode(String teamId) async {
    try {
      final teamDoc = await databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'teams',
        documentId: teamId,
      );
      
      return teamDoc.data['invitation_code'];
    } catch (e) {
      print('Error getting invitation code: $e');
      return null;
    }
  }
  
  // Generate ulang kode undangan tim (hanya untuk leader)
  Future<String?> regenerateInvitationCode(String teamId) async {
    try {
      final userData = await account.get();
      
      // Cek apakah pengguna adalah leader tim
      final teamDoc = await databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'teams',
        documentId: teamId,
      );
      
      if (teamDoc.data['leader_id'] != userData.$id) {
        return null; // Bukan leader tim
      }
      
      final newCode = _generateInvitationCode();
      
      await databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'teams',
        documentId: teamId,
        data: {
          'invitation_code': newCode,
        },
      );
      
      return newCode;
    } catch (e) {
      print('Error regenerating invitation code: $e');
      return null;
    }
  }
  
  // Membuat tugas tim
  // Fungsi untuk membuat tugas tim dengan parameter terpisah
  Future<Map<String, dynamic>?> createTeamTaskWithParams(
    String teamId,
    String title,
    String description,
    String assignedTo,
    DateTime dueDate,
  ) async {
    try {
      final userData = await account.get();
      final taskId = const Uuid().v4();
      
      // Cek apakah pengguna adalah leader tim
      final teamMemberResponse = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'team_members',
        queries: [
          Query.equal('team_id', teamId),
          Query.equal('user_id', userData.$id),
          Query.equal('role', 'leader'),
        ],
      );
      
      if (teamMemberResponse.documents.isEmpty) {
        return null; // Pengguna bukan leader tim
      }
      
      // Buat tugas tim
      await databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'team_tasks',
        documentId: taskId,
        data: {
          'team_id': teamId,
          'title': title,
          'description': description,
          'assigned_to': assignedTo,
          'created_by': userData.$id,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(), // Tambahkan updated_at yang required
          'due_date': dueDate.toUtc().toIso8601String(),
          'status': 'pending',
        },
      );
      
      // Buat notifikasi untuk anggota yang ditugaskan
      await databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'notifications',
        documentId: ID.unique(),
        data: {
          'user_id': assignedTo,
          'title': 'Tugas Baru',
          'message': 'Anda mendapatkan tugas baru: $title',
          'notification_type': 'task_assigned',
          'status': 'unread',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'task_id': taskId,
          'team_id': teamId,
        },
      );
      
      final task = {
        'id': taskId,
        'teamId': teamId,
        'title': title,
        'description': description,
        'assignedTo': assignedTo,
        'createdBy': userData.$id,
        'createdAt': DateTime.now(),
        'dueDate': dueDate,
        'status': 'pending',
      };
      
      _teamTasks.add(task);
      notifyListeners();
      
      return task;
    } catch (e) {
      print('Error creating team task: $e');
      return null;
    }
  }
  
  // Fungsi untuk membuat tugas tim dengan parameter Map
  Future<bool> createTeamTask(Map<String, dynamic> taskData) async {
    try {
      final userData = await account.get();
      final taskId = ID.unique();
      final teamId = taskData['team_id'];
      final title = taskData['title'];
      final description = taskData['description'];
      final assignedTo = taskData['assigned_to'];
      final dueDate = taskData['due_date']; // dueDate sudah dalam format string ISO8601
      final priority = taskData['priority'] ?? 'medium';
      
      // Buat tugas tim
      await databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'team_tasks',
        documentId: taskId,
        data: {
          'team_id': teamId,
          'title': title,
          'description': description,
          'assigned_to': assignedTo,
          'created_by': userData.$id,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(), // Tambahkan updated_at yang required
          'due_date': dueDate, // dueDate sudah dalam format string ISO8601
          'status': 'pending',
          'priority': priority,
        },
      );
      
      // Buat notifikasi untuk anggota yang ditugaskan
      await databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'notifications',
        documentId: ID.unique(),
        data: {
          'user_id': assignedTo,
          'title': 'Tugas Baru',
          'message': 'Anda mendapatkan tugas baru: $title',
          'notification_type': 'task_assigned',
          'status': 'unread',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'task_id': taskId,
          'team_id': teamId,
        },
      );
      
      // Reload tasks
      await loadTeamTasks(teamId);
      
      return true;
    } catch (e) {
      print('Error creating team task: $e');
      return false;
    }
  }
  
  // Mengambil daftar tugas tim
  Future<void> loadTeamTasks(String teamId) async {
    try {
      final tasksResponse = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'team_tasks',
        queries: [
          Query.equal('team_id', teamId),
        ],
      );
      
      _teamTasks = tasksResponse.documents
          .map((doc) {
            final data = doc.data;
            data['id'] = doc.$id; // Tambahkan ID dokumen ke data
            return data;
          })
          .toList();
      
      notifyListeners();
    } catch (e) {
      print('Error loading team tasks: $e');
    }
  }
  
  // Mengambil daftar tugas yang diberikan kepada pengguna
  Future<List<Map<String, dynamic>>> loadAssignedTasks() async {
    try {
      final userData = await account.get();
      
      final tasksResponse = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'team_tasks',
        queries: [
          Query.equal('assigned_to', userData.$id),
        ],
      );
      
      final tasks = tasksResponse.documents
          .map((doc) => doc.data)
          .toList();
      
      return tasks;
    } catch (e) {
      print('Error loading assigned tasks: $e');
      return [];
    }
  }
  
  // Mengambil detail tugas berdasarkan ID
  Future<Map<String, dynamic>?> getTaskById(String taskId) async {
    try {
      final taskDoc = await databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'team_tasks',
        documentId: taskId,
      );
      
      return taskDoc.data;
    } catch (e) {
      print('Error getting task by ID: $e');
      return null;
    }
  }
  
  // Mengunggah bukti penyelesaian tugas
  Future<bool> uploadTaskCompletionProof(String taskId, String filePath) async {
    try {
      final userData = await account.get();
      
      // Dapatkan informasi tugas
      final taskDoc = await databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'team_tasks',
        documentId: taskId,
      );
      
      // Cek apakah pengguna adalah yang ditugaskan
      if (taskDoc.data['assigned_to'] != userData.$id) {
        return false; // Bukan tugas pengguna
      }
      
      // Upload bukti penyelesaian
      final fileId = const Uuid().v4();
      await storage.createFile(
        bucketId: AppwriteConfig.storageBucketId,
        fileId: fileId,
        file: InputFile.fromPath(path: filePath),
      );
      
      // Dapatkan URL file
      final fileUrl = storage.getFileDownload(
        bucketId: AppwriteConfig.storageBucketId,
        fileId: fileId,
      ).toString();
      
      // Update status tugas
      await databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'team_tasks',
        documentId: taskId,
        data: {
          'status': 'completed',
          'completion_proof': fileUrl,
        },
      );
      
      // Buat notifikasi untuk leader tim
      final teamId = taskDoc.data['team_id'];
      final createdBy = taskDoc.data['created_by'];
      final title = taskDoc.data['title'];
      
      final notificationId = const Uuid().v4();
      await databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'notifications',
        documentId: notificationId,
        data: {
          'team_id': teamId,
          'user_id': createdBy,
          'title': 'Tugas Selesai',
          'message': '${userData.name} telah menyelesaikan tugas: $title',
          'notification_type': 'task_completed',
          'task_id': taskId,
          'status': 'unread',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
      
      // Update local data
      final taskIndex = _teamTasks.indexWhere((task) => task['id'] == taskId);
      if (taskIndex != -1) {
        _teamTasks[taskIndex]['status'] = 'completed';
        _teamTasks[taskIndex]['completionProof'] = fileUrl;
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      print('Error uploading completion proof: $e');
      return false;
    }
  }
  
  // Mengambil notifikasi pengguna
  Future<void> loadUserNotifications() async {
    try {
      final userData = await account.get();
      
      final notificationsResponse = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'notifications',
        queries: [
          Query.equal('user_id', userData.$id),
          Query.orderDesc('created_at'),
        ],
      );
      
      _notifications = notificationsResponse.documents
          .map((doc) => TeamNotification.fromJson(doc.data))
          .toList();
      
      notifyListeners();
    } catch (e) {
      print('Error loading notifications: $e');
    }
  }
  
  // Menandai notifikasi sebagai dibaca
  Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      await databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'notifications',
        documentId: notificationId,
        data: {
          'status': 'read',
        },
      );
      
      // Update local data
      final notificationIndex = _notifications.indexWhere((n) => n.id == notificationId);
      if (notificationIndex != -1) {
        _notifications[notificationIndex] = _notifications[notificationIndex].copyWith(
          isRead: true,
        );
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      print('Error marking notification as read: $e');
      return false;
    }
  }
  
  Future<bool> inviteMember(String teamId, String email) async {
    try {
      // Check if user exists
      final userResponse = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'users',
        queries: [
          Query.equal('email', email),
        ],
      );
      
      if (userResponse.documents.isEmpty) {
        return false;
      }
      
      final userId = userResponse.documents.first.data['id'];
      
      // Get current team
      final teamDoc = await databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'teams',
        documentId: teamId,
      );
      
      final currentMembers = List<String>.from(teamDoc.data['members_list']);
      
      // Check if user is already a member
      if (currentMembers.contains(userId)) {
        return true;
      }
      
      // Check if team is full
      if (currentMembers.length >= teamDoc.data['max_members']) {
        return false;
      }
      
      // Add member to team
      currentMembers.add(userId);
      
      await databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'teams',
        documentId: teamId,
        data: {
          'members_list': currentMembers,
        },
      );
      
      // Add as team member with role 'member'
      final memberDocId = const Uuid().v4();
      await databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'team_members',
        documentId: memberDocId,
        data: {
          'user_id': userId,
          'team_id': teamId,
          'role': 'member',
          'joined_at': DateTime.now().toIso8601String(),
        },
      );
      
      // Create notification for the invited user
      final notificationId = const Uuid().v4();
      final teamName = teamDoc.data['team_name'];
      await databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'notifications',
        documentId: notificationId,
        data: {
          'team_id': teamId,
          'user_id': userId,
          'title': 'Undangan Tim',
          'message': 'Anda telah diundang untuk bergabung dengan tim $teamName',
          'notification_type': 'team_invitation',
          'status': 'unread',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
      
      // Update local data
      final teamIndex = _teams.indexWhere((team) => team.id == teamId);
      if (teamIndex != -1) {
        final updatedTeam = TeamModel(
          id: _teams[teamIndex].id,
          name: _teams[teamIndex].name,
          description: _teams[teamIndex].description,
          createdBy: _teams[teamIndex].createdBy,
          members: currentMembers,
          maxMembers: _teams[teamIndex].maxMembers,
          createdAt: _teams[teamIndex].createdAt,
        );
        
        _teams[teamIndex] = updatedTeam;
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      print('Error inviting member: $e');
      return false;
    }
  }
  
  Future<bool> removeMember(String teamId, String userId) async {
    try {
      // Get current team
      final teamDoc = await databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'teams',
        documentId: teamId,
      );
      
      // Check if user is the creator
      if (teamDoc.data['leader_id'] == userId) {
        return false; // Creator cannot be removed
      }
      
      // Delete team member record
      final memberResponse = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'team_members',
        queries: [
          Query.equal('team_id', teamId),
          Query.equal('user_id', userId),
        ],
      );
      
      if (memberResponse.documents.isNotEmpty) {
        await databases.deleteDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: 'team_members',
          documentId: memberResponse.documents.first.$id,
        );
      }
      
      // Update local data
      final teamIndex = _teams.indexWhere((team) => team.id == teamId);
      if (teamIndex != -1) {
        // Mendapatkan anggota tim yang diperbarui dari database
        final updatedMembers = await getTeamMembers(teamId);
        
        final updatedTeam = TeamModel(
          id: _teams[teamIndex].id,
          name: _teams[teamIndex].name,
          description: _teams[teamIndex].description,
          createdBy: _teams[teamIndex].createdBy,
          members: updatedMembers,
          maxMembers: _teams[teamIndex].maxMembers,
          createdAt: _teams[teamIndex].createdAt,
        );
        
        _teams[teamIndex] = updatedTeam;
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      print('Error removing member: $e');
      return false;
    }
  }
  
  // Mendapatkan daftar anggota tim dari koleksi team_members
  Future<List<String>> getTeamMembers(String teamId) async {
    try {
      final response = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'team_members',
        queries: [
          Query.equal('team_id', teamId),
        ],
      );
      
      return response.documents.map((doc) => doc.data['user_id'] as String).toList();
    } catch (e) {
      print('Error getting team members: $e');
      return [];
    }
  }
  
  Future<bool> deleteTeam(String teamId) async {
    try {
      await databases.deleteDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'teams',
        documentId: teamId,
      );
      
      // Delete all team members
      final membersResponse = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'team_members',
        queries: [
          Query.equal('team_id', teamId),
        ],
      );
      
      for (var doc in membersResponse.documents) {
        await databases.deleteDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: 'team_members',
          documentId: doc.$id,
        );
      }
      
      // Delete all team tasks
      final tasksResponse = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'team_tasks',
        queries: [
          Query.equal('team_id', teamId),
        ],
      );
      
      for (var doc in tasksResponse.documents) {
        await databases.deleteDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: 'team_tasks',
          documentId: doc.$id,
        );
      }
      
      // Delete all team notifications
      final notificationsResponse = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'notifications',
        queries: [
          Query.equal('team_id', teamId),
        ],
      );
      
      for (var doc in notificationsResponse.documents) {
        await databases.deleteDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: 'notifications',
          documentId: doc.$id,
        );
      }
      
      _teams.removeWhere((team) => team.id == teamId);
      _teamTasks.removeWhere((task) => task['teamId'] == teamId);
      _notifications.removeWhere((notification) => notification.teamId == teamId);
      
      notifyListeners();
      
      return true;
    } catch (e) {
      print('Error deleting team: $e');
      return false;
    }
  }
  
  // Mendapatkan tim pengguna berdasarkan userId
  Future<List<TeamModel>> getUserTeams(String userId) async {
    try {
      // Fetch teams created by user
      final createdTeamsResponse = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'teams',
        queries: [
          Query.equal('leader_id', userId),
        ],
      );
      
      // Fetch teams where user is a member
      final memberTeamsResponse = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'teams',
        queries: [
          Query.search('members_list', userId),
        ],
      );
      
      // Combine and remove duplicates
      final allTeams = [
        ...createdTeamsResponse.documents,
        ...memberTeamsResponse.documents,
      ];
      
      final uniqueTeams = <String, Map<String, dynamic>>{};
      for (var doc in allTeams) {
        // Tambahkan ID dokumen ke data
        final data = Map<String, dynamic>.from(doc.data);
        data['document_id'] = doc.$id;
        uniqueTeams[doc.$id] = data;
      }
      
      final teams = uniqueTeams.values
          .map((data) => TeamModel.fromMap(_convertToTeamModelFormat(data)))
          .toList();
      
      return teams;
    } catch (e) {
      print('Error loading teams for user: $e');
      return [];
    }
  }
  
  // Mendapatkan nama pengguna berdasarkan ID
  Future<String> getUserName(String userId) async {
    try {
      // Strategi 1: Coba cari dengan ID dokumen langsung
      try {
        final userDoc = await databases.getDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: 'users',
          documentId: userId,
        );
        
        return userDoc.data['name'] ?? 'Unknown User';
      } catch (e) {
        print('Error getting user name by document ID: $e');
        
        // Strategi 2: Coba cari dengan query berdasarkan $id
        try {
          final userResponse = await databases.listDocuments(
            databaseId: AppwriteConfig.databaseId,
            collectionId: 'users',
            queries: [
              Query.equal('\$id', userId),
            ],
          );
        
          if (userResponse.documents.isNotEmpty) {
            final userDoc = userResponse.documents.first;
            return userDoc.data['name'] ?? 'Unknown User';
          }
        } catch (queryError) {
          print('Error querying user by \$id: $queryError');
        }
        
        // Jika semua strategi gagal
        return 'Unknown User';
      }
    } catch (e) {
      print('Error getting user name: $e');
      return 'Unknown User';
    }
  }
  
  // Mendapatkan daftar anggota tim dengan nama
  Future<Map<String, String>> getTeamMembersWithNames(String teamId) async {
    try {
      final response = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'team_members',
        queries: [
          Query.equal('team_id', teamId),
        ],
      );
      
      final Map<String, String> members = {};
      
      for (var doc in response.documents) {
        final userId = doc.data['user_id'] as String;
        final userName = await getUserName(userId);
        members[userId] = userName;
      }
      
      return members;
    } catch (e) {
      print('Error getting team members with names: $e');
      return {};
    }
  }
  
  // Keluar dari tim
  Future<bool> leaveTeam(String teamId) async {
    try {
      final userData = await account.get();
      final userId = userData.$id;
      
      // Cek apakah pengguna adalah leader tim
      final teamDoc = await databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'teams',
        documentId: teamId,
      );
      
      if (teamDoc.data['leader_id'] == userId) {
        return false; // Leader tidak dapat keluar dari tim
      }
      
      // Hapus keanggotaan tim
      final memberResponse = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'team_members',
        queries: [
          Query.equal('team_id', teamId),
          Query.equal('user_id', userId),
        ],
      );
      
      if (memberResponse.documents.isNotEmpty) {
        await databases.deleteDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: 'team_members',
          documentId: memberResponse.documents.first.$id,
        );
      }
      
      // Perbarui data lokal
      final teamIndex = _teams.indexWhere((team) => team.id == teamId);
      if (teamIndex != -1) {
        _teams.removeAt(teamIndex);
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      print('Error leaving team: $e');
      return false;
    }
  }

  // Method untuk mendapatkan team tasks
  Future<List<Map<String, dynamic>>> getTeamTasksData(String teamId) async {
    try {
      final response = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'team_tasks',
        queries: [
          Query.equal('team_id', teamId),
          Query.orderDesc('\$createdAt'),
        ],
      );

      return response.documents
          .map((doc) => Map<String, dynamic>.from(doc.data))
          .toList();
    } catch (e) {
      print('Error getting team tasks: $e');
      return [];
    }
  }

  // Method untuk mendapatkan team members data
  Future<List<Map<String, dynamic>>> getTeamMembersData(String teamId) async {
    try {
      final response = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'team_members',
        queries: [
          Query.equal('team_id', teamId),
        ],
      );

      List<Map<String, dynamic>> members = [];
      for (var doc in response.documents) {
        try {
          // Ambil user_id dari dokumen team_members
          final userId = doc.data['user_id'];
          print('Mencari user dengan ID: $userId');
          
          // Strategi 1: Coba cari dengan ID dokumen langsung
          try {
            final userDoc = await databases.getDocument(
              databaseId: AppwriteConfig.databaseId,
              collectionId: 'users',
              documentId: userId,
            );
            
            final memberData = Map<String, dynamic>.from(userDoc.data);
            memberData['id'] = userDoc.$id;
            members.add(memberData);
            print('User ditemukan dengan ID dokumen: ${memberData['name']}');
            continue; // Lanjutkan ke anggota berikutnya
          } catch (e) {
            print('User tidak ditemukan dengan ID dokumen: $e');
            
            // Strategi 2: Coba cari dengan query berdasarkan $id
            try {
              final userResponse = await databases.listDocuments(
                databaseId: AppwriteConfig.databaseId,
                collectionId: 'users',
                queries: [
                  Query.equal('\$id', userId),
                ],
              );
            
              if (userResponse.documents.isNotEmpty) {
                final userDoc = userResponse.documents.first;
                final memberData = Map<String, dynamic>.from(userDoc.data);
                memberData['id'] = userDoc.$id;
                members.add(memberData);
                print('User ditemukan dengan query \$id: ${memberData['name']}');
                continue; // Lanjutkan ke anggota berikutnya
              }
            } catch (queryError) {
              print('Error saat query berdasarkan \$id: $queryError');
            }
            
            // Strategi 3: Coba cari dengan query berdasarkan email atau nama jika ada
            // Ini bisa ditambahkan jika diperlukan
            
            // Jika semua strategi gagal, tambahkan data minimal
            print('User dengan ID $userId tidak ditemukan dengan semua strategi');
            members.add({
              'id': userId,
              'name': 'Anggota Tim',
              'email': '',
            });
          }
        } catch (e) {
          print('Error getting user data: $e');
        }
      }

      return members;
    } catch (e) {
      print('Error getting team members: $e');
      return [];
    }
  }

  // Method untuk mendapatkan task statistics
  Future<Map<String, dynamic>> getTeamTaskStatistics(String teamId) async {
    try {
      final tasks = await getTeamTasksData(teamId);
      final members = await getTeamMembersData(teamId);

      int totalTasks = tasks.length;
      int completedTasks = tasks.where((task) => task['status'] == 'completed').length;
      int inProgressTasks = tasks.where((task) => task['status'] == 'in_progress').length;
      int pendingTasks = tasks.where((task) => task['status'] == 'pending').length;

      Map<String, int> memberTaskCounts = {};
      Map<String, int> memberCompletedCounts = {};

      for (var member in members) {
        final memberTasks = tasks.where((task) => task['assigned_to'] == member['id']).toList();
        final memberCompleted = memberTasks.where((task) => task['status'] == 'completed').toList();
        
        memberTaskCounts[member['id']] = memberTasks.length;
        memberCompletedCounts[member['id']] = memberCompleted.length;
      }

      return {
        'totalTasks': totalTasks,
        'completedTasks': completedTasks,
        'inProgressTasks': inProgressTasks,
        'pendingTasks': pendingTasks,
        'completionRate': totalTasks > 0 ? completedTasks / totalTasks : 0.0,
        'memberTaskCounts': memberTaskCounts,
        'memberCompletedCounts': memberCompletedCounts,
        'members': members,
        'tasks': tasks,
      };
    } catch (e) {
      print('Error getting team statistics: $e');
      return {};
    }
  }

  // Method untuk update task status
  Future<void> updateTaskStatus(String taskId, String newStatus) async {
    try {
      Map<String, dynamic> updateData = {
        'status': newStatus,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (newStatus == 'completed') {
        updateData['completed_at'] = DateTime.now().toUtc().toIso8601String();
      }

      await databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'team_tasks',
        documentId: taskId,
        data: updateData,
      );

      // Send notification if task is completed
      if (newStatus == 'completed') {
        final task = await getTaskById(taskId);
        if (task != null) {
          await _sendTaskCompletionNotification(task);
        }
      }
    } catch (e) {
      print('Error updating task status: $e');
      throw e;
    }
  }

  // Method untuk mengirim notifikasi penyelesaian tugas
  Future<void> _sendTaskCompletionNotification(Map<String, dynamic> task) async {
    try {
      await databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'notifications',
        documentId: ID.unique(),
        data: {
          'user_id': task['created_by'], // Kirim ke pembuat tugas
          'title': 'Tugas Selesai',
          'message': 'Tugas "${task['title']}" telah diselesaikan',
          'notification_type': 'task_completed',
          'status': 'unread',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'task_id': task['\$id'],
          'team_id': task['team_id'],
        },
      );
    } catch (e) {
      print('Error sending task completion notification: $e');
    }
  }

  // Method untuk membuat sample tasks untuk testing
  Future<bool> createSampleTasks(String teamId) async {
    try {
      print('Creating sample tasks for team: $teamId');
      
      final userData = await account.get();
      print('Current user ID: ${userData.$id}');

      // Ensure current user is a member of the team
      await _ensureUserIsTeamMember(teamId, userData.$id);
      
      final teamMembers = await getTeamMembersData(teamId);
      print('Team members found: ${teamMembers.length}');
      
      if (teamMembers.isEmpty) {
        print('No team members found - creating fallback user assignment');
        // Use current user as fallback if no members found
        final fallbackMember = {
          'id': userData.$id,
          'name': userData.name ?? 'Current User',
          'email': userData.email ?? '',
        };
        teamMembers.add(fallbackMember);
        print('Added fallback member: ${fallbackMember['name']}');
      }

      // Check if collection exists by trying to list documents
      try {
        await databases.listDocuments(
          databaseId: AppwriteConfig.databaseId,
          collectionId: 'team_tasks',
          queries: [Query.limit(1)],
        );
        print('team_tasks collection is accessible');
      } catch (e) {
        print('Error accessing team_tasks collection: $e');
        return false;
      }

      // Sample tasks data
      final sampleTasks = [
        {
          'title': 'Dokumentasi Project API',
          'description': 'Membuat dokumentasi lengkap untuk API endpoint aplikasi',
          'status': 'pending',
          'priority': 'high',
          'due_date': DateTime.now().add(Duration(days: 7)).toUtc().toIso8601String(),
        },
        {
          'title': 'Testing Fitur Login',
          'description': 'Melakukan testing comprehensive untuk fitur login dan autentikasi',
          'status': 'in_progress',
          'priority': 'medium',
          'due_date': DateTime.now().add(Duration(days: 3)).toUtc().toIso8601String(),
        },
        {
          'title': 'Design UI Dashboard',
          'description': 'Merancang antarmuka pengguna untuk halaman dashboard',
          'status': 'completed',
          'priority': 'medium',
          'due_date': DateTime.now().subtract(Duration(days: 2)).toUtc().toIso8601String(),
        },
      ];

      print('Creating ${sampleTasks.length} sample tasks');

      for (int i = 0; i < sampleTasks.length; i++) {
        try {
          final task = sampleTasks[i];
          final assignedMember = teamMembers[i % teamMembers.length];
          
          print('Creating task ${i + 1}: ${task['title']}');
          print('Assigned to: ${assignedMember['id']}');
          
          final docData = {
            'team_id': teamId,
            'title': task['title'],
            'description': task['description'],
            'assigned_to': assignedMember['id'],
            'created_by': userData.$id,
            'status': task['status'],
            'priority': task['priority'],
            'due_date': task['due_date'],
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          };
          
          final document = await databases.createDocument(
            databaseId: AppwriteConfig.databaseId,
            collectionId: 'team_tasks',
            documentId: ID.unique(),
            data: docData,
          );
          
          print('Task created successfully with ID: ${document.$id}');
        } catch (taskError) {
          print('Error creating individual task ${i + 1}: $taskError');
          // Continue with other tasks even if one fails
        }
      }

      print('Sample tasks creation completed');
      return true;
    } catch (e) {
      print('Error creating sample tasks: $e');
      print('Error type: ${e.runtimeType}');
      if (e is AppwriteException) {
        print('Appwrite error code: ${e.code}');
        print('Appwrite error message: ${e.message}');
        print('Appwrite error type: ${e.type}');
      }
      return false;
    }
  }

  // Method untuk cek apakah team sudah memiliki tasks
  Future<bool> hasTeamTasks(String teamId) async {
    try {
      final tasks = await getTeamTasksData(teamId);
      return tasks.isNotEmpty;
    } catch (e) {
      print('Error checking team tasks: $e');
      return false;
    }
  }

  // Method untuk memastikan user adalah anggota tim
  Future<void> _ensureUserIsTeamMember(String teamId, String userId) async {
    try {
      print('Checking if user $userId is member of team $teamId');
      
      // Check if user is already a team member
      final memberCheck = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'team_members',
        queries: [
          Query.equal('team_id', teamId),
          Query.equal('user_id', userId),
        ],
      );
      
      if (memberCheck.documents.isNotEmpty) {
        print('User is already a team member with role: ${memberCheck.documents.first.data['role']}');
        return;
      }
      
      // Check if user is the team leader
      final teamDoc = await databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'teams',
        documentId: teamId,
      );
      
      if (teamDoc.data['leader_id'] == userId) {
        print('User is team leader, adding as team member');
        // Add leader as team member if not already added
        await databases.createDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: 'team_members',
          documentId: ID.unique(),
          data: {
            'user_id': userId,
            'team_id': teamId,
            'role': 'leader',
            'joined_at': DateTime.now().toUtc().toIso8601String(),
          },
        );
        print('Leader successfully added as team member');
      } else {
        print('User is not team leader and not team member - this might be an issue');
      }
    } catch (e) {
      print('Error ensuring user is team member: $e');
      // Don't throw error, just log it
    }
  }
}