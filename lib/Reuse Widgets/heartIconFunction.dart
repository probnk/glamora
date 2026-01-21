import 'package:flutter/material.dart';
import 'package:glamora/Services/personalization_service.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/models/productModel.dart';
import 'package:glamora/models/wishListProducts.dart';
import 'package:glamora/providers/WishListProvider.dart';
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
      onPressed: () async{
        if (!isFound) {
          value.addWishListItem(wishlistData);
          value.storeClothsList(wishlistData);
          trackPersonalization(currentUser.uid, cloth.category, "wishlist",'increment');
        } else {
          value.deleteWishListItem(cloth.id);
          value.removeWishListItems(cloth.id);
          trackPersonalization(currentUser.uid, cloth.category, "wishlist",'decrement');
        }

      },
      icon: Icon(
        isFound ? IconlyBold.heart : IconlyLight.heart,
        color: isFound ? lightRed : Colors.grey.shade400,
      ),
    );
  });
}
