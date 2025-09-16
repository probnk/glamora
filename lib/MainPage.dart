import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:glamora/providers/UserProvider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:flutter/material.dart';
import 'package:glamora/BottomNavBar/BottomNavBar.dart';
import 'package:glamora/screens/Login/Login.dart';
import 'package:glamora/screens/onBoarding%20Screen/onBoardingScreen.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  Future<bool>? _personalizationFuture;

  Future<bool> _doesUserHavePersonalization(String uid) async {
    final response = await supabase.Supabase.instance.client
        .from('personalization')
        .select('email, name, picture')
        .eq('uid', uid)
        .maybeSingle(); // only get one result

    print('\n\n\nSupabase response for personalization: ${response}\n\n\n');

    if (response != null) {
      // set user once, outside of build
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.setUser(
        email: response['email'] ?? '',
        name: response['name'] ?? '',
        pictureUrl: response['picture'] ?? '',
      );
      return true;
    } else {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();

    final currentUser = fb_auth.FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      _personalizationFuture = _doesUserHavePersonalization(currentUser.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<fb_auth.User?>(
        stream: fb_auth.FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active) {
            if (snapshot.hasData && snapshot.data != null) {
              return FutureBuilder<bool>(
                future: _personalizationFuture,
                builder: (context, personalizationSnapshot) {
                  if (personalizationSnapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (personalizationSnapshot.hasError) {
                    return Center(child: Text('Error: ${personalizationSnapshot.error}'));
                  }

                  if (personalizationSnapshot.data == true) {
                    return BottomNavBar();
                  } else {
                    return GenderCategoryScreen();
                  }
                },
              );
            } else {
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
