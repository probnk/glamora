import 'package:buttons_tabbar/buttons_tabbar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:glamora/Guest%20Local%20Storage/WishlistLocalStorage.dart';
import 'package:glamora/Reuse%20Widgets/LimitedStock.dart';
import 'package:glamora/Reuse%20Widgets/imagesFunctionCall.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/models/productModel.dart';
import 'package:glamora/models/wishListProducts.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:glamora/providers/ProductListProvider.dart';
import 'package:glamora/providers/RatingProvider.dart';
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
  var currentUser;

  @override
  void initState() {
    super.initState();
    currentUser = FirebaseAuth.instance.currentUser;
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

  _categoryBody({required bool isDarkMode, required var currentUser}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Catagories(isDarkMode: isDarkMode, currentUser: currentUser),
        Expanded(child: Items(isDarkMode: isDarkMode,currentUser:currentUser)),
      ],
    );
  }

  _clothList({required bool isDarkMode}) {
    return Consumer<ProductListProvider>(builder: (context, value, child) {
      return MasonryGridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 2,
        crossAxisSpacing: 1,
        itemCount: value.clothsList.length,
        itemBuilder: (context, index) {
          return _clothDesign(
              cloth: value.clothsList[index],
              index: index,
              isDarkMode: isDarkMode,
              currentUser: currentUser);
        },
      );
    });
  }

  _clothDesign(
      {required ClothingProductModel cloth,
      required int index,
      required bool isDarkMode,
      required var currentUser}) {
    double averageRating =
        context.read<RatingProvider>().calculateAverageRating();
    return Stack(
      children: [
        InkWell(
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        ProductDetails(clothDetails: cloth, index: index)));
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
                              text: averageRating.toString(),
                              color: isDarkMode ? white : grayBlack,
                              weight: FontWeight.w600)
                        ],
                      )
                    ],
                  ),
                  networkImagesCache(url: cloth.images[0]),
                  productTitle(
                      text: "${cloth.title}",
                      color: isDarkMode ? white : Colors.grey.shade700,
                      maxWidth: 80),
                  smallFont(text: cloth.category, color: Colors.grey.shade400),
                  Row(
                    children: [
                      if (cloth.discount != 0)
                        Row(
                          children: [
                            productTitle(
                                text:
                                    "Rs ${((cloth.price / 100) * (100 - cloth.discount))}",
                                color: isDarkMode ? white : grayBlack),
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
                  limitedStock(context: context),
                  SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 110,
          right: 5,
          child: Consumer<WishListProvider>(
            builder: (context, value, child) {
              bool isFound = false;
              var wishlistData = WishlistProducts(
                  id: cloth.id,
                  title: cloth.title,
                  price: cloth.price,
                  discount: cloth.discount,
                  images: cloth.images,
                  category: cloth.category,
                  gender: cloth.gender,
                  isFav: false);
              for (int i = 0; i < value.wishListProducts.length; i++) {
                if (value.wishListProducts[i].id.contains(cloth.id)) {
                  isFound = true;
                  break;
                }
              }

              return IconButton(
                onPressed: () async{
                    if (!isFound) {
                      value.addWishListItem(wishlistData);
                      value.storeClothsList(wishlistData);
                    } else {
                      value.deleteWishListItem(cloth.id);
                      value.removeWishListItems(cloth.id);
                    }
                },
                icon: Icon(
                  isFound ? IconlyBold.heart : IconlyLight.heart,
                  color: isFound ? lightRed : Colors.grey.shade400,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Catagories({required bool isDarkMode, required var currentUser}) {
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
            Tab(text: 'Man'),
          ]),
    );
  }

  Items({required bool isDarkMode, required var currentUser}) {
    return TabBarView(
      controller: _tabController,
      children: [
        _clothList(isDarkMode: isDarkMode),
        _clothList(isDarkMode: isDarkMode),
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
      body: _categoryBody(
          isDarkMode: themeProvider.isDarkMode, currentUser: currentUser),
    );
  }
}
