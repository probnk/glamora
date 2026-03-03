// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:glamora/models/productModel.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
//
// class ProductListProvider with ChangeNotifier {
//   List<ClothingProductModel> _clothsList = [];
//   List<ClothingProductModel> get clothsList => _clothsList;
//   List<ClothingProductModel> _recommendedCloths = []; // For personalized products
//   List<ClothingProductModel> get recommendedCloths => _recommendedCloths;
//   double? _rating;
//   double? get rating => _rating;
//   List<ClothingProductModel> _productDetailsList = [];
//   String _selectedGender = 'Man';
//   String _selectedCategory = 'T-Shirt';
//   bool _isLoading = false;
//
//   List<ClothingProductModel> get productDetailsList => _productDetailsList;
//   String get selectedGender => _selectedGender;
//   String get selectedCategory => _selectedCategory;
//   bool get isLoading => _isLoading;
//
//   void setProducts(List<ClothingProductModel> products) {
//     _productDetailsList = products;
//     notifyListeners();
//   }
//
//   void removeProduct(int index) {
//     _productDetailsList.removeAt(index);
//     notifyListeners();
//   }
//
//   void setSelectedGender(String gender) {
//     _selectedGender = gender;
//     notifyListeners();
//   }
//
//   void setSelectedCategory(String category) {
//     _selectedCategory = category;
//     notifyListeners();
//   }
//
//   void setLoading(bool loading) {
//     _isLoading = loading;
//     notifyListeners();
//   }
//   Future<void> fetchClothsList() async {
//     QuerySnapshot querySnapshot = await FirebaseFirestore.instance
//         .collection('Cloths').doc("Man").collection("T-Shirt").get();
//     _clothsList =
//         querySnapshot.docs.map((doc) => ClothingProductModel.fromSnapshot(doc)).toList();
//     // _calculateTotal();
//     notifyListeners();
//   }
//   Future<void> fetchPersonalizedProducts() async {
//     setLoading(true);
//     try {
//       final currentUser = FirebaseAuth.instance.currentUser;
//       if (currentUser == null) {
//         print('No authenticated user');
//         return;
//       }
//
//       final supabase = Supabase.instance.client;
//       final uid = currentUser.uid;
//
//       // Fetch personalization data from Supabase
//       final response = await supabase
//           .from('personalization')
//           .select('email, categories, gender')
//           .eq('uid', uid)
//           .maybeSingle();
//
//       if (response == null) {
//         print('No personalization data found for user $uid');
//         return;
//       }
//       print('personalization data found for user $uid');
//
//       final data = response as Map<String, dynamic>;
//       final String gender = data['gender'] ?? 'Man';
//       final List<dynamic> categoriesJson = data['categories'] ?? [];
//
//       // Parse categories JSON
//       List<Map<String, dynamic>> categories =
//       categoriesJson.cast<Map<String, dynamic>>();
//
//       // Extract and sort categories by weight
//       List<MapEntry<String, int>> categoryWeights = categories.map((catMap) {
//         String category = catMap.keys.first;
//         int weight = catMap[category] as int;
//         return MapEntry(category, weight);
//       }).toList();
//
//       categoryWeights.sort((a, b) => b.value.compareTo(a.value)); // Descending
//
//       // Take top 2 categories (or fewer if less available)
//       List<String> topCategories =
//       categoryWeights.take(2).map((e) => e.key).toList();
//
//       if (topCategories.isEmpty) {
//         print('No categories found for user $uid');
//         return;
//       }
//
//       // Fetch products from Firestore for each top category
//       List<ClothingProductModel> recommendedProducts = [];
//       final firestore = FirebaseFirestore.instance;
//
//       for (String category in topCategories) {
//         final querySnapshot = await firestore
//             .collection('Cloths')
//             .doc(gender)
//             .collection(category)
//             .get();
//         recommendedProducts.addAll(querySnapshot.docs
//             .map((doc) => ClothingProductModel.fromSnapshot(doc)));
//       }
//
//       // Update recommended cloths
//       setRecommendedCloths(recommendedProducts);
//     } catch (e) {
//       print('Error fetching personalized products: $e');
//     } finally {
//       setLoading(false);
//     }
//   }
//   void setRecommendedCloths(List<ClothingProductModel> products) {
//     _recommendedCloths = products;
//     notifyListeners();
//   }
//   void _calculateTotal() {
//     int sum = 0;
//     for(int i=0;i<_clothsList.length;i++){
//      for(int j=0;j<_clothsList[i].reviews.length;j++){
//        sum += _clothsList[i].reviews[i].rating;
//      }
//      int length = _clothsList.length;
//      _rating = (sum/length);
//     }
//     notifyListeners();
//   }
// }
//
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:glamora/models/productModel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductListProvider with ChangeNotifier {
  List<ClothingProductModel> _clothsList = [];
  List<ClothingProductModel> get clothsList => _clothsList;
  String? _gender;
  String? get gender => _gender;
  List<ClothingProductModel> _recommendedCloths = [];
  List<ClothingProductModel> get recommendedCloths => _recommendedCloths;

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
        .collection('Cloths')
        .doc("Man")
        .collection("T-Shirt")
        .get();

    _clothsList = querySnapshot.docs
        .map((doc) => ClothingProductModel.fromSnapshot(doc))
        .toList();

    notifyListeners();
  }

  Future<void> fetchPersonalizedProducts() async {
    setLoading(true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('No authenticated user');
        return;
      }

      final supabase = Supabase.instance.client;
      final uid = currentUser.uid;

      // Fetch personalization data from Supabase
      final response = await supabase
          .from('personalization')
          .select('email, categories, gender')
          .eq('uid', uid)
          .maybeSingle();

      if (response == null) {
        print('No personalization data found for user $uid');
        return;
      }

      final data = response as Map<String, dynamic>;
      final String gender = data['gender'] ?? 'Man';
      _gender = data['gender'] ?? 'Man';
      final List<dynamic> categoriesJson = data['categories'] ?? [];

      // Parse categories JSON
      List<Map<String, dynamic>> categories =
      categoriesJson.cast<Map<String, dynamic>>();

      // Extract and sort categories by weight
      List<MapEntry<String, int>> categoryWeights = categories.map((catMap) {
        String category = catMap.keys.first;
        int weight = catMap[category] as int;
        return MapEntry(category, weight);
      }).toList();

      categoryWeights.sort((a, b) => b.value.compareTo(a.value)); // Descending

      // Choose categories based on count
      List<String> topCategories = [];
      if (categoryWeights.isNotEmpty) {
        if (categoryWeights.length == 1) {
          topCategories.add(categoryWeights[0].key);
        } else if (categoryWeights.length == 2) {
          topCategories.add(categoryWeights[0].key);
        } else {
          topCategories.addAll(categoryWeights.take(2).map((e) => e.key));
        }
      }

      if (topCategories.isEmpty) {
        print('No valid categories found for user $uid');
        return;
      }

      // Fetch products from Firestore for each top category
      List<ClothingProductModel> recommendedProducts = [];
      final firestore = FirebaseFirestore.instance;

      for (String category in topCategories) {
        final querySnapshot = await firestore
            .collection('Cloths')
            .doc(gender)
            .collection(category)
            .get();

        recommendedProducts.addAll(querySnapshot.docs
            .map((doc) => ClothingProductModel.fromSnapshot(doc)));
      }

      // Update recommended cloths
      setRecommendedCloths(recommendedProducts);
    } catch (e) {
      print('Error fetching personalized products: $e');
    } finally {
      setLoading(false);
    }
  }

  void setRecommendedCloths(List<ClothingProductModel> products) {
    _recommendedCloths = products;
    notifyListeners();
  }

  void _calculateTotal() {
    int sum = 0;
    for (int i = 0; i < _clothsList.length; i++) {
      for (int j = 0; j < _clothsList[i].reviews.length; j++) {
        sum += _clothsList[i].reviews[j].rating;
      }
    }
    if (_clothsList.isNotEmpty) {
      int totalReviews = _clothsList.fold(
        0,
            (prev, element) => prev + element.reviews.length,
      );
      if (totalReviews > 0) {
        _rating = sum / totalReviews;
      }
    }
    notifyListeners();
  }
}
