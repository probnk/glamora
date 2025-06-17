import 'package:firebase_auth/firebase_auth.dart';

Future<User?> getCurrentUser() async{
  final user = await FirebaseAuth.instance.currentUser;
  if(user != null)
    return user;
  return null;
}