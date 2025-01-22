import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

smallFont(
    {required String text,
    Color color = white,
    FontWeight weight = FontWeight.w400,
    TextAlign align = TextAlign.center,
    double maxWidth = double.infinity,
    bool isDiscounted = false,
    TextOverflow overflow = TextOverflow.visible}) {
  return Container(
    constraints: BoxConstraints(maxWidth: maxWidth),
    child: Text(
      text,
      style: GoogleFonts.montserrat(
          color: color,
          fontSize: 14,
          fontWeight: weight,
          decoration: isDiscounted ? TextDecoration.lineThrough : null),
      textAlign: align,
      overflow: overflow,
    ),
  );
}

mediumFont(
    {bool isDiscounted = false,
    required String text,
    Color color = white,
    FontWeight weight = FontWeight.w500,
    TextAlign align = TextAlign.center,
    double maxWidth = 120,
    TextOverflow overflow = TextOverflow.visible}) {
  return Container(
    constraints: BoxConstraints(
      maxWidth: maxWidth,
    ),
    child: Text(
      text,
      style: GoogleFonts.montserrat(
          color: color,
          fontSize: 18,
          fontWeight: weight,
          decoration: isDiscounted ? TextDecoration.lineThrough : null),
      textAlign: align,
      overflow: overflow,
    ),
  );
}

productTitle(
    {required String text,
    Color color = grayBlack,
    FontWeight weight = FontWeight.w600,
    double maxWidth = 120,
    bool isDiscounted = false}) {
  return Container(
    constraints: BoxConstraints(maxWidth: maxWidth),
    child: Text(text,
        style: GoogleFonts.exo2(
            color: color,
            fontSize: 16,
            fontWeight: weight,
            decoration: isDiscounted ? TextDecoration.lineThrough : null)),
  );
}

headingFont(
    {required String text,
    Color color = white,
    FontWeight weight = FontWeight.bold,
    TextAlign align = TextAlign.center}) {
  return Text(
    text,
    style: GoogleFonts.exo2(color: color, fontSize: 30, fontWeight: weight),
    textAlign: align,
  );
}

titleFont(
    {required String text,
    Color color = grayBlack,
    FontWeight weight = FontWeight.bold}) {
  return Text(text,
      style: GoogleFonts.abel(fontSize: 28, color: color, fontWeight: weight));
}
