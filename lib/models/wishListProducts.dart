import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:glamora/models/productModel.dart';

class WishlistProducts extends ClothingProductModel {
  final bool isFav;
  WishlistProducts({
    required String id,
    required String title,
    required int price,
    required int discount,
    required List<String> images,
    required String category,
    required String gender,
    required this.isFav
  }) : super(
    id: id,
    title: title,
    price: price,
    discount: discount,
    images: images,
    category: category,
    gender: gender
  );

  factory WishlistProducts.fromSnapshot(DocumentSnapshot snapshot) {
    Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;

    return WishlistProducts(
      id: data['id'] ?? "",
      title: data['title'] ?? '',
      price: data['price'] ?? 0,
      discount: data['discount'] ?? 0,
      images: List<String>.from(data['imageUrls'] ?? []),
      category: data['category'] ?? "",
      gender: data['gender'] ?? "",
      isFav: data['isFav'] ?? false,
    );
  }

  factory WishlistProducts.fromMap(Map<String, dynamic> data) {
    return WishlistProducts(
      id: data['id'] ?? "",
      title: data['title'] ?? '',
      price: data['price'] ?? 0,
      discount: data['discount'] ?? 0,
      images: List<String>.from(data['imageUrls'] ?? []),
      category: data['category'] ?? "",
      gender: data['gender'] ?? "",
      isFav: data['isFav'] ?? false,
    );
  }


  Map<String, dynamic> toMap() {
    return {
      'id':id,
      'title': title,
      'discount': discount,
      'price': price,
      'imageUrls':images,
      'category': category,
      'gender': gender,
      'isFav': isFav
    };
  }
}
