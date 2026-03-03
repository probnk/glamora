import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:glamora/BottomNavBar/BottomNavBar.dart';
import 'package:glamora/Reuse%20Widgets/features.dart';
import 'package:glamora/Reuse%20Widgets/genderCategoryContainer.dart';
import 'package:glamora/Reuse%20Widgets/imagesFunctionCall.dart';
import 'package:glamora/Services/Try%20On%20Service/tryon.dart';
import 'package:glamora/Services/personalization_service.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/constants/reponsivness.dart';
import 'package:glamora/models/ReviewsModel.dart';
import 'package:glamora/models/cartProducts.dart';
import 'package:glamora/models/productModel.dart';
import 'package:glamora/models/wishListProducts.dart';
import 'package:glamora/providers/CartProvider.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:glamora/providers/ProductDetailsProvider.dart';
import 'package:glamora/providers/WishListProvider.dart';
import 'package:glamora/screens/Rating/Rating.dart';
import 'package:iconly/iconly.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../Reuse Widgets/loadingShimmer.dart';
import '../../Services/Try On Service/ar_service.dart';
import '../../Services/Try On Service/image_cache_service.dart';
import '../../constants/app_theme.dart';
import '../../providers/UserDetailsProvider.dart';
import '../AR Try On/ar_try_on_screen.dart';
import '../AR Try On/widgets/try_on_button.dart';
import '../Order Process/OrderDetails.dart';
import 'AI Image stlying/AIVisualization.dart';
import 'AR Try On/CameraDetection.dart';

class ProductDetails extends StatefulWidget {
  final String id;
  final String gender;
  final String category;

  const ProductDetails({
    super.key,
    required this.id,
    required this.gender,
    required this.category,
  });

  @override
  State<ProductDetails> createState() => _ProductDetailsState();
}

class _ProductDetailsState extends State<ProductDetails> {
  var currentUser;
  bool _isARPreloaded = false;
  double _preloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      trackPersonalization(
          currentUser.uid, widget.category, "view", 'increment');
    }
  }

  Future<void> _preloadARResources(ClothingProductModel product) async {
    try {
      final arService = context.read<ARService>();
      final imageCacheService = context.read<ImageCacheService>();

      // Initialize AR service
      if (!arService.isInitialized) {
        setState(() => _preloadProgress = 0.2);
        await arService.initialize();
      }

      // Preload images
      setState(() => _preloadProgress = 0.5);
      await imageCacheService.preloadImages([
        product.front,
        product.back,
      ]);

      // Load product for AR
      setState(() => _preloadProgress = 0.8);
      await arService.loadProductForAR(product);

      setState(() {
        _isARPreloaded = true;
        _preloadProgress = 1.0;
      });
    } catch (e) {
      print('AR preloading failed: $e');
      // Silently fail, button will handle it
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMMM, yyyy').format(date);
  }

  String _formatTime(DateTime date) {
    return DateFormat('h:mm a').format(date);
  }

  _productDetailsAppbar({required bool isDarkMode}) {
    final provider = Provider.of<ProductDetailsProvider>(context);
    return AppBar(
      backgroundColor: isDarkMode ? lightGrayBlack : Colors.grey.shade50,
      centerTitle: true,
      title: titleFont(
          text: "Product Details", color: isDarkMode ? white : grayBlack),
      iconTheme: IconThemeData(color: isDarkMode ? white : grayBlack),
      actions:  [
          // Add this button where you want to show virtual try-on
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VirtualTryOnScreen(
                    clothImageUrl: provider.productDetails!.front, // or item.imageUrl
                    productTitle: provider.productDetails!.title,
                    category: provider.productDetails!.category,// or item.name
                  ),
                ),
              );
            },
            icon: const Icon(Icons.checkroom_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: white,
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          IconButton(
            // In your ProductDetails screen when navigating to Try-On
            // When navigating to TryOn
              onPressed: () async {
                // Request camera permission
                var status = await Permission.camera.request();
                if (status.isGranted) {
                  // Permission allowed, open camera screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) =>
                        PoseDetectorScreen(
                            gender: widget.gender, category: widget.category,products: [provider.productDetails!],)),
                  );
                } else {
                  // Permission denied, pop navigator (or show message)
                  if (status.isPermanentlyDenied) {
                    // If permanently denied, open app settings
                    openAppSettings();
                  } else {
                    // Just denied, you can show a snackbar or pop
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Camera permission denied')),
                    );
                    Navigator.pop(
                        context); // Pop if this is a new screen, or handle accordingly
                  }
                }
              },
              icon: Icon(CupertinoIcons.cube_box_fill, )),
        ],

      // leading: IconButton(
      //   // In your ProductDetails screen when navigating to Try-On
      //   // When navigating to TryOn
      //     onPressed: () async {
      //       try {
      //         final cameras = await CameraHelper.getCameras();
      //         if (cameras.isEmpty) throw Exception('No cameras available');
      //         Navigator.push(
      //           context,
      //           MaterialPageRoute(builder: (_) => TryOnScreen(cameras: cameras)),
      //         );
      //       } catch (e) {
      //         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Camera error: $e')));
      //       }
      //     },
      //     icon: Icon(IconlyBold.camera)),
    );
  }

  Widget _selectedText({required String text, required bool isDarkMode}) {
    return mediumFont(
      text: text,
      color: isDarkMode ? white : grayBlack,
      weight: FontWeight.w800,
      maxWidth: MediaQuery
          .of(context)
          .size
          .width * .2,
    );
  }

  Widget _productDetailsBody({required bool isDarkMode}) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("Cloths")
          .doc(widget.gender)
          .collection(widget.category)
          .doc(widget.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error loading product details"));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Center(child: Text("No data available"));
        }

        final data = snapshot.data!.data();
        if (data is! Map<String, dynamic>) {
          return Center(child: Text("Invalid data format"));
        }

        final productDetails = ClothingProductModel.fromMap(data);
        context.read<ProductDetailsProvider>().addProductDetails(productDetails);
        return ListView(
          shrinkWrap: true,
          physics: const ScrollPhysics(),
          children: [
            Stack(
              alignment: Alignment.topLeft,
              children: [
                Consumer<ProductDetailsProvider>(
                  builder: (context, value, child) {
                    return Stack(
                      children: [
                        Container(
                          height: 300,
                          color: isDarkMode ? grayBlack : Colors.grey.shade50,
                          child: Center(
                            child: PageView.builder(
                              itemCount: productDetails.images.length,
                              onPageChanged: (index) {
                                value.setSelectedImage(index);
                              },
                              itemBuilder: (context, index) {
                                return networkImagesCache(
                                  url: productDetails.images[index],
                                  width: MediaQuery
                                      .of(context)
                                      .size
                                      .width,
                                  height: 400,
                                );
                              },
                            ),
                          ),
                        ),
                        // Container(
                        //   width: 250,height: 100,
                        //   padding: const EdgeInsets.only(right: 12),
                        //   alignment: Alignment.topRight,
                        //   child: ARTryOnButton(
                        //     product: productDetails,
                        //     onPressed: _isARPreloaded
                        //         ? () {
                        //       Navigator.push(
                        //         context,
                        //         MaterialPageRoute(
                        //           builder: (context) => ARTryOnScreen(
                        //             product: productDetails,
                        //           ),
                        //         ),
                        //       );
                        //     }
                        //         : null,
                        //   ),
                        // ),
                      ],
                    );
                  },
                ),
              ],
            ),
            _productDetailsCard(
              productDetails: productDetails,
              isDarkMode: isDarkMode,
            ),
          ],
        );
      },
    );
  }

  Widget _productDetailsCard({
    required ClothingProductModel productDetails,
    required bool isDarkMode,
  }) {
    final hasReviews = productDetails.reviews.isNotEmpty;
    DateTime? tempDate;
    String date = '';
    String time = '';

    if (hasReviews) {
      try {
        tempDate = DateTime.parse(productDetails.reviews.first.reviewDate);
        date = _formatDate(tempDate);
        time = _formatTime(tempDate);
      } catch (e) {
        tempDate = DateTime.now();
        date = _formatDate(tempDate);
        time = _formatTime(tempDate);
      }
    }
    final screenWidth = getResponsiveWidth(MediaQuery
        .of(context)
        .size
        .width);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? grayBlack : white,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(20),
          topLeft: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          headingFont(
            text: productDetails.title,
            color: isDarkMode ? white : grayBlack,
            align: TextAlign.start,
            weight: FontWeight.w500,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  genderCategoryContainer(
                      text: productDetails.gender,
                      isDarkMode: isDarkMode,
                      color: Colors.green.withOpacity(0.15),
                      textColor: Colors.green),
                  const SizedBox(width: 4),
                  genderCategoryContainer(
                      text: productDetails.category,
                      isDarkMode: isDarkMode,
                      color: Colors.blue.withOpacity(0.15),
                      textColor: Colors.blue),
                ],
              ),
              Consumer<WishListProvider>(builder: (context, value, child) {
                bool isFound = false;
                var wishlistData = WishlistProducts(
                  id: productDetails.id,
                  title: productDetails.title,
                  price: productDetails.price,
                  discount: productDetails.discount,
                  images: productDetails.images,
                  category: productDetails.category,
                  gender: productDetails.gender,
                  isFav: false,
                );

                for (int i = 0; i < value.wishListProducts.length; i++) {
                  if (value.wishListProducts[i].id
                      .contains(productDetails.id)) {
                    isFound = true;
                    break;
                  }
                }

                return InkWell(
                  onTap: () {
                    if (!isFound) {
                      value.addWishListItem(wishlistData);
                      value.storeClothsList(wishlistData);
                      trackPersonalization(currentUser.uid, widget.category,
                          "wishlist", 'increment');
                    } else {
                      value.deleteWishListItem(productDetails.id);
                      value.removeWishListItems(productDetails.id);
                      trackPersonalization(currentUser.uid, widget.category,
                          "wishlist", 'decrement');
                    }
                    // if(currentUser != null){
                    //   trackPersonalization(currentUser.uid, widget.category, "wishlist",'increment');
                    // }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDarkMode ? lightGrayBlack : Colors.grey.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isFound ? IconlyBold.heart : IconlyLight.heart,
                      color: lightRed,
                    ),
                  ),
                );
              }),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (productDetails.discount != 0)
                Row(
                  children: [
                    productTitle(
                      text:
                      "Rs ${((productDetails.price / 100) *
                          (100 - productDetails.discount)).toStringAsFixed(2)}",
                      color: isDarkMode ? white : grayBlack,
                    ),
                    const SizedBox(width: 5),
                    smallFont(
                      text: "Rs ${productDetails.price.toStringAsFixed(2)}",
                      color: darkRed,
                      isDiscounted: true,
                      weight: FontWeight.w600,
                    ),
                  ],
                )
              else
                smallFont(
                  text: "Rs ${productDetails.price}",
                  color: darkRed,
                  isDiscounted: true,
                  weight: FontWeight.w600,
                ),
              smallFont(
                text:
                "🔥📦 Stock:${productDetails.variants[0].sizes[context
                    .watch<ProductDetailsProvider>()
                    .selectedSize].stock}",
                color: productDetails
                    .variants[0]
                    .sizes[context
                    .watch<ProductDetailsProvider>()
                    .selectedSize]
                    .stock >
                    10
                    ? lightGreen
                    : darkRed,
                weight: FontWeight.w600,
              ),
            ],
          ),
          const SizedBox(height: 10),
          mediumFont(
              text: "${productDetails.views} Person Viewed this ${productDetails
                  .category}", maxWidth: 300),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _selectedText(text: "Colors:", isDarkMode: isDarkMode),
              const SizedBox(width: 5),
              productDetails.variants.first.colors.isNotEmpty
                  ? Expanded(
                child: Consumer<ProductDetailsProvider>(
                  builder: (context, selectedColor, child) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(
                          productDetails.variants.first.colors.length,
                              (index) {
                            final color = productDetails
                                .variants.first.colors[index];
                            final isWhiteColor = color == Colors.white;
                            final isBlackColor = color == Colors.black;

                            return InkWell(
                              onTap: () {
                                selectedColor.setSelectedColor(index);
                              },
                              child: Container(
                                margin: index > 0
                                    ? const EdgeInsets.only(left: 5)
                                    : EdgeInsets.zero,
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: color,
                                  border: Border.all(
                                      color: Colors.grey.shade300),
                                  shape: BoxShape.circle,
                                ),
                                child: Container(
                                  margin: EdgeInsets.zero,
                                  padding: EdgeInsets.zero,
                                  decoration: BoxDecoration(
                                    color: selectedColor.selectedColor ==
                                        index
                                        ? Colors.white24
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                    border: selectedColor.selectedColor ==
                                        index
                                        ? Border.all(
                                      color: isBlackColor
                                          ? darkGreen
                                          : lightGrayBlack,
                                      width: 2,
                                    )
                                        : Border.all(
                                        color: Colors.transparent),
                                  ),
                                  child:
                                  selectedColor.selectedColor == index
                                      ? Icon(
                                    Icons.done,
                                    color: isWhiteColor
                                        ? lightGrayBlack
                                        : white,
                                  )
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              )
                  : const Text("None"),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _selectedText(text: "Sizes:", isDarkMode: isDarkMode),
              const SizedBox(width: 5),
              productDetails.variants.first.sizes.isNotEmpty
                  ? Expanded(
                child: Consumer<ProductDetailsProvider>(
                  builder: (context, selectedSize, child) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(
                          productDetails.variants.first.sizes.length,
                              (index) {
                            final size = productDetails
                                .variants.first.sizes[index];
                            final isSelected =
                                selectedSize.selectedSize == index;

                            return Padding(
                              padding: index > 0
                                  ? const EdgeInsets.only(left: 5)
                                  : EdgeInsets.zero,
                              child: ChoiceChip(
                                label: smallFont(
                                  text: size.size,
                                  color: isSelected
                                      ? white
                                      : (isDarkMode ? white : grayBlack),
                                  weight: FontWeight.w500,
                                ),
                                backgroundColor: isDarkMode
                                    ? lightGrayBlack
                                    : Colors.grey.shade100,
                                disabledColor: Colors.grey.shade100,
                                selected: isSelected,
                                checkmarkColor: isDarkMode
                                    ? lightGrayBlack
                                    : lightGreen,
                                selectedColor:
                                isDarkMode ? lightGreen : grayBlack,
                                onSelected: (selected) {
                                  selectedSize.setSelectedSize(index);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              )
                  : const Text("No sizes available"),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      Rating(
                        reviews: productDetails.reviews,
                      ),
                ),
              );
            },
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _buildStarRating(
                            _calculateAverageRating(productDetails.reviews)),
                        const SizedBox(width: 8),
                        productTitle(
                          text:
                          "${_calculateAverageRating(productDetails.reviews)
                              .toStringAsFixed(1)} (${productDetails.reviews
                              .length} reviews)",
                          color: isDarkMode ? white : grayBlack,
                        ),
                      ],
                    ),
                    smallFont(text: "See all", color: Colors.grey),
                  ],
                ),
                const SizedBox(height: 10),
                if (hasReviews) ...[
                  Card(
                    elevation: 3,
                    color: isDarkMode ? lightGrayBlack : white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Colors.transparent,
                                    backgroundImage: NetworkImage(productDetails
                                        .reviews.first.profilePhoto),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      productTitle(
                                        text: productDetails
                                            .reviews.first.reviewerName,
                                        color: isDarkMode ? white : grayBlack,
                                      ),
                                      smallFont(
                                        text: date,
                                        color: Colors.grey,
                                        weight: FontWeight.w600,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _buildStarRating(productDetails
                                      .reviews.first.rating
                                      .toDouble()),
                                  smallFont(
                                    text: time,
                                    color: Colors.grey,
                                    weight: FontWeight.w600,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          smallFont(
                            text: productDetails.reviews.first.comment,
                            color: Colors.grey,
                            align: TextAlign.start,
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else
                  ...[
                    const SizedBox(height: 16),
                    smallFont(
                      text: "No reviews yet",
                      color: Colors.grey,
                      weight: FontWeight.w600,
                    ),
                  ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          _productDescriptionFonts(
            title: "Description",
            subTitle: productDetails.description,
            isDarkMode: isDarkMode,
          ),
          if (productDetails.features.isNotEmpty)
            mediumFont(
                text: 'Features',
                color: isDarkMode ? white : grayBlack,
                weight: FontWeight.bold),
          buildFeatureList(productDetails.features, isDarkMode, screenWidth),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  double _calculateAverageRating(List<ProductReviewModel> reviews) {
    if (reviews.isEmpty) return 0.0;

    double total = 0.0;
    for (var review in reviews) {
      total += review.rating.toDouble();
    }
    return total / reviews.length;
  }

  Widget _buildStarRating(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return Icon(
            Icons.star_rounded,
            color: Colors.yellow.shade700,
            size: 20,
          );
        } else if (index == rating.floor() && rating % 1 >= 0.5) {
          return Icon(
            Icons.star_half_rounded,
            color: Colors.yellow.shade700,
            size: 20,
          );
        } else {
          return Icon(
            Icons.star_outline_rounded,
            color: Colors.yellow.shade700,
            size: 20,
          );
        }
      }),
    );
  }

  Widget _productDescriptionFonts({
    required String title,
    required String subTitle,
    required bool isDarkMode,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        mediumFont(
          text: title,
          color: isDarkMode ? white : grayBlack,
          weight: FontWeight.bold,
          align: TextAlign.start,
        ),
        smallFont(
          text: subTitle,
          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
          align: TextAlign.start,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _quantityCounter({
    required bool isDarkMode,
    required ClothingProductModel productDetails,
  }) {
    return Consumer<ProductDetailsProvider>(builder: (context, value, child) {
      final selectedSize = value.selectedSize;
      final stock = productDetails.variants[0].sizes[selectedSize].stock;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        constraints: BoxConstraints(maxWidth: 130, minWidth: 120),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isDarkMode ? grayBlack : white,
        ),
        child: Row(
          children: [
            InkWell(
              onTap: value.quantity == 1 || stock == 0
                  ? null
                  : () {
                value.subtractValue();
              },
              child: Container(
                width: 40,
                height: 45,
                padding: EdgeInsets.all(0),
                decoration: BoxDecoration(
                  color: value.quantity == 1 || stock <= 0
                      ? Colors.grey.shade300
                      : lightGrayBlack,
                  shape: BoxShape.circle,
                ),
                child: headingFont(
                  text: "-",
                  weight: FontWeight.bold,
                  color: value.quantity == 1 || stock <= 0 ? grayBlack : white,
                ),
              ),
            ),
            const SizedBox(width: 10),
            mediumFont(
              text: value.quantity.toString(),
              color: isDarkMode ? white : grayBlack,
              weight: FontWeight.bold,
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: value.quantity == 10 || value.quantity >= stock
                  ? null
                  : () {
                value.addValue();
              },
              child: Container(
                width: 40,
                height: 45,
                padding: EdgeInsets.all(0),
                decoration: BoxDecoration(
                  color: value.quantity == 10 || value.quantity >= stock
                      ? Colors.grey.shade300
                      : lightGrayBlack,
                  shape: BoxShape.circle,
                ),
                child: headingFont(
                  text: "+",
                  weight: FontWeight.bold,
                  color: value.quantity == 10 || value.quantity >= stock
                      ? grayBlack
                      : white,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  bool _isItemAlreadyInCart(ClothingProductModel productDetails) {
    final cartProvider = context.read<CartProvider>();
    final productDetailsProvider = context.read<ProductDetailsProvider>();

    for (int i = 0; i < cartProvider.cartItems.length; ++i) {
      if (cartProvider.cartItems[i].id.contains(productDetails.id) &&
          productDetailsProvider.quantity == cartProvider.cartItems[i].pieces) {
        return true;
      }
    }
    return false;
  }

  void _addProductToCart(ClothingProductModel productDetails) async {
    final productDetailsProvider = context.read<ProductDetailsProvider>();
    final cartProvider = context.read<CartProvider>();

    final int totalPrice = (productDetailsProvider.quantity *
        ((productDetails.price / 100) * (100 - productDetails.discount)))
        .toInt();
    final cartProduct = CartProducts(
      id: productDetails.id,
      pieces: productDetailsProvider.quantity,
      total: totalPrice.toString(),
      title: productDetails.title,
      price: productDetails.price,
      discount: productDetails.discount,
      size: productDetails
          .variants[0].sizes[productDetailsProvider.selectedSize].size,
      photoUrl: productDetails.images,
      colorHex: productDetails
          .variants[0].colors[productDetailsProvider.selectedColor],
      category: productDetails.category,
      gender: productDetails.gender,
    );

    cartProvider.addProductToCart(cartProduct);
    cartProvider.storeClothsList(cartProduct);
    productDetailsProvider.resetQuantity();
    if (currentUser != null) {
      trackPersonalization(
          currentUser.uid, widget.category, "cart", 'increment');
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => BottomNavBar()),
    );
  }

  void _showItemAlreadyInCartSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: smallFont(text: "Item is Already in the Cart")),
    );
  }

  Widget _buttonContent({
    required bool isDarkMode,
    required ClothingProductModel productDetails,
  }) {
    return Consumer<ProductDetailsProvider>(builder: (context, value, child) {
      final selectedSize = value.selectedSize;
      final stock = productDetails.variants[0].sizes[selectedSize].stock;
      return stock == 0
          ? Container(
        width: MediaQuery
            .of(context)
            .size
            .width,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 40),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey,
        ),
        child: mediumFont(
          text: "Out of Stock",
          color: isDarkMode ? grayBlack : white,
        ),
      )
          : Row(
        children: [
          InkWell(
            onTap: stock == 0
                ? null
                : () async {
              bool isAlreadyInCart =
              _isItemAlreadyInCart(productDetails);

              if (!isAlreadyInCart) {
                _addProductToCart(productDetails);
              } else {
                _showItemAlreadyInCartSnackbar();
              }
            },
            child: Container(
              margin:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              padding: const EdgeInsets.symmetric(
                  vertical: 10, horizontal: 40),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: isDarkMode ? white : grayBlack,
              ),
              child: mediumFont(
                text: "Add to Cart",
                color: isDarkMode ? grayBlack : white,
              ),
            ),
          ),
          InkWell(
            onTap: stock == 0
                ? null
                : () async {
              bool isAlreadyInCart =
              _isItemAlreadyInCart(productDetails);

              if (!isAlreadyInCart) {
                // _addProductToCart(productDetails);
                _buyNow(productDetails);
              }
            },
            child: Container(
              margin:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              padding: const EdgeInsets.symmetric(
                  vertical: 10, horizontal: 40),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: isDarkMode
                      ? [lightOrange, darkOrange]
                      : [lightPurple, lightBlue],
                ),
              ),
              child: mediumFont(
                text: "Buy Now",
                color: white,
              ),
            ),
          ),
        ],
      );
    });
  }

  void _buyNow(ClothingProductModel productDetails) async {
    final provider = context.read<ProductDetailsProvider>();
    final cartProvider = context.read<CartProvider>();
    final user = FirebaseAuth.instance.currentUser;
    context.read<UserDetailsProvider>().fetchUserDetails();

    final cartProduct = CartProducts(
      id: productDetails.id,
      pieces: provider.quantity,
      total: (provider.quantity *
          ((productDetails.price / 100) * (100 - productDetails.discount)))
          .toInt()
          .toString(),
      title: productDetails.title,
      price: productDetails.price,
      discount: productDetails.discount,
      size: productDetails.variants[0].sizes[provider.selectedSize].size,
      gender: productDetails.gender,
      category: productDetails.category,
      photoUrl: productDetails.images,
      colorHex: productDetails.variants[0].colors[provider.selectedColor],
    );

    cartProvider.addProductToCart(cartProduct);
    cartProvider.storeClothsList(cartProduct);
    provider.resetQuantity();
    // Track personalization
    // if (user != null) {
    //   trackPersonalization(user.uid, widget.category, "order", 'increment');
    // }

    // Navigate directly to OrderDetails with single item
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            OrderDetails(
              itemsToCheckout: [cartProduct],
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider
        .of<DarkModeProvider>(context)
        .isDarkMode;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("Cloths")
          .doc(widget.gender)
          .collection(widget.category)
          .doc(widget.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: isDarkMode ? grayBlack : white,
            appBar: _productDetailsAppbar(isDarkMode: isDarkMode),
            body: Center(child: Text("Error loading product details")),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return productDetailsShimmer(
              context: context, isDarkMode: isDarkMode);
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            backgroundColor: isDarkMode ? grayBlack : white,
            appBar: _productDetailsAppbar(isDarkMode: isDarkMode),
            body: Center(child: Text("No data available")),
          );
        }

        final data = snapshot.data!.data();
        if (data is! Map<String, dynamic>) {
          return Center(child: Text("Invalid data format"));
        }

        final productDetails = ClothingProductModel.fromMap(data);
        _preloadARResources(productDetails);
        return Scaffold(
          bottomSheet: Container(
            height: MediaQuery
                .of(context)
                .size
                .height * .15,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDarkMode ? lightGrayBlack : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _quantityCounter(
                  isDarkMode: isDarkMode,
                  productDetails: productDetails,
                ),
                _buttonContent(
                  isDarkMode: isDarkMode,
                  productDetails: productDetails,
                ),
              ],
            ),
          ),
          backgroundColor: isDarkMode ? grayBlack : white,
          appBar: _productDetailsAppbar(isDarkMode: isDarkMode),
          body: _productDetailsBody(isDarkMode: isDarkMode),
        );
      },
    );
  }
}
