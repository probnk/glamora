import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:glamora/models/wishListProducts.dart';
import '../Guest Local Storage/WishlistLocalStorage.dart';

class WishListProvider with ChangeNotifier {
  List<WishlistProducts> _wishListProducts = [];
  List<WishlistProducts> get wishListProducts => _wishListProducts;

  // Fetch wishlist items from Firestore or Local Storage
  Future<void> fetchClothsList() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      // Fetch from Firestore if user is logged in
      final querySnapshot = await FirebaseFirestore.instance
          .collection('WishList')
          .doc("${FirebaseAuth.instance.currentUser!.email}")
          .collection('Cloths')
          .get();

      _wishListProducts = querySnapshot.docs.map((doc) {
        return WishlistProducts.fromSnapshot(doc);
      }).toList();
    } else {
      // Fetch from local storage if the user is not logged in
      List<WishlistProducts> localWishList =
      await WishlistLocalStorageService().loadWishlistFromLocal();
      _wishListProducts = localWishList;
    }

    // Deduplicate the list just in case
    _wishListProducts = {
      for (var item in _wishListProducts) item.id: item
    }.values.toList();

    notifyListeners();
  }

  // Store wishlist item in Firestore or Local Storage
  Future<void> storeClothsList(WishlistProducts cloths) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      // Store in Firestore if user is logged in
      try {
        await FirebaseFirestore.instance
            .collection("WishList")
            .doc(FirebaseAuth.instance.currentUser!.email)
            .collection("Cloths")
            .doc(cloths.id)
            .set(cloths.toMap());
        print("Uploaded to Firestore");
      } catch (e) {
        print("Error uploading to Firestore: $e");
      }
    } else {
      // Check if the item already exists before storing
      final exists =
      _wishListProducts.any((element) => element.id == cloths.id);
      if (!exists) {
        _wishListProducts.add(cloths);
      }

      await WishlistLocalStorageService()
          .saveWishlistToLocal(_wishListProducts);
    }

    notifyListeners();
  }

  // Delete wishlist item from Firestore or Local Storage
  Future<void> deleteWishListItem(String id) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      // Remove from Firestore if user is logged in
      try {
        await FirebaseFirestore.instance
            .collection("WishList")
            .doc(FirebaseAuth.instance.currentUser!.email)
            .collection("Cloths")
            .doc(id)
            .delete();
        print("Deleted from Firestore");
      } catch (e) {
        print("Error deleting from Firestore: $e");
      }
    } else {
      // Remove from local storage if user is not logged in
      await WishlistLocalStorageService().removeItemFromLocal(id);
    }

    // Remove from local list
    _wishListProducts.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  // Add a wishlist item (if not already present)
  void addWishListItem(WishlistProducts cloths) {
    final exists = _wishListProducts.any((item) => item.id == cloths.id);
    if (!exists) {
      _wishListProducts.add(cloths);
      storeClothsList(cloths); // Store it in Firestore or local storage
      notifyListeners();
    }
  }

  // Remove a wishlist item
  void removeWishListItems(String id) {
    _wishListProducts.removeWhere((item) => item.id == id);
    deleteWishListItem(id); // Remove it from Firestore or local storage
    notifyListeners();
  }
}
