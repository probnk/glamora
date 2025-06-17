import 'package:flutter/material.dart';
import 'package:glamora/models/SizesVariants.dart';

class ClothingVariantModel {
  final List<Color> colors;
  final List<ClothingSizesModel> sizes;

  ClothingVariantModel({
    required this.colors,
    required this.sizes,
  });

  factory ClothingVariantModel.fromMap(Map<String, dynamic> data) {
    // Convert hex strings to Colors
    List<Color> colorList = (data['colors'] as List<dynamic>?)
        ?.map((hex) => Color(int.parse(hex, radix: 16)))
        .toList() ?? [];

    // Convert size data to ClothingSizesModel
    List<ClothingSizesModel> sizeList = (data['sizes'] as List<dynamic>?)
        ?.map((sizeData) => ClothingSizesModel.fromMap(sizeData))
        .toList() ?? [];

    return ClothingVariantModel(
      colors: colorList,
      sizes: sizeList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'colors': colors.map((c) => c.value.toRadixString(16)).toList(), // ✅ convert to hex string
      'sizes': sizes.map((s) => s.toMap()).toList(),
    };
  }

}
