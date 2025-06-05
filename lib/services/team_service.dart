import 'package:appwrite/appwrite.dart';
import '../models/team.dart';
import '../models/team_member.dart';
import '../appwrite_config.dart';

class TeamService {
  final String databaseId = AppwriteConfig.databaseId;
  final String teamsCollectionId = 'teams';
  final String teamMembersCollectionId = 'team_members';
  final Databases databases;

  TeamService(this.databases);

  // Membuat tim baru
  Future<Team> createTeam(String teamName, String leaderId) async {
    try {
      // Generate kode undangan unik
      String invitationCode = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
      
      final document = await databases.createDocument(
        databaseId: databaseId,
        collectionId: teamsCollectionId,
        documentId: ID.unique(),
        data: {
          'team_name': teamName,
          'leader_id': leaderId,
          'invitation_code': invitationCode,
          'created_at': DateTime.now().toIso8601String(),
        },
      );

      return Team.fromJson(document.data);
    } catch (e) {
      rethrow;
    }
  }

  // Mendapatkan tim berdasarkan ID
  Future<Team> getTeam(String teamId) async {
    try {
      final document = await databases.getDocument(
        databaseId: databaseId,
        collectionId: teamsCollectionId,
        documentId: teamId,
      );

      return Team.fromJson(document.data);
    } catch (e) {
      rethrow;
    }
  }

  // Mendapatkan daftar tim yang dipimpin oleh user
  Future<List<Team>> getTeamsByLeader(String leaderId) async {
    try {
      final documents = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: teamsCollectionId,
        queries: [
          Query.equal('leader_id', leaderId),
        ],
      );

      return documents.documents.map((doc) => Team.fromJson(doc.data)).toList();
    } catch (e) {
      rethrow;
    }
  }

  // Bergabung dengan tim menggunakan kode undangan
  Future<void> joinTeam(String userId, String invitationCode) async {
    try {
      // Cari tim dengan kode undangan
      final teams = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: teamsCollectionId,
        queries: [
          Query.equal('invitation_code', invitationCode),
        ],
      );

      if (teams.documents.isEmpty) {
        throw Exception('Tim tidak ditemukan');
      }

      final team = Team.fromJson(teams.documents.first.data);

      // Cek apakah user sudah menjadi anggota tim
      final existingMember = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: teamMembersCollectionId,
        queries: [
          Query.equal('user_id', userId),
          Query.equal('team_id', team.id),
        ],
      );

      if (existingMember.documents.isNotEmpty) {
        throw Exception('Anda sudah menjadi anggota tim ini');
      }

      // Tambahkan user sebagai anggota tim
      await databases.createDocument(
        databaseId: databaseId,
        collectionId: teamMembersCollectionId,
        documentId: ID.unique(),
        data: {
          'user_id': userId,
          'team_id': team.id,
          'role': 'member',
          'joined_at': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  // Mendapatkan daftar tim yang diikuti oleh user
  Future<List<Team>> getJoinedTeams(String userId) async {
    try {
      // Dapatkan semua team_members untuk user
      final memberships = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: teamMembersCollectionId,
        queries: [
          Query.equal('user_id', userId),
        ],
      );

      // Dapatkan tim untuk setiap membership
      List<Team> teams = [];
      for (var membership in memberships.documents) {
        final teamId = membership.data['team_id'];
        final team = await getTeam(teamId);
        teams.add(team);
      }

      return teams;
    } catch (e) {
      rethrow;
    }
  }

  // Mendapatkan daftar anggota tim
  Future<List<TeamMember>> getTeamMembers(String teamId) async {
    try {
      final documents = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: teamMembersCollectionId,
        queries: [
          Query.equal('team_id', teamId),
        ],
      );

      return documents.documents.map((doc) => TeamMember.fromJson(doc.data)).toList();
    } catch (e) {
      rethrow;
    }
  }

  // Keluar dari tim
  Future<void> leaveTeam(String userId, String teamId) async {
    try {
      // Cek apakah user adalah leader
      final team = await getTeam(teamId);
      if (team.leaderId == userId) {
        throw Exception('Leader tidak dapat keluar dari tim. Silakan transfer kepemimpinan terlebih dahulu.');
      }

      // Cari membership
      final memberships = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: teamMembersCollectionId,
        queries: [
          Query.equal('user_id', userId),
          Query.equal('team_id', teamId),
        ],
      );

      if (memberships.documents.isEmpty) {
        throw Exception('Anda bukan anggota tim ini');
      }

      // Hapus membership
      await databases.deleteDocument(
        databaseId: databaseId,
        collectionId: teamMembersCollectionId,
        documentId: memberships.documents.first.$id,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Menghapus tim dan semua anggotanya
  Future<void> deleteTeam(String teamId, String userId) async {
    try {
      // Cek apakah user adalah leader
      final team = await getTeam(teamId);
      if (team.leaderId != userId) {
        throw Exception('Hanya leader yang dapat menghapus tim');
      }

      // Hapus semua anggota tim
      final members = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: teamMembersCollectionId,
        queries: [
          Query.equal('team_id', teamId),
        ],
      );

      for (var member in members.documents) {
        await databases.deleteDocument(
          databaseId: databaseId,
          collectionId: teamMembersCollectionId,
          documentId: member.$id,
        );
      }

      // Hapus tim
      await databases.deleteDocument(
        databaseId: databaseId,
        collectionId: teamsCollectionId,
        documentId: teamId,
      );
    } catch (e) {
      rethrow;
    }
  }
} 