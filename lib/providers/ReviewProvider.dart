import 'dart:io';
import 'package:flutter/cupertino.dart';

class ReviewProvider with ChangeNotifier {
  int _selectedStarRating = 5;
  int get selectedStarRating => _selectedStarRating;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<String> _productPhotoUrls = [];
  List<String> get productPhotoUrls => _productPhotoUrls;

  File? _imageFile;
  File? get imageFile => _imageFile;

  // Set the picked image file
  void setImageFile(File image) {
    _imageFile = image;
    notifyListeners();
  }

  // Set the product photo URL (after uploading to Firebase)
  void setProductPhoto(String url) {
    _productPhotoUrls.add(url);
    notifyListeners();
  }

  // Toggle loading state (e.g., show a loading indicator during image upload)
  void toggleLoading(bool isTrue) {
    _isLoading = isTrue;
    notifyListeners();
  }

  // Update the star rating
  void setStarRating(int index) {
    _selectedStarRating = index;
    notifyListeners();
  }
}
