import 'package:flutter/material.dart';
import 'package:glamora/Reuse%20Widgets/LimitedStock.dart';
import 'package:glamora/Reuse%20Widgets/genderCategoryContainer.dart';
import 'package:glamora/Reuse%20Widgets/heartIconFunction.dart';
import 'package:glamora/Reuse%20Widgets/imagesFunctionCall.dart';
import 'package:glamora/Reuse%20Widgets/loadingShimmer.dart';
import 'package:glamora/Reuse%20Widgets/ratingCalculations.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/models/productModel.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:glamora/providers/ProductListProvider.dart';
import 'package:glamora/screens/Product%20Details/ProductDetails.dart';
import 'package:provider/provider.dart';

Widget newArrivalSerumList(
    {required var currentUser, required bool isDarkMode}) {
  return Consumer<ProductListProvider>(
    builder: (context, value, child) {
      if (value.isLoading) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                productCardShimmer(context: context, isDarkMode: isDarkMode),
                productCardShimmer(context: context, isDarkMode: isDarkMode)
              ],
            ),
          ),
        );
      }
      if (value.recommendedCloths.isEmpty) {
        return const Center(child: Text('No recommended products found'));
      }
      return Container(
        height: 380,
        child: ListView.builder(
          itemCount: value.recommendedCloths.length,
          scrollDirection: Axis.horizontal,
          shrinkWrap: true,
          itemBuilder: (context, index) {
            return ProductCard(
              context: context,
              index: index,
              cloth: value.recommendedCloths[index], // Use recommendedCloths
              currentUser: currentUser,
            );
          },
        ),
      );
    },
  );
}

ProductCard({required BuildContext context,
  required int index,
  required ClothingProductModel cloth,
  required var currentUser}) {
  final isDarkMode = Provider
      .of<DarkModeProvider>(context)
      .isDarkMode;
  return Padding(
    padding: const EdgeInsets.only(left: 8, bottom: 5, top: 5),
    child: InkWell(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    ProductDetails(
                        id: cloth.id,
                        gender: cloth.gender,
                        category: cloth.category)));
      },
      child: Card(
        elevation: isDarkMode ? 3 : 0,
        child: Stack(
          children: [
            Container(
              width: MediaQuery
                  .of(context)
                  .size
                  .width * .45,
              decoration: BoxDecoration(
                  color: isDarkMode ? lightGrayBlack : white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isDarkMode
                          ? Colors.transparent
                          : Colors.grey.shade200)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  networkImagesCache(
                    url: cloth.images[0],
                    height: 120,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 8),
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 10),
                            ConstrainedBox(
                              constraints: BoxConstraints(maxHeight: 200),
                              child: productTitle(
                                  text: cloth.title,
                                  maxLine: 2,
                                  color: isDarkMode ? white : lightGrayBlack),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                genderCategoryContainer(
                                    text: cloth.gender,
                                    isDarkMode: isDarkMode,
                                    color: purple.withAlpha(100)),
                                const SizedBox(width: 4),
                                genderCategoryContainer(
                                    text: cloth.category,
                                    isDarkMode: isDarkMode,
                                    color: green.withAlpha(100)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                buildStarRating(
                                    calculateAverageRating(cloth.reviews)),
                                const SizedBox(width: 4),
                                mediumFont(
                                    text:
                                    "${calculateAverageRating(cloth.reviews)
                                        .toStringAsFixed(1)} (${cloth.reviews
                                        .length} reviews)",
                                    color: isDarkMode ? white : grayBlack,
                                    weight: FontWeight.bold),
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
                                          "Rs. ${((cloth.price / 100) *
                                              (100 - cloth.discount))}",
                                          color:
                                          isDarkMode ? white : grayBlack),
                                      SizedBox(width: 5),
                                      smallFont(
                                          text: "Rs. ${cloth.price}",
                                          color: darkRed,
                                          isDiscounted: true,
                                          weight: FontWeight.w600),
                                    ],
                                  )
                                else
                                  smallFont(
                                      text: "Rs. ${cloth.price}",
                                      color: darkRed,
                                      isDiscounted: true,
                                      weight: FontWeight.w600),
                              ],
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                  cloth.variants.first.colors.isNotEmpty
                      ? SizedBox(
                    width: MediaQuery
                        .of(context)
                        .size
                        .width * .3,
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
                left: 5,
                top: 0,
                child: checkAndAddWishlistItems(
                    cloth: cloth, index: index, currentUser: currentUser)),
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
