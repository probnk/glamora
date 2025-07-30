import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:glamora/Reuse%20Widgets/ProductCard.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/providers/CartProvider.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:glamora/providers/HistoryProvider.dart';
import 'package:glamora/providers/HomeProvider.dart';
import 'package:glamora/providers/NotificationDetailsProvider.dart';
import 'package:glamora/providers/ProductListProvider.dart';
import 'package:glamora/providers/RatingProvider.dart';
import 'package:glamora/providers/UserDetailsProvider.dart';
import 'package:glamora/providers/WishListProvider.dart';
import 'package:glamora/screens/Live%20Chat%20Support/MessagingScreen.dart';
import 'package:glamora/screens/Login/Login.dart';
import 'package:glamora/screens/UserProfile/UserProfile.dart';
import 'package:glamora/screens/home/Notification%20Details/NotificationDetails.dart';
import 'package:iconly/iconly.dart';
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
  var currentUser;

  @override
  void initState() {
    super.initState();
    currentUser = FirebaseAuth.instance.currentUser;
    context.read<HomeProvider>().fetchImagesList();
    context.read<ProductListProvider>().fetchClothsList();
    context.read<WishListProvider>().fetchClothsList();
    if(currentUser != null){
      notificationService.requestNotificationPermission();
      notificationService.getDeviceToken();
      notificationService.firebaseInit(context);
      notificationService.setupInteractMessage(context);
      FirebaseMessaging.instance.subscribeToTopic(currentUser.uid);
    }
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

  _commonActionButton(
      {required bool isDarkMode, required IconData icon, required Function() onPressed}) {
    return Card(
      elevation: 3,
      margin: EdgeInsets.symmetric(horizontal: 16),
      color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon)),
    );
  }

  _homePageAppbar({required var currentUser}) {
    final themeProvider = Provider.of<DarkModeProvider>(context);
    return AppBar(
        backgroundColor: themeProvider.isDarkMode ? lightGrayBlack : white,
        centerTitle: true,
        iconTheme: IconThemeData(
          color: themeProvider.isDarkMode ? white : lightGrayBlack,
        ),
        title: titleFont(
            text: "Vision Cart",
            color: themeProvider.isDarkMode ? white : lightGrayBlack),
        actions: currentUser != null ? [_commonActionButton(
            isDarkMode: themeProvider.isDarkMode,
            icon: IconlyBold.message,
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => MessagingScreen()));
            },)] :[_commonActionButton(
          isDarkMode: themeProvider.isDarkMode,
          icon: IconlyLight.logout,
          onPressed: () {
            context.read<CartProvider>().cartItems.clear();
            context.read<HistoryProvider>().historyModelList.clear();
            context.read<NotificationDetailsProvider>().notificationDetails.clear();
            context.read<RatingProvider>().ratingList.clear();
            context.read<UserDetailsProvider>().clearUserDetails();
            context.read<WishListProvider>().wishListProducts.clear();
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => Login()));
          },)]
    );
  }

  _homePageBody() {
    return ListView(
      shrinkWrap: true,
      physics: ScrollPhysics(),
      children: [
        _bannerCarousel(),
        _newArrivalProducts(),
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
            placeholder: (context, url) =>
                Center(
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
    return Consumer<HomeProvider>(builder: (context, value, child) {
      return value.productPhotoUrls.isEmpty
          ? Center(child: CircularProgressIndicator(color: grayBlack))
          : Stack(
        alignment: Alignment.bottomCenter,
        children: [
          CarouselSlider(
            items: [
              for (int i = 0; i < value.productPhotoUrls.length; i++)
                bannerItem(value.productPhotoUrls[i])
            ],
            options: CarouselOptions(
              height: 210,
              enlargeCenterPage: true,
              autoPlay: true,
              autoPlayCurve: Curves.fastOutSlowIn,
              enableInfiniteScroll: true,
              autoPlayAnimationDuration: Duration(milliseconds: 800),
              viewportFraction: .85,
              initialPage: context
                  .read<HomeProvider>()
                  .activeIndex,
              onPageChanged: (index, reason) {
                // Update the active index when the page changes
                context.read<HomeProvider>().setActiveIndex(index);
              },
            ),
          ),
          AnimatedSmoothIndicator(
            activeIndex: context
                .read<HomeProvider>()
                .activeIndex,
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
          newArrivalSerumList(currentUser: currentUser),
          SizedBox(height: 10),
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
        width: MediaQuery
            .of(context)
            .size
            .width,
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


  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<DarkModeProvider>(context);
    return Scaffold(
      backgroundColor: themeProvider.isDarkMode ? grayBlack : white,
      appBar: _homePageAppbar(currentUser: currentUser),
      body: _homePageBody(),
      drawer:currentUser != null ? UserProfile() : null,
    );
  }
}
