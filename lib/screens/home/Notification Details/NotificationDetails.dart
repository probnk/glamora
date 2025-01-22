import 'package:flutter/material.dart';
import 'package:glamora/constants/colors.dart';
import 'package:glamora/constants/fonts.dart';
import 'package:glamora/providers/DarkModeProvider.dart';
import 'package:glamora/providers/NotificationDetailsProvider.dart';
import 'package:provider/provider.dart';

class NotificationDetails extends StatefulWidget {
  const NotificationDetails({super.key});

  @override
  State<NotificationDetails> createState() => _NotificationDetailsState();
}

class _NotificationDetailsState extends State<NotificationDetails> {
  //it is the main body of the notification
  _notificationBody({required bool isDarkMode}) {
    return ListView(
      shrinkWrap: true,
      physics: ScrollPhysics(),
      children: [
        _newNotifications(isDarkMode: isDarkMode),
      ],
    );
  }

  //This function will show only new Notification's
  _newNotifications({required bool isDarkMode}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _notificationStatusAndCountingRow(
            title: "New", counting: "2", isDarkMode: isDarkMode),
        _newNotificationsList(isDarkMode: isDarkMode),
        _notificationStatusAndCountingRow(
            title: "Earlier", counting: "8", isDarkMode: isDarkMode)
      ],
    );
  }

  _notificationStatusAndCountingRow(
      {required String title,
      required String counting,
      required bool isDarkMode}) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Row(
        children: [
          productTitle(text: title, color: isDarkMode ? white : grayBlack),
          SizedBox(width: 10),
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDarkMode
                    ? lightBlue.withOpacity(.2)
                    : lightBlue.withOpacity(.05)),
            child: smallFont(text: counting, color: lightBlue),
          )
        ],
      ),
    );
  }

  _newNotificationsList({required bool isDarkMode}) {
    return Consumer<NotificationDetailsProvider>(
        builder: (context, value, child) {
      return ListView.builder(
          itemCount: value.notificationDetails.length,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            return InkWell(
              focusColor: Colors.transparent,
              splashColor: Colors.transparent,
              onTap: () {
                value.updateNotificationStatus(index, "seen");
              },
              child: Container(
                color: value.notificationDetails[index].status == "seen"
                    ? Colors.transparent
                    : (isDarkMode
                        ? Colors.white12
                        : lightBlue.withOpacity(.05)),
                margin: EdgeInsets.symmetric(vertical: 3),
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.transparent,
                      backgroundImage: AssetImage(
                          "assets/images/${value.notificationDetails[index].photoUrl}.png"),
                      radius: 30,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              mediumFont(
                                  text: value.notificationDetails[index].title,
                                  color: isDarkMode ? white : grayBlack,
                                  align: TextAlign.start,
                                  maxWidth:
                                      MediaQuery.of(context).size.width * .53,
                                  overflow: TextOverflow.ellipsis),
                              smallFont(
                                  text: value.notificationDetails[index].time,
                                  color: Colors.grey.shade400),
                            ],
                          ),
                          smallFont(
                              text: value.notificationDetails[index].subTitle,
                              color:isDarkMode? white :  grayBlack,
                              overflow: TextOverflow.ellipsis,
                              maxWidth: MediaQuery.of(context).size.width * .7)
                        ],
                      ),
                    )
                  ],
                ),
              ),
            );
          });
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<DarkModeProvider>(context);
    return Scaffold(
        appBar: AppBar(
          backgroundColor: themeProvider.isDarkMode ? lightGrayBlack : white,
          iconTheme: IconThemeData(
            color: themeProvider.isDarkMode ? white : grayBlack
          ),
          centerTitle: true,
          title: titleFont(
              text: "Notifications",
              color: themeProvider.isDarkMode ? white : grayBlack),
        ),
        backgroundColor: themeProvider.isDarkMode ? grayBlack : white,
        body: _notificationBody(isDarkMode: themeProvider.isDarkMode));
  }
}
