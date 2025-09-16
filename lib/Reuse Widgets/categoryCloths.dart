import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:glamora/Reuse%20Widgets/features.dart';
import 'package:glamora/Reuse%20Widgets/heartIconFunction.dart';
import 'package:glamora/Reuse%20Widgets/imagesFunctionCall.dart';
import 'package:glamora/Reuse%20Widgets/ratingCalculations.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/constants/reponsivness.dart';
import 'package:glamora/models/productModel.dart';
import 'package:glamora/providers/ProductListProvider.dart';
import 'package:glamora/screens/Product%20Details/ProductDetails.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

final FirebaseFirestore _firestore = FirebaseFirestore.instance;
final List<String> _genders = ['Man', 'Woman'];
const List<String> productFeatures = [
  "Material:100% Cotton",
  "Fit Type: Regular Fit",
  "Sleeve Type: Short Sleeve",
  "Neck Style: Round Neck",
];

Widget buildProductCard(
    BuildContext context, ClothingProductModel product, int index, isDarkMode) {
  final screenWidth = getResponsiveWidth(MediaQuery.of(context).size.width);
  final imageWidth = screenWidth * 0.35;
  final imageHeight = getResponsiveHeight(180);
  final iconSize = screenWidth * 0.04;

  return InkWell(
    onTap: () {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ProductDetails(
                  id: product.id,
                  gender: product.gender,
                  category: product.category)));
    },
    child: Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? lightGrayBlack : white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 3,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// LEFT IMAGE SECTION
          Column(
            children: [
              networkImagesCache(
                  url: product.images[0],
                  width: imageWidth,
                  height: imageHeight,
                  fit: BoxFit.cover),
              Column(
                children: [
                  Container(
                    width: imageWidth,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red[700],
                      borderRadius: const BorderRadius.only(
                        bottomRight: Radius.circular(6),
                        bottomLeft: Radius.circular(6),
                      ),
                    ),
                    child: Text(
                      "Mega Deal",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: screenWidth * 0.03,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      buildStarRating(calculateAverageRating(product.reviews)),
                      const SizedBox(width: 4),
                      mediumFont(
                          text:
                              "${calculateAverageRating(product.reviews).toStringAsFixed(1)} (${product.reviews.length} reviews)",
                          color: isDarkMode ? white : grayBlack,
                          weight: FontWeight.bold),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 4),
              product.variants.first.colors.isNotEmpty
                  ? SizedBox(
                      width: MediaQuery.of(context).size.width * .3,
                      height: 28,
                      child: ListView.builder(
                          itemCount: product.variants.first.colors.length,
                          physics: const ScrollPhysics(),
                          shrinkWrap: true,
                          scrollDirection: Axis.horizontal,
                          itemBuilder: (context, index) {
                            return Container(
                              margin: const EdgeInsets.only(right: 3),
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                  color: product.variants.first.colors[index],
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color:
                                          isDarkMode ? white : lightGrayBlack,
                                      width: .5)),
                            );
                          }),
                    )
                  : const Text("None"),
            ],
          ),

          const SizedBox(width: 10),

          /// RIGHT DETAILS SECTION
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                productTitle(
                    text: product.title,
                    maxWidth: screenWidth * .6,
                    color: isDarkMode ? white : Colors.grey.shade800),
                const SizedBox(height: 4),
                buildFeatureList(productFeatures, isDarkMode, screenWidth),
                const SizedBox(height: 6),
                Row(
                  children: [
                    productTitle(
                        text:
                            "Rs. ${((product.price / 100) * (100 - product.discount))}",
                        weight: FontWeight.bold,
                        color: isDarkMode ? white : lightGrayBlack),
                    const SizedBox(width: 4),
                    smallFont(
                        text: "Rs.${product.price.toStringAsFixed(0)}",
                        color: isDarkMode ? Colors.grey.shade400 : Colors.grey,
                        isDiscounted: true),
                    const SizedBox(width: 4),
                    smallFont(
                        text: "${product.discount}% OFF",
                        color: isDarkMode ? green : Colors.green,
                        weight: FontWeight.bold)
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.lock,
                        size: iconSize, color: Colors.orange.shade700),
                    const SizedBox(width: 4),
                    Text("Selling out fast",
                        style: GoogleFonts.exo2(
                            color: isDarkMode ? white : grayBlack,
                            fontSize: screenWidth * 0.032)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    DottedBorder(
                      options: RoundedRectDottedBorderOptions(
                        color: isDarkMode ? green : Colors.green,
                        strokeWidth: 1,
                        dashPattern: [4, 2],
                        radius: const Radius.circular(4),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_offer,
                                size: iconSize,
                                color: isDarkMode ? green : Colors.green),
                            const SizedBox(width: 4),
                            smallFont(
                                text: "${product.discount}% Discount",
                                color: isDarkMode ? green : Colors.green),
                          ],
                        ),
                      ),
                    ),
                    checkAndAddWishlistItems(
                        cloth: product,
                        index: index,
                        currentUser: FirebaseAuth.instance.currentUser)
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.yellow[700],
                            borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(8),
                                bottomLeft: Radius.circular(8),
                                bottomRight: Radius.circular(6))),
                        child: smallFont(
                            text: 'express',
                            color: grayBlack,
                            weight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    smallFont(
                        text: "Get it by 2-3 Days",
                        color: isDarkMode ? white : grayBlack)
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget buildEmptyState(
    {required bool isDarkMode, required BuildContext context}) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.inventory_2_outlined,
          size: 80,
          color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade300,
        ),
        const SizedBox(height: 20),
        productTitle(
            text: 'No Products Found',
            weight: FontWeight.w500,
            color: isDarkMode ? white : grayBlack,
            maxWidth: MediaQuery.of(context).size.width * .6),
      ],
    ),
  );
}

Future<void> fetchProducts(BuildContext context) async {
  final provider = Provider.of<ProductListProvider>(context, listen: false);
  provider.setLoading(true);

  try {
    QuerySnapshot snapshot = await _firestore
        .collection('Cloths')
        .doc(provider.selectedGender)
        .collection(provider.selectedCategory)
        .get();

    List<ClothingProductModel> products = snapshot.docs
        .map((doc) => ClothingProductModel.fromSnapshot(doc))
        .toList();

    provider.setProducts(products);
  } catch (e) {
    debugPrint('Error fetching products: $e');
  } finally {
    provider.setLoading(false);
  }
}

Widget buildGenderDropdown({required bool isDarkMode}) {
  return Consumer<ProductListProvider>(
    builder: (context, provider, child) {
      return DropdownButton<String>(
        dropdownColor: isDarkMode ? lightGrayBlack : white,
        value: provider.selectedGender,
        items: _genders
            .map((gender) => DropdownMenuItem(
                  value: gender,
                  child: mediumFont(
                      text: gender, color: isDarkMode ? white : grayBlack),
                ))
            .toList(),
        onChanged: (value) {
          provider.setSelectedGender(value!);
          fetchProducts(context);
        },
      );
    },
  );
}
