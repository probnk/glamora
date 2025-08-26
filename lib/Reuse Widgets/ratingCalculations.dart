import 'package:flutter/material.dart';
import 'package:glamora/models/ReviewsModel.dart';

double calculateAverageRating(List<ProductReviewModel> reviews) {
  if (reviews.isEmpty) return 0.0;

  double total = 0.0;
  for (var review in reviews) {
    total += review.rating.toDouble();
  }
  return total / reviews.length;
}

Widget buildStarRating(double rating) {
  IconData iconData;

  if (rating <= 0) {
    iconData = Icons.star_outline_rounded; // Empty
  } else if (rating > 0 && rating <= 1) {
    iconData = Icons.star_border_rounded; // Light fill (custom pick)
  } else if (rating > 1 && rating <= 2) {
    iconData = Icons.star_half_rounded; // Partially filled
  } else if (rating > 2 && rating <= 3) {
    iconData = Icons.star_half_rounded; // Half filled
  } else if (rating > 3 && rating <= 4) {
    iconData = Icons.star; // Mostly filled (fully colored)
  } else if (rating > 4 && rating <= 5) {
    iconData = Icons.star_rounded; // Fully filled
  } else {
    iconData = Icons.star_outline_rounded;
  }

  return Icon(
    iconData,
    color: Colors.yellow.shade700,
    size: 18,
  );
}