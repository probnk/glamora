import 'package:flutter/material.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/models/productModel.dart';
import 'package:glamora/models/wishListProducts.dart';
import 'package:glamora/providers/WishListProvider.dart';
import 'package:glamora/screens/Login/Login.dart';
import 'package:iconly/iconly.dart';
import 'package:provider/provider.dart';

checkAndAddWishlistItems(
    {required ClothingProductModel cloth,
    required int index,
    required var currentUser}) {
  return Consumer<WishListProvider>(builder: (context, value, child) {
    bool isFound = false;
    var wishlistData = WishlistProducts(
        id: cloth.id,
        title: cloth.title,
        price: cloth.price,
        discount: cloth.discount,
        images: cloth.images,
        category: cloth.category,
        gender: cloth.gender,
        isFav: false);
    for (int i = 0; i < value.wishListProducts.length; i++) {
      if (value.wishListProducts[i].id.contains(cloth.id)) {
        isFound = true;
        break;
      }
    }
    return IconButton(
        onPressed: () async {
            final wishListProvider =
                Provider.of<WishListProvider>(context, listen: false);
            if (!isFound) {
              wishListProvider.addWishListItem(wishlistData);
              wishListProvider.storeClothsList(wishlistData);
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: smallFont(text: "${cloth.title} added")));
            } else {
              wishListProvider.deleteWishListItem(
                  wishListProvider.wishListProducts[index].id);
              value.removeWishListItems(cloth.id);
            }
        },
        icon: isFound
            ? Icon(IconlyBold.heart, color: lightRed)
            : Icon(IconlyLight.heart, color: Colors.grey.shade400));
  });
}
