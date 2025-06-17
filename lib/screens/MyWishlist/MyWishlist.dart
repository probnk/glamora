import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:glamora/Reuse%20Widgets/cartProductsList.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:glamora/providers/WishListProvider.dart';
import 'package:iconly/iconly.dart';
import 'package:provider/provider.dart';

class MyWishlist extends StatefulWidget {
  const MyWishlist({super.key});

  @override
  State<MyWishlist> createState() => _MyWishlistState();
}

class _MyWishlistState extends State<MyWishlist> {

  @override
  void initState() {
    super.initState();
    Provider.of<WishListProvider>(context, listen: false).fetchClothsList();
  }

  _wishListAppbar({required bool isDarkMode}) {
    return AppBar(
      backgroundColor: isDarkMode ? lightGrayBlack : Colors.grey.shade50,
      iconTheme: IconThemeData(color: isDarkMode ? white : grayBlack),
      centerTitle: true,
      title: titleFont(
          text: "WishList Serum's", color: isDarkMode ? white : grayBlack),
    );
  }

  _wishListBody({required bool isDarkMode}) {
    return Consumer<WishListProvider>(builder: (context, value, child) {
      if (value.wishListProducts.isEmpty)
        return Center(
            child: Icon(
              Icons.search_off_rounded,
              color: isDarkMode ? Colors.grey.shade600 : grayBlack,
              size: 200,
            ));
      else
        return ListView.builder(
            itemCount: value.wishListProducts.length,
            shrinkWrap: true,
            physics: ScrollPhysics(),
            itemBuilder: (context, index) {
              return Stack(
                children: [
                  cartClothCardDesign(
                      context: context,
                      isCart: false,
                      isDarkMode: isDarkMode,
                      wishListProducts: value.wishListProducts[index]),
                  Positioned(
                    top: 0,
                    right: 10,
                    child: IconButton(
                        onPressed: () {
                          value.deleteWishListItem(
                              value.wishListProducts[index].id);
                          value.removeWishListItems(
                              value.wishListProducts[index].id);
                        },
                        icon: Icon(
                          IconlyLight.close_square,
                          color: isDarkMode ? Colors.grey : lightGrayBlack,
                        )),
                  )
                ],
              );
            });
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<DarkModeProvider>(context);
    return Scaffold(
      backgroundColor: themeProvider.isDarkMode ? grayBlack : white,
      appBar: _wishListAppbar(isDarkMode: themeProvider.isDarkMode),
      body:_wishListBody(isDarkMode: themeProvider.isDarkMode),
    );
  }
}
