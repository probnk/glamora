import 'package:flutter/material.dart';
import 'package:glamora/constants/fonts.dart';

const double referenceWidth = 411.0;  // Realme 8 width (dp)
const double referenceHeight = 891.0; // Realme 8 height (dp)

double _logicalWidth() {
  return WidgetsBinding
      .instance.platformDispatcher.views.first.physicalSize.width /
      WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
}

double _logicalHeight() {
  return WidgetsBinding
      .instance.platformDispatcher.views.first.physicalSize.height /
      WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
}

double getResponsiveWidth(double baseWidth) {
  return baseWidth * (_logicalWidth() / referenceWidth);
}

double getResponsiveHeight(double baseHeight) {
  return baseHeight * (_logicalHeight() / referenceHeight);
}

double getResponsiveIconSize(double baseSize) {
  return getResponsiveFontSize(baseSize); // or use width scaling
}

EdgeInsets responsivePadding({
  double left = 0,
  double top = 0,
  double right = 0,
  double bottom = 0,
}) {
  return EdgeInsets.only(
    left: getResponsiveWidth(left),
    top: getResponsiveHeight(top),
    right: getResponsiveWidth(right),
    bottom: getResponsiveHeight(bottom),
  );
}
