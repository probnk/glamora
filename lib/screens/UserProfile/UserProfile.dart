import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:glamora/Google%20Auth%20Services/GoogleAuthService.dart';
import 'package:glamora/Google%20Auth%20Services/ServerClientId.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/providers/CartProvider.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:glamora/providers/HistoryProvider.dart';
import 'package:glamora/providers/NotificationDetailsProvider.dart';
import 'package:glamora/providers/RatingProvider.dart';
import 'package:glamora/providers/UserDetailsProvider.dart';
import 'package:glamora/providers/WishListProvider.dart';
import 'package:glamora/screens/History/History.dart';
import 'package:glamora/screens/Login/Login.dart';
import 'package:glamora/screens/MyCart/MyCart.dart';
import 'package:glamora/screens/MyWishlist/MyWishlist.dart';
import 'package:glamora/screens/Track%20Order/TrackOrder.dart';
import 'package:glamora/screens/UserProfile/UserDetails.dart';
import 'package:line_icons/line_icon.dart';
import 'package:line_icons/line_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfile extends StatelessWidget {
  final auth = GoogleAuthService();

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    List _options = [
      {
        'title': 'User Detail\'s',
        'icon': Icons.details_rounded,
        'screen': UserDetails()
      },
      {
        'title': 'Track Order',
        'icon': Icons.track_changes_rounded,
        'screen': TrackOrderScreen()
      },
      {'title': 'Cart', 'icon': Icons.card_travel_rounded, 'screen': MyCart()},
      {
        'title': 'WishList',
        'icon': Icons.favorite_rounded,
        'screen': MyWishlist()
      },
      {'title': 'History', 'icon': Icons.history, 'screen': History()},
    ];
    final themeProvider = Provider.of<DarkModeProvider>(context);
    return Drawer(
      child: Container(
        color: themeProvider.isDarkMode ? lightGrayBlack : white,
        child: Stack(
          children: [
            ListView(
              padding: EdgeInsets.zero,
              children: [
                FutureBuilder<User?>(
                  future: Future.value(currentUser),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return DrawerHeader(
                        child: Center(child: CircularProgressIndicator()),
                      );
                    } else if (snapshot.hasError) {
                      return DrawerHeader(
                        child: Center(child: Text('Error fetching user')),
                      );
                    } else if (snapshot.hasData) {
                      final User user = snapshot.data!;
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: themeProvider.isDarkMode
                                ? [lightOrange, darkOrange]
                                : [lightBlue, lightPurple],
                          ),
                        ),
                        child: UserAccountsDrawerHeader(
                          currentAccountPicture: CircleAvatar(
                            backgroundColor: Colors.transparent,
                            backgroundImage: user.photoURL != null
                                ? NetworkImage(user.photoURL!)
                                : AssetImage('assets/default_avatar.png')
                                    as ImageProvider,
                          ),
                          accountEmail: smallFont(
                              text: user.email ?? 'Email not available',
                              color: white),
                          accountName: smallFont(
                              text: user.displayName ?? 'Name not available',
                              color: white),
                          decoration: BoxDecoration(
                            color: Colors
                                .transparent, // Set this to transparent to use the gradient
                          ),
                        ),
                      );
                    } else {
                      return DrawerHeader(
                        child: Center(child: Text('No user signed in')),
                      );
                    }
                  },
                ),
                ..._options.map((value) => _customRow(
                    title: value['title'],
                    icon: value['icon'],
                    screen: value['screen'],
                    themeProvider: themeProvider,
                    context: context)),
                Divider(
                    color: themeProvider.isDarkMode
                        ? Colors.grey.shade700
                        : Colors.grey.shade300),
                Padding(
                  padding: EdgeInsets.only(left: 10),
                  child: titleFont(
                      text: "Out Social Media's",
                      color: themeProvider.isDarkMode ? white : grayBlack),
                ),

                _socialMediaRow(
                    icon: LineIcons.facebook,
                    title: 'Facebook',
                    color: Colors.blue,
                    themeProvider: themeProvider),
                _socialMediaRow(
                    icon: LineIcons.instagram,
                    title: 'Instagram',
                    color: lightRed,
                    themeProvider: themeProvider),
                SizedBox(height: 20), // Add some space before the logout button
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: InkWell(
                      onTap: () async {
                        try {
                          final uid = FirebaseAuth.instance.currentUser?.uid;

                          await auth.signOut();

                          if (uid != null) {
                            await FirebaseMessaging.instance
                                .unsubscribeFromTopic(uid);
                          }

                          // clear providers...
                          context.read<CartProvider>().cartItems.clear();
                          context
                              .read<HistoryProvider>()
                              .historyModelList
                              .clear();
                          context
                              .read<NotificationDetailsProvider>()
                              .notificationDetails
                              .clear();
                          context.read<RatingProvider>().ratingList.clear();
                          context
                              .read<UserDetailsProvider>()
                              .clearUserDetails();
                          context
                              .read<WishListProvider>()
                              .wishListProducts
                              .clear();

                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => Login()),
                          );
                        } catch (e) {
                          print('Error signing out: $e');
                        }
                      },
                      child: Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 3,
                        margin: EdgeInsets.symmetric(horizontal: 50),
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: themeProvider.isDarkMode
                                      ? [lightOrange, darkOrange]
                                      : [lightBlack, darkBlack])),
                          child: smallFont(text: "Logout", color: white),
                        ),
                      )),
                ),
              ],
            ),
            Positioned(
              bottom: 10,
              left: 20,
              child:
                  Consumer<DarkModeProvider>(builder: (context, value, child) {
                return FlutterSwitch(
                  width: 80.0,
                  height: 40.0,
                  toggleSize: 45.0,
                  value: value.isDarkMode,
                  borderRadius: 30.0,
                  padding: 2.0,
                  activeToggleColor: Color(0xFF6E40C9),
                  inactiveToggleColor: Color(0xFF2F363D),
                  activeSwitchBorder: Border.all(
                    color: Color(0xFF3C1E70),
                    width: 6.0,
                  ),
                  inactiveSwitchBorder: Border.all(
                    color: Color(0xFFD1D5DA),
                    width: 6.0,
                  ),
                  activeColor: Color(0xFF271052),
                  inactiveColor: Colors.white,
                  activeIcon: Icon(
                    Icons.nightlight_round,
                    color: Color(0xFFF8E3A1),
                  ),
                  inactiveIcon: Icon(
                    Icons.wb_sunny,
                    color: Color(0xFFFFDF5D),
                  ),
                  onToggle: (val) async {
                    value.toggleMode(val);
                    final isDarkMode = await SharedPreferences.getInstance();
                    isDarkMode.setBool("isDarkMode", value.isDarkMode);
                  },
                );
              }),
            )
          ],
        ),
      ),
    );
  }
}

_socialMediaRow(
    {required IconData icon,
    required String title,
    required Color color,
    required DarkModeProvider themeProvider}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        LineIcon(icon, color: color),
        SizedBox(width: 10),
        productTitle(
            text: title, color: themeProvider.isDarkMode ? white : grayBlack),
      ],
    ),
  );
}

_customRow(
    {required String title,
    required IconData icon,
    required Widget screen,
    required DarkModeProvider themeProvider,
    required BuildContext context}) {
  return InkWell(
    onTap: () {
      Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: themeProvider.isDarkMode ? white : grayBlack),
          SizedBox(width: 10),
          productTitle(
              text: title, color: themeProvider.isDarkMode ? white : grayBlack),
        ],
      ),
    ),
  );
}
