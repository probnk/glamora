import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:glamora/models/ReviewsModel.dart';

enum StarFilter { all, five, four, three, two, one }

class RatingProvider with ChangeNotifier {
  // ── Star counts ─────────────────────────────────────────────────────────────
  int _firstCount  = 0;
  int _secondCount = 0;
  int _thirdCount  = 0;
  int _fourthCount = 0;
  int _fifthCount  = 0;

  int get firstCount  => _firstCount;
  int get secondCount => _secondCount;
  int get thirdCount  => _thirdCount;
  int get fourthCount => _fourthCount;
  int get fifthCount  => _fifthCount;

  // ── All reviews & filter ────────────────────────────────────────────────────
  List<ProductReviewModel> _ratingList = [];
  List<ProductReviewModel> get ratingList => _ratingList;

  StarFilter _activeFilter = StarFilter.all;
  StarFilter get activeFilter => _activeFilter;

  /// Returns the filtered subset for display
  List<ProductReviewModel> get filteredList {
    if (_activeFilter == StarFilter.all) return List.unmodifiable(_ratingList);
    final star = _starFromFilter(_activeFilter);
    return _ratingList.where((r) => r.rating == star).toList();
  }

  int get filteredCount => filteredList.length;

  void setFilter(StarFilter filter) {
    if (_activeFilter == filter) return;
    _activeFilter = filter;
    notifyListeners();
  }

  int _starFromFilter(StarFilter f) {
    switch (f) {
      case StarFilter.five:  return 5;
      case StarFilter.four:  return 4;
      case StarFilter.three: return 3;
      case StarFilter.two:   return 2;
      case StarFilter.one:   return 1;
      default:               return 0;
    }
  }

  int countForFilter(StarFilter f) {
    if (f == StarFilter.all) return _ratingList.length;
    final star = _starFromFilter(f);
    return _ratingList.where((r) => r.rating == star).length;
  }

  // ── Snapshot / list helpers ─────────────────────────────────────────────────
  void addReviewFromSnapshot(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final reviewModel = ProductReviewModel.fromMap(data);
    final isDuplicate = _ratingList.any(
          (e) =>
      e.reviewerName == reviewModel.reviewerName &&
          e.reviewDate   == reviewModel.reviewDate   &&
          e.comment      == reviewModel.comment,
    );
    if (!isDuplicate) {
      _ratingList.insert(0, reviewModel);
      _recount();
      notifyListeners();
    }
  }

  void clearReviews() {
    _ratingList.clear();
    _resetCounts();
    _activeFilter = StarFilter.all;
    notifyListeners();
  }

  double calculateAverageRating() {
    if (_ratingList.isEmpty) return 0.0;
    return _ratingList.fold(0.0, (s, r) => s + r.rating) / _ratingList.length;
  }

  void countStarRatings(List<ProductReviewModel> reviews) {
    _ratingList = List.of(reviews);
    _recount();
    notifyListeners();
  }

  // ── Private helpers ─────────────────────────────────────────────────────────
  void _resetCounts() {
    _firstCount = _secondCount = _thirdCount = _fourthCount = _fifthCount = 0;
  }

  void _recount() {
    _resetCounts();
    for (final r in _ratingList) {
      switch (r.rating) {
        case 1: _firstCount++;  break;
        case 2: _secondCount++; break;
        case 3: _thirdCount++;  break;
        case 4: _fourthCount++; break;
        case 5: _fifthCount++;  break;
      }
    }
  }
}