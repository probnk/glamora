import 'package:flutter/material.dart';
import 'package:glamora/constants/fonts.dart';

Widget guestUserSkipCrossButton({required String label, required Function() onPressed}) {
  return Positioned(
    top: 20,
    right: 5,
    child: TextButton(
      onPressed: onPressed,
      child: mediumFont(
          text: label,
          weight: FontWeight.w400,
          color: Colors.grey.shade700,
          align: TextAlign.end),
    ),
  );
}
