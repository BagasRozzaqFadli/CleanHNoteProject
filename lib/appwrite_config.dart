import 'package:appwrite/appwrite.dart';

class AppwriteConfig {
  static const String databaseId = '6841a248003633f06890';
  static final Client client = Client()
      .setEndpoint('https://fra.cloud.appwrite.io/v1') // Ganti dengan URL Appwrite
      .setProject('cleanhnoteproject'); // Ganti dengan Project ID Appwrite Anda
}
