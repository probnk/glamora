// cart_products_list.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:glamora/Reuse%20Widgets/genderCategoryContainer.dart';
import 'package:glamora/Reuse%20Widgets/imagesFunctionCall.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/models/cartProducts.dart';
import 'package:glamora/models/productModel.dart';
import 'package:glamora/providers/CartProvider.dart';
import 'package:glamora/screens/Product%20Details/ProductDetails.dart';
import 'package:iconly/iconly.dart';
import 'package:provider/provider.dart';

import '../Services/personalization_service.dart';

shoppingCartBody({required bool isDarkMode}) {
  final currentUser = FirebaseAuth.instance.currentUser;

  return Consumer<CartProvider>(builder: (context, value, child) {
    return ListView.builder(
        shrinkWrap: true,
        itemCount: value.cartItems.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              // Navigate to ProductDetails when item is tapped
              Navigator.pushNamed(
                context,
                '/productDetails',
                arguments: value.cartItems[index].id,
              );
            },
            onLongPress: () {
              // Toggle selection on long press
              value.toggleItemSelection(value.cartItems[index]);
            },
            child: Stack(
              children: [
                cartClothCardDesign(
                    cartItems: value.cartItems[index],
                    context: context,
                    isCart: true,
                    isDarkMode: isDarkMode,
                    isSelected: value.selectedItems
                        .any((item) => item.id == value.cartItems[index].id)),
                Positioned(
                  top: 0,
                  right: 10,
                  child: IconButton(
                      onPressed: () {
                        trackPersonalization(
                            currentUser!.uid,
                            value.cartItems[index].category,
                            "cart",
                            'decrement');
                        value.deleteCartItem(value.cartItems[index]);
                        value.removeProductFromCart(value.cartItems[index].id);
                      },
                      icon: Icon(
                        IconlyLight.close_square,
                        color: isDarkMode ? lightRed : darkRed,
                      )),
                ),
                // Selection checkbox
                if (value.isSelectionMode)
                  Positioned(
                    top: 0,
                    left: 10,
                    child: Checkbox(
                      value: value.selectedItems
                          .any((item) => item.id == value.cartItems[index].id),
                      onChanged: (bool? selected) {
                        if (selected != null) {
                          if (selected) {
                            value.addToSelectedItems(value.cartItems[index]);
                          } else {
                            value.removeFromSelectedItems(
                                value.cartItems[index]);
                          }
                        }
                      },
                    ),
                  ),
              ],
            ),
          );
        });
  });
}

cartClothCardDesign({
  CartProducts? cartItems,
  ClothingProductModel? wishListProducts,
  required BuildContext context,
  required bool isCart,
  required bool isDarkMode,
  bool isSelected = false,
}) {
  return InkWell(
    onTap: () {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ProductDetails(
                  id: isCart ? cartItems!.id : wishListProducts!.id,
                  gender: isCart ? cartItems!.gender : wishListProducts!.gender,
                  category: isCart
                      ? cartItems!.category
                      : wishListProducts!.category)));
    },
    child: Container(
      margin: EdgeInsets.all(8),
      padding: EdgeInsets.only(top: 5),
      decoration: isSelected
          ? BoxDecoration(
              border: Border.all(color: Colors.blue, width: 2),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              networkImagesCache(
                url:
                    "${isCart ? cartItems!.images[0] : wishListProducts!.images[0]}",
                heightFactor: 0.11,
                widthFactor: 0.25,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    productTitle(
                        text:
                            isCart ? cartItems!.title : wishListProducts!.title,
                        maxWidth: MediaQuery.of(context).size.width * .5,
                        maxLine: 1,
                        color: isDarkMode ? white : grayBlack),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        genderCategoryContainer(
                            text: isCart
                                ? cartItems!.gender
                                : wishListProducts!.gender,
                            isDarkMode: isDarkMode,
                            textColor: Colors.green,
                            color: Colors.green.withOpacity(0.15)),
                        const SizedBox(width: 4),
                        genderCategoryContainer(
                            text: isCart
                                ? cartItems!.category
                                : wishListProducts!.category,
                            isDarkMode: isDarkMode,
                            textColor: Colors.blue,
                            color:Colors.blue.withOpacity(0.15)),
                      ],
                    ),
                    SizedBox(height: 8),
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
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (isCart)
                              Container(
                                margin: EdgeInsets.zero,
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: cartItems!.colorHex,
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (isCart)
                                    Container(
                                      decoration: BoxDecoration(
                                        color: isDarkMode
                                            ? Colors.grey.shade800
                                            : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Minus button
                                          Container(
                                            width: 28,
                                            height: 28,
                                            child: IconButton(
                                              padding: EdgeInsets.zero,
                                              iconSize: 16,
                                              icon: Icon(Icons.remove),
                                              color: isDarkMode
                                                  ? white
                                                  : grayBlack,
                                              onPressed: () {
                                                if (cartItems!.pieces > 1) {
                                                  context
                                                      .read<CartProvider>()
                                                      .updateItemQuantity(
                                                        cartItems.id,
                                                        cartItems.pieces - 1,
                                                      );
                                                }
                                              },
                                            ),
                                          ),

                                          // Quantity text
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 8),
                                            child: smallFont(
                                              text: "${cartItems!.pieces}",
                                              color: isDarkMode
                                                  ? white
                                                  : grayBlack,
                                              align: TextAlign.center,
                                            ),
                                          ),

                                          // Plus button
                                          Container(
                                            width: 28,
                                            height: 28,
                                            child: IconButton(
                                              padding: EdgeInsets.zero,
                                              iconSize: 16,
                                              icon: Icon(Icons.add),
                                              color: isDarkMode
                                                  ? white
                                                  : grayBlack,
                                              onPressed: () {
                                                context
                                                    .read<CartProvider>()
                                                    .updateItemQuantity(
                                                      cartItems.id,
                                                      cartItems.pieces + 1,
                                                    );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  SizedBox(width: 8),
                                  if (isCart)
                                    Flexible(
                                      child: smallFont(
                                        text: "Total: RS ${cartItems!.total}",
                                        color: isDarkMode ? white : grayBlack,
                                        align: TextAlign.end,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
          SizedBox(height: 5),
          Divider(
              color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300)
        ],
      ),
    ),
  );
}
