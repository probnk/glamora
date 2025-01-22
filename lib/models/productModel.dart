import 'package:cloud_firestore/cloud_firestore.dart';
import 'ReviewsModel.dart';

class Serum {
  final String title;
  final String description;
  final String features;
  final String usage;
  final int oldPrice;
  final int newPrice;
  final int discount;
  final int stock;
  final int totalOrders;
  final List<ProductReviewsModel> reviews;
  final List<String> photoUrl;
  final String dimensions;

  Serum({
    required this.title,
    required this.description,
    required this.features,
    required this.usage,
    required this.oldPrice,
    required this.newPrice,
    required this.discount,
    required this.stock,
    required this.totalOrders,
    required this.reviews,
    required this.photoUrl,
    required this.dimensions,
  });

  factory Serum.fromSnapshot(DocumentSnapshot snapshot) {
    Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
    return Serum(
      title: data['title'],
      description: data['description'],
      features: data['features'],
      usage: data['usage'],
      oldPrice: data['oldPrice'] ?? 0, // Default to 0 if null
      newPrice: data['newPrice'] ?? 0,
      discount: data['discount'] ?? 0, // Default to 0 if null
      stock: data['stock'] ?? 0, // Default to 0 if null
      totalOrders: data['totalOrders'] ?? 0, // Default to 0 if null
      reviews: List<ProductReviewsModel>.from(data['reviews']?.map((review) => ProductReviewsModel.fromMap(review)) ?? []),
      photoUrl: List<String>.from(data['imageUrls'] ?? []),
      dimensions: data['dimensions'],
    );
  }
}
