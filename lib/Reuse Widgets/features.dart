import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Widget buildFeatureList(
  List<String> features,
  bool isDarkMode,
  double screenWidth,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: features.map((feature) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "• ",
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
              ),
            ),
            Expanded(
              child: Text(
                feature,
                style: GoogleFonts.exo2(
                  fontSize: screenWidth * 0.035,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList(),
  );
}
