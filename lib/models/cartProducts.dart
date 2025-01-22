import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:glamora/models/ReviewsModel.dart';
import 'package:glamora/models/productModel.dart';

class CartProducts extends Serum {
  final String pieces;
  final String total;

  CartProducts({
    required this.pieces,
    required this.total,
    required String title,
    required String description,
    required String features,
    required String usage,
    required int oldPrice,
    required int newPrice,
    required int discount,
    required int stock,
    required int totalOrders,
    required List<ProductReviewsModel> reviews,
    required List<String> photoUrl,
    required String dimensions,
  }) : super(
      title: title,
      description: description,
      features: features,
      usage: usage,
      oldPrice: oldPrice,
      newPrice: newPrice,
      discount: discount,
      stock: stock,
      totalOrders: totalOrders,
      reviews: reviews,
      photoUrl: photoUrl,
      dimensions: dimensions);

  factory CartProducts.fromSnapshot(DocumentSnapshot snapshot) {
    Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
    return CartProducts(
      pieces: data['pieces'] ?? '',
      total: data['total'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      features: data['features'] ?? '',
      usage: data['usage'] ?? '',
      oldPrice: data['oldPrice'] ?? 0,
      newPrice: data['newPrice'] ?? 0,
      discount: data['discount'] ?? 0,
      stock: data['stock'] ?? 0,
      totalOrders: data['totalOrders'] ?? 0,
      reviews: List<ProductReviewsModel>.from(data['reviews']?.map((review) => ProductReviewsModel.fromMap(review)) ?? []),
      photoUrl: List<String>.from(data['imageUrls'] ?? []),
      dimensions: data['dimensions'] ?? '',
    );
  }

  // Method to convert CartProducts object to a map
  Map<String, dynamic> toMap() {
    return {
      'pieces': pieces,
      'total': total,
      'title': title,
      'newPrice': newPrice,
      'discount': discount,
      'imageUrls': photoUrl[0],
      'reviewed':false
    };
  }
}
