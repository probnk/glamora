import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:glamora/models/ReviewsModel.dart';

class RatingProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _firstCount = 0;  // For 1-star ratings
  int _secondCount = 0; // For 2-star ratings
  int _thirdCount = 0;  // For 3-star ratings
  int _fourthCount = 0; // For 4-star ratings
  int _fifthCount = 0;  // For 5-star ratings

  int get firstCount => _firstCount;
  int get secondCount => _secondCount;
  int get thirdCount => _thirdCount;
  int get fourthCount => _fourthCount;
  int get fifthCount => _fifthCount;

  List<ProductReviewModel> _ratingList = [];

  List<ProductReviewModel> get ratingList => _ratingList;

  void addReviewFromSnapshot(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final reviewModel = ProductReviewModel.fromMap(data);
    if (!_ratingList.any((e) =>
    e.reviewerName == reviewModel.reviewerName &&
        e.reviewDate == reviewModel.reviewDate &&
        e.comment == reviewModel.comment)) {
      _ratingList.insert(0, reviewModel);
      notifyListeners();
    }
  }

  void clearReviews() {
    _ratingList.clear();
    notifyListeners();
  }

  double calculateAverageRating() {
    if (_ratingList.isEmpty) return 0.0;
    double total = _ratingList.fold(0.0, (sum, item) => sum + item.rating);
    return total / _ratingList.length;
  }

  // In RatingProvider class
  void countStarRatings(List<ProductReviewModel> reviews) {
    // Reset all counts before calculating
    _firstCount = 0;
    _secondCount = 0;
    _thirdCount = 0;
    _fourthCount = 0;
    _fifthCount = 0;

    for (var review in reviews) {
      switch (review.rating) {
        case 1:
          _firstCount++;
          break;
        case 2:
          _secondCount++;
          break;
        case 3:
          _thirdCount++;
          break;
        case 4:
          _fourthCount++;
          break;
        case 5:
          _fifthCount++;
          break;
        default:
        // Handle unexpected ratings if needed
          break;
      }
    }
    notifyListeners(); // Add this to update UI
  }
}
