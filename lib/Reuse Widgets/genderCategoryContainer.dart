import 'package:flutter/material.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';

genderCategoryContainer(
    {required String text, required bool isDarkMode, required Color color, required textColor}) {
  return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: smallFont(
          text: text, color: textColor,weight: FontWeight.w600));
}