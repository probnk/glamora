import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> saveFCMToken() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    final ref = FirebaseDatabase.instance
        .ref('token/${user.uid}/fcmToken');

    await ref.set(token);

    print('FCM Token saved: $token');
  } catch (e) {
    print('Error saving FCM token: $e');
  }
}
void listenForTokenRefresh() {
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    saveFCMToken();
  });
}