import 'dart:async';
import 'package:flutter/material.dart';
import 'package:glamora/MainPage.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:glamora/screens/Get%20Started/GetStarted.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    initializeTheme();
    Timer(Duration(seconds: 2), () async {
      final sharedPreference = await SharedPreferences.getInstance();
      final _isGetStarted = sharedPreference.getBool('isGetStarted') ?? false;
      final _isGuestUser = sharedPreference.getBool('skip') ?? false;
      if (_isGetStarted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MainPage(isGuestUser: _isGuestUser)),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => GetStarted()),
        );
      }
    });
  }

  Future<void> initializeTheme() async {
    final themePreference = await SharedPreferences.getInstance();
    final provider = Provider.of<DarkModeProvider>(context, listen: false);

    final isDarkTheme = themePreference.getBool('isDarkMode') ?? false;
    provider.toggleMode(isDarkTheme);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(colors: [lightPurple,darkPurple])
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("assets/images/glamora.png", width: 200, height: 200),
            Text(
              "Vision Cart",
              style: GoogleFonts.whisper(color: white, fontSize: 60),
            ),
            Text(
              "Buy More, Save More",
              style: GoogleFonts.josefinSans(
                  color: Colors.grey.shade300, fontSize: 18),
            )
          ],
        )),
      ),
    );
  }
}
