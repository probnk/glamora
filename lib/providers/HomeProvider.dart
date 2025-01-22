import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';

class HomeProvider with ChangeNotifier {
  int _activeIndex = 0;
  int get activeIndex => _activeIndex;

  void setActiveIndex(int index) {
    _activeIndex = index;
    notifyListeners();
  }

  final FirebaseStorage _storage = FirebaseStorage.instance;

  List<String> _productPhotoUrls = [];
  bool _isLoading = true;

  List<String> get productPhotoUrls => _productPhotoUrls;
  bool get isLoading => _isLoading;

  Future<List<String>> fetchImagesList() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Banner').doc("bannerList") // Assuming you're fetching from Firestore
          .get();

      if (snapshot.exists) {
        var data = snapshot.data() as Map<String, dynamic>;
        List<dynamic> banners = data['banners'] ?? [];

        _productPhotoUrls = banners.cast<String>();  // Cast dynamic to List<String>
      }

      notifyListeners();

      return _productPhotoUrls; // Return the list of image URLs
    } catch (e) {
      // Handle errors
      print('Error fetching images: $e');
      return []; // Return an empty list if there's an error
    }
  }
}
