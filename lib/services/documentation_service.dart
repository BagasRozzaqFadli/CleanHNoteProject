import 'dart:io';
import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../appwrite_config.dart';
import '../models/documentation_model.dart';

class DocumentationService extends ChangeNotifier {
  final Client client = Client();
  late final Account account;
  late final Databases databases;
  late final Storage storage;
  
  List<DocumentationModel> _documentations = [];
  List<DocumentationModel> get documentations => _documentations;
  
  DocumentationService() {
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
  
  Future<void> loadUserDocumentations() async {
    try {
      final userData = await account.get();
      
      final response = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'documentations',
        queries: [
          Query.equal('userId', userData.$id),
        ],
      );
      
      _documentations = response.documents
          .map((doc) => DocumentationModel.fromMap(doc.data))
          .toList();
      
      notifyListeners();
    } catch (e) {
      print('Error loading documentations: $e');
    }
  }
  
  Future<void> loadTeamDocumentations(String teamId) async {
    try {
      final response = await databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'documentations',
        queries: [
          Query.equal('teamId', teamId),
        ],
      );
      
      _documentations = response.documents
          .map((doc) => DocumentationModel.fromMap(doc.data))
          .toList();
      
      notifyListeners();
    } catch (e) {
      print('Error loading team documentations: $e');
    }
  }
  
  Future<String?> _uploadImage(File imageFile) async {
    try {
      // Compress image is now simplified
      final fileId = const Uuid().v4();
      
      await storage.createFile(
        bucketId: AppwriteConfig.storageBucketId,
        fileId: fileId,
        file: InputFile.fromPath(
          path: imageFile.path,
        ),
      );
      
      return fileId;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }
  
  Future<DocumentationModel?> createDocumentation({
    required String description,
    required File beforeImage,
    required File afterImage,
    String? teamId,
  }) async {
    try {
      final userData = await account.get();
      final docId = const Uuid().v4();
      
      // Upload images
      final beforeImageId = await _uploadImage(beforeImage);
      final afterImageId = await _uploadImage(afterImage);
      
      if (beforeImageId == null || afterImageId == null) {
        return null;
      }
      
      await databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'documentations',
        documentId: docId,
        data: {
          'id': docId,
          'userId': userData.$id,
          'teamId': teamId,
          'beforeImage': beforeImageId,
          'afterImage': afterImageId,
          'description': description,
          'createdAt': DateTime.now().toIso8601String(),
        },
      );
      
      final documentation = DocumentationModel(
        id: docId,
        userId: userData.$id,
        teamId: teamId,
        beforeImage: beforeImageId,
        afterImage: afterImageId,
        description: description,
        createdAt: DateTime.now(),
      );
      
      _documentations.add(documentation);
      notifyListeners();
      
      return documentation;
    } catch (e) {
      print('Error creating documentation: $e');
      return null;
    }
  }
  
  Future<String> getImageUrl(String fileId) async {
    try {
      final result = await storage.getFileDownload(
        bucketId: AppwriteConfig.storageBucketId,
        fileId: fileId,
      );
      
      return result.toString();
    } catch (e) {
      print('Error getting image URL: $e');
      return '';
    }
  }
  
  Future<bool> deleteDocumentation(String docId) async {
    try {
      final doc = _documentations.firstWhere((doc) => doc.id == docId);
      
      // Delete images
      await storage.deleteFile(
        bucketId: AppwriteConfig.storageBucketId,
        fileId: doc.beforeImage,
      );
      
      await storage.deleteFile(
        bucketId: AppwriteConfig.storageBucketId,
        fileId: doc.afterImage,
      );
      
      // Delete document
      await databases.deleteDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'documentations',
        documentId: docId,
      );
      
      _documentations.removeWhere((doc) => doc.id == docId);
      notifyListeners();
      
      return true;
    } catch (e) {
      print('Error deleting documentation: $e');
      return false;
    }
  }
  
  Future<File?> pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (pickedFile == null) return null;
      
      return File(pickedFile.path);
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }
} 