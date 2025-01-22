import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:glamora/models/productModel.dart';

class ProductListProvider with ChangeNotifier {
  List<Serum> _serumList = [];
  List<Serum> get serumList => _serumList;

  double? _rating;
  double? get rating => _rating;

  Future<void> fetchSerumList() async {
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('Products')
        .orderBy('totalOrders', descending: true)
        .get();
    _serumList =
        querySnapshot.docs.map((doc) => Serum.fromSnapshot(doc)).toList();
    _calculateTotal();
    notifyListeners();
  }
  void _calculateTotal() {
    int sum = 0;
    for(int i=0;i<_serumList.length;i++){
     for(int j=0;j<_serumList[i].reviews.length;j++){
       sum += _serumList[i].reviews[i].rating;
     }
     int length = _serumList.length;
     _rating = (sum/length);
    }
    notifyListeners();
  }
}
