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
              cartClothCardDesign(
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
                      value.removeProductFromCart(value.cartItems[index].id);
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

cartClothCardDesign(
    {CartProducts? cartItems,
    ClothingProductModel? wishListProducts,
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
                      "${isCart ? cartItems!.images[0] : wishListProducts!.images[0]}",
                  height: 80),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                productTitle(
                    text: isCart ? cartItems!.title : wishListProducts!.title,
                    maxWidth: 150,
                    color: isDarkMode ? white : grayBlack),
                smallFont(
                    text: isCart
                        ? cartItems!.category
                        : wishListProducts!.category,
                    color: Colors.grey),
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isCart
                        ? cartItems!.discount != 0
                        : wishListProducts!.discount != 0)
                      Row(
                        children: [
                          productTitle(
                              text:
                                  "Rs ${isCart ? ((cartItems!.price / 100) * (100 - cartItems.discount)) : ((wishListProducts!.price / 100) * (100 - wishListProducts.discount))}",
                              color: isDarkMode ? white : grayBlack),
                          SizedBox(width: 5),
                          smallFont(
                              text:
                                  "Rs ${isCart ? cartItems!.price : wishListProducts!.price}",
                              color: darkRed,
                              isDiscounted: true,
                              weight: FontWeight.w600),
                        ],
                      )
                    else
                      mediumFont(
                          text:
                              "Rs ${isCart ? cartItems!.price : wishListProducts!.price}",
                          color: darkRed,
                          isDiscounted: true,
                          weight: FontWeight.w600),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isCart)
                          Container(
                            margin: EdgeInsets.zero,
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: cartItems!.colorHex,
                              border: Border.all(color: Colors.grey.shade300),
                              shape: BoxShape.circle,
                            ),
                          ),
                        SizedBox(width: 70),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            if (isCart)
                              smallFont(
                                  text: "x${cartItems!.pieces}",
                                  color: Colors.grey,
                                  align: TextAlign.end),
                            SizedBox(width: 10),
                            if (isCart)
                              smallFont(
                                  text: "Total RS ${cartItems!.total}",
                                  color: isDarkMode ? white : grayBlack)
                          ],
                        )
                      ],
                    )
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
