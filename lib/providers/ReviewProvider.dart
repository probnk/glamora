import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:glamora/models/ReviewsModel.dart';

class ReviewProvider with ChangeNotifier {
  final _firestore = FirebaseFirestore.instance.collection("Cloths");

  int _selectedStarRating = 5;

  int get selectedStarRating => _selectedStarRating;

  bool _isLoading = false;

  bool get isLoading => _isLoading;

  List<String> _productPhotoUrls = [];

  List<String> get productPhotoUrls => _productPhotoUrls;

  File? _imageFile;

  File? get imageFile => _imageFile;

  int _selectedImageUrl = 0;

  int get selectedImageUrl => _selectedImageUrl;

  void setImageFile(File image) {
    _imageFile = image;
    notifyListeners();
  }

  void selectedImage(int url) {
    _selectedImageUrl = url;
    notifyListeners();
  }

  void setProductPhoto(String url) {
    _productPhotoUrls.add(url);
    notifyListeners();
  }

  void clearImages() {
    _productPhotoUrls.clear();
    _imageFile = null;
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


  Future<void> submitReview({
    required String docId,
    required String gender,
    required String category,
    required ProductReviewModel newReview
  }) async {
    try {
      toggleLoading(true);

      // Create review model

      // Add to Firestore using arrayUnion to append without replacing
      await _firestore
          .doc(gender)
          .collection(category)
          .doc(docId)
          .update({
        'reviews': FieldValue.arrayUnion([newReview.toMap()])
      });

      // Clear form after submission
      clearImages();
      _selectedStarRating = 5;

    } catch (e) {
      debugPrint("Error submitting review: $e");
      rethrow;
    } finally {
      toggleLoading(false);
    }
  }
}
