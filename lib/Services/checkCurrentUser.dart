import 'package:firebase_auth/firebase_auth.dart';

Future<bool> checkCurrentUser() async{
  User? user = FirebaseAuth.instance.currentUser;

  if (user != null) {
    print("User email: ${user.email}");
    return true;
  } else {
    print("No user is signed in.");
    return false;
  }
}