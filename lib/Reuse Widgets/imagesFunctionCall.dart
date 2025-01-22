import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:glamora/constants/colors.dart';

networkImagesCache({required String url, double height = 120, double width = double.infinity}) {
  return  Center(
    child:CachedNetworkImage(
      imageUrl: url,
      height: height,
      width: width,
      fit: BoxFit.contain,
      placeholder: (context, url) => Center(
        child: CircularProgressIndicator(color: white,),
      ),
      errorWidget: (context, url, error) =>
          Center(child: Icon(Icons.error,color: darkRed,)),
    ),);
}