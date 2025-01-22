import 'package:cloud_firestore/cloud_firestore.dart';

class WishListProducts {
  final List<String> photoUrl;
  final String title;
  final String subTitle;
  final String newPrice;
  final String oldPrice;
  final bool isFav;

  WishListProducts({
    required this.photoUrl,
    required this.title,
    required this.subTitle,
    required this.newPrice,
    required this.oldPrice,
    this.isFav = false,
  });

  factory WishListProducts.fromSnapshot(DocumentSnapshot snapshot) {
    Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
    return WishListProducts(
      photoUrl: List<String>.from(data['photoUrl'] ?? []),
      title: data['title'],
      subTitle: data['subTitle'],
      newPrice: data['newPrice'],
      oldPrice: data['oldPrice'],
      isFav: data['isFav'] ?? false,
    );
  }
}