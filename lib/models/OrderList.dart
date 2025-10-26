import 'package:cloud_firestore/cloud_firestore.dart';

import 'OrderProducts.dart';
import 'TackingStatusModel.dart';
import 'UserDetailsModel.dart';

class OrderList {
  final String docId;
  final String orderId;
  final String orderDate;
  final String orderTime;
  final UserDetailsModel userDetails;
  final String uid;
  final List<OrderProducts> cartItems;
  bool paid;
  bool fulfilled;
  bool cancelled;
  String? trackingId; // Made nullable
  String? trackingUrl; // Made nullable
  List<TrackingStatusModel>? trackingStatus; // Made nullable


  OrderList({
    required this.docId,
    required this.orderId,
    required this.orderDate,
    required this.orderTime,
    required this.userDetails,
    required this.uid,
    required this.cartItems,
    required this.paid,
    required this.fulfilled,
    required this.cancelled,
    this.trackingId,
    this.trackingUrl,
    this.trackingStatus
  });

  factory OrderList.fromMap(Map<String, dynamic> data) {
    return OrderList(
      docId: data['docId'] ?? '',
      orderId: data['orderId'] ?? '',
      orderDate: data['orderDate'] ?? '',
      orderTime: data['orderTime'] ?? '',
      userDetails: UserDetailsModel.fromMap(data['userDetails'] ?? {}),
      uid:data['uid'],
      cartItems: (data['cartItems'] as List<dynamic>)
          .map((item) => OrderProducts.fromMap(item as Map<String, dynamic>))
          .toList(),
      paid: data['paid'] ?? false,
      fulfilled: data['fulfilled'] ?? false,
      cancelled: data['cancelled'] ?? false,
      trackingId: data['trackingId'],
      trackingUrl: data['trackingUrl'],
      trackingStatus: (data['trackingStatus'] as List<dynamic>?)?.map((item) => TrackingStatusModel.fromMap(item as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'docId': docId,
      'orderId': orderId,
      'orderDate': orderDate,
      'orderTime': orderTime,
      'userDetails': userDetails.toMap(),
      'uid':uid,
      'cartItems': cartItems.map((item) => item.toMap()).toList(),
      'paid': paid,
      'fulfilled': fulfilled,
      'cancelled': cancelled,
      'trackingId': trackingId,
      'trackingUrl': trackingUrl,
      'trackingStatus': trackingStatus?.map((item) => item.toMap()).toList(),
    };
  }

  factory OrderList.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return OrderList.fromMap(data);
  }
}
