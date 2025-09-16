import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

void setupCustomerOnlineStatus() {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    print('No authenticated user found. Skipping online status setup.');
    return;
  }

  final uid = user.uid; // Safe access after null check
  final userStatusRef = FirebaseDatabase.instance.ref('status/$uid');
  final connectedRef = FirebaseDatabase.instance.ref('.info/connected');

  print('Setting up online status for customer: $uid');

  connectedRef.onValue.listen((event) async {
    final isConnected = event.snapshot.value as bool?;
    print('Connection status: $isConnected');

      try {
        await userStatusRef.update({
          'isOnline': true,
          'lastSeen': ServerValue.timestamp,
        });
        print('Set status to online for $uid');
        await userStatusRef.onDisconnect().update({
          'isOnline': false,
          'lastSeen': ServerValue.timestamp,
        });
        print('onDisconnect handler registered for $uid');
      } catch (e) {
        print('Error updating status: $e');
      }

  });
}