class ProductReviewsModel {
  String name, date, profileUrl, comment;
  List reviewImages;
  int rating;

  ProductReviewsModel({
    this.name = "",
    this.date = "",
    this.profileUrl = "",
    this.comment = "",
    this.reviewImages = const [],
    this.rating = 0,
  });

  factory ProductReviewsModel.fromMap(Map<String, dynamic> data) {
    return ProductReviewsModel(
      name: data['name'] ?? '',
      date: data['date'] ?? '',
      profileUrl: data['profileUrl'] ?? '',
      comment: data['comment'] ?? '',
      reviewImages: List.from(data['reviewImages'] ?? []),
      rating: data['rating'] ?? 0,
    );
  }

  // Method to convert the object to a map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'date': date,
      'profileUrl': profileUrl,
      'comment': comment,
      'reviewImages': reviewImages,
      'rating': rating,
    };
  }
}
