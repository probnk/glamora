import 'package:buttons_tabbar/buttons_tabbar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:glamora/Reuse%20Widgets/ProductCard.dart';
import 'package:glamora/Reuse%20Widgets/imagesFunctionCall.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:glamora/providers/HomeProvider.dart';
import 'package:glamora/providers/ProductListProvider.dart';
import 'package:glamora/providers/WishListProvider.dart';
import 'package:glamora/screens/Product%20Details/ProductDetails.dart';
import 'package:glamora/screens/UserProfile/UserProfile.dart';
import 'package:glamora/screens/home/Notification%20Details/NotificationDetails.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconly/iconly.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../Services/notificationService.dart';

class HomeScreen extends StatefulWidget {
  HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  NotificationService notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    context.read<HomeProvider>().fetchImagesList();
    context.read<ProductListProvider>().fetchSerumList();
    context.read<WishListProvider>().fetchSerumList();
    notificationService.requestNotificationPermission();
    notificationService.getDeviceToken();
    notificationService.firebaseInit(context);
    notificationService.setupInteractMessage(context);
  }

  _customizableEffect() {
    final themeProvider = Provider.of<DarkModeProvider>(context);
    return CustomizableEffect(
      dotDecoration: DotDecoration(
          color: themeProvider.isDarkMode ? Colors.grey : Colors.grey.shade300,
          width: 10,
          height: 10),
      activeDotDecoration: DotDecoration(
          color: themeProvider.isDarkMode ? white : grayBlack,
          width: 16,
          height: 16,
          rotationAngle: 45),
    );
  }

  _homePageAppbar() {
    final themeProvider = Provider.of<DarkModeProvider>(context);
    return AppBar(
      backgroundColor: themeProvider.isDarkMode ? lightGrayBlack : white,
      centerTitle: true,
      iconTheme: IconThemeData(
        color: themeProvider.isDarkMode ? white : lightGrayBlack,
      ),
      title: titleFont(
          text: "Glamora",
          color: themeProvider.isDarkMode ? white : lightGrayBlack),
      actions: [
        Card(
          elevation: 3,
          margin: EdgeInsets.symmetric(horizontal: 16),
          color: themeProvider.isDarkMode
              ? Colors.grey.shade800
              : Colors.grey.shade100,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          child: IconButton(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => NotificationDetails()));
              },
              icon: Icon(IconlyLight.notification)),
        ),
      ],
    );
  }

  _homePageBody() {
    return ListView(
      shrinkWrap: true,
      physics: ScrollPhysics(),
      children: [
        _bannerCarousel(),
        _newArrivalProducts(),
        Catagories(),
        Items()
      ],
    );
  }

  bannerItem(String image) {
    return Column(
      children: [
        SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: image,
            height: 165,
            width: double.infinity,
            fit: BoxFit.fill,
            placeholder: (context, url) => Center(
              child: CircularProgressIndicator(color: white),
            ),
            errorWidget: (context, url, error) =>
                Center(child: Icon(Icons.error, color: darkRed)),
          ),
        ),
      ],
    );
  }

  _bannerCarousel() {
    return Consumer<HomeProvider>(builder: (context,value,child){
      return value.productPhotoUrls.isEmpty ? Center(child: CircularProgressIndicator(color: grayBlack)) : Stack(
        alignment: Alignment.bottomCenter,
        children: [
          CarouselSlider(
            items: [
              for (int i = 0; i < value.productPhotoUrls.length; i++) bannerItem(value.productPhotoUrls[i])
            ],
            options: CarouselOptions(
              height: 210,
              enlargeCenterPage: true,
              autoPlay: true,
              autoPlayCurve: Curves.fastOutSlowIn,
              enableInfiniteScroll: true,
              autoPlayAnimationDuration: Duration(milliseconds: 800),
              viewportFraction: .85,
              initialPage: context.read<HomeProvider>().activeIndex,
              onPageChanged: (index, reason) {
                // Update the active index when the page changes
                context.read<HomeProvider>().setActiveIndex(index);
              },
            ),
          ),
          AnimatedSmoothIndicator(
            activeIndex: context.read<HomeProvider>().activeIndex,
            count: value.productPhotoUrls.length,
            effect: _customizableEffect(),
            onDotClicked: (index) {
              // You can implement behavior when a dot is clicked, if desired
              context.read<HomeProvider>().setActiveIndex(index);
            },
          ),
        ],
      );
    });
  }


  _newArrivalProducts() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titleText(title: "New Arrival", subTitle: "See all"),
          SizedBox(height: 10),
          _saleMobileAdBanner(),
          SizedBox(height: 10),
          newArrivalSerumList(),
          SizedBox(height: 10),
          _saleMobileAdBanner(),
          SizedBox(height: 10),
          _titleText(title: "Best Seller", subTitle: "See all"),
        ],
      ),
    );
  }

  _saleMobileAdBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        "assets/images/sales.png",
        height: 50,
        width: MediaQuery.of(context).size.width,
        fit: BoxFit.fill,
      ),
    );
  }

  _titleText({required String title, required String subTitle}) {
    final themeProvider = Provider.of<DarkModeProvider>(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        titleFont(
            text: title, color: themeProvider.isDarkMode ? white : grayBlack),
        smallFont(text: subTitle, color: Colors.grey)
      ],
    );
  }

  _bestSellerItems() {
    final themeProvider = Provider.of<DarkModeProvider>(context);
    return Consumer<ProductListProvider>(builder: (context, value, child) {
      return value.serumList.isEmpty ? Center(child: CircularProgressIndicator(color: grayBlack,),) : ListView.builder(
          itemCount: 3,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            return Container(
              margin: EdgeInsets.all(10),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: themeProvider.isDarkMode
                          ? Colors.transparent : Colors.grey.shade200),
                  color: themeProvider.isDarkMode ? lightGrayBlack : white),
              child: Stack(
                children: [
                  Row(
                    children: [
                      SizedBox(width: 6),
                      Container(
                        height: 100,
                        width: 100,
                        child:   networkImagesCache(url: value.serumList[index].photoUrl[0]),
                      ),
                      SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            constraints: BoxConstraints(
                                maxWidth:
                                MediaQuery.of(context).size.width * .5),
                            child: productTitle(
                                text: value.serumList[index].title,
                                color: themeProvider.isDarkMode
                                    ? white
                                    : grayBlack),
                          ),
                          smallFont(text: "Face Serum", color: Colors.grey),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  productTitle(
                                      text: value.rating.toString(),
                                      color: themeProvider.isDarkMode
                                          ? white
                                          : grayBlack),
                                  SizedBox(width: 3),
                                  Icon(
                                    Icons.star_rounded,
                                    color: Colors.yellow.shade700,
                                    size: 20,
                                  ),
                                ],
                              ),
                              SizedBox(width: 45),
                              smallFont(
                                  text:
                                  'Sold: ${value.serumList[index].totalOrders}🔥',
                                  color: Colors.grey)
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  productTitle(
                                      text:
                                      "Rs ${value.serumList[index].newPrice}",
                                      color: themeProvider.isDarkMode
                                          ? white
                                          : grayBlack),
                                  SizedBox(width: 5),
                                  smallFont(
                                      text:
                                      "Rs ${value.serumList[index].oldPrice}",
                                      color: darkRed,
                                      isDiscounted: true,
                                      weight: FontWeight.w600),
                                ],
                              ),
                            ],
                          )
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    bottom: 0,
                    right: 20,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => ProductDetails(
                                    serumDetails: value.serumList[index],
                                    index: index)));
                      },
                      child: Container(
                        padding: EdgeInsets.all(3),
                        margin: EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: themeProvider.isDarkMode
                                  ? white
                                  : Colors.grey),
                        ),
                        child: Icon(
                          IconlyLight.arrow_right,
                          color: themeProvider.isDarkMode ? white : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  Consumer<WishListProvider>(builder: (context, wishListProvider, child) {
                    bool isFound = false;
                    // Check if the product is in the wishlist
                    for (int i = 0; i < wishListProvider.wishListProducts.length; i++) {
                      if (wishListProvider.wishListProducts[i].title == value.serumList[index].title) {
                        isFound = true;
                        break;
                      }
                    }

                    return Positioned(
                      top: 0,
                      right: 10,
                      child: Container(
                        child: IconButton(
                          onPressed: () {
                            if (!isFound) {
                              // Add to wishlist
                              wishListProvider.addWishListItem(value.serumList[index]);
                              wishListProvider.storeSerumList(value.serumList[index]);
                            } else {
                              // Remove from wishlist
                              wishListProvider.removeWishListItems(value.serumList[index].title);
                              wishListProvider.deleteWishListItem(value.serumList[index].title);
                            }
                          },
                          icon: isFound
                              ? Icon(IconlyBold.heart, color: lightRed)
                              : Icon(IconlyLight.heart, color: Colors.grey.shade300),
                        ),
                      ),
                    );
                  })
                ],
              ),
            );
          });
    });
  }

  Catagories() {
    final themeProvider = Provider.of<DarkModeProvider>(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 5, right: 5),
      child: ButtonsTabBar(
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
          unselectedBackgroundColor:
          themeProvider.isDarkMode ? lightGrayBlack : Colors.white,
          height: 50,
          labelStyle: GoogleFonts.exo2(
              color: white, fontSize: 20, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.exo2(
              color: themeProvider.isDarkMode ? white : grayBlack,
              fontSize: 20),
          tabs: [
            Tab(text: 'All'),
            Tab(text: 'Serum'),
          ]),
    );
  }

  Items() {
    return SizedBox(
        height: 400,
        child: TabBarView(children: [_bestSellerItems(), _bestSellerItems()]));
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<DarkModeProvider>(context);
    return Scaffold(
      backgroundColor: themeProvider.isDarkMode ? grayBlack : white,
      appBar: _homePageAppbar(),
      body: DefaultTabController(
        length: 2,
        child: _homePageBody(),
      ),
      drawer: UserProfile(),
    );
  }
}