import 'package:appwrite/appwrite.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart';
import '../models/user_model.dart';
import '../appwrite_config.dart';

class UserService {
  final String databaseId = AppwriteConfig.databaseId;
  final String usersCollectionId = 'users';
  final Databases databases;
  
  UserService([Databases? db]) : databases = db ?? Databases(Client()
      .setEndpoint(AppwriteConfig.endpoint)
      .setProject(AppwriteConfig.projectId)
      .setSelfSigned());

  // Mendapatkan semua pengguna untuk admin
  Future<List<UserModel>> getAllUsers() async {
    try {
      final response = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: usersCollectionId,
        queries: [
          Query.limit(100), // Batasi 100 pengguna untuk performa
        ],
      );
      
      return response.documents.map((doc) {
        return UserModel.fromMap({
          'id': doc.$id,
          'name': doc.data['name'] ?? 'Unknown',
          'email': doc.data['email'] ?? '',
          'isPremium': doc.data['isPremium'] ?? false,
          'premiumExpiryDate': doc.data['premiumExpiryDate'],
          'createdAt': doc.data['created_at'] ?? doc.data['createdAt'] ?? DateTime.now().toIso8601String(),
        });
      }).toList();
    } catch (e) {
      print('Error getting all users: $e');
      throw Exception('Gagal mendapatkan daftar pengguna: $e');
    }
  }

  // Aktivasi premium oleh admin
  Future<bool> activatePremium(String userId, int months) async {
    try {
      // Verifikasi user ID terlebih dahulu
      final userExists = await _checkUserExists(userId);
      if (!userExists) {
        print('Error: User dengan ID $userId tidak ditemukan');
        return false;
      }
      
      final now = DateTime.now();
      final expiryDate = now.add(Duration(days: 30 * months));
      
      // Cek apakah pengguna sudah premium
      try {
        final userDoc = await databases.getDocument(
          databaseId: databaseId,
          collectionId: usersCollectionId,
          documentId: userId,
        );
        
        final isPremium = userDoc.data['isPremium'] ?? false;
        final currentExpiryDateStr = userDoc.data['premiumExpiryDate'];
        DateTime? currentExpiryDate;
        
        if (currentExpiryDateStr != null) {
          try {
            currentExpiryDate = DateTime.parse(currentExpiryDateStr);
          } catch (e) {
            print('Error parsing expiry date: $e');
          }
        }
        
        // Jika sudah premium, perpanjang masa berlaku
        if (isPremium && currentExpiryDate != null && currentExpiryDate.isAfter(now)) {
          final newExpiryDate = currentExpiryDate.add(Duration(days: 30 * months));
          
          await databases.updateDocument(
            databaseId: databaseId,
            collectionId: usersCollectionId,
            documentId: userId,
            data: {
              'isPremium': true,
              'premiumExpiryDate': newExpiryDate.toIso8601String(),
            },
          );
        } else {
          // Jika belum premium atau sudah expired, set tanggal baru
          await databases.updateDocument(
            databaseId: databaseId,
            collectionId: usersCollectionId,
            documentId: userId,
            data: {
              'isPremium': true,
              'premiumExpiryDate': expiryDate.toIso8601String(),
            },
          );
        }
      } catch (e) {
        print('Error getting user document: $e');
        return false;
      }
      
      // Buat catatan pembayaran
      final paymentId = const Uuid().v4();
      double amount = 50000; // Default 1 bulan
      
      if (months == 6) {
        amount = 270000;
      } else if (months == 12) {
        amount = 480000;
      }
      
      await databases.createDocument(
        databaseId: databaseId,
        collectionId: 'payments',
        documentId: paymentId,
        data: {
          'user_id': userId,
          'subscription_id': paymentId, // Menggunakan ID yang sama untuk subscription
          'amount': amount.toString(),
          'payment_method': 'admin_activation',
          'payment_status': 'verified',
          'transaction_id': 'admin_${DateTime.now().millisecondsSinceEpoch}',
          'payment_proof': 'admin_activation',
          'created_at': DateTime.now().toIso8601String(),
          'verified_at': DateTime.now().toIso8601String(),
          'duration_months': months.toString(),
        },
      );
      
      return true;
    } catch (e) {
      print('Error activating premium: $e');
      return false;
    }
  }

  // Helper method untuk memeriksa keberadaan user
  Future<bool> _checkUserExists(String userId) async {
    try {
      await databases.getDocument(
        databaseId: databaseId,
        collectionId: usersCollectionId,
        documentId: userId,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

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
  
  // Mendapatkan user model berdasarkan ID
  Future<UserModel> getUserById(String userId) async {
    try {
      final document = await databases.getDocument(
        databaseId: databaseId,
        collectionId: usersCollectionId,
        documentId: userId,
      );

      return UserModel.fromMap({
        'id': document.data['id'] ?? document.$id ?? '',
        'name': document.data['name'] ?? '',
        'email': document.data['email'] ?? '',
        'isPremium': document.data['isPremium'] ?? false,
        'premiumExpiryDate': document.data['premiumExpiryDate'],
        'createdAt': document.data['created_at'] ?? document.data['createdAt'] ?? DateTime.now().toIso8601String(),
      });
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

  Future<bool> setAdminStatus(String userId, bool isAdmin, {String? currentUserEmail}) async {
    try {
      // Pengecekan tambahan untuk memastikan hanya admin utama yang dapat mengubah status admin
      if (currentUserEmail != null && currentUserEmail != 'admin@cleanhnote.com') {
        print('Error: Hanya admin utama yang dapat mengubah status admin');
        return false;
      }
      
      // Cek apakah user yang akan diubah adalah admin utama
      final userDoc = await databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'users',
        documentId: userId,
      );
      
      final String userEmail = userDoc.data['email'] ?? '';
      if (userEmail == 'admin@cleanhnote.com' && !isAdmin) {
        print('Error: Tidak dapat mencabut hak admin dari admin utama');
        return false;
      }
      
      await databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'users',
        documentId: userId,
        data: {
          'isAdmin': isAdmin,
        },
      );
      
      return true;
    } catch (e) {
      print('Error setting admin status: $e');
      return false;
    }
  }
  
  Future<bool> checkAdminStatus(String userId) async {
    try {
      final doc = await databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'users',
        documentId: userId,
      );
      
      return doc.data['isAdmin'] ?? false;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }
  
  Future<List<Map<String, dynamic>>> getAdminList() async {
    try {
      final response = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'users',
        queries: [
          Query.equal('isAdmin', true),
        ],
      );
      
      return response.documents.map((doc) {
        return {
          'id': doc.$id,
          'name': doc.data['name'] ?? 'Unknown',
          'email': doc.data['email'] ?? 'No Email',
          'isAdmin': doc.data['isAdmin'] ?? false,
        };
      }).toList();
    } catch (e) {
      print('Error getting admin list: $e');
      return [];
    }
  }
} 