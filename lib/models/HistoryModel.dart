import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:glamora/models/cartProducts.dart';
import 'HistoryProductItems.dart';

class HistoryModel {
  final String orderId;
  final String orderDate;
  final String orderTime;
  final Map<String, dynamic> userDetails;
  final List<CartProducts> cartItems;
  final bool paid;
  final bool fulfilled;
  late final String status;

  HistoryModel({
    required this.orderId,
    required this.orderDate,
    required this.orderTime,
    required this.userDetails,
    required this.cartItems,
    required this.paid,
    required this.fulfilled,
    required this.status,
  });

  // Factory constructor to create a HistoryModel from a Firestore DocumentSnapshot
  factory HistoryModel.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;  // Get the data from snapshot

    print("From Snapshot: ${data}");
    List<CartProducts> cartItems = List<Map<String, dynamic>>.from(data['cartItems'] ?? [])
        .map((item) => CartProducts.fromMap(item))
        .toList();

    // Mapping the data from Firestore to HistoryModel
    return HistoryModel(
      orderId: data['orderId'] ?? '',
      orderDate: data['orderDate'] ?? '',
      orderTime: data['orderTime'] ?? '',
      userDetails: data['userDetails'] ?? {},  // User details is already a map
      cartItems:cartItems,
      paid: data['paid'] ?? false,
      fulfilled: data['fulfilled'] ?? false,
      status: data['status'] ?? 'unseen',
    );
  }

  // Method to convert HistoryModel to a map, for storing in Firestore
  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'orderDate': orderDate,
      'orderTime': orderTime,
      'userDetails': userDetails,
      'cartItems': cartItems.map((item) => item.toMap()).toList(), // Ensure cartItems are converted to Map
      'paid': paid,
      'fulfilled': fulfilled,
      'status': status,
    };
  }
}
