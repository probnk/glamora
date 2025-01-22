import 'package:flutter/material.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/screens/Get%20Started/GetStartedDesign.dart';
import 'package:glamora/screens/Login/Login.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class GetStarted extends StatefulWidget {
  const GetStarted({super.key});

  @override
  State<GetStarted> createState() => _GetStartedState();
}

class _GetStartedState extends State<GetStarted> {
  var _pageController;
  int _currentPage = 0;

  _worm() {
    return ExpandingDotsEffect(
      activeDotColor: lightGrayBlack,
      dotColor: white,
      dotWidth: 16,
      dotHeight: 16,
    );
  }


  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  _nextAndBackRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: () {
            _pageController.previousPage(
                duration: Duration(milliseconds: 500), curve: Curves.ease);
          },
          child: mediumFont(text: "Back"),
        ),
        SmoothPageIndicator(
          controller: _pageController,
          count: 4,
          effect: _worm(),
        ),
        TextButton(
          onPressed: () async{
            if (_currentPage == 3) {
              final sharedPreference = await SharedPreferences.getInstance();
              sharedPreference.setBool('isGetStarted', true);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => Login()),
              );
            } else {
              _pageController.nextPage(
                  duration: Duration(milliseconds: 500), curve: Curves.ease);
            }
          },
          child: mediumFont(text: "Next"),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            children: [
              GetStartedDesign(
                  title: "Illuminate Your Essence",
                  subTitle:
                      "Unveil the radiance within you with our luxurious serums. Experience the transformative power of our products that illuminate and rejuvenate your skin. Dive into a world where every drop promises a glow that's simply irresistible. Embrace the journey to flawless beauty with us!",
                  url: "orange serum",
                  darkColor: lightOrange),
              GetStartedDesign(
                  title: "Timeless Youth Revealed",
                  subTitle:
                      "Wave goodbye to those stubborn blemishes and embrace a younger, smoother complexion. Our advanced serums target acne and signs of aging, leaving you with a clearer and more youthful appearance. Discover the secret to timeless beauty and rejuvenate your skin like never before!",
                  url: "green serum",
                  darkColor: lightGreen),
              GetStartedDesign(
                  title: "Pore Perfection",
                  subTitle:
                      "Achieve the flawless skin you've always desired with our pore-refining serums. Smooth out imperfections, minimize pores, and reveal a complexion that's not only perfect but also enviably radiant. Transform your skincare routine and enjoy the silky-smooth texture of your revitalized skin!",
                  url: "purple serum",
                  darkColor: lightPurple),
              GetStartedDesign(
                  title: "Exclusive Radiance Awaits",
                  subTitle:
                      "Step into a world of exclusive deals and exceptional products tailored just for you. Explore our range and find the perfect match for your skincare needs. From luxurious serums to must-have essentials, seize the opportunity to indulge in the finest skincare solutions designed to elevate your routine.",
                  url: "red serum",
                  darkColor: lightRed),
            ],
          ),
          Positioned(
              bottom: 20,
              right: 20,
              left: 20,
              child: _buildBottomNavigationBar())
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    if (_currentPage == 0) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(),
          SmoothPageIndicator(
            controller: _pageController,
            count: 4,
            effect: _worm(),
          ),
          TextButton(
              onPressed: () {
                _pageController.nextPage(
                    duration: Duration(milliseconds: 500), curve: Curves.ease);
              },
              child: mediumFont(text: "Next")),
        ],
      );
    } else if (_currentPage == 3) {
      return _nextAndBackRow();
    } else {
      return _nextAndBackRow();
    }
  }
}
