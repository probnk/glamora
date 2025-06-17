import 'package:flutter/cupertino.dart';
import 'package:glamora/models/ReviewsModel.dart';

class RatingProvider with ChangeNotifier {
  List<ProductReviewModel> _ratingList = [
    ProductReviewModel(
      reviewerName: 'John Doe',
      reviewDate: '2023-03-15',
      profilePhoto: 'person.png',
      comment: 'This serum is amazing! My skin feels so much smoother and brighter. ✨',
      reviewImages: [],
      rating: 5,
    ),
    ProductReviewModel(
      reviewerName: 'Jane Doe',
      reviewDate: '2023-03-14',
      profilePhoto: 'person.png',
      comment: 'I love this serum! It really helps to reduce the appearance of my fine lines. 👍',
      reviewImages: [],
      rating: 4,
    ),
    ProductReviewModel(
      reviewerName: 'Peter Pan',
      reviewDate: '2023-03-13',
      profilePhoto: 'person.png',
      comment: 'This serum is a bit pricey, but it definitely delivers on its promises. 💰',
      reviewImages: [],
      rating: 4,
    ),
    ProductReviewModel(
      reviewerName: 'Wendy Darling',
      reviewDate: '2023-03-12',
      profilePhoto: 'person.png',
      reviewImages: [],
      rating: 5,
    ),
    ProductReviewModel(
      reviewerName: 'Captain Hook',
      reviewDate: '2023-03-11',
      profilePhoto: 'person.png',
      comment: 'This serum is a game changer! My skin looks and feels so much better. 💯',
      reviewImages: [],
      rating: 5,
    ),
    ProductReviewModel(
      reviewerName: 'Alice in Wonderland',
      reviewDate: '2023-03-10',
      profilePhoto: 'person.png',
      comment: 'I love the way this serum makes my skin feel. It is so soft and hydrated. 🥰',
      reviewImages: [],
      rating: 5,
    ),
    ProductReviewModel(
      reviewerName: 'The Mad Hatter',
      reviewDate: '2023-03-09',
      profilePhoto: 'person.png',
      comment: 'This serum is a great value for the price. I would definitely recommend it. 👌',
      reviewImages: [],
      rating: 4,
    ),
    ProductReviewModel(
      reviewerName: 'The Queen of Hearts',
      reviewDate: '2023-03-08',
      profilePhoto: 'person.png',
      comment: 'I have been using this serum for a while now and I love it. It is so gentle on my sensitive skin. 💆‍♀️',
      reviewImages: [],
      rating: 4,
    ),
    ProductReviewModel(
      reviewerName: 'The Cheshire Cat',
      reviewDate: '2023-03-07',
      profilePhoto: 'person.png',
      comment: 'This serum is a great product. I would definitely recommend it to others. 👍',
      reviewImages: [],
      rating: 5,
    ),
    ProductReviewModel(
      reviewerName: 'The White Rabbit',
      reviewDate: '2023-03-06',
      profilePhoto: 'person.png',
      comment: 'I am so happy with this serum. It has made a huge difference in my skin. 😄',
      reviewImages: [],
      rating: 5,
    ),
  ];

  List<ProductReviewModel> get ratingList => _ratingList;

  void addNewRating(ProductReviewModel ratingModel) {
    _ratingList.add(ratingModel);
    _ratingList.sort((a, b) => b.reviewDate.compareTo(a.reviewDate));
    notifyListeners();
  }

  // Method to calculate average rating
  double calculateAverageRating() {
    if (_ratingList.isEmpty) {
      return 0.0; // Return 0 if the list is empty
    }

    // Sum all the ratings
    double totalRating = 0.0;
    for (var review in _ratingList) {
      totalRating += review.rating.toDouble(); // Ensure the rating is treated as a double
    }

    // Calculate the average
    double averageRating = totalRating / _ratingList.length;
    return averageRating;
  }
}
