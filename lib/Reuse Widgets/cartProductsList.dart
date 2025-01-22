import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:glamora/Reuse%20Widgets/imagesFunctionCall.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/models/cartProducts.dart';
import 'package:glamora/models/productModel.dart';
import 'package:glamora/providers/CartProvider.dart';
import 'package:iconly/iconly.dart';
import 'package:provider/provider.dart';

shoppingCartBody({required bool isDarkMode}) {
  return Consumer<CartProvider>(builder: (context, value, child) {
    return ListView.builder(
        shrinkWrap: true,
        itemCount: value.cartItems.length,
        itemBuilder: (context, index) {
          return Stack(
            children: [
              cartSerumCardDesign(
                  cartItems: value.cartItems[index],
                  context: context,
                  isCart: true,
                  isDarkMode: isDarkMode),
              Positioned(
                top: 0,
                right: 10,
                child: IconButton(
                    onPressed: () {
                      value.deleteCartItem(value.cartItems[index]);
                      value.removeProductFromCart(value.cartItems[index].title);
                    },
                    icon: Icon(
                      IconlyLight.close_square,
                      color: isDarkMode ? lightRed : darkRed,
                    )),
              )
            ],
          );
        });
  });
}

cartSerumCardDesign(
    {CartProducts? cartItems,
    Serum? wishListProducts,
    required BuildContext context,
    required bool isCart,
    required bool isDarkMode}) {
  return Container(
    padding: EdgeInsets.only(top: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 100,
              height: 80,
              child: networkImagesCache(
                  url:
                      "${isCart ? cartItems!.photoUrl[0] : wishListProducts!.photoUrl[0]}",
                  height: 80),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                productTitle(
                    text: isCart ? cartItems!.title : wishListProducts!.title,
                    maxWidth: 150,
                    color: isDarkMode ? white : grayBlack),
                smallFont(text: "Face Serum", color: Colors.grey),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    mediumFont(
                        text:
                            "RS ${isCart ? cartItems!.newPrice : wishListProducts!.newPrice}",
                        color: lightGreen),
                    SizedBox(width: 20),
                    if (isCart)
                      smallFont(
                          text: "x${cartItems!.pieces}", color: Colors.grey)
                    else
                      mediumFont(
                        text: "Rs ${wishListProducts!.oldPrice}",
                        color: lightRed,
                        isDiscounted: true,
                      ),
                    SizedBox(width: 20),
                    if (isCart)
                      smallFont(
                          text: "Total RS ${cartItems!.total}",
                          color: isDarkMode ? white : grayBlack),
                  ],
                ),
              ],
            )
          ],
        ),
        SizedBox(height: 10),
        Divider(color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300)
      ],
    ),
  );
}
