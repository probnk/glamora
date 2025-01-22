import 'package:cloud_firestore/cloud_firestore.dart';
import 'HistoryProductItems.dart';

class HistoryModel {
  final String orderId;
  final String orderDate;
  final String orderTime;
  final Map<String, dynamic> userDetails;
  final List<HistoryProductItems> cartItems;
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
    Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;  // Get the data from snapshot

    print("From Snapshot: ${data}");

    // Mapping the data from Firestore to HistoryModel
    return HistoryModel(
      orderId: data['orderId'] ?? '',
      orderDate: data['orderDate'] ?? '',
      orderTime: data['orderTime'] ?? '',
      userDetails: data['userDetails'] ?? {},  // User details is already a map
      cartItems: List<HistoryProductItems>.from(
        // Map each cart item to the HistoryProductItems model
        (data['cartItems'] as List).map((item) => HistoryProductItems.fromMap(item)),
      ),
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
