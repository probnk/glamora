import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:glamora/models/productModel.dart';

class ProductListProvider with ChangeNotifier {
  List<ClothingProductModel> _clothsList = [];
  List<ClothingProductModel> get clothsList => _clothsList;

  double? _rating;
  double? get rating => _rating;
  List<ClothingProductModel> _productDetailsList = [];
  String _selectedGender = 'Man';
  String _selectedCategory = 'T-Shirt';
  bool _isLoading = false;

  List<ClothingProductModel> get productDetailsList => _productDetailsList;
  String get selectedGender => _selectedGender;
  String get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;

  void setProducts(List<ClothingProductModel> products) {
    _productDetailsList = products;
    notifyListeners();
  }

  void removeProduct(int index) {
    _productDetailsList.removeAt(index);
    notifyListeners();
  }

  void setSelectedGender(String gender) {
    _selectedGender = gender;
    notifyListeners();
  }

  void setSelectedCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
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

