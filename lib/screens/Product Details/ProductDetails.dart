import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:glamora/Reuse%20Widgets/features.dart';
import 'package:glamora/Reuse%20Widgets/genderCategoryContainer.dart';
import 'package:glamora/Reuse%20Widgets/imagesFunctionCall.dart';
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
import 'package:glamora/screens/MyCart/MyCart.dart';
import 'package:glamora/screens/Rating/Rating.dart';
import 'package:iconly/iconly.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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

  @override
  void initState() {
    super.initState();
    currentUser = FirebaseAuth.instance.currentUser;
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMMM, yyyy').format(date);
  }

  String _formatTime(DateTime date) {
    return DateFormat('h:mm a').format(date);
  }

  _productDetailsAppbar({required bool isDarkMode}) {
    return AppBar(
      backgroundColor: isDarkMode ? lightGrayBlack : Colors.grey.shade50,
      centerTitle: true,
      title: titleFont(
          text: "Product Details", color: isDarkMode ? white : grayBlack),
      iconTheme: IconThemeData(color: isDarkMode ? white : grayBlack),
    );
  }

  Widget _selectedText({required String text, required bool isDarkMode}) {
    return mediumFont(
      text: text,
      color: isDarkMode ? white : grayBlack,
      weight: FontWeight.w800,
      maxWidth: MediaQuery.of(context).size.width * .2,
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
        return ListView(
          shrinkWrap: true,
          physics: const ScrollPhysics(),
          children: [
            Stack(
              alignment: Alignment.topLeft,
              children: [
                Consumer<ProductDetailsProvider>(
                  builder: (context, value, child) {
                    return Container(
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
                              width: MediaQuery.of(context).size.width,
                              height: 400,
                            );
                          },
                        ),
                      ),
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
    final screenWidth = getResponsiveWidth(MediaQuery.of(context).size.width);

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
                      isDarkMode:isDarkMode,
                      color: purple.withAlpha(100)),
                  const SizedBox(width: 4),
                  genderCategoryContainer(
                      text: productDetails.category,
                      isDarkMode: isDarkMode,
                      color: green.withAlpha(100)),
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
                  if (value.wishListProducts[i].id.contains(productDetails.id)) {
                    isFound = true;
                    break;
                  }
                }

                return InkWell(
                  onTap: () {
                    if (!isFound) {
                      value.addWishListItem(wishlistData);
                      value.storeClothsList(wishlistData);
                    } else {
                      value.deleteWishListItem(productDetails.id);
                      value.removeWishListItems(productDetails.id);
                    }
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
                      "Rs ${((productDetails.price / 100) * (100 - productDetails.discount))}",
                      color: isDarkMode ? white : grayBlack,
                    ),
                    const SizedBox(width: 5),
                    smallFont(
                      text: "Rs ${productDetails.price}",
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
                "🔥📦 Stock:${productDetails.variants[0].sizes[context.watch<ProductDetailsProvider>().selectedSize].stock}",
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
                                checkmarkColor:
                                isDarkMode ? lightGrayBlack : lightGreen,
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
                  builder: (context) => Rating(
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
                          "${_calculateAverageRating(productDetails.reviews).toStringAsFixed(1)} (${productDetails.reviews.length} reviews)",
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
                                    backgroundImage: NetworkImage(
                                        productDetails.reviews.first.profilePhoto),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                ] else ...[
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
          if(productDetails.features.isNotEmpty)
           mediumFont(text: 'Features',color: isDarkMode ? white : grayBlack,weight: FontWeight.bold),
            buildFeatureList(productDetails.features, isDarkMode, screenWidth),
          const SizedBox(height: 60),
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

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MyCart()),
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
      return InkWell(
        onTap: stock == 0
            ? null
            : () async {
          bool isAlreadyInCart = _isItemAlreadyInCart(productDetails);

          if (!isAlreadyInCart) {
            _addProductToCart(productDetails);
          } else {
            _showItemAlreadyInCartSnackbar();
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 40),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: stock == 0
                ? LinearGradient(
                colors: [Colors.grey.shade300, Colors.grey.shade300])
                : LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: isDarkMode
                  ? [lightOrange, darkOrange]
                  : [lightBlack, darkBlack],
            ),
          ),
          child: mediumFont(
            text: stock == 0 ? "Out of Stock" : "Add to Cart",
            color: stock == 0 ? grayBlack : white,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<DarkModeProvider>(context);

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
            backgroundColor: themeProvider.isDarkMode ? grayBlack : white,
            appBar: _productDetailsAppbar(
                isDarkMode: themeProvider.isDarkMode),
            body: Center(child: Text("Error loading product details")),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            backgroundColor: themeProvider.isDarkMode ? grayBlack : white,
            appBar: _productDetailsAppbar(
                isDarkMode: themeProvider.isDarkMode),
            body: Center(child: Text("No data available")),
          );
        }

        final data = snapshot.data!.data();
        if (data is! Map<String, dynamic>) {
          return Center(child: Text("Invalid data format"));
        }

        final productDetails = ClothingProductModel.fromMap(data);

        return Scaffold(
          bottomSheet: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: themeProvider.isDarkMode
                  ? lightGrayBlack
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _quantityCounter(
                  isDarkMode: themeProvider.isDarkMode,
                  productDetails: productDetails,
                ),
                _buttonContent(
                  isDarkMode: themeProvider.isDarkMode,
                  productDetails: productDetails,
                ),
              ],
            ),
          ),
          backgroundColor: themeProvider.isDarkMode ? grayBlack : white,
          appBar: _productDetailsAppbar(
              isDarkMode: themeProvider.isDarkMode),
          body: _productDetailsBody(
              isDarkMode: themeProvider.isDarkMode),
        );
      },
    );
  }

}