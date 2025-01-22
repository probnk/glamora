import 'package:flutter/material.dart';
import 'package:glamora/BottomNavBar/BottomNavBar.dart';
import 'package:glamora/Google%20Auth%20Services/GoogleAuthServices.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
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
        SizedBox(height: 40),
        Container(
          width: double.maxFinite,
          margin: EdgeInsets.symmetric(horizontal: 20),
          child: ElevatedButton(
            onPressed: () async {
              final user = await GoogleAuthService().signInWithGoogle();
              if (user != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Welcome, ${user.displayName}!')));
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => BottomNavBar()),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login Failed")));
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset("assets/images/google.png", width: 30, height: 30),
                SizedBox(width: 8),
                Text("Google"),
              ],
            ),
          )
        )
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
