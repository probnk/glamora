import 'package:flutter/material.dart';
import 'package:glamora/BottomNavBar/BottomNavBar.dart';
import 'package:glamora/Google%20Auth%20Services/GoogleAuthService.dart';
import 'package:glamora/Reuse%20Widgets/guestUser.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:glamora/screens/onBoarding%20Screen/onBoardingScreen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {

  final auth = GoogleAuthService();

  Future<void> setSkip() async {
    final setGuestUser = await SharedPreferences.getInstance();
    await setGuestUser.setBool('skip', true);
  }

  //Login Page Parent Container
  _loginBody() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: green),
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
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (context) => BottomNavBar()));
            })
      ],
    );
  }

  loginDesign() {
    return Column(
      children: [
        SizedBox(height: 60),
        Image.asset(
          "assets/images/t-shirt1.png",
          width: double.infinity,
          filterQuality: FilterQuality.high,
          height: 300,
        ),
        SizedBox(height: 10),
        Text(
          "Select\n a Login Method",
          style: GoogleFonts.lobster(fontSize: 48, color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 20),
        smallFont(
            text:
                "\nLog in with Gmail to unlock exclusive offers and discover amazing deals tailored just for you!",
            color: grayBlack),
        SizedBox(height: 50),
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
                final user = await auth.signInWithGoogle();
                if (user != null) {

                  // Check in Supabase
                  final response = await Supabase.instance.client
                      .from('personalization')
                      .select()
                      .eq('uid', FirebaseAuth.instance.currentUser!.uid);

                  print(
                      '\n\n\nSupabase response for personalization: $response\n\n\n');

                  // FIXED: Properly check if response is empty
                  if (response != null && response.isNotEmpty && response != []) {
                    // User already personalized, go to BottomNavBar
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => BottomNavBar()),
                    );
                  } else {
                    // User has no personalization yet, go to GenderCategoryScreen
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => GenderCategoryScreen()),
                    );
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Welcome, ${FirebaseAuth.instance.currentUser!.displayName}!')),
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
                  Text("Google", style: TextStyle(color: Colors.white)),
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
