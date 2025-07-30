import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:glamora/BottomNavBar/BottomNavBar.dart';
import 'package:glamora/screens/Login/Login.dart';
import 'package:glamora/screens/onBoarding%20Screen/onBoardingScreen.dart';

class MainPage extends StatelessWidget {
  bool isGuestUser;
  MainPage({super.key,required this.isGuestUser});

  Future<DocumentSnapshot> _getUserPersonalizationData(String uid) async {
    try {
      // Check if the user's personalization data exists in Firestore
      return await FirebaseFirestore.instance.collection('personalization').doc(uid).get();
    } catch (e) {
      throw Exception('Error fetching personalization data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active) {
            if (snapshot.hasData && snapshot.data != null) {
              // User is logged in
              String uid = snapshot.data!.uid;
              // Check if personalization data exists in Firestore
              return FutureBuilder<DocumentSnapshot>(
                future: _getUserPersonalizationData(uid),
                builder: (context, personalizationSnapshot) {
                  if (personalizationSnapshot.connectionState == ConnectionState.waiting) {
                    // While waiting for data, show a loading indicator
                    return Center(child: CircularProgressIndicator());
                  }

                  if (personalizationSnapshot.hasError) {
                    return Center(child: Text('Error: ${personalizationSnapshot.error}'));
                  }

                  if ((personalizationSnapshot.hasData && personalizationSnapshot.data!.exists)) {
                    // Personalization data exists, navigate to BottomNavBar
                    return BottomNavBar();
                  } else {
                    // Personalization data doesn't exist, navigate to GenderCategoryScreen
                    return GenderCategoryScreen();
                  }
                },
              );
            } else {
              // User is not logged in, navigate to Login screen
              if(isGuestUser){
                return BottomNavBar();
              }
              return Login();
            }
          } else {
            // Waiting for connection state to be active
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
