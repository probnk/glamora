import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService{
  final _firebaseAuth = FirebaseAuth.instance;
  final _googleSignIn = GoogleSignIn.instance;

  Future<UserCredential?> signInWithGoogle() async {
    try{
      await _googleSignIn.initialize(
        serverClientId: "517719105350-plc260vb3h7tf1cuqvlv8knmtepmkjvb.apps.googleusercontent.com"
      );

      final account = await _googleSignIn.authenticate();
      if(account == null){
        return null;
      }

      final auth = account.authentication;
      final cred = GoogleAuthProvider.credential(idToken: auth.idToken);
      return await _firebaseAuth.signInWithCredential(cred);
    }
    catch(e){
      print("Google Signin Failed:$e");
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();
    } catch (e) {
      print('Error signing out: $e');
      throw e;
    }
  }

  String? get currentUser{
    final user = _firebaseAuth.currentUser;
    return user?.email;
  }
}