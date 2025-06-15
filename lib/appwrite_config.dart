import 'package:appwrite/appwrite.dart';

class AppwriteConfig {
  static const String endpoint = 'https://fra.cloud.appwrite.io/v1';
  static const String projectId = 'cleanhnoteproject';
  static const String databaseId = '6841a248003633f06890';
  static const String storageBucketId = 'cleanhnote_storage';
  
  static final Client client = Client()
      .setEndpoint(endpoint)
      .setProject(projectId);
}
