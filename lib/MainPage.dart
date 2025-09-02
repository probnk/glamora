import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:flutter/material.dart';
import 'package:glamora/BottomNavBar/BottomNavBar.dart';
import 'package:glamora/screens/Login/Login.dart';
import 'package:glamora/screens/onBoarding%20Screen/onBoardingScreen.dart';

class MainPage extends StatelessWidget {
  final bool isGuestUser;

  MainPage({super.key, required this.isGuestUser});

  Future<bool> _doesUserHavePersonalization(String uid) async {
    final response = await supabase.Supabase.instance.client
        .from('personalization')
        .select()
        .eq('uid', fb_auth.FirebaseAuth.instance.currentUser!.uid);

    print('\n\n\nSupabase response for personalization: ${response}\n\n\n');
    return response.isNotEmpty; // Check if response is not null (indicates a row exists)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<fb_auth.User?>(
        stream: fb_auth.FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active) {
            if (snapshot.hasData && snapshot.data != null) {
              String uid = snapshot.data!.uid;
              print('Firebase UID: $uid'); // Add this line
              return FutureBuilder<bool>(
                future: _doesUserHavePersonalization(uid),
                builder: (context, personalizationSnapshot) {
                  if (personalizationSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (personalizationSnapshot.hasError) {
                    return Center(
                        child: Text('Error: ${personalizationSnapshot.error}'));
                  }

                  if (personalizationSnapshot.data == true) {
                    return BottomNavBar();
                  } else {
                    return GenderCategoryScreen();
                  }
                },
              );
            } else {
              if (isGuestUser) {
                return BottomNavBar();
              }
              return Login();
            }
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
