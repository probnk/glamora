import 'package:flutter/material.dart';
import 'package:glamora/Services/getServerKey.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:glamora/screens/Catagory/ProductCatagory.dart';
import 'package:glamora/screens/MyCart/MyCart.dart';
import 'package:glamora/screens/MyWishlist/MyWishlist.dart';
import 'package:glamora/screens/home/HomeScreen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:line_icons/line_icons.dart';
import 'package:provider/provider.dart';

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({super.key});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {


  List _screen = [HomeScreen(),ProductCatagory(),MyCart(),MyWishlist()];
  int _selectedScreen = 0;

  _bottomNavbar(BuildContext context){
    final themeProvider = Provider.of<DarkModeProvider>(context);
    return Container(
      color: themeProvider.isDarkMode ? grayBlack : white,
      child: Card(
        elevation: 3,
        margin: EdgeInsets.all(10),
        color: themeProvider.isDarkMode ? grayBlack : white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)
        ),
        child: Container(
          width: MediaQuery.of(context).size.width,
          height: 70,
          decoration: BoxDecoration(
              color:themeProvider.isDarkMode ? lightGrayBlack : white,
              borderRadius: BorderRadius.circular(20)
          ),
          alignment: Alignment.center,
          padding:EdgeInsets.symmetric(vertical: 10,horizontal: 12),
          child: GNav(
              onTabChange: (index){
                setState(() {
                  _selectedScreen = index;
                });
              },
              gap: 8,
              curve: Curves.easeIn,
              backgroundColor: themeProvider.isDarkMode  ? lightGrayBlack : white,
              rippleColor:Colors.blue,
              textStyle: GoogleFonts.montserrat(
                color: white,
                fontSize: 16,
              ),
              tabBackgroundGradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: themeProvider.isDarkMode ? [lightOrange, darkOrange] :[lightBlue,lightPurple]

              ),
              tabs: [
                GButton(
                    padding: EdgeInsets.all(10),
                    iconSize: 24,
                    iconColor:themeProvider.isDarkMode ? white : grayBlack,
                    iconActiveColor: Colors.white,
                    icon: LineIcons.home,
                    text: 'Home'
                ),
                GButton(
                    padding: EdgeInsets.all(10),
                    iconSize: 24,
                    iconColor:themeProvider.isDarkMode ? white : grayBlack,
                    iconActiveColor: Colors.white,
                    icon: LineIcons.boxes,
                    text: 'Category'
                ),
                GButton(
                  padding: EdgeInsets.all(10),
                  iconSize: 24,
                  iconColor:themeProvider.isDarkMode ? white : grayBlack,
                  iconActiveColor: Colors.white,
                  icon: LineIcons.shoppingCart,
                  text: 'Cart',
                ),
                GButton(
                    padding: EdgeInsets.all(10),
                    iconSize: 24,
                    iconColor:themeProvider.isDarkMode ? white : grayBlack,
                    iconActiveColor: Colors.white,
                    icon: LineIcons.heart,
                    text: 'Wishlist'
                ),
              ]
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: _bottomNavbar(context),
      body: _screen[_selectedScreen],
    );
  }
}
