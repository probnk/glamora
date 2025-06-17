import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:glamora/models/ColorVariantModel.dart';
import 'package:glamora/models/ReviewsModel.dart';

class ClothingProductModel {
  String id;
  String title;
  String description;
  List<String> tags;
  String type;
  String category;
  String gender;
  int price; // Added price field
  int discount;
  List<String> images;
  String front;
  String back;
  int totalOrders;
  List<ClothingVariantModel> variants;
  List<ProductReviewModel> reviews;
  String createdAt;
  String updatedAt;

  ClothingProductModel({
    this.id = "",
    this.title = "",
    this.description = "",
    this.tags = const [],
    this.type = "",
    this.category = "",
    this.gender = "",
    this.price = 0,
    this.discount = 0,
    this.images = const [],
    this.front = "",
    this.back = "",
    this.totalOrders = 0,
    this.variants = const [],
    this.reviews = const [],
    this.createdAt = "",
    this.updatedAt = "",
  });

  factory ClothingProductModel.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;

    return ClothingProductModel(
      id: data['id'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      type: data['type'] ?? '',
      category: data['category'] ?? '',
      gender: data['gender'] ?? '',
      price: (data['price'] as num?)?.toInt() ?? 0,
      discount: data['discount'],
      images: List<String>.from(data['images'] ?? []),
      front: data['front'],
      back: data['back'] ?? '',
      totalOrders: data['totalOrders'],
      variants: (data['variants'] as List<dynamic>?)
          ?.map((v) => ClothingVariantModel.fromMap(v))
          .toList() ?? [],
      reviews: (data['reviews'] as List<dynamic>?)
          ?.map((r) => ProductReviewModel.fromMap(r))
          .toList() ?? [],
      createdAt: data['createdAt'] ?? '',
      updatedAt: data['updatedAt'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'tags': tags,
      'type': type,
      'category': category,
      'gender': gender,
      'price': price,
      'discount':discount,
      'images': images,
      'front': front,
      'back': back,
      'totalOrders': totalOrders,
      'variants': variants.map((v) => v.toMap()).toList(),
      'reviews': reviews.map((r) => r.toMap()).toList(),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}