import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:glamora/Reuse%20Widgets/imagesFunctionCall.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
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
import 'package:provider/provider.dart';

class ProductDetails extends StatefulWidget {
  final ClothingProductModel clothDetails;
  final int index;

  const ProductDetails(
      {super.key, required this.clothDetails, required this.index});

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

  _productDetailsAppbar({required bool isDarkMode}) {
    return AppBar(
      backgroundColor: isDarkMode ? lightGrayBlack : Colors.grey.shade50,
      centerTitle: true,
      title: titleFont(
          text: "Product Details", color: isDarkMode ? white : grayBlack),
      iconTheme: IconThemeData(color: isDarkMode ? white : grayBlack),
    );
  }

  _selectedText({required String text, required bool isDarkMode}) {
    return mediumFont(
        text: text,
        color: isDarkMode ? white : grayBlack,
        weight: FontWeight.w800,
        maxWidth: MediaQuery
            .of(context)
            .size
            .width * .2);
  }

  _productDetailsBody({required bool isDarkMode}) {
    return ListView(
      shrinkWrap: true,
      physics: ScrollPhysics(),
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
                      itemCount: widget.clothDetails.images.length,
                      onPageChanged: (index) {
                        value.setSelectedImage(index);
                      },
                      itemBuilder: (context, index) {
                        return networkImagesCache(
                            url: widget.clothDetails.images[index],
                            height: MediaQuery
                                .of(context)
                                .size
                                .height * .4,
                            width: MediaQuery
                                .of(context)
                                .size
                                .width);
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        _productDetailsCard(isDarkMode: isDarkMode)
      ],
    );
  }

  _productDetailsCard({required bool isDarkMode}) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: isDarkMode ? grayBlack : white,
          borderRadius: BorderRadius.only(
              topRight: Radius.circular(20), topLeft: Radius.circular(20))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          headingFont(
              text: widget.clothDetails.title,
              color: isDarkMode ? white : grayBlack,
              align: TextAlign.start,
              weight: FontWeight.w500),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  mediumFont(
                      text: widget.clothDetails.gender,
                      color: Colors.grey,
                      align: TextAlign.start),
                  SizedBox(width: 4),
                  mediumFont(
                      text: widget.clothDetails.category, color: Colors.grey)
                ],
              ),
              Consumer<WishListProvider>(builder: (context, value, child) {
                bool isFound = false;
                var wishlistData = WishlistProducts(
                    id: widget.clothDetails.id,
                    title: widget.clothDetails.title,
                    price: widget.clothDetails.price,
                    discount: widget.clothDetails.discount,
                    images: widget.clothDetails.images,
                    category: widget.clothDetails.category,
                    gender: widget.clothDetails.gender,
                    isFav: false);
                for (int i = 0; i < value.wishListProducts.length; i++) {
                  if (value.wishListProducts[i].id
                      .contains(widget.clothDetails.id)) {
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
                      value.deleteWishListItem(widget.clothDetails.id);
                      value.removeWishListItems(widget.clothDetails.id);
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        color:
                        isDarkMode ? lightGrayBlack : Colors.grey.shade50,
                        shape: BoxShape.circle),
                    child: Icon(isFound ? IconlyBold.heart : IconlyLight.heart,
                        color: lightRed),
                  ),
                );
              })
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (widget.clothDetails.discount != 0)
                Row(
                  children: [
                    productTitle(
                        text:
                        "Rs ${((widget.clothDetails.price / 100) *
                            (100 - widget.clothDetails.discount))}",
                        color: isDarkMode ? white : grayBlack),
                    SizedBox(width: 5),
                    smallFont(
                        text: "Rs ${widget.clothDetails.price}",
                        color: darkRed,
                        isDiscounted: true,
                        weight: FontWeight.w600),
                  ],
                )
              else
                smallFont(
                    text: "Rs ${widget.clothDetails.price}",
                    color: darkRed,
                    isDiscounted: true,
                    weight: FontWeight.w600),
              smallFont(
                  text:
                  "🔥📦 Stock:${widget.clothDetails.variants[0].sizes[context
                      .watch<ProductDetailsProvider>()
                      .selectedSize].stock}",
                  color: widget
                      .clothDetails
                      .variants[0]
                      .sizes[context
                      .watch<ProductDetailsProvider>()
                      .selectedSize]
                      .stock >
                      10
                      ? lightGreen
                      : darkRed,
                  weight: FontWeight.w600)
            ],
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _selectedText(text: "Colors:", isDarkMode: isDarkMode),
              SizedBox(width: 5),
              widget.clothDetails.variants.first.colors.isNotEmpty
                  ? Expanded(
                // Use Expanded to allow it to take up available space
                child: Consumer<ProductDetailsProvider>(
                  builder: (context, selectedColor, child) {
                    return SingleChildScrollView(
                      // Wrap ListView.builder in SingleChildScrollView to allow horizontal scrolling
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(
                          widget
                              .clothDetails.variants.first.colors.length,
                              (index) {
                            final color = widget.clothDetails.variants
                                .first.colors[index];
                            final isWhiteColor = color == Colors.white;
                            final isBlackColor = color == Colors.black;

                            return InkWell(
                              onTap: () {
                                selectedColor.setSelectedColor(index);
                              },
                              child: Container(
                                margin: index > 0
                                    ? EdgeInsets.only(left: 5)
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
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _selectedText(text: "Sizes:", isDarkMode: isDarkMode),
              SizedBox(width: 5),
              widget.clothDetails.variants.first.sizes.isNotEmpty
                  ? Expanded(
                // Use Expanded to allow it to take up available space
                child: Consumer<ProductDetailsProvider>(
                  builder: (context, selectedSize, child) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(
                          widget.clothDetails.variants.first.sizes.length,
                              (index) {
                            final size = widget
                                .clothDetails.variants.first.sizes[index];
                            final isSelected =
                                selectedSize.selectedSize == index;

                            return Padding(
                              padding: index > 0
                                  ? EdgeInsets.only(left: 5)
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
                                  selectedSize.setSelectedSize(
                                      index); // Set the selected size
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
          SizedBox(height: 10),
          InkWell(
            onTap: () {
              Navigator.push(
                  context, MaterialPageRoute(builder: (context) => Rating()));
            },
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.star_rounded,
                            color: Colors.yellow.shade700, size: 20),
                        Icon(Icons.star_rounded,
                            color: Colors.yellow.shade700, size: 20),
                        Icon(Icons.star_rounded,
                            color: Colors.yellow.shade700, size: 20),
                        Icon(Icons.star_rounded,
                            color: Colors.yellow.shade700, size: 20),
                        Icon(Icons.star_half_rounded,
                            color: Colors.yellow.shade700, size: 20),
                        productTitle(
                            text:
                            "${widget.clothDetails.reviews.length
                                .toDouble()} Rating",
                            color: isDarkMode ? white : grayBlack)
                      ],
                    ),
                    smallFont(text: "See all", color: Colors.grey)
                  ],
                ),
                SizedBox(height: 10),
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  color: isDarkMode ? lightGrayBlack : white,
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
                                  backgroundImage:
                                  AssetImage("assets/images/person.png"),
                                ),
                                SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    productTitle(
                                        text: "Jhon Doe",
                                        color: isDarkMode ? white : grayBlack),
                                    smallFont(
                                        text: "18 Aug 2024",
                                        color: Colors.grey,
                                        weight: FontWeight.w600)
                                  ],
                                )
                              ],
                            ),
                            Row(
                              children: [
                                Icon(Icons.star_rounded,
                                    color: Colors.yellow.shade700, size: 20),
                                Icon(Icons.star_rounded,
                                    color: Colors.yellow.shade700, size: 20),
                                Icon(Icons.star_rounded,
                                    color: Colors.yellow.shade700, size: 20),
                                Icon(Icons.star_rounded,
                                    color: Colors.yellow.shade700, size: 20),
                                Icon(Icons.star_rounded,
                                    color: Colors.yellow.shade700, size: 20),
                              ],
                            )
                          ],
                        ),
                        SizedBox(height: 16),
                        smallFont(
                            text:
                            "Fast Delivery! Delivered in just 2 day and packaging is good and product is awesome i am using it from past 7 day",
                            color: Colors.grey,
                            align: TextAlign.start)
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
          SizedBox(height: 10),
          _productDescriptionFonts(
              title: "Description",
              subTitle: widget.clothDetails.description,
              isDarkMode: isDarkMode),
          SizedBox(height: 60),
        ],
      ),
    );
  }

  _productDescriptionFonts({required String title,
    required String subTitle,
    required bool isDarkMode}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        mediumFont(
            text: title,
            color: isDarkMode ? white : grayBlack,
            weight: FontWeight.bold,
            align: TextAlign.start),
        smallFont(text: subTitle, color: Colors.grey, align: TextAlign.start),
        SizedBox(height: 8),
      ],
    );
  }

  _quantityCounter({required bool isDarkMode}) {
    return Consumer<ProductDetailsProvider>(builder: (context, value, child) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isDarkMode ? grayBlack : white),
        child: Row(
          children: [
            InkWell(
              onTap: value.quantity == 1 ||
                  widget.clothDetails.variants[0].sizes[value.selectedSize]
                      .stock ==
                      0
                  ? null
                  : () {
                value.subtractValue();
              },
              child: Container(
                width: 40,
                height: 45,
                padding: EdgeInsets.all(0),
                decoration: BoxDecoration(
                    color: value.quantity == 1 ||
                        widget.clothDetails.variants[0]
                            .sizes[value.selectedSize].stock <=
                            0
                        ? Colors.grey.shade300
                        : lightGrayBlack,
                    shape: BoxShape.circle),
                child: headingFont(
                    text: "-",
                    weight: FontWeight.bold,
                    color: value.quantity == 1 ||
                        widget.clothDetails.variants[0]
                            .sizes[value.selectedSize].stock <=
                            0
                        ? grayBlack
                        : white),
              ),
            ),
            SizedBox(width: 10),
            mediumFont(
                text: value.quantity.toString(),
                color: isDarkMode ? white : grayBlack,
                weight: FontWeight.bold),
            SizedBox(width: 10),
            InkWell(
              onTap: value.quantity == 10 ||
                  value.quantity >=
                      widget.clothDetails.variants[0]
                          .sizes[value.selectedSize].stock
                  ? null
                  : () {
                value.addValue();
              },
              child: Container(
                width: 40,
                height: 45,
                padding: EdgeInsets.all(0),
                decoration: BoxDecoration(
                    color: value.quantity == 10 ||
                        value.quantity >=
                            widget.clothDetails.variants[0]
                                .sizes[value.selectedSize].stock
                        ? Colors.grey.shade300
                        : lightGrayBlack,
                    shape: BoxShape.circle),
                child: headingFont(
                    text: "+",
                    weight: FontWeight.bold,
                    color: value.quantity == 10 ||
                        value.quantity >=
                            widget.clothDetails.variants[0]
                                .sizes[value.selectedSize].stock
                        ? grayBlack
                        : white),
              ),
            )
          ],
        ),
      );
    });
  }

  bool _isItemAlreadyInCart() {
    final cartProvider = context.read<CartProvider>();
    for (int i = 0; i < cartProvider.cartItems.length; ++i) {
      if (cartProvider.cartItems[i].id.contains(widget.clothDetails.id) &&
          context
              .read<ProductDetailsProvider>()
              .quantity ==
              cartProvider.cartItems[i].pieces) {
        return true;
      }
    }
    return false;
  }

  void _addProductToCart() async {
    final cartProvider = context.read<ProductDetailsProvider>();

    final int totalPrice = (cartProvider.quantity *
        ((widget.clothDetails.price / 100) *
            (100 - widget.clothDetails.discount)))
        .toInt();
    final cartProduct = CartProducts(
      id: widget.clothDetails.id,
      pieces: cartProvider.quantity,
      total: totalPrice.toString(),
      title: widget.clothDetails.title,
      price: widget.clothDetails.price,
      discount: widget.clothDetails.discount,
      size:
      widget.clothDetails.variants[0].sizes[cartProvider.selectedSize].size,
      photoUrl: widget.clothDetails.images,
      colorHex:
      widget.clothDetails.variants[0].colors[cartProvider.selectedColor],
      category: widget.clothDetails.category,
      gender: widget.clothDetails.gender,
    );

    // Add to cart and store in Firestore
    context.read<CartProvider>().addProductToCart(cartProduct);
    context.read<CartProvider>().storeClothsList(cartProduct);
    // Reset quantity in the ProductDetailsProvider
    context.read<ProductDetailsProvider>().resetQuantity();
    // Navigate to cart screen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MyCart()),
    );
  }

  void _showItemAlreadyInCartSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: smallFont(text: "Item is Already in the Cart")),
    );
  }

  Widget _buttonContent(bool isDarkMode) {
    return InkWell(
      onTap: () async {
        bool isAlreadyInCart = _isItemAlreadyInCart();

        if (!isAlreadyInCart) {
          // Add the product to the cart
          _addProductToCart();
        } else {
          // Show a snackbar if the item is already in the cart
          _showItemAlreadyInCartSnackbar();
        }
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 40),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: isDarkMode
                ? [lightOrange, darkOrange]
                : [lightBlack, darkBlack],
          ),
        ),
        child: mediumFont(text: "Add to Cart", color: white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<DarkModeProvider>(context);
    return Scaffold(
      bottomSheet: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: themeProvider.isDarkMode
                ? lightGrayBlack
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _quantityCounter(isDarkMode: themeProvider.isDarkMode),
            _buttonContent(themeProvider.isDarkMode)
          ],
        ),
      ),
      backgroundColor: themeProvider.isDarkMode ? grayBlack : white,
      appBar: _productDetailsAppbar(isDarkMode: themeProvider.isDarkMode),
      body: _productDetailsBody(isDarkMode: themeProvider.isDarkMode),
    );
  }
}
