// app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Base
  static const background = Color(0xFFF8FAFC);
  static const foreground = Color(0xFF0F172A);
  static const mutedForeground = Color(0xFF64748B);
  static const card = Colors.white;

  // Brand
  static const primary = Color(0xFF6366F1); // Indigo
  static const accent = Color(0xFFF97316); // Orange
  static const success = Color(0xFF16A34A);
}

class AppGradients {
  static const stats = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF6366F1),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
    ],
  );
}

class AppText {
  static TextStyle title = GoogleFonts.poppins(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.foreground,
  );

  static TextStyle label = GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.mutedForeground,
  );

  static TextStyle value = GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );


  static TextStyle statLabel = GoogleFonts.poppins(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: Colors.white70,
  );
}
