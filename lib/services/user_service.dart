import 'package:appwrite/appwrite.dart';
import '../models/user.dart';
import '../appwrite_config.dart';

class UserService {
  final String databaseId = AppwriteConfig.databaseId;
  final String usersCollectionId = 'users';
  final Databases databases;

  UserService(this.databases);

  // Membuat user baru
  Future<User> createUser({
    required String id,
    required String name,
    required String email,
  }) async {
    try {
      // Generate tenant ID unik
      String tenantId = DateTime.now().millisecondsSinceEpoch.toString();
      
      final document = await databases.createDocument(
        databaseId: databaseId,
        collectionId: usersCollectionId,
        documentId: id, // Menggunakan ID yang sama dengan auth
        data: {
          'name': name,
          'email': email,
          'tenant_id': tenantId,
          'created_at': DateTime.now().toIso8601String(),
        },
      );

      return User.fromJson(document.data);
    } on AppwriteException catch (e) {
      if (e.message?.contains('Database not found') ?? false) {
        throw Exception('Database belum dibuat. Silakan buat database dan collection users terlebih dahulu.');
      } else if (e.message?.contains('Collection not found') ?? false) {
        throw Exception('Collection users belum dibuat. Silakan buat collection users terlebih dahulu.');
      }
      throw Exception('Gagal membuat user: ${e.message}');
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  // Mendapatkan user berdasarkan ID
  Future<User> getUser(String userId) async {
    try {
      final document = await databases.getDocument(
        databaseId: databaseId,
        collectionId: usersCollectionId,
        documentId: userId,
      );

      return User.fromJson(document.data);
    } on AppwriteException catch (e) {
      if (e.message?.contains('Document not found') ?? false) {
        throw Exception('User tidak ditemukan');
      }
      throw Exception('Gagal mendapatkan user: ${e.message}');
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }

  // Update data user
  Future<User> updateUser({
    required String id,
    String? name,
    String? email,
  }) async {
    try {
      Map<String, dynamic> data = {};
      if (name != null) data['name'] = name;
      if (email != null) data['email'] = email;

      final document = await databases.updateDocument(
        databaseId: databaseId,
        collectionId: usersCollectionId,
        documentId: id,
        data: data,
      );

      return User.fromJson(document.data);
    } on AppwriteException catch (e) {
      if (e.message?.contains('Document not found') ?? false) {
        throw Exception('User tidak ditemukan');
      }
      throw Exception('Gagal mengupdate user: ${e.message}');
    } catch (e) {
      throw Exception('Terjadi kesalahan: $e');
    }
  }
} 