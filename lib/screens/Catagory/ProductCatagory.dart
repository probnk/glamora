import 'package:buttons_tabbar/buttons_tabbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:glamora/Reuse%20Widgets/LimitedStock.dart';
import 'package:glamora/Reuse%20Widgets/imagesFunctionCall.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/models/productModel.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:glamora/providers/ProductListProvider.dart';
import 'package:glamora/providers/WishListProvider.dart';
import 'package:glamora/screens/Product%20Details/ProductDetails.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconly/iconly.dart';
import 'package:provider/provider.dart';

class ProductCatagory extends StatefulWidget {
  const ProductCatagory({super.key});

  @override
  State<ProductCatagory> createState() => _ProductCatagoryState();
}

class _ProductCatagoryState extends State<ProductCatagory>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  _productCategoryAppbar({required bool isDarkMode}) {
    return AppBar(
      backgroundColor: isDarkMode ? lightGrayBlack : white,
      centerTitle: true,
      title:
          titleFont(text: "Categories", color: isDarkMode ? white : grayBlack),
    );
  }

  _categoryBody({required bool isDarkMode}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Catagories(isDarkMode: isDarkMode),
        Expanded(child: Items(isDarkMode: isDarkMode)),
      ],
    );
  }

  _serumList({required bool isDarkMode}) {
    return Consumer<ProductListProvider>(builder: (context, value, child) {
      return MasonryGridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        itemCount: value.serumList.length,
        itemBuilder: (context, index) {
          return _serumDesign(
              serum: value.serumList[index],
              index: index,
              isDarkMode: isDarkMode);
        },
      );
    });
  }

  _serumDesign(
      {required Serum serum, required int index, required bool isDarkMode}) {
    return Stack(
      children: [
        InkWell(
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        ProductDetails(serumDetails: serum, index: index)));
          },
          child: Card(
            color: isDarkMode ? lightGrayBlack : white,
            elevation: 3,
            margin: EdgeInsets.all(8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Image.asset("assets/images/discount.png",
                          width: 40, height: 30, fit: BoxFit.contain),
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              color: Colors.yellow.shade700),
                          smallFont(
                              text: serum.reviews.length.toString(),
                              color: isDarkMode ? white : grayBlack,
                              weight: FontWeight.w600)
                        ],
                      )
                    ],
                  ),
                 networkImagesCache(url: serum.photoUrl[0]),
                  Row(
                    children: [
                      productTitle(
                          text: "Rs ${serum.newPrice}",
                          color: isDarkMode ? white : grayBlack),
                      SizedBox(width: 10),
                      productTitle(
                          text: "Rs ${serum.oldPrice}",
                          isDiscounted: true,
                          color: lightRed)
                    ],
                  ),
                  productTitle(
                      text: "${serum.title}",
                      color: isDarkMode ? white : Colors.grey.shade700,
                      maxWidth: 100),
                  smallFont(text: "Face Serum", color: Colors.grey.shade400),
                  limitedStock(context: context),
                  SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 70,
          right: 5,
          child: Consumer<WishListProvider>(
            builder: (context, value, child) {
              bool isFound = false;
              // Check if the product is in the wishlist
              for (int i = 0; i < value.wishListProducts.length; i++) {
                if (value.wishListProducts[i].title == serum.title) {
                  isFound = true;
                  break;
                }
              }

              return IconButton(
                onPressed: () {
                  if (!isFound) {
                    // Add to wishlist
                    value.addWishListItem(serum);
                    value.storeSerumList(serum);
                  } else {
                    // Remove from wishlist
                    value.removeWishListItems(serum.title);
                    value.deleteWishListItem(serum.title);
                  }
                },
                icon: Icon(
                  isFound ? IconlyBold.heart : IconlyLight.heart,
                  color: lightRed,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Catagories({required bool isDarkMode}) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 5, right: 5),
      child: ButtonsTabBar(
          controller: _tabController,
          splashColor: lightBlue4,
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [lightBlue, lightPurple])),
          physics: ClampingScrollPhysics(),
          elevation: 0,
          radius: 10,
          contentCenter: true,
          contentPadding: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          unselectedBackgroundColor: isDarkMode ? lightGrayBlack : white,
          labelStyle: GoogleFonts.exo2(
              color: white, fontSize: 20, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.exo2(
              color: isDarkMode ? white : grayBlack, fontSize: 20),
          tabs: [
            Tab(text: 'All'),
            Tab(text: 'Serum'),
          ]),
    );
  }

  Items({required bool isDarkMode}) {
    return TabBarView(
      controller: _tabController,
      children: [
        _serumList(isDarkMode: isDarkMode),
        _serumList(isDarkMode: isDarkMode),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<DarkModeProvider>(context);
    return Scaffold(
      backgroundColor:
          themeProvider.isDarkMode ? grayBlack : Colors.grey.shade50,
      appBar: _productCategoryAppbar(isDarkMode: themeProvider.isDarkMode),
      body: _categoryBody(isDarkMode: themeProvider.isDarkMode),
    );
  }
}
