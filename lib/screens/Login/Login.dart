import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:glamora/BottomNavBar/BottomNavBar.dart';
import 'package:glamora/Google%20Auth%20Services/GoogleAuthServices.dart';
import 'package:glamora/Reuse%20Widgets/guestUser.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:glamora/screens/onBoarding%20Screen/onBoardingScreen.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {


  Future<void> setSkip() async {
    final setGuestUser = await SharedPreferences.getInstance();
    await setGuestUser.setBool('skip', true);
    print("Shared Preference 3: ${setGuestUser.getBool('skip')}");
  }


  //Login  Page Parent Container
  _loginBody() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
          gradient: LinearGradient(
        colors: [lightPurple3, lightBlue3],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      )),
      child: _loginComponents(),
    );
  }

  _loginComponents() {
    return Stack(
      children: [
        loginDesign(),
        guestUserSkipCrossButton(
            label: "SKIP",
            onPressed: () {
              setSkip();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => BottomNavBar()));
        })
      ],
    );
  }

  loginDesign() {
    return Column(
      children: [
        Image.asset("assets/images/glamora.png", width: 150, height: 150),
        headingFont(text: "Login", color: lightGrayBlack),
        Image.asset(
          "assets/images/login.png",
          width: double.infinity,
          height: 300,
        ),
        smallFont(
            text:
            "\nLog in with Gmail to unlock exclusive offers and discover amazing deals tailored just for you!",
            color: grayBlack),
        SizedBox(height: 80),
        Container(
            width: double.maxFinite,
            margin: EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  backgroundColor: grayBlack,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  )),
              onPressed: () async {
                final user = await GoogleAuthService().signInWithGoogle();
                if (user != null) {
                  final uid = user.uid;

                  // Check in Firestore
                  final doc = await FirebaseFirestore.instance
                      .collection('personalization')
                      .doc(uid)
                      .get();

                  if (doc.exists) {
                    // User already personalized, go to BottomNavBar
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => BottomNavBar()),
                    );
                  } else {
                    // User has no personalization yet, go to OnboardingScreen
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => GenderCategoryScreen()),
                    );
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Welcome, ${user.displayName}!')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Login Failed")),
                  );
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset("assets/images/google.png",
                      width: 30, height: 30),
                  SizedBox(width: 8),
                  smallFont(text: "Google"),
                ],
              ),
            )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loginBody(),
    );
  }
}
