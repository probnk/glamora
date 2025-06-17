import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:glamora/models/productModel.dart';

class CartProducts extends ClothingProductModel {
  final int pieces;
  final String total;
  final String size;
  final Color colorHex; // ✅ Store hex string instead of Color

  CartProducts({
    required String id,
    required this.pieces,
    required this.total,
    required String title,
    required int price,
    required int discount,
    required this.size,
    required String gender,
    required String category,
    required List<String> photoUrl,
    required this.colorHex
  }) : super(
    id: id,
    title: title,
    price: price,
    discount: discount,
    images: photoUrl,
    gender: gender,
    category: category,
  );

  /// Helper: Get usable Color from hex
  factory CartProducts.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    Color color = Color(int.parse(data['colors'], radix: 16));
    return CartProducts(
      id: data['id'] ?? '',
      pieces: data['pieces'] ?? 0,
      total: data['total'] ?? '',
      title: data['title'] ?? '',
      price: data['price'] ?? 0,
      discount: data['discount'] ?? 0,
      size: data['size'] ?? '',
      gender: data['gender'] ?? '',
      category: data['category'] ?? '',
      photoUrl: List<String>.from(data['imageUrls'] ?? []),
      colorHex: color// 👈 converts it directly to Color, // default black
    );
  }
  factory CartProducts.fromMap(Map<String, dynamic> data) {
    Color color = Color(int.parse(data['colors'], radix: 16));
    return CartProducts(
      id: data['id'] ?? '',
      pieces: data['pieces'] ?? 0,
      total: data['total'] ?? '',
      title: data['title'] ?? '',
      price: data['price'] ?? 0,
      discount: data['discount'] ?? 0,
      size: data['size'] ?? '',
      gender: data['gender'] ?? '',
      category: data['category'] ?? '',
      photoUrl: List<String>.from(data['imageUrls'] ?? []),
      colorHex: color,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pieces': pieces,
      'total': total,
      'title': title,
      'price': price,
      'discount': discount,
      'size': size,
      'gender': gender,
      'category': category,
      'imageUrls': images,
      'colors': colorHex.value.toRadixString(16),
    };
  }
}