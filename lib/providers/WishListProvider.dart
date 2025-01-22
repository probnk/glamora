import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:glamora/models/productModel.dart';

class WishListProvider with ChangeNotifier {
  List<Serum> _wishListProducts = [];

  List<Serum> get wishListProducts => _wishListProducts;

  Future<void> fetchSerumList() async {
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('WishList')
        .doc("${FirebaseAuth.instance.currentUser!.email}")
        .collection("Serums")
        .get();
    _wishListProducts =
        querySnapshot.docs.map((doc) => Serum.fromSnapshot(doc)).toList();
    notifyListeners();
  }

  Future<void> storeSerumList(Serum serum) async {
    try{
      final productData = {
        'title': serum.title,
        'description': serum.description,
        'features': serum.features,
        'usage': serum.usage,
        'oldPrice': serum.oldPrice,
        'newPrice':serum.newPrice,
        'discount': serum.discount,
        'stock': serum.stock,
        'dimensions': serum.dimensions,
        'imageUrls': serum.photoUrl,
        'reviews': serum.reviews,
      };
      await FirebaseFirestore.instance
          .collection("WishList")
          .doc(FirebaseAuth
          .instance.currentUser!.email)
          .collection("Serums")
          .doc(serum.title)
          .set(productData);
      print("Uploaded");
    } catch(e) {
      print("Not Uploaded");
    }
  }

  Future<void> deleteWishListItem(String title) async {
    try {
      await FirebaseFirestore.instance
          .collection("WishList")
          .doc(FirebaseAuth.instance.currentUser!.email)
          .collection("Serums")
          .doc(title)
          .delete();
      print("Deleted from Firestore");
    } catch (e) {
      print("Error deleting from Firestore: $e");
    }
  }

  void addWishListItem(Serum serum) {
    _wishListProducts.add(serum);
    notifyListeners();
  }

  void removeWishListItems(String title) {
    _wishListProducts.removeWhere((item) => item.title == title);
    notifyListeners();
  }
}
