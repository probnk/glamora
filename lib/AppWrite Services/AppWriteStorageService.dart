import 'package:appwrite/appwrite.dart';

class AppwriteService {
  late Client _client;
  late Storage _storage;

  AppwriteService() {
    _client = Client()
      ..setEndpoint('https://cloud.appwrite.io/v1') // Replace with your Appwrite endpoint
      ..setProject('677132610020fa2644ac'); // Replace with your Appwrite project ID
    _storage = Storage(_client);
  }

  // Getter to access storage
  Storage get storage => _storage;
}
