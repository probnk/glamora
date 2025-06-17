class ProductReviewModel {
  String reviewerName;
  String reviewDate;
  String profilePhoto;
  String comment;
  List<String> reviewImages;
  int rating;

  ProductReviewModel({
    this.reviewerName = "",
    this.reviewDate = "",
    this.profilePhoto = "",
    this.comment = "",
    this.reviewImages = const [],
    this.rating = 0,
  });

  factory ProductReviewModel.fromMap(Map<String, dynamic> data) {
    return ProductReviewModel(
      reviewerName: data['reviewerName'] ?? '',
      reviewDate: data['reviewDate'] ?? '',
      profilePhoto: data['profilePhoto'] ?? '',
      comment: data['comment'] ?? '',
      reviewImages: List<String>.from(data['reviewImages'] ?? []),
      rating: data['rating'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reviewerName': reviewerName,
      'reviewDate': reviewDate,
      'profilePhoto': profilePhoto,
      'comment': comment,
      'reviewImages': reviewImages,
      'rating': rating,
    };
  }
}
