import 'package:flutter/cupertino.dart';
import 'package:glamora/models/NotificationModel.dart';

class NotificationDetailsProvider with ChangeNotifier {
  List<NotificationModel> _notificationDetails = [
    NotificationModel(
        photoUrl: "white serum",
        title: "Big Day, Big Deal!",
        subTitle: "Buy now and get upto 50% off now!",
        time: "9:45 AM",
        status: "unseen"),
    NotificationModel(
        photoUrl: "red serum",
        title: "Eid Mubarak!",
        subTitle: "Limited Stock! Grab it Before it Gone!",
        time: "9:33 AM",
        status: "unseen"),
    NotificationModel(
        photoUrl: "green serum",
        title: "Happy Independence Day Sale!",
        subTitle: "Buy now and get upto 20% off now!",
        time: "yesterday",
        status: "unseen"),
    NotificationModel(
        photoUrl: "blue serum",
        title: "Order Confirmed #1253!",
        subTitle: "Readu for Packaging!",
        time: "20 Apr",
        status: "unseen"),
    NotificationModel(
        photoUrl: "orange serum",
        title: "Big Day, Big Deal!",
        subTitle: "Buy now and get upto 50% off now!",
        time: "19 Apr",
        status: "unseen"),
    NotificationModel(
        photoUrl: "purple serum",
        title: "Big Day, Big Deal!",
        subTitle: "Buy now and get upto 50% off now!",
        time: "15 Apr",
        status: "unseen"),
    NotificationModel(
        photoUrl: "pink serum",
        title: "Big Day, Big Deal!",
        subTitle: "Buy now and get upto 50% off now!",
        time: "14 Apr",
        status: "unseen"),
    NotificationModel(
        photoUrl: "white serum",
        title: "Big Day, Big Deal!",
        subTitle: "Buy now and get upto 50% off now!",
        time: "14 Apr",
        status: "unseen"),
  ];

  List<NotificationModel> get notificationDetails => _notificationDetails;

  void updateNotificationStatus(int index, String status) {
    _notificationDetails[index].status = status;
    notifyListeners();
  }
}
