import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../constants/colors.dart';
import '../constants/reponsivness.dart';

Widget reusableShimmerContainer({
  required BuildContext context,
  required bool isDarkMode,
  required double height,
  double? width,
  bool isCircle = false,
}) {
  return Shimmer.fromColors(
    baseColor: Colors.white30,
    highlightColor: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade100,
    child: Container(
      height: height,
      width: width ?? MediaQuery.of(context).size.width,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade900 : Colors.grey.shade300,
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : BorderRadius.circular(6),
      ),
    ),
  );
}

Widget categoryProductCardShimmer({
  required BuildContext context,
  required bool isDarkMode,
}) {
  final screenWidth = getResponsiveWidth(MediaQuery.of(context).size.width);
  final imageWidth = screenWidth * 0.35;
  final imageHeight = getResponsiveHeight(180);

  return Container(
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
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Image Section
        Column(
          children: [
            // Image placeholder
            reusableShimmerContainer(
              context: context,
              isDarkMode: isDarkMode,
              height: imageHeight,
              width: imageWidth,
            ),
            // Mega Deal placeholder
            reusableShimmerContainer(
              context: context,
              isDarkMode: isDarkMode,
              height: 16,
              width: imageWidth,
            ),
            const SizedBox(height: 4),
            // Rating placeholder
            reusableShimmerContainer(
              context: context,
              isDarkMode: isDarkMode,
              height: 12,
              width: imageWidth * 0.6,
            ),
            const SizedBox(height: 4),
            // Color dots placeholder
            Row(
              children: List.generate(
                3,
                (index) => Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: reusableShimmerContainer(
                    context: context,
                    isDarkMode: isDarkMode,
                    height: 18,
                    width: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
        // Right Details Section
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title placeholder
              reusableShimmerContainer(
                context: context,
                isDarkMode: isDarkMode,
                height: 16,
                width: screenWidth * 0.5,
              ),
              const SizedBox(height: 4),
              // Features placeholder
              Column(
                children: List.generate(
                  2,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: reusableShimmerContainer(
                      context: context,
                      isDarkMode: isDarkMode,
                      height: 12,
                      width: screenWidth * 0.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Price and discount placeholder
              Row(
                children: [
                  reusableShimmerContainer(
                    context: context,
                    isDarkMode: isDarkMode,
                    height: 14,
                    width: 60,
                  ),
                  const SizedBox(width: 4),
                  reusableShimmerContainer(
                    context: context,
                    isDarkMode: isDarkMode,
                    height: 12,
                    width: 40,
                  ),
                  const SizedBox(width: 4),
                  reusableShimmerContainer(
                    context: context,
                    isDarkMode: isDarkMode,
                    height: 12,
                    width: 50,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Selling out fast placeholder
              reusableShimmerContainer(
                context: context,
                isDarkMode: isDarkMode,
                height: 12,
                width: 100,
              ),
              const SizedBox(height: 4),
              // Discount and wishlist placeholder
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  reusableShimmerContainer(
                    context: context,
                    isDarkMode: isDarkMode,
                    height: 20,
                    width: 80,
                  ),
                  reusableShimmerContainer(
                    context: context,
                    isDarkMode: isDarkMode,
                    height: 24,
                    width: 24,
                    isCircle: true, // Circle for wishlist icon
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Express delivery placeholder
              Row(
                children: [
                  reusableShimmerContainer(
                    context: context,
                    isDarkMode: isDarkMode,
                    height: 16,
                    width: 50,
                  ),
                  const SizedBox(width: 4),
                  reusableShimmerContainer(
                    context: context,
                    isDarkMode: isDarkMode,
                    height: 12,
                    width: 80,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget productCardShimmer({
  required BuildContext context,
  required bool isDarkMode,
}) {
  final screenWidth = MediaQuery.of(context).size.width;
  final cardWidth = screenWidth * 0.45;

  return Padding(
    padding: const EdgeInsets.only(left: 8, bottom: 5, top: 5),
    child: Card(
      elevation: isDarkMode ? 3 : 0,
      child: Stack(
        children: [
          Container(
            width: cardWidth,
            decoration: BoxDecoration(
              color: isDarkMode ? lightGrayBlack : white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDarkMode ? Colors.transparent : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image placeholder
                reusableShimmerContainer(
                  context: context,
                  isDarkMode: isDarkMode,
                  height: 120,
                  width: cardWidth,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      // Title placeholder
                      reusableShimmerContainer(
                        context: context,
                        isDarkMode: isDarkMode,
                        height: 16,
                        width: cardWidth * 0.8,
                      ),
                      const SizedBox(height: 4),
                      // Gender and category tags placeholder
                      Row(
                        children: [
                          reusableShimmerContainer(
                            context: context,
                            isDarkMode: isDarkMode,
                            height: 20,
                            width: 60,
                          ),
                          const SizedBox(width: 4),
                          reusableShimmerContainer(
                            context: context,
                            isDarkMode: isDarkMode,
                            height: 20,
                            width: 60,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Rating placeholder
                      Row(
                        children: [
                          reusableShimmerContainer(
                            context: context,
                            isDarkMode: isDarkMode,
                            height: 12,
                            width: cardWidth * 0.6,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Price placeholder
                      Row(
                        children: [
                          reusableShimmerContainer(
                            context: context,
                            isDarkMode: isDarkMode,
                            height: 14,
                            width: 60,
                          ),
                          const SizedBox(width: 5),
                          reusableShimmerContainer(
                            context: context,
                            isDarkMode: isDarkMode,
                            height: 12,
                            width: 40,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Color dots placeholder
                // Row(
                //   mainAxisAlignment: MainAxisAlignment.spaceAround,
                //   children: [
                //     Padding(
                //       padding: const EdgeInsets.only(left: 3),
                //       child: reusableShimmerContainer(
                //         context: context,
                //         isDarkMode: isDarkMode,
                //         height: 24,
                //         width: 24,
                //         isCircle: true, // Circular for color dots
                //       ),
                //     ),
                //     reusableShimmerContainer(
                //       context: context,
                //       isDarkMode: isDarkMode,
                //       height: 20,
                //       width: cardWidth * 0.5,
                //     ),
                //   ],
                // ),
                // // Limited stock placeholder
                // Padding(
                //   padding: EdgeInsets.all(8),
                //   child: reusableShimmerContainer(
                //     context: context,
                //     isDarkMode: isDarkMode,
                //     height: 20,
                //     width: cardWidth * 0.9,
                //   ),
                // )
              ],
            ),
          ),
          // Wishlist icon placeholder
          Positioned(
            left: 5,
            top: 0,
            child: reusableShimmerContainer(
              context: context,
              isDarkMode: isDarkMode,
              height: 24,
              width: 24,
              isCircle: true, // Circular for wishlist icon
            ),
          ),
          // Discount badge placeholder
          Positioned(
            right: 5,
            top: 5,
            child: reusableShimmerContainer(
              context: context,
              isDarkMode: isDarkMode,
              height: 30,
              width: 50,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget cartClothCardShimmer({
  required BuildContext context,
  required bool isDarkMode,
}) {
  final screenWidth = MediaQuery.of(context).size.width;
  final imageHeight =
      MediaQuery.of(context).size.height * 0.11; // Matches heightFactor
  final imageWidth = screenWidth * 0.25; // Matches widthFactor

  return Stack(
    children: [
      Container(
        padding: const EdgeInsets.only(top: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Image placeholder
                reusableShimmerContainer(
                  context: context,
                  isDarkMode: isDarkMode,
                  height: imageHeight,
                  width: imageWidth,
                  isCircle: false,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title placeholder
                      reusableShimmerContainer(
                        context: context,
                        isDarkMode: isDarkMode,
                        height: 16,
                        width: 150,
                        // Matches maxWidth
                        isCircle: false,
                      ),
                      const SizedBox(height: 4),
                      // Gender and category tags placeholder
                      Row(
                        children: [
                          reusableShimmerContainer(
                            context: context,
                            isDarkMode: isDarkMode,
                            height: 20,
                            width: 60,
                            isCircle: false,
                          ),
                          const SizedBox(width: 4),
                          reusableShimmerContainer(
                            context: context,
                            isDarkMode: isDarkMode,
                            height: 20,
                            width: 60,
                            isCircle: false,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Price placeholder
                      Row(
                        children: [
                          reusableShimmerContainer(
                            context: context,
                            isDarkMode: isDarkMode,
                            height: 14,
                            width: 60,
                            isCircle: false,
                          ),
                          const SizedBox(width: 5),
                          reusableShimmerContainer(
                            context: context,
                            isDarkMode: isDarkMode,
                            height: 12,
                            width: 40,
                            isCircle: false,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Color dot and quantity/total placeholder
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          reusableShimmerContainer(
                            context: context,
                            isDarkMode: isDarkMode,
                            height: 28,
                            width: 28,
                            isCircle: true, // Circular for color dot
                          ),
                          const SizedBox(width: 70),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              reusableShimmerContainer(
                                context: context,
                                isDarkMode: isDarkMode,
                                height: 12,
                                width: 20,
                                // For quantity (xN)
                                isCircle: false,
                              ),
                              const SizedBox(width: 10),
                              reusableShimmerContainer(
                                context: context,
                                isDarkMode: isDarkMode,
                                height: 12,
                                width: 60,
                                // For total price
                                isCircle: false,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            // Divider placeholder
            reusableShimmerContainer(
              context: context,
              isDarkMode: isDarkMode,
              height: 1,
              width: double.infinity,
              isCircle: false,
            ),
          ],
        ),
      ),
      // Close button placeholder
      Positioned(
        top: 0,
        right: 10,
        child: reusableShimmerContainer(
          context: context,
          isDarkMode: isDarkMode,
          height: 24,
          width: 24,
          isCircle: true, // Circular for close button
        ),
      ),
    ],
  );
}

Widget historyOrderShimmer({
  required BuildContext context,
  required bool isDarkMode,
}) {
  final screenWidth = MediaQuery.of(context).size.width;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        color: isDarkMode ? lightGrayBlack : grayBlack,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order ID and Order Time row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                reusableShimmerContainer(
                  context: context,
                  isDarkMode: isDarkMode,
                  height: 16,
                  width: screenWidth * 0.6,
                  // Matches maxWidth
                  isCircle: false,
                ),
                reusableShimmerContainer(
                  context: context,
                  isDarkMode: isDarkMode,
                  height: 12,
                  width: 80,
                  // Approximate width for order time
                  isCircle: false,
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Order Date and Total Price row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                reusableShimmerContainer(
                  context: context,
                  isDarkMode: isDarkMode,
                  height: 12,
                  width: 100,
                  // Approximate width for order date
                  isCircle: false,
                ),
                reusableShimmerContainer(
                  context: context,
                  isDarkMode: isDarkMode,
                  height: 12,
                  width: screenWidth * 0.5,
                  // Matches maxWidth
                  isCircle: false,
                ),
              ],
            ),
            const SizedBox(height: 10),
            // View Detail's placeholder
            reusableShimmerContainer(
              context: context,
              isDarkMode: isDarkMode,
              height: 12,
              width: 100,
              // Approximate width for "View Detail's"
              isCircle: false,
            ),
          ],
        ),
      ),
      // Divider placeholder
      reusableShimmerContainer(
        context: context,
        isDarkMode: isDarkMode,
        height: 5,
        // Matches divider thickness
        width: double.infinity,
        isCircle: false,
      ),
    ],
  );
}

Widget productDetailsShimmer({
  required BuildContext context,
  required bool isDarkMode,
}) {
  final screenWidth = MediaQuery.of(context).size.width;

  return ListView(
    physics: const NeverScrollableScrollPhysics(),
    children: [
      // Top Image Section (PageView placeholder)
      reusableShimmerContainer(
        context: context,
        isDarkMode: isDarkMode,
        height: 300,
        width: screenWidth,
      ),

      // Main Card Content
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? grayBlack : white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            reusableShimmerContainer(
              context: context,
              isDarkMode: isDarkMode,
              height: 24,
              width: screenWidth * 0.7,
            ),
            const SizedBox(height: 12),

            // Gender & Category Tags + Heart Icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    reusableShimmerContainer(
                      context: context,
                      isDarkMode: isDarkMode,
                      height: 28,
                      width: 70,
                    ),
                    const SizedBox(width: 8),
                    reusableShimmerContainer(
                      context: context,
                      isDarkMode: isDarkMode,
                      height: 28,
                      width: 80,
                    ),
                  ],
                ),
                reusableShimmerContainer(
                  context: context,
                  isDarkMode: isDarkMode,
                  height: 40,
                  width: 40,
                  isCircle: true,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Price Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    reusableShimmerContainer(
                      context: context,
                      isDarkMode: isDarkMode,
                      height: 28,
                      width: 100,
                    ),
                    const SizedBox(width: 8),
                    reusableShimmerContainer(
                      context: context,
                      isDarkMode: isDarkMode,
                      height: 20,
                      width: 70,
                    ),
                  ],
                ),
                reusableShimmerContainer(
                  context: context,
                  isDarkMode: isDarkMode,
                  height: 20,
                  width: 120,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Colors Label + Color Circles
            Row(
              children: [
                reusableShimmerContainer(
                  context: context,
                  isDarkMode: isDarkMode,
                  height: 18,
                  width: 60,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(
                          5,
                          (i) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: reusableShimmerContainer(
                                  context: context,
                                  isDarkMode: isDarkMode,
                                  height: 32,
                                  width: 32,
                                  isCircle: true,
                                ),
                              )),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Sizes Label + Size Chips
            Row(
              children: [
                reusableShimmerContainer(
                  context: context,
                  isDarkMode: isDarkMode,
                  height: 18,
                  width: 60,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(
                          5,
                          (i) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: reusableShimmerContainer(
                                  context: context,
                                  isDarkMode: isDarkMode,
                                  height: 36,
                                  width: 50,
                                ),
                              )),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Rating Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Row(
                      children: List.generate(
                          5,
                          (_) => const Icon(Icons.star,
                              size: 20, color: Colors.grey)),
                    ),
                    const SizedBox(width: 8),
                    reusableShimmerContainer(
                      context: context,
                      isDarkMode: isDarkMode,
                      height: 16,
                      width: 100,
                    ),
                  ],
                ),
                reusableShimmerContainer(
                  context: context,
                  isDarkMode: isDarkMode,
                  height: 16,
                  width: 60,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Review Card (first review preview)
            Card(
              elevation: 3,
              color: isDarkMode ? lightGrayBlack : white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            reusableShimmerContainer(
                              context: context,
                              isDarkMode: isDarkMode,
                              height: 40,
                              width: 40,
                              isCircle: true,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                reusableShimmerContainer(
                                  context: context,
                                  isDarkMode: isDarkMode,
                                  height: 16,
                                  width: 100,
                                ),
                                const SizedBox(height: 4),
                                reusableShimmerContainer(
                                  context: context,
                                  isDarkMode: isDarkMode,
                                  height: 12,
                                  width: 80,
                                ),
                              ],
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Row(
                              children: List.generate(
                                  5,
                                  (_) => const Icon(Icons.star,
                                      size: 16, color: Colors.grey)),
                            ),
                            const SizedBox(height: 4),
                            reusableShimmerContainer(
                              context: context,
                              isDarkMode: isDarkMode,
                              height: 12,
                              width: 60,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    reusableShimmerContainer(
                      context: context,
                      isDarkMode: isDarkMode,
                      height: 12,
                      width: double.infinity,
                    ),
                    const SizedBox(height: 8),
                    reusableShimmerContainer(
                      context: context,
                      isDarkMode: isDarkMode,
                      height: 12,
                      width: screenWidth * 0.6,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Description Title + Text
            reusableShimmerContainer(
              context: context,
              isDarkMode: isDarkMode,
              height: 20,
              width: 100,
            ),
            const SizedBox(height: 8),
            reusableShimmerContainer(
              context: context,
              isDarkMode: isDarkMode,
              height: 12,
              width: double.infinity,
            ),
            const SizedBox(height: 8),
            reusableShimmerContainer(
              context: context,
              isDarkMode: isDarkMode,
              height: 12,
              width: screenWidth * 0.8,
            ),
            const SizedBox(height: 24),

            // Features Title
            reusableShimmerContainer(
              context: context,
              isDarkMode: isDarkMode,
              height: 18,
              width: 80,
            ),
            const SizedBox(height: 12),

            // Feature List Items
            ...List.generate(
                4,
                (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.check, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          reusableShimmerContainer(
                            context: context,
                            isDarkMode: isDarkMode,
                            height: 14,
                            width: screenWidth * 0.6,
                          ),
                        ],
                      ),
                    )),

            const SizedBox(height: 120), // Space for bottom sheet
          ],
        ),
      ),
    ],
  );
}

Widget buildShimmerLoading(BuildContext context, bool isDark) {
  return ListView.builder(
    padding: responsivePadding(left: 16, right: 16, bottom: 16),
    itemCount: 5, // Show 5 shimmer cards for loading
    itemBuilder: (context, index) {
      return Card(
        elevation: 0,
        margin: EdgeInsets.only(bottom: getResponsiveHeight(16)),
        color: isDark ? lightGrayBlack : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(getResponsiveWidth(16)),
        ),
        child: Padding(
          padding: responsivePadding(left: 16, right: 16, top: 16, bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Shimmer for header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        reusableShimmerContainer(
                          context: context,
                          isDarkMode: isDark,
                          height: getResponsiveHeight(20),
                          width: getResponsiveWidth(200),
                        ),
                        SizedBox(height: getResponsiveHeight(4)),
                        reusableShimmerContainer(
                          context: context,
                          isDarkMode: isDark,
                          height: getResponsiveHeight(12),
                          width: getResponsiveWidth(150),
                        ),
                      ],
                    ),
                  ),
                  reusableShimmerContainer(
                    context: context,
                    isDarkMode: isDark,
                    height: getResponsiveHeight(24),
                    width: getResponsiveWidth(24),
                    isCircle: true,
                  ),
                ],
              ),
              SizedBox(height: getResponsiveHeight(16)),
              // Shimmer for customer row
              Row(
                children: [
                  reusableShimmerContainer(
                    context: context,
                    isDarkMode: isDark,
                    height: getResponsiveHeight(16),
                    width: getResponsiveWidth(16),
                    isCircle: true,
                  ),
                  SizedBox(width: getResponsiveWidth(8)),
                  Expanded(
                    child: reusableShimmerContainer(
                      context: context,
                      isDarkMode: isDark,
                      height: getResponsiveHeight(14),
                      width: double.infinity,
                    ),
                  ),
                ],
              ),
              SizedBox(height: getResponsiveHeight(8)),
              // Shimmer for items row
              Row(
                children: [
                  reusableShimmerContainer(
                    context: context,
                    isDarkMode: isDark,
                    height: getResponsiveHeight(16),
                    width: getResponsiveWidth(16),
                    isCircle: true,
                  ),
                  SizedBox(width: getResponsiveWidth(8)),
                  Expanded(
                    child: reusableShimmerContainer(
                      context: context,
                      isDarkMode: isDark,
                      height: getResponsiveHeight(12),
                      width: getResponsiveWidth(100),
                    ),
                  ),
                ],
              ),
              SizedBox(height: getResponsiveHeight(12)),
              // Shimmer for track button
              Align(
                alignment: Alignment.centerRight,
                child: reusableShimmerContainer(
                  context: context,
                  isDarkMode: isDark,
                  height: getResponsiveHeight(32),
                  width: getResponsiveWidth(100),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
