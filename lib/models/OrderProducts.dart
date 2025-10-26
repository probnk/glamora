import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class OrderProducts {
  final String id;
  final int pieces;
  final String total;
  final String title;
  final int price;
  final int discount;
  final String size;
  final String gender;
  final String category;
  final List<String> photoUrl;
  final Color colorHex;

  OrderProducts({
    required this.id,
    required this.pieces,
    required this.total,
    required this.title,
    required this.price,
    required this.discount,
    required this.size,
    required this.gender,
    required this.category,
    required this.photoUrl,
    required this.colorHex,
  });

  factory OrderProducts.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    final color = Color(int.parse(data['colors'], radix: 16));
    return OrderProducts(
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

  factory OrderProducts.fromMap(Map<String, dynamic> data) {
    final color = Color(int.parse(data['colors'], radix: 16));
    return OrderProducts(
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
      'imageUrls': photoUrl,
      'colors': colorHex.value.toRadixString(16),
    };
  }
}
