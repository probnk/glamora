// my_cart.dart (updated)
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:glamora/Reuse%20Widgets/cartProductsList.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/providers/CartProvider.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:glamora/providers/UserDetailsProvider.dart';
import 'package:glamora/screens/Order%20Process/OrderDetails.dart';
import 'package:glamora/screens/UserProfile/UserDetails.dart';
import 'package:provider/provider.dart';

import '../../Reuse Widgets/loadingShimmer.dart';
import '../../models/cartProducts.dart';

class MyCart extends StatefulWidget {
  const MyCart({super.key});

  @override
  State<MyCart> createState() => _MyCartState();
}

class _MyCartState extends State<MyCart> {
  final _couponController = TextEditingController();
  var currentUser;

  @override
  void initState() {
    super.initState();
    currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      context.read<UserDetailsProvider>().fetchUserDetails();
    }
    context.read<CartProvider>().fetchUserCartFromFirestore();
  }

  _cartAppbar({required bool isDarkMode, required CartProvider cartProvider}) {
    return AppBar(
      backgroundColor: isDarkMode ? lightGrayBlack : Colors.grey.shade50,
      iconTheme: IconThemeData(color: isDarkMode ? white : grayBlack),
      centerTitle: true,
      title: titleFont(
          text: cartProvider.isSelectionMode ? "Select Items" : "Shopping Cart",
          color: isDarkMode ? white : grayBlack),
      actions: [
        if (cartProvider.isSelectionMode)
          IconButton(
            icon: Icon(Icons.clear),
            onPressed: () {
              cartProvider.clearSelection();
            },
          ),
      ],
    );
  }

  _shoppingCartBottomSheet({
    required bool isDarkMode,
    required var currentUser,
    required CartProvider cartProvider,
  }) {
    return Container(
      color: isDarkMode ? grayBlack : white,
      child: Consumer<CartProvider>(builder: (context, value, child) {
        // Calculate total based on selection mode
        int total = 0;
        List<CartProducts> itemsForCheckout = [];

        if (value.isSelectionMode && value.selectedItems.isNotEmpty) {
          itemsForCheckout = value.selectedItems;
          total = itemsForCheckout.fold(0, (sum, item) => sum + int.parse(item.total));
        } else {
          itemsForCheckout = value.cartItems;
          total = value.cartItems.fold(0, (sum, item) => sum + int.parse(item.total));
        }

        if (value.isLoading) {
          return ListView.builder(
            itemCount: 6,
            itemBuilder: (context, index) {
              return cartClothCardShimmer(
                  isDarkMode: isDarkMode, context: context);
            },
          );
        }
        else if (value.cartItems.isEmpty)
          return Center(
              child: Icon(
                Icons.remove_shopping_cart_rounded,
                color: isDarkMode ? Colors.grey.shade600 : grayBlack,
                size: 200,
              ));
        else
          return Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
                color: isDarkMode ? lightGrayBlack : white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                    color: isDarkMode
                        ? Colors.grey.shade700
                        : Colors.grey.shade300)),
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        mediumFont(
                            text: "Total",
                            color: isDarkMode ? white : grayBlack),
                        smallFont(
                            text: "Order now", color: Colors.grey.shade400)
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        mediumFont(
                            text: "Rs $total",
                            color: isDarkMode ? white : grayBlack),
                        smallFont(
                            text: "Free Shipping", color: Colors.grey.shade400)
                      ],
                    )
                  ],
                ),
                SizedBox(height: 20),
                Center(
                  child: ElevatedButton(
                      onPressed: total == 0
                          ? null
                          : () {
                        final user = Provider.of<UserDetailsProvider>(
                            context,
                            listen: false);

                        if (user.userDetails.fullName == "" ||
                            user.userDetails.address == "" ||
                            user.userDetails.zipCode == "" ||
                            user.userDetails.phoneNumber == "") {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserDetails(),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OrderDetails(
                                itemsToCheckout: itemsForCheckout,
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: grayBlack,
                          elevation: 8,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8))),
                      child: Container(
                          width: MediaQuery.of(context).size.width * .7,
                          padding:
                          EdgeInsets.symmetric(vertical: 8, horizontal: 40),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: isDarkMode
                                      ? [lightOrange, darkOrange]
                                      : [lightBlack, darkBlack])),
                          child: smallFont(
                              text: "Proceed to Checkout", color: white))),
                ),
              ],
            ),
          );
      }),
    );
  }

  @override
  build(BuildContext context) {
    final themeProvider = Provider.of<DarkModeProvider>(context);
    final cartProvider = Provider.of<CartProvider>(context);

    return Scaffold(
        backgroundColor: themeProvider.isDarkMode ? grayBlack : white,
        appBar: _cartAppbar(
            isDarkMode: themeProvider.isDarkMode,
            cartProvider: cartProvider
        ),
        bottomSheet: _shoppingCartBottomSheet(
          isDarkMode: themeProvider.isDarkMode,
          currentUser: currentUser,
          cartProvider: cartProvider,
        ),
        body: shoppingCartBody(isDarkMode: themeProvider.isDarkMode));
  }
}