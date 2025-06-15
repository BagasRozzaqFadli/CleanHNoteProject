import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:cleanhnoteapp/appwrite_config.dart';
import 'package:uuid/uuid.dart';
import 'user_service.dart';
import '../models/user.dart' as app_models;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AuthService {
  final Account _account = Account(AppwriteConfig.client);
  final UserService _userService = UserService(Databases(AppwriteConfig.client));
  final _uuid = Uuid();
  models.Session? _cachedSession;

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

  // Fungsi untuk menyimpan sesi ke SharedPreferences
  Future<void> _saveSessionToCache(models.Session session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionData = {
        'id': session.$id,
        'userId': session.userId,
        'expire': session.$createdAt, // Gunakan createdAt sebagai referensi
        'provider': session.provider,
        'providerUid': session.providerUid,
      };
      await prefs.setString('cached_session', jsonEncode(sessionData));
      _cachedSession = session;
      debugPrint('Sesi berhasil disimpan ke cache');
    } catch (e) {
      debugPrint('Error saat menyimpan sesi ke cache: $e');
    }
  }

  // Fungsi untuk mendapatkan sesi dari SharedPreferences
  Future<models.Session?> _getSessionFromCache() async {
    try {
      if (_cachedSession != null) {
        return _cachedSession;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final sessionJson = prefs.getString('cached_session');
      if (sessionJson == null) return null;
      
      // Cek sesi aktif di server untuk memastikan masih valid
      try {
        final currentSession = await _account.getSession(sessionId: 'current');
        _cachedSession = currentSession;
        return currentSession;
      } catch (e) {
        // Sesi tidak valid, hapus dari cache
        await prefs.remove('cached_session');
        return null;
      }
    } catch (e) {
      debugPrint('Error saat mendapatkan sesi dari cache: $e');
      return null;
    }
  }

  Future<models.Session> signIn(String email, String password) async {
    int maxRetries = 3;
    int currentRetry = 0;
    int retryDelay = 5000; // milliseconds - meningkatkan delay awal menjadi 5 detik
    
    // Coba dapatkan sesi dari cache terlebih dahulu
    final cachedSession = await _getSessionFromCache();
    if (cachedSession != null) {
      debugPrint('Menggunakan sesi dari cache');
      return cachedSession;
    }
    
    while (currentRetry < maxRetries) {
      try {
        debugPrint('Mencoba login dengan email: $email (Percobaan ${currentRetry + 1}/${maxRetries})');
        
        // Buat sesi baru
        debugPrint('Membuat sesi baru...');
        final response = await _account.createEmailPasswordSession(
          email: email,
          password: password,
        );
        debugPrint('Berhasil membuat sesi baru dengan ID: ${response.$id}');
        
        // Simpan sesi ke cache
        await _saveSessionToCache(response);
        
        return response;
      } on AppwriteException catch (e) {
        debugPrint('Appwrite error dalam proses login: ${e.message}');
        
        // Jika rate limit, tunggu dan coba lagi
        if (e.message?.contains('Rate limit') == true && currentRetry < maxRetries - 1) {
          currentRetry++;
          debugPrint('Rate limit terdeteksi, menunggu ${retryDelay/1000} detik sebelum mencoba lagi...');
          await Future.delayed(Duration(milliseconds: retryDelay));
          retryDelay *= 2; // Exponential backoff
          continue;
        }
        
        if (e.type == 'user_invalid_credentials') {
          throw AppwriteException(e.message, e.code, e.type);
        }
        throw e;
      } catch (e) {
        debugPrint('Error dalam proses login: $e');
        throw Exception('Terjadi kesalahan saat login: $e');
      }
    }
    
    throw Exception('Gagal login setelah $maxRetries percobaan. Silakan coba lagi nanti.');
  }

  Future<void> signOut() async {
    try {
      debugPrint('Mencoba logout...');
      
      // Hapus sesi dari cache terlebih dahulu
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_session');
      _cachedSession = null;
      
      // Coba hapus sesi di server
      try {
        await _account.deleteSession(sessionId: 'current');
        debugPrint('Berhasil logout dari server');
      } catch (e) {
        // Jika gagal menghapus sesi di server, abaikan karena sesi lokal sudah dihapus
        debugPrint('Tidak dapat menghapus sesi di server: $e');
      }
      
      debugPrint('Berhasil logout');
    } catch (e) {
      debugPrint('Error saat logout: $e');
      // Tidak perlu throw exception karena sesi lokal sudah dihapus
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
