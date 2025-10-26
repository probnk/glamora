import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:timeline_tile/timeline_tile.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/OrderList.dart';
import '../models/TackingStatusModel.dart';

class OrdersProvider with ChangeNotifier {
  List<OrderList> _orders = [];
  List<OrderList> get orders => _orders;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<List<OrderList>>? _subscription;

  OrdersProvider() {
    _subscription = _firestore.collection('Orders').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => OrderList.fromSnapshot(doc)).toList();
    }).listen((orders) {
      _orders = orders;
      _isLoading = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Stream<List<OrderList>> get ordersStream {
    return _firestore.collection('Orders').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => OrderList.fromSnapshot(doc)).toList();
    });
  }

  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase();
    notifyListeners();
  }

  void fetchOrders() {
    // For initial load or manual refresh
    _firestore.collection('Orders').get().then((snapshot) {
      _orders = snapshot.docs.map((doc) => OrderList.fromSnapshot(doc)).toList();
      notifyListeners();
    });
  }

  void updateOrderTrackingStatus(String docId, List<TrackingStatusModel> trackingStatus) {
    _firestore.collection('Orders').doc(docId).update({
      'trackingStatus': trackingStatus.map((item) => item.toMap()).toList(),
    }).then((_) {
      // Refresh orders after update
      fetchOrders();
    });
  }
}