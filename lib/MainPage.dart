import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:glamora/screens/Login/Login.dart';

import 'BottomNavBar/BottomNavBar.dart';

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.active) {
              // Check if the user is logged in
              if (snapshot.hasData && snapshot.data != null) {
                // Navigate to BottomNavBar if logged in
                return BottomNavBar();
              } else {
                // Navigate to LoginScreen if not logged in
                return Login();
              }
            } else {
              // Show a loading screen while waiting for the stream
              return CircularProgressIndicator();
            }
          },
        )

    );
  }
}