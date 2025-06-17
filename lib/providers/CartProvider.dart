import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:glamora/Guest%20Local%20Storage/CartLocalStorage.dart';
import 'package:glamora/models/cartProducts.dart';

class CartProvider with ChangeNotifier {
  List<CartProducts> _cartItems = [] ;
  List<CartProducts> get cartItems => _cartItems ?? [];
  int _totalAmount = 0;
  int get totalAmount => _totalAmount;

  void addProductToCart(CartProducts product) {
    if (_cartItems.any((item) => item.id == product.id)) {
      // Already exists; optionally increase quantity instead
      return;
    }
    _cartItems.add(product);
    _calculateTotal();
    notifyListeners();
  }


  /// Remove from cart
  void removeProductFromCart(String id) {
    _cartItems.removeWhere((item) => item.id == id);
    if (_cartItems.isNotEmpty) {
      _calculateTotal();
    }
    notifyListeners();
  }

  /// Total bill
  void _calculateTotal() {
    _totalAmount = _cartItems.fold(0, (sum, item) => sum + int.parse(item.total));
    notifyListeners();
  }

  Future<void> storeClothsList(CartProducts cloths) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        final productData = cloths.toMap();
        await FirebaseFirestore.instance
            .collection("Cart")
            .doc(currentUser!.email.toString())
            .collection("items")
            .doc(cloths.id)
            .set(productData);
      } catch (e) {
        print("Failed to upload: $e");
      }
    } else {
      // ✅ Remove redundant addition
      await CartLocalStorageService().saveCartToLocal(_cartItems);
    }
    notifyListeners();
  }


  Future<void> fetchUserCartFromFirestore() async {
    print("Fetching cart...");

    final currentUser = FirebaseAuth.instance.currentUser;

    _cartItems.clear(); // clear old list before loading

    if (currentUser != null) {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('Cart')
            .doc(currentUser.email)
            .collection('items')
            .get();

        print("Fetched ${querySnapshot.docs.length} items from Firestore");

        _cartItems = querySnapshot.docs
            .map((doc) => CartProducts.fromSnapshot(doc))
            .toList();
      } catch (error) {
        print("Error fetching user cart: $error");
      }
    } else {
      print("User is guest — loading from local storage");
      _cartItems = await CartLocalStorageService().loadCartFromLocal();
    }

    _calculateTotal();
    notifyListeners();
  }



  /// Remove cart item from Firestore
  Future<void> deleteCartItem(CartProducts item) async {
    final currentUser = FirebaseAuth.instance.currentUser;
   if(currentUser != null) {
     try {
       await FirebaseFirestore.instance
           .collection("Cart")
           .doc(currentUser!.email.toString())
           .collection("items")
           .doc(item.id)
           .delete();
     } catch (e) {
       print(e);
     }
   } else{
     await CartLocalStorageService().removeItemFromCartLocal(item.id);
   }
    notifyListeners();
  }
}
