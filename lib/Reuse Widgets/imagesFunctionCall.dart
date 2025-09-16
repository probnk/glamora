import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:glamora/Reuse%20Widgets/loadingShimmer.dart';
import 'package:glamora/constants/colors.dart';

Widget networkImagesCache(
    {required String url,
    double? height, // optional
    double? width, // optional
    double? heightFactor, // responsive percentage (0.2 = 20% of screen height)
    double? widthFactor, // responsive percentage (0.5 = 50% of screen width)
    EdgeInsetsGeometry padding = const EdgeInsets.all(8.0),
    BoxFit fit = BoxFit.fill,
    bool isDarkMode = true}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height;

      // agar px diye hue hain, wo use ho; warna percentage se calculate karo
      final imageWidth = width ??
          (widthFactor != null ? screenWidth * widthFactor : screenWidth * 0.4);
      final imageHeight = height ??
          (heightFactor != null
              ? screenHeight * heightFactor
              : screenHeight * 0.25);

      return Center(
        child: Padding(
          padding: padding,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: url,
              height: imageHeight,
              width: imageWidth,
              fit: fit,
              placeholder: (context, url) => Center(child: CircularProgressIndicator(color: white,),),
              errorWidget: (context, url, error) =>
                  Center(child: Icon(Icons.error, color: darkRed)),
            ),
          ),
        ),
      );
    },
  );
}
