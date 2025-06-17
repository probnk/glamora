import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:glamora/models/productModel.dart';

class ProductListProvider with ChangeNotifier {
  List<ClothingProductModel> _clothsList = [];
  List<ClothingProductModel> get clothsList => _clothsList;

  double? _rating;
  double? get rating => _rating;

  Future<void> fetchClothsList() async {
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('Cloths').doc("Man").collection("T-Shirt").get();
    _clothsList =
        querySnapshot.docs.map((doc) => ClothingProductModel.fromSnapshot(doc)).toList();
    // _calculateTotal();
    notifyListeners();
  }
  void _calculateTotal() {
    int sum = 0;
    for(int i=0;i<_clothsList.length;i++){
     for(int j=0;j<_clothsList[i].reviews.length;j++){
       sum += _clothsList[i].reviews[i].rating;
     }
     int length = _clothsList.length;
     _rating = (sum/length);
    }
    notifyListeners();
  }
}
