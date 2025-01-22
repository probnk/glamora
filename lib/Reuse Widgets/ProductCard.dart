import 'package:flutter/material.dart';
import 'package:glamora/Reuse%20Widgets/LimitedStock.dart';
import 'package:glamora/Reuse%20Widgets/imagesFunctionCall.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/models/productModel.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:glamora/providers/ProductListProvider.dart';
import 'package:glamora/providers/WishListProvider.dart';
import 'package:glamora/screens/Product%20Details/ProductDetails.dart';
import 'package:iconly/iconly.dart';
import 'package:provider/provider.dart';

newArrivalSerumList() {
  return Consumer<ProductListProvider>(builder: (context, value, child) {
    return Container(
      height: 330,
      child: ListView.builder(
          itemCount: value.serumList.length,
          scrollDirection: Axis.horizontal,
          shrinkWrap: true,
          itemBuilder: (context, index) {
            return ProductCard(
                context: context, index: index, serum: value.serumList[index]);
          }),
    );
  });
}

ProductCard({
  required BuildContext context,
  required int index,
  required Serum serum,
}) {
  final themeProvider = Provider.of<DarkModeProvider>(context);
  return Padding(
    padding: const EdgeInsets.only(left: 8,bottom: 5,top: 5),
    child: InkWell(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => ProductDetails(
                      serumDetails: serum,
                      index: index,
                    )));
      },
      child: Card(
        elevation: themeProvider.isDarkMode ? 3 : 0,
        child: Stack(
          children: [
            Container(
              width: MediaQuery.of(context).size.width * .45,
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode ? lightGrayBlack : white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: themeProvider.isDarkMode
                          ? Colors.transparent
                          : Colors.grey.shade200)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  networkImagesCache(url: serum.photoUrl[0]),
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 8),
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 10),
                            productTitle(
                                text: serum.title,
                                color: themeProvider.isDarkMode
                                    ? white
                                    : lightGrayBlack),
                            smallFont(text: "Face Serum", color: Colors.grey),
                            Row(
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  color: Colors.yellow.shade700,
                                ),
                                productTitle(
                                    text: serum.reviews.length.toString(),
                                    color: themeProvider.isDarkMode
                                        ? white
                                        : lightGrayBlack)
                              ],
                            ),
                            Row(
                              children: [
                                productTitle(
                                    text: "Rs ${serum.newPrice}",
                                    color: themeProvider.isDarkMode
                                        ? white
                                        : lightGrayBlack),
                                SizedBox(width: 5),
                                productTitle(
                                    text: "Rs ${serum.oldPrice}",
                                    color: lightRed,
                                    isDiscounted: true)
                              ],
                            )
                          ],
                        ),
                        Align(
                          alignment: Alignment.topRight,
                          child: Consumer<WishListProvider>(
                              builder: (context, value, child) {
                            bool isFound = false;
                            for (int i = 0; i < value.wishListProducts.length; i++) {
                              if (value.wishListProducts[i].title.contains(serum.title)) {
                                isFound = true;
                                break;
                              }
                            }
                            return IconButton(
                                onPressed: () async {
                                  final wishListProvider =
                                      Provider.of<WishListProvider>(context,
                                          listen: false);
                                  if (!isFound) {
                                    wishListProvider.addWishListItem(serum);
                                    wishListProvider.storeSerumList(serum);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: smallFont(
                                                text: "${serum.title} added")));
                                  } else {
                                    wishListProvider.deleteWishListItem(
                                        wishListProvider
                                            .wishListProducts[index].title);
                                    value.removeWishListItems(serum.title);
                                  }
                                },
                                icon: isFound
                                    ? Icon(IconlyBold.heart, color: lightRed)
                                    : Icon(IconlyLight.heart,
                                        color: Colors.grey.shade400));
                          }),
                        )
                      ],
                    ),
                  ),
                  limitedStock(context: context)
                ],
              ),
            ),
            Positioned(
              right: 10,
              top: 0,
              child: Image.asset(
                "assets/images/discount.png",
                width: 50,
                height: 40,
              ),
            )
          ],
        ),
      ),
    ),
  );
}
