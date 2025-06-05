import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:cleanhnoteapp/appwrite_config.dart';
import 'package:uuid/uuid.dart';
import 'user_service.dart';
import '../models/user.dart' as app_models;
import 'package:flutter/foundation.dart';

class AuthService {
  final Account _account = Account(AppwriteConfig.client);
  final UserService _userService = UserService(Databases(AppwriteConfig.client));
  final _uuid = Uuid();

  Future<models.User> signUp(String email, String password, String name) async {
    try {
      debugPrint('=== MULAI PROSES REGISTRASI ===');
      debugPrint('Email: $email');
      debugPrint('Name: $name');
      
      final userId = _uuid.v4();
      debugPrint('Generated UUID: $userId');

      debugPrint('Mencoba membuat user di auth...');
      debugPrint('Client endpoint: ${AppwriteConfig.client.endPoint}');
      debugPrint('Project ID: ${AppwriteConfig.client.config['project']}');
      
      // Buat user di auth
      final authUser = await _account.create(
        userId: userId,
        email: email,
        password: password,
        name: name,
      );
      debugPrint('User berhasil dibuat di auth dengan ID: ${authUser.$id}');

      try {
        // Buat user di database
        debugPrint('=== MULAI MEMBUAT USER DI DATABASE ===');
        debugPrint('Database ID: ${AppwriteConfig.databaseId}');
        debugPrint('Collection ID: ${_userService.usersCollectionId}');
        
        await _userService.createUser(
          id: userId,
          name: name,
          email: email,
        );
        debugPrint('User berhasil dibuat di database');
      } catch (dbError) {
        debugPrint('=== ERROR SAAT MEMBUAT USER DI DATABASE ===');
        debugPrint('Error type: ${dbError.runtimeType}');
        debugPrint('Error detail: $dbError');
        
        if (dbError is AppwriteException) {
          debugPrint('Appwrite error code: ${dbError.code}');
          debugPrint('Appwrite error type: ${dbError.type}');
          debugPrint('Appwrite error message: ${dbError.message}');
        }

        // Jika gagal membuat user di database, hapus user di auth
        try {
          debugPrint('Mencoba menghapus sesi karena gagal membuat di database...');
          await _account.deleteSession(sessionId: 'current');
          debugPrint('Berhasil menghapus sesi');
        } catch (deleteError) {
          debugPrint('Error saat menghapus sesi: $deleteError');
        }
        throw Exception('Gagal membuat user di database: ${dbError.toString()}');
      }

      debugPrint('=== REGISTRASI BERHASIL ===');
      return authUser;
    } on AppwriteException catch (e) {
      debugPrint('=== APPWRITE ERROR DALAM REGISTRASI ===');
      debugPrint('Error code: ${e.code}');
      debugPrint('Error type: ${e.type}');
      debugPrint('Error message: ${e.message}');
      
      if (e.type == 'user_already_exists') {
        throw Exception('Email sudah terdaftar. Silakan gunakan email lain.');
      }
      throw Exception('Gagal melakukan registrasi: ${e.message}');
    } catch (e) {
      debugPrint('=== ERROR TIDAK TERDUGA DALAM REGISTRASI ===');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error detail: $e');
      throw Exception('Terjadi kesalahan saat registrasi: $e');
    }
  }

  Future<models.Session> signIn(String email, String password) async {
    try {
      debugPrint('Mencoba login dengan email: $email');
      
      // Coba hapus sesi yang aktif terlebih dahulu
      try {
        debugPrint('Mencoba menghapus sesi aktif...');
        await _account.deleteSession(sessionId: 'current');
        debugPrint('Berhasil menghapus sesi aktif');
      } catch (e) {
        debugPrint('Tidak ada sesi aktif untuk dihapus: $e');
        // Abaikan error jika tidak ada sesi aktif
      }

      // Buat sesi baru
      debugPrint('Membuat sesi baru...');
      final response = await _account.createEmailPasswordSession(
        email: email,
        password: password,
      );
      debugPrint('Berhasil membuat sesi baru dengan ID: ${response.$id}');

      return response;
    } on AppwriteException catch (e) {
      debugPrint('Appwrite error dalam proses login: ${e.message}');
      if (e.type == 'user_invalid_credentials') {
        throw Exception('Email atau password salah');
      }
      throw Exception('Gagal melakukan login: ${e.message}');
    } catch (e) {
      debugPrint('Error dalam proses login: $e');
      throw Exception('Terjadi kesalahan saat login: $e');
    }
  }

  Future<void> signOut() async {
    try {
      debugPrint('Mencoba logout...');
      await _account.deleteSession(sessionId: 'current');
      debugPrint('Berhasil logout');
    } catch (e) {
      debugPrint('Error saat logout: $e');
      throw Exception('Terjadi kesalahan saat logout: $e');
    }
  }

  Future<app_models.User> getCurrentUser() async {
    try {
      debugPrint('Mengambil data user saat ini...');
      final authUser = await _account.get();
      debugPrint('Berhasil mendapatkan data auth user dengan ID: ${authUser.$id}');
      
      // Ambil data user dari database
      debugPrint('Mengambil data user dari database...');
      final user = await _userService.getUser(authUser.$id);
      debugPrint('Berhasil mendapatkan data user dari database');
      
      return user;
    } on AppwriteException catch (e) {
      debugPrint('Appwrite error saat mengambil data user: ${e.message}');
      if (e.type == 'user_not_found') {
        throw Exception('User tidak ditemukan');
      }
      throw Exception('Gagal mendapatkan data user: ${e.message}');
    } catch (e) {
      debugPrint('Error saat mengambil data user: $e');
      throw Exception('Terjadi kesalahan saat mengambil data user: $e');
    }
  }
}
