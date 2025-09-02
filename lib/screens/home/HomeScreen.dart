import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:glamora/Reuse%20Widgets/ProductCard.dart';
import 'package:glamora/constants/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'package:glamora/screens/Login/Login.dart';
import 'package:glamora/screens/SupportingChat.dart';
import 'package:glamora/screens/UserProfile/UserProfile.dart';
import 'package:glamora/screens/home/singleCategory.dart';
import 'package:iconly/iconly.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../Services/notificationService.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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

    // Non-problematic async calls
    context.read<HomeProvider>().fetchImagesList();
    context.read<WishListProvider>().fetchClothsList();
    if (currentUser != null) {
      notificationService.requestNotificationPermission();
      notificationService.getDeviceToken();
      notificationService.firebaseInit(context);
      notificationService.setupInteractMessage(context);
      FirebaseMessaging.instance.subscribeToTopic(currentUser.uid);
    }

    // Schedule fetchPersonalizedProducts after build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductListProvider>().fetchPersonalizedProducts();
    });
  }

  _customizableEffect() {
    final themeProvider = Provider.of<DarkModeProvider>(context);
    return CustomizableEffect(
      dotDecoration: DotDecoration(
        color: themeProvider.isDarkMode ? Colors.grey : Colors.grey.shade300,
        width: 10,
        height: 10,
      ),
      activeDotDecoration: DotDecoration(
        color: themeProvider.isDarkMode ? white : grayBlack,
        width: 16,
        height: 16,
        rotationAngle: 45,
      ),
    );
  }

  Future<void> setSkipFalse() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("skip", false);
  }

  _commonActionButton({
    required bool isDarkMode,
    required IconData icon,
    required Function() onPressed,
  }) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: IconButton(onPressed: onPressed, icon: Icon(icon)),
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
      title: headingFont(
        text: "Vision Cart",
        color: themeProvider.isDarkMode ? white : lightGrayBlack,
      ),
      actions: currentUser != null
          ? [
        _commonActionButton(
          isDarkMode: themeProvider.isDarkMode,
          icon: IconlyBold.message,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SupportHomeScreen()),
            );
          },
        )
      ]
          : [
        _commonActionButton(
          isDarkMode: themeProvider.isDarkMode,
          icon: IconlyLight.logout,
          onPressed: () {
            context.read<CartProvider>().cartItems.clear();
            context.read<HistoryProvider>().historyModelList.clear();
            context
                .read<NotificationDetailsProvider>()
                .notificationDetails
                .clear();
            context.read<RatingProvider>().ratingList.clear();
            context.read<UserDetailsProvider>().clearUserDetails();
            context.read<WishListProvider>().wishListProducts.clear();
            setSkipFalse();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const Login()),
            );
          },
        )
      ],
    );
  }

  _homePageBody() {
    return ListView(
      shrinkWrap: true,
      physics: const ScrollPhysics(),
      children: [
        _bannerCarousel(),
        _categorySection(),
        _newArrivalProducts(),
      ],
    );
  }

  Widget bannerItem(String image) {
    return Column(
      children: [
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: image,
            height: 165,
            width: double.infinity,
            fit: BoxFit.fill,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(color: white),
            ),
            errorWidget: (context, url, error) => const Center(
              child: Icon(Icons.error, color: darkRed),
            ),
          ),
        ),
      ],
    );
  }

  _bannerCarousel() {
    return Consumer<HomeProvider>(builder: (context, value, child) {
      return value.productPhotoUrls.isEmpty
          ? const Center(child: CircularProgressIndicator(color: grayBlack))
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
              autoPlayAnimationDuration: const Duration(milliseconds: 800),
              viewportFraction: 0.95,
              initialPage: context.read<HomeProvider>().activeIndex,
              onPageChanged: (index, reason) {
                context.read<HomeProvider>().setActiveIndex(index);
              },
            ),
          ),
          AnimatedSmoothIndicator(
            activeIndex: context.read<HomeProvider>().activeIndex,
            count: value.productPhotoUrls.length,
            effect: _customizableEffect(),
            onDotClicked: (index) {
              context.read<HomeProvider>().setActiveIndex(index);
            },
          ),
        ],
      );
    });
  }

  _categorySection() {
    final isDarkMode = Provider.of<DarkModeProvider>(context).isDarkMode;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleFont(
            text: "Shop by category",
            color: isDarkMode ? white : grayBlack,
            weight: FontWeight.bold,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _category(
                image: "t-shirt1",
                text: "T-Shirt",
                color: purple,
                isDarkMode: isDarkMode,
              ),
              _category(
                image: "pant",
                text: "Pant",
                color: green,
                isDarkMode: isDarkMode,
              ),
              _category(
                image: "hoodie",
                text: "Hoodie",
                color: lightOrange,
                isDarkMode: isDarkMode,
              ),
            ],
          ),
        ],
      ),
    );
  }

  _category({
    required String image,
    required String text,
    required Color color,
    required bool isDarkMode,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SingleCategory(category: text),
          ),
        );
      },
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: color,
            radius: 35,
            backgroundImage: AssetImage("assets/images/$image.png"),
          ),
          const SizedBox(height: 5),
          smallFont(
            text: "${text}s",
            color: isDarkMode ? white : grayBlack,
            weight: FontWeight.bold,
          ),
        ],
      ),
    );
  }

  _newArrivalProducts() {
    final isDarkMode = Provider.of<DarkModeProvider>(context).isDarkMode;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleFont(
            text: 'Recommended Cloths',
            color: isDarkMode ? white : grayBlack,
          ),
          const SizedBox(height: 10),
          newArrivalSerumList(currentUser: currentUser),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<DarkModeProvider>(context);
    return Scaffold(
      backgroundColor: themeProvider.isDarkMode ? grayBlack : white,
      appBar: _homePageAppbar(currentUser: currentUser),
      body: _homePageBody(),
      drawer: currentUser != null ? UserProfile() : null,
    );
  }
}