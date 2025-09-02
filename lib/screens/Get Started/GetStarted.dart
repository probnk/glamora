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
                title: "Wear Your Vibe",
                subTitle:
                "Har T-shirt ek kahani hai jo tumhari personality ko express karti hai. Bold designs, soft fabric aur effortless comfort – apni vibe ko duniya ke saamne proudly pehno. Style jo sirf fashion nahi, ek statement hai!",
                url: "t-shirt1",
                darkColor: green,
              ),
              GetStartedDesign(
                title: "Everyday Comfort, Endless Style",
                subTitle:
                "Chahe tum office jaa rahe ho, friends k saath chill kar rahe ho ya gym – hamari T-shirts tumhe har jagah comfortable aur stylish feel karayengi. Ek wardrobe essential jo har mood aur look ke saath match hoti hai.",
                url: "t-shirt2",
                darkColor: purple,
              ),
              GetStartedDesign(
                title: "Stand Out from the Crowd",
                subTitle:
                "Unique cuts aur trendy colors ke saath, hamari T-shirts tumhe bheed se alag banati hain. Apna look elevate karo aur woh confidence pao jo sirf perfect outfit de sakta hai. Because ordinary is not an option!",
                url: "t-shirt5",
                darkColor: pink,
              ),
              GetStartedDesign(
                title: "Exclusive Styles, Just for You",
                subTitle:
                "Limited edition T-shirts jo tumhari individuality ko highlight karti hain. Apni favorite pick karo aur style game ko next level par le jao. Don’t wait – fashion ka best edition tumhara intizaar kar raha hai!",
                url: "t-shirt4",
                darkColor: lightOrange,
              ),

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
