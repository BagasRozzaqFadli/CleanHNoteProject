import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../appwrite_config.dart';
import '../models/payment_model.dart';
import '../models/user_model.dart';

class PremiumService extends ChangeNotifier {
  final Client client = Client();
  late final Account account;
  late final Databases databases;
  late final Storage storage;
  
  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;
  
  bool get isPremium => _currentUser?.isPremium ?? false;
  
  PremiumService() {
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
  
  Future<void> loadCurrentUser() async {
    try {
      final userData = await account.get();
      final userDoc = await databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'users',
        documentId: userData.$id,
      );
      
      _currentUser = UserModel.fromMap({
        'id': userDoc.$id,
        'name': userDoc.data['name'],
        'email': userDoc.data['email'],
        'isPremium': userDoc.data['isPremium'] ?? false,
        'premiumExpiryDate': userDoc.data['premiumExpiryDate'] != null 
            ? DateTime.parse(userDoc.data['premiumExpiryDate']) 
            : null,
        'createdAt': userDoc.data['created_at'] ?? userDoc.data['createdAt'] ?? DateTime.now().toIso8601String(),
      });
      
      notifyListeners();
    } catch (e) {
      print('Error loading user: $e');
      // Buat user dengan status non-premium jika terjadi error
      _currentUser = UserModel(
        id: '',
        name: '',
        email: '',
        isPremium: false,
        createdAt: DateTime.now(),
      );
      notifyListeners();
    }
  }
  
  Future<bool> upgradeToPremium(int months) async {
    if (_currentUser == null) return false;
    
    try {
      final now = DateTime.now();
      final expiryDate = now.add(Duration(days: 30 * months));
      
      await databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'users',
        documentId: _currentUser!.id,
        data: {
          'isPremium': true,
          'premiumExpiryDate': expiryDate.toIso8601String(),
        },
      );
      
      await loadCurrentUser();
      return true;
    } catch (e) {
      print('Error upgrading to premium: $e');
      return false;
    }
  }
  
  Future<String> createPayment(double amount, String method) async {
    if (_currentUser == null) throw Exception('User not logged in');
    
    final paymentId = const Uuid().v4();
    
    try {
      await databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'payments',
        documentId: paymentId,
        data: {
          'userId': _currentUser!.id,
          'amount': amount.toString(), // Menyimpan sebagai string untuk menghindari masalah presisi
          'method': method,
          'payment_status': 'pending',
          'createdAt': DateTime.now().toIso8601String(),
          'transaction_id': paymentId, // Menambahkan transaction_id sesuai database
        },
      );
      
      return paymentId;
    } catch (e) {
      print('Error creating payment: $e');
      throw Exception('Failed to create payment: $e');
    }
  }
  
  Future<bool> uploadPaymentProof(String paymentId, String filePath) async {
    try {
      final fileId = const Uuid().v4();
      
      await storage.createFile(
        bucketId: AppwriteConfig.storageBucketId,
        fileId: fileId,
        file: InputFile.fromPath(path: filePath),
      );
      
      await databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'payments',
        documentId: paymentId,
        data: {
          'payment_proof': fileId,
        },
      );
      
      return true;
    } catch (e) {
      print('Error uploading payment proof: $e');
      return false;
    }
  }
  
  Future<List<PaymentModel>> getUserPayments() async {
    if (_currentUser == null) return [];
    
    try {
      final response = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'payments',
        queries: [
          Query.equal('userId', _currentUser!.id),
        ],
      );
      
      return response.documents
          .map((doc) => PaymentModel.fromMap({...doc.data, 'id': doc.$id}))
          .toList();
    } catch (e) {
      print('Error getting user payments: $e');
      return [];
    }
  }
  
  Future<bool> checkPremiumStatus() async {
    if (_currentUser == null) return false;
    
    try {
      if (_currentUser!.isPremium && _currentUser!.premiumExpiryDate != null) {
        final now = DateTime.now();
        if (_currentUser!.premiumExpiryDate!.isAfter(now)) {
          return true;
        } else {
          // Premium expired
          await databases.updateDocument(
            databaseId: AppwriteConfig.databaseId,
            collectionId: 'users',
            documentId: _currentUser!.id,
            data: {
              'isPremium': false,
            },
          );
          
          await loadCurrentUser();
          return false;
        }
      }
      
      return false;
    } catch (e) {
      print('Error checking premium status: $e');
      return false;
    }
  }
  
  // Fungsi admin untuk mengaktifkan status premium pengguna
  Future<bool> adminActivatePremium(String userId, int months) async {
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
          databaseId: AppwriteConfig.databaseId,
          collectionId: 'users',
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
            databaseId: AppwriteConfig.databaseId,
            collectionId: 'users',
            documentId: userId,
            data: {
              'isPremium': true,
              'premiumExpiryDate': newExpiryDate.toIso8601String(),
            },
          );
        } else {
          // Jika belum premium atau sudah expired, set tanggal baru
          await databases.updateDocument(
            databaseId: AppwriteConfig.databaseId,
            collectionId: 'users',
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
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'payments',
        documentId: paymentId,
        data: {
          'userId': userId,
          'amount': amount.toString(),
          'method': 'admin_activation',
          'payment_status': 'verified',
          'createdAt': DateTime.now().toIso8601String(),
          'verifiedAt': DateTime.now().toIso8601String(),
          'verifiedBy': _currentUser?.id ?? 'admin',
          'durationMonths': months,
        },
      );
      
      // Jika pengguna yang diaktifkan adalah pengguna saat ini, perbarui data lokal
      if (_currentUser != null && _currentUser!.id == userId) {
        await loadCurrentUser();
      }
      
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
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'users',
        documentId: userId,
      );
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Fungsi untuk memverifikasi pembayaran (biasanya dilakukan oleh admin)
  Future<bool> verifyPayment(String paymentId) async {
    try {
      // Dapatkan data pembayaran
      final paymentDoc = await databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'payments',
        documentId: paymentId,
      );
      
      final userId = paymentDoc.data['userId'];
      final amount = double.tryParse(paymentDoc.data['amount'] ?? '0') ?? 0.0;
      
      // Tentukan durasi berdasarkan jumlah pembayaran
      int months = 1; // Default 1 bulan
      
      if (amount >= 480000) {
        months = 12; // 12 bulan untuk 480.000
      } else if (amount >= 270000) {
        months = 6; // 6 bulan untuk 270.000
      }
      
      // Update status pembayaran
      await databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'payments',
        documentId: paymentId,
        data: {
          'payment_status': 'verified',
          'verifiedAt': DateTime.now().toIso8601String(),
        },
      );
      
      // Aktifkan premium untuk pengguna
      return await adminActivatePremium(userId, months);
    } catch (e) {
      print('Error verifying payment: $e');
      return false;
    }
  }
  
  // Fungsi untuk mengambil semua pembayaran tertunda
  Future<List<PaymentModel>> getPendingPayments() async {
    try {
      final response = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'payments',
        queries: [
          Query.equal('payment_status', 'pending'),
        ],
      );
      
      return response.documents
          .map((doc) => PaymentModel.fromMap({...doc.data, 'id': doc.$id}))
          .toList();
    } catch (e) {
      print('Error getting pending payments: $e');
      return [];
    }
  }
} 