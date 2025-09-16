import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

double getResponsiveFontSize(double baseSize) {
  final logicalWidth = WidgetsBinding
      .instance.platformDispatcher.views.first.physicalSize.width /
      WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

  const referenceWidth = 411.0;
  return baseSize * (logicalWidth / referenceWidth);
}

/// Small Font
Widget smallFont({
  required String text,
  Color color = white,
  FontWeight weight = FontWeight.w400,
  TextAlign align = TextAlign.center,
  double maxWidth = double.infinity,
  bool isDiscounted = false,
  int? maxLine = 6,
  TextOverflow overflow = TextOverflow.visible,
}) {
  final fontSize = getResponsiveFontSize(13.5);
  return Container(
    constraints: BoxConstraints(maxWidth: maxWidth),
    child: Text(
      text,
      style: GoogleFonts.exo2(
        color: color,
        fontSize: fontSize,
        fontWeight: weight,
        decoration: isDiscounted ? TextDecoration.lineThrough : null,
      ),
      maxLines: maxLine,
      textAlign: align,
      overflow: overflow,
    ),
  );
}

/// Medium Font
Widget mediumFont({
  required String text,
  Color color = white,
  FontWeight weight = FontWeight.w500,
  TextAlign align = TextAlign.center,
  double maxWidth = 120,
  bool isDiscounted = false,
  int maxLine = 1,
  TextOverflow overflow = TextOverflow.visible,
}) {
  final fontSize = getResponsiveFontSize(15.5);
  return Container(
    constraints: BoxConstraints(maxWidth: maxWidth),
    child: Text(
      text,
      style: GoogleFonts.exo2(
        color: color,
        fontSize: fontSize,
        fontWeight: weight,
        decoration: isDiscounted ? TextDecoration.lineThrough : null,
      ),
      maxLines: maxLine,
      textAlign: align,
      overflow: overflow,
    ),
  );
}

/// Product Title
Widget productTitle({
  required String text,
  Color color = grayBlack,
  FontWeight weight = FontWeight.w600,
  double maxWidth = 120,
  bool isDiscounted = false,
  int maxLine = 3,
  TextOverflow textOverFlow = TextOverflow.ellipsis,
}) {
  final fontSize = getResponsiveFontSize(17.5);
  return Container(
    constraints: BoxConstraints(maxWidth: maxWidth),
    child: Text(
      text,
      maxLines: maxLine,
      overflow: textOverFlow,
      style: GoogleFonts.exo2(
        color: color,
        fontSize: fontSize,
        fontWeight: weight,
        decoration: isDiscounted ? TextDecoration.lineThrough : null,
      ),
    ),
  );
}

/// Heading Font
Widget headingFont({
  required String text,
  Color color = white,
  FontWeight weight = FontWeight.bold,
  TextAlign align = TextAlign.center,
}) {
  final fontSize = getResponsiveFontSize(28);
  return Text(
    text,
    style: GoogleFonts.exo2(
      color: color,
      fontSize: fontSize,
      fontWeight: weight,
    ),
    textAlign: align,
  );
}

/// Title Font
Widget titleFont({
  required String text,
  Color color = grayBlack,
  FontWeight weight = FontWeight.bold,
}) {
  final fontSize = getResponsiveFontSize(24);
  return Text(
    text,
    style: GoogleFonts.exo2(
      fontSize: fontSize,
      color: color,
      fontWeight: weight,
    ),
  );
}

Widget tinyFont({
  required String text,
  Color color = white,
  FontWeight weight = FontWeight.w400,
  TextAlign align = TextAlign.center,
  double maxWidth = double.infinity,
  bool isDiscounted = false,
  TextOverflow overflow = TextOverflow.visible,
}) {
  final fontSize = getResponsiveFontSize(8);
  return Container(
    constraints: BoxConstraints(maxWidth: maxWidth),
    child: Text(
      text,
      style: GoogleFonts.exo2(
        color: color,
        fontSize: fontSize,
        fontWeight: weight,
        decoration: isDiscounted ? TextDecoration.lineThrough : null,
      ),
      textAlign: align,
      overflow: overflow,
    ),
  );
}
