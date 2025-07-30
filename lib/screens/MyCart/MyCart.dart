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

  _cartAppbar({required bool isDarkMode}) {
    return AppBar(
      backgroundColor: isDarkMode ? lightGrayBlack : Colors.grey.shade50,
      iconTheme: IconThemeData(color: isDarkMode ? white : grayBlack),
      centerTitle: true,
      title: titleFont(
          text: "Shopping Cart", color: isDarkMode ? white : grayBlack),
    );
  }

  _shoppingCartBottomSheet(
      {required bool isDarkMode, required var currentUser}) {
    return Container(
      color: isDarkMode ? grayBlack : white,
      child: Consumer<CartProvider>(builder: (context, value, child) {
        int total = 0;
        for (int i = 0; i < value.cartItems.length; i++)
          total += int.parse(value.cartItems[i].total);
        if (value.cartItems.isEmpty)
          return Center(
              child: Icon(
            Icons.remove_shopping_cart_rounded,
            color: isDarkMode ? Colors.grey.shade600 : grayBlack,
            size: 200,
          ));
        else
          return Container(
            height: 210,
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
                Container(
                  width: MediaQuery.of(context).size.width,
                  height: 50,
                  child: TextFormField(
                    cursorColor: Colors.black,
                    controller: _couponController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDarkMode ? grayBlack : Colors.grey.shade100,
                      hintText: "Add coupon code",
                      hintStyle: TextStyle(
                          color: isDarkMode ? white : Colors.grey.shade400),
                      prefixIcon: Icon(
                        CupertinoIcons.ticket,
                        color: Colors.grey,
                      ),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.transparent)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.transparent)),
                    ),
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
                SizedBox(height: 10),
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
                              // Access UserDetailsProvider with listen: false
                              final user = Provider.of<UserDetailsProvider>(
                                  context,
                                  listen: false);

                              if (user.userDetails.fullName == "" ||
                                  user.userDetails.address == "" ||
                                  user.userDetails.zipCode == "" ||
                                  user.userDetails.phoneNumber == "") {
                                Navigator.push
                                  (
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UserDetails(),
                                  ),
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => OrderDetails(),
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
    return Scaffold(
        backgroundColor: themeProvider.isDarkMode ? grayBlack : white,
        appBar: _cartAppbar(isDarkMode: themeProvider.isDarkMode),
        bottomSheet:_shoppingCartBottomSheet(
                isDarkMode: themeProvider.isDarkMode, currentUser: currentUser),
        body: shoppingCartBody(isDarkMode: themeProvider.isDarkMode));
  }
}
