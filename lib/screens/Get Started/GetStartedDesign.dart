import 'package:flutter/material.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:google_fonts/google_fonts.dart';

class GetStartedDesign extends StatelessWidget {
  final String title;
  final String subTitle;
  final String url;
  final Color darkColor;

  GetStartedDesign(
      {super.key,
      required this.title,
      required this.subTitle,
      required this.url,
      required this.darkColor});

  _customContainer(BuildContext context, double width, double height) {
    return Container(
      width: MediaQuery.of(context).size.width * width,
      height: MediaQuery.of(context).size.height * height,
      decoration: BoxDecoration(shape: BoxShape.circle, color: white.withOpacity(.1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: white,
      body: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(color: darkColor),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      _customContainer(context, 1, .5),
                      _customContainer(context, .8, .4),
                      _customContainer(context, .9, .3),
                    ],
                  ),
                  Center(
                      child: Image.asset(
                        "assets/images/${url}.png",
                        height: MediaQuery.of(context).size.height * .35,
                        fit: BoxFit.cover,
                    )
                  )
                ],
              ),
              SizedBox(height: 20),
              Center(child: headingFont(text: title)),
              Container(
                  alignment: Alignment.center,
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * .9),
                  child: smallFont(text: subTitle))
            ],
          ),
        ),
      ),
    );
  }
}
