import 'package:flutter/material.dart';
import 'package:glamora/Reuse%20Widgets/imagesFunctionCall.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/models/cartProducts.dart';
import 'package:glamora/models/productModel.dart';
import 'package:glamora/providers/CartProvider.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:glamora/providers/ProductDetailsProvider.dart';
import 'package:glamora/providers/WishListProvider.dart';
import 'package:glamora/screens/MyCart/MyCart.dart';
import 'package:glamora/screens/Rating/Rating.dart';
import 'package:iconly/iconly.dart';
import 'package:provider/provider.dart';

class ProductDetails extends StatefulWidget {
  final Serum serumDetails;
  final int index;

  const ProductDetails(
      {super.key, required this.serumDetails, required this.index});

  @override
  State<ProductDetails> createState() => _ProductDetailsState();
}

class _ProductDetailsState extends State<ProductDetails> {
  @override
  void initState() {
    super.initState();
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
                  color: Colors.grey.shade50,
                  child: Center(
                    child: PageView.builder(
                      itemCount: widget.serumDetails.photoUrl.length,
                      onPageChanged: (index) {
                        value.setSelectedImage(index);
                      },
                      itemBuilder: (context, index) {
                        return networkImagesCache(
                            url: widget.serumDetails.photoUrl[index],
                            height: MediaQuery.of(context).size.height * .4,
                            width: MediaQuery.of(context).size.width);
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
              text: widget.serumDetails.title,
              color: isDarkMode ? white : grayBlack,
              align: TextAlign.start,
              weight: FontWeight.w500),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  mediumFont(
                      text: "Face Serum",
                      color: Colors.grey,
                      align: TextAlign.start,
                      weight: FontWeight.w400),
                  SizedBox(width: 20),
                  mediumFont(
                      text: widget.serumDetails.dimensions, color: Colors.grey)
                ],
              ),
              Consumer<WishListProvider>(builder: (context, value, child) {
                bool isFound = false;
                for (int i = 0; i < value.wishListProducts.length; i++) {
                  if (value.wishListProducts[i].title
                      .contains(widget.serumDetails.title)) {
                    isFound = true;
                    break;
                  }
                }
                return InkWell(
                  onTap: () {
                    if (!isFound) {
                      value.addWishListItem(widget.serumDetails);
                      value.storeSerumList(widget.serumDetails);
                    } else {
                      value.deleteWishListItem(
                          value.wishListProducts[widget.index].title);
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
            children: [
              productTitle(
                  text: "Rs ${widget.serumDetails.newPrice}",
                  color: isDarkMode ? white : grayBlack),
              SizedBox(width: 10),
              productTitle(
                  text: "Rs ${widget.serumDetails.oldPrice}",
                  isDiscounted: true,
                  color: lightRed)
            ],
          ),
          SizedBox(height: 10),
          InkWell(
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => Rating()));
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
                        productTitle(text: "4.5 Rating")
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
              title: "Description", subTitle: widget.serumDetails.description, isDarkMode:isDarkMode),
          _productDescriptionFonts(
              title: "Features", subTitle: widget.serumDetails.features, isDarkMode:isDarkMode),
          _productDescriptionFonts(
              title: "Usage", subTitle: widget.serumDetails.usage, isDarkMode:isDarkMode),
          _productDescriptionFonts(
              title: "Dimensions", subTitle: widget.serumDetails.dimensions, isDarkMode:isDarkMode),
          SizedBox(height: 20),
          _quantityCounter(isDarkMode: isDarkMode),
          SizedBox(height: 60),
        ],
      ),
    );
  }

  _productDescriptionFonts({required String title, required String subTitle, required bool isDarkMode}) {
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
    return Row(
      children: [
        Container(
            padding: EdgeInsets.all(3),
            decoration: BoxDecoration(
                color: isDarkMode ? lightGrayBlack : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20)),
            child: Consumer<ProductDetailsProvider>(
                builder: (context, value, child) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: value.quantity == 1
                            ? null
                            : () {
                                value.subtractValue();
                              },
                        child: Container(
                          width: 40,
                          height: 45,
                          padding: EdgeInsets.all(0),
                          decoration: BoxDecoration(
                              color: value.quantity == 1
                                  ? Colors.grey.shade300
                                  : grayBlack,
                              shape: BoxShape.circle),
                          child:
                              headingFont(text: "-", weight: FontWeight.bold),
                        ),
                      ),
                      SizedBox(width: 10),
                      mediumFont(
                          text: value.quantity.toString(),
                          color: isDarkMode ? white : grayBlack,
                          weight: FontWeight.bold),
                      SizedBox(width: 10),
                      InkWell(
                        onTap: value.quantity == 10
                            ? null
                            : () {
                                value.addValue();
                              },
                        child: Container(
                          width: 40,
                          height: 45,
                          padding: EdgeInsets.all(0),
                          decoration: BoxDecoration(
                              color: value.quantity == 10
                                  ? Colors.grey.shade300
                                  : grayBlack,
                              shape: BoxShape.circle),
                          child:
                              headingFont(text: "+", weight: FontWeight.bold),
                        ),
                      )
                    ],
                  ),
                  SizedBox(width: 40),
                  mediumFont(
                      text: "Save RS ${value.quantity * 800}",
                      color: Colors.green,
                      maxWidth: 150),
                  SizedBox(width: 20),
                ],
              );
            }))
      ],
    );
  }

  _button({required bool isDarkMode}) {
    return Container(
      width: MediaQuery.of(context).size.width,
      decoration: BoxDecoration(
        color: isDarkMode ? lightGrayBlack : white,
      ),
      margin: EdgeInsets.zero,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
            backgroundColor: isDarkMode ? lightGrayBlack : Colors.grey.shade50,
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(vertical: 8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        onPressed: () {
          bool isAlreadyInCart = false;
          for (int i = 0;
              i < context.read<CartProvider>().cartItems.length;
              ++i) {
            if (context
                .read<CartProvider>()
                .cartItems[i]
                .title
                .contains(widget.serumDetails.title)) {
              isAlreadyInCart = true;
              break;
            }
          }
          if (!isAlreadyInCart) {
            final quantity = context.read<ProductDetailsProvider>().quantity;
            final totalPrice =
                quantity * int.parse(widget.serumDetails.newPrice.toString());
            final data = CartProducts(
                pieces: quantity.toString(),
                total: totalPrice.toString(),
                title: widget.serumDetails.title,
                description: widget.serumDetails.description,
                features: widget.serumDetails.features,
                usage: widget.serumDetails.usage,
                oldPrice: widget.serumDetails.oldPrice,
                newPrice: widget.serumDetails.newPrice,
                discount: widget.serumDetails.discount,
                stock: widget.serumDetails.stock,
                totalOrders: widget.serumDetails.totalOrders,
                reviews: widget.serumDetails.reviews,
                photoUrl: widget.serumDetails.photoUrl,
                dimensions: widget.serumDetails.dimensions);
            context.read<CartProvider>().addProductToCart(data);
            context.read<CartProvider>().storeSerumList(data);
            context.read<ProductDetailsProvider>().resetQuantity();
            Navigator.push(
                context, MaterialPageRoute(builder: (context) => MyCart()));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: smallFont(text: "Item is Already in the Cart")));
          }
        },
        child: Container(
            width: MediaQuery.of(context).size.width * .7,
            margin: EdgeInsets.only(bottom: 7),
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 40),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors:
                        isDarkMode ? [lightOrange,darkOrange] : [lightBlack, darkBlack])),
            child: mediumFont(
                text: "Add to Cart", color: white)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<DarkModeProvider>(context);
    return Scaffold(
      bottomSheet: _button(isDarkMode: themeProvider.isDarkMode),
      backgroundColor: themeProvider.isDarkMode ? grayBlack : white,
      appBar: _productDetailsAppbar(isDarkMode: themeProvider.isDarkMode),
      body: _productDetailsBody(isDarkMode: themeProvider.isDarkMode),
    );
  }
}
