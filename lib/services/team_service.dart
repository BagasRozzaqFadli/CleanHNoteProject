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
          'created_at': DateTime.now().toIso8601String(),
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
          'joined_at': DateTime.now().toIso8601String(),
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
          'joined_at': DateTime.now().toIso8601String(),
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
          'created_at': DateTime.now().toIso8601String(),
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
  Future<Map<String, dynamic>?> createTeamTask(
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
          'created_at': DateTime.now().toIso8601String(),
          'due_date': dueDate.toIso8601String(),
          'status': 'pending',
        },
      );
      
      // Buat notifikasi untuk anggota yang ditugaskan
      final notificationId = const Uuid().v4();
      await databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'team_notifications',
        documentId: notificationId,
        data: {
          'team_id': teamId,
          'user_id': assignedTo,
          'title': 'Tugas Baru',
          'message': 'Anda mendapatkan tugas baru: $title',
          'type': 'task_assigned',
          'related_entity_id': taskId,
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
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
          .map((doc) => doc.data)
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
        collectionId: 'team_notifications',
        documentId: notificationId,
        data: {
          'team_id': teamId,
          'user_id': createdBy,
          'title': 'Tugas Selesai',
          'message': '${userData.name} telah menyelesaikan tugas: $title',
          'type': 'task_completed',
          'related_entity_id': taskId,
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
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
        collectionId: 'team_notifications',
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
        collectionId: 'team_notifications',
        documentId: notificationId,
        data: {
          'is_read': true,
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
        collectionId: 'team_notifications',
        documentId: notificationId,
        data: {
          'team_id': teamId,
          'user_id': userId,
          'title': 'Undangan Tim',
          'message': 'Anda telah diundang untuk bergabung dengan tim $teamName',
          'type': 'team_invitation',
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
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
        collectionId: 'team_notifications',
        queries: [
          Query.equal('team_id', teamId),
        ],
      );
      
      for (var doc in notificationsResponse.documents) {
        await databases.deleteDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: 'team_notifications',
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
      final userDoc = await databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'users',
        documentId: userId,
      );
      
      return userDoc.data['name'] ?? 'Unknown User';
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
} 