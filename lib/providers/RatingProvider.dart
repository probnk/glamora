import 'package:flutter/cupertino.dart';
import 'package:glamora/models/ReviewsModel.dart';


class RatingProvider with ChangeNotifier{
  List<ProductReviewsModel> _ratingList = [
    ProductReviewsModel(
      name: 'John Doe',
      date: '2023-03-15',
      profileUrl: 'person.png',
      comment: 'This serum is amazing! My skin feels so much smoother and brighter. ✨',
      rating: 5,
    ),
    ProductReviewsModel(
      name: 'Jane Doe',
      date: '2023-03-14',
      profileUrl: 'person.png',
      comment: 'I love this serum! It really helps to reduce the appearance of my fine lines. 👍',
      rating: 4,
    ),
    ProductReviewsModel(
      name: 'Peter Pan',
      date: '2023-03-13',
      profileUrl: 'person.png',
      comment: 'This serum is a bit pricey, but it definitely delivers on its promises. 💰',
      rating: 4,
    ),
    ProductReviewsModel(
      name: 'Wendy Darling',
      date: '2023-03-12',
      profileUrl: 'person.png',
      comment: 'I have been using this serum for a few weeks now and I am really impressed with the results. 🤩',
      rating: 5,
    ),
    ProductReviewsModel(
      name: 'Captain Hook',
      date: '2023-03-11',
      profileUrl: 'person.png',
      comment: 'This serum is a game changer! My skin looks and feels so much better. 💯',
      rating: 5,
    ),
    ProductReviewsModel(
      name: 'Alice in Wonderland',
      date: '2023-03-10',
      profileUrl: 'person.png',
      comment: 'I love the way this serum makes my skin feel. It is so soft and hydrated. 🥰',
      rating: 5,
    ),
    ProductReviewsModel(
      name: 'The Mad Hatter',
      date: '2023-03-09',
      profileUrl: 'person.png',
      comment: 'This serum is a great value for the price. I would definitely recommend it. 👌',
      rating: 4,
    ),
    ProductReviewsModel(
      name: 'The Queen of Hearts',
      date: '2023-03-08',
      profileUrl: 'person.png',
      comment: 'I have been using this serum for a while now and I love it. It is so gentle on my sensitive skin. 💆‍♀️',
      rating: 4,
    ),
    ProductReviewsModel(
      name: 'The Cheshire Cat',
      date: '2023-03-07',
      profileUrl: 'person.png',
      comment: 'This serum is a great product. I would definitely recommend it to others. 👍',
      rating: 5,
    ),
    ProductReviewsModel(
      name: 'The White Rabbit',
      date: '2023-03-06',
      profileUrl: 'person.png',
      comment: 'I am so happy with this serum. It has made a huge difference in my skin. 😄',
      rating: 5,
    ),
  ];
  List<ProductReviewsModel> get ratingList => _ratingList;


  void addNewRating(ProductReviewsModel ratingModel) {
    _ratingList.add(ratingModel);
    _ratingList.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }
}