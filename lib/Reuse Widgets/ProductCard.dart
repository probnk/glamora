import 'package:flutter/material.dart';
import 'package:glamora/Reuse%20Widgets/LimitedStock.dart';
import 'package:glamora/Reuse%20Widgets/heartIconFunction.dart';
import 'package:glamora/Reuse%20Widgets/imagesFunctionCall.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/models/productModel.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:glamora/providers/ProductListProvider.dart';
import 'package:glamora/screens/Product%20Details/ProductDetails.dart';
import 'package:provider/provider.dart';

newArrivalSerumList({required var currentUser}) {
  return Consumer<ProductListProvider>(builder: (context, value, child) {
    return Container(
      height: 360,
      child: ListView.builder(
          itemCount: value.clothsList.length,
          scrollDirection: Axis.horizontal,
          shrinkWrap: true,
          itemBuilder: (context, index) {
            return ProductCard(
                context: context,
                index: index,
                cloth: value.clothsList[index],
                currentUser: currentUser);
          }),
    );
  });
}

ProductCard(
    {required BuildContext context,
    required int index,
    required ClothingProductModel cloth,
    required var currentUser}) {
  final themeProvider = Provider.of<DarkModeProvider>(context);
  return Padding(
    padding: const EdgeInsets.only(left: 8, bottom: 5, top: 5),
    child: InkWell(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => ProductDetails(
                      clothDetails: cloth,
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
                  networkImagesCache(url: cloth.images[0]),
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 8),
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 10),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: 200
                              ),
                              child: productTitle(
                                  text: cloth.title,
                                  maxLine: 2,
                                  color: themeProvider.isDarkMode
                                      ? white
                                      : lightGrayBlack),
                            ),
                            smallFont(
                                text: "${cloth.gender} : ${cloth.category}",
                                color: themeProvider.isDarkMode
                                    ? white
                                    : Colors.grey),
                            Row(
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  color: Colors.yellow.shade700,
                                ),
                                productTitle(
                                    text: cloth.reviews.length.toString(),
                                    color: themeProvider.isDarkMode
                                        ? white
                                        : lightGrayBlack)
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (cloth.discount != 0)
                                  Row(
                                    children: [
                                      productTitle(
                                          text:
                                              "Rs ${((cloth.price / 100) * (100 - cloth.discount))}",
                                          color: themeProvider.isDarkMode
                                              ? white
                                              : grayBlack),
                                      SizedBox(width: 5),
                                      smallFont(
                                          text: "Rs ${cloth.price}",
                                          color: darkRed,
                                          isDiscounted: true,
                                          weight: FontWeight.w600),
                                    ],
                                  )
                                else
                                  smallFont(
                                      text: "Rs ${cloth.price}",
                                      color: darkRed,
                                      isDiscounted: true,
                                      weight: FontWeight.w600),
                              ],
                            )
                          ],
                        ),
                        Align(
                            alignment: Alignment.topRight,
                            child: checkAndAddWishlistItems(
                                cloth: cloth,
                                index: index,
                                currentUser: currentUser))
                      ],
                    ),
                  ),
                  cloth.variants.first.colors.isNotEmpty
                      ? SizedBox(
                          width: MediaQuery.of(context).size.width * .3,
                          height: 28,
                          child: ListView.builder(
                              itemCount: cloth.variants.first.colors.length,
                              physics: const ScrollPhysics(),
                              shrinkWrap: true,
                              scrollDirection: Axis.horizontal,
                              itemBuilder: (context, index) {
                                return Container(
                                  margin: const EdgeInsets.only(left: 3),
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                      color: cloth.variants.first.colors[index],
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: lightGrayBlack, width: .5)),
                                );
                              }),
                        )
                      : const Text("None"),
                  limitedStock(context: context)
                ],
              ),
            ),
            Positioned(
                right: 5,
                top: 5,
                child: Container(
                  width: 50,
                  height: 30,
                  padding: EdgeInsets.all(5),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.green),
                  child: smallFont(
                      text: "${cloth.discount.toString()}%",
                      align: TextAlign.center,
                      weight: FontWeight.bold),
                ))
          ],
        ),
      ),
    ),
  );
}
