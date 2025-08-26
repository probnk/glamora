import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:provider/provider.dart';

import 'Ai Chat Bot/aiChatBot.dart';
import 'Live Chat Support/MessagingScreen.dart';

class SupportHomeScreen extends StatelessWidget {
  const SupportHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    bool isDark = Provider.of<DarkModeProvider>(context).isDarkMode;

    // Change status bar style dynamically
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: isDark ? white : grayBlack, // Background
        statusBarIconBrightness:
        isDark ? Brightness.dark : Brightness.light, // Icon color
      ),
    );
    return Scaffold(
      backgroundColor: isDark ? grayBlack : white,
      body: SafeArea(
        child: Column(
          children: [
            // Live Chat - Upper Half
            Expanded(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MessagingScreen()),
                  );
                },
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6D5DF6), Color(0xFF8F85F3)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.support_agent,
                          size: 80, color: Colors.white),
                      const SizedBox(height: 14),
                      mediumFont(
                          text: "Live Chat Support",
                          color: white,
                          weight: FontWeight.bold,
                          maxWidth: double.infinity),
                      const SizedBox(height: 6),
                      smallFont(
                          text: "Talk directly with our support team",
                          color: Colors.white70,
                          maxWidth: MediaQuery.of(context).size.width * 0.8),
                    ],
                  ),
                ),
              ),
            ),

            // AI Chatbot - Lower Half
            Expanded(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ChatScreen()),
                  );
                },
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF8C68), Color(0xFFFF6F61)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.smart_toy,
                          size: 80, color: Colors.white),
                      const SizedBox(height: 14),
                      mediumFont(
                          text: "AI Chatbot",
                          color: white,
                          weight: FontWeight.bold,
                          maxWidth: double.infinity),
                      const SizedBox(height: 6),
                      smallFont(
                          text: "Get instant AI-powered answers",
                          color: Colors.white70,
                          maxWidth: MediaQuery.of(context).size.width * 0.8),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}