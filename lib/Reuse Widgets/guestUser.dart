import 'package:flutter/material.dart';
import 'package:glamora/constants/fonts.dart';

Widget guestUserSkipCrossButton({required String label, required Function() onPressed}) {
  return Positioned(
    top: 20,
    right: 0,
    child: TextButton(
      onPressed: onPressed,
      child: productTitle(
          text: "$label",
          weight: FontWeight.w900,
          color: Colors.yellowAccent),
    ),
  );
}
