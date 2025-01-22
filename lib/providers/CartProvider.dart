import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:glamora/models/cartProducts.dart';

class CartProvider with ChangeNotifier {
  List<CartProducts> _cartItems = [];
  List<CartProducts> get cartItems => _cartItems;

  int _totalAmount = 0;
  int get totalAmount => _totalAmount;

  final String _currentUserEmail = FirebaseAuth.instance.currentUser!.email.toString();

  // Adding product to the cart
  void addProductToCart(CartProducts product) {
    _cartItems.add(product);
    _calculateTotal();
    notifyListeners();
  }

  // Removing product from the cart
  void removeProductFromCart(String title) {
    _cartItems.removeWhere((item) => item.title == title);
    if(_cartItems.isNotEmpty){
      _calculateTotal();
    }
    notifyListeners();
  }

  // Calculate the total amount of the cart
  void _calculateTotal() {
    _totalAmount = _cartItems.fold(0, (sum, item) => sum + int.parse(item.total));
    notifyListeners();
  }

  // Save the cart item (CartProducts) to Firestore
  Future<void> storeSerumList(CartProducts serum) async {
    try {
      final productData = {
        'title': serum.title,
        'description': serum.description,
        'features': serum.features,
        'usage': serum.usage,
        'oldPrice': serum.oldPrice,
        'newPrice': serum.newPrice,
        'discount': serum.discount,
        'stock': serum.stock,
        'totalOrders': serum.totalOrders,
        'reviews': serum.reviews.map((review) => review.toMap()).toList(), // Map each review to a map
        'imageUrls': serum.photoUrl,  // List of photo URLs
        'dimensions': serum.dimensions,
        'pieces': serum.pieces,
        'total': serum.total,
      };

      // Save the product data to Firestore
      await FirebaseFirestore.instance
          .collection("Cart")
          .doc(FirebaseAuth.instance.currentUser!.email)
          .collection("items")
          .doc(serum.title)  // Use the product title as the document ID
          .set(productData);

      print("Uploaded successfully");
    } catch (e) {
      print("Failed to upload: $e");
    }
  }


  // Fetch user cart from Firestore (to restore saved cart items)
  Future<void> fetchUserCartFromFirestore() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('Cart')
          .doc(_currentUserEmail)
          .collection('items')
          .get();

      final cartItems = querySnapshot.docs.map((doc) {
        return CartProducts.fromSnapshot(doc);
      }).toList();

      _cartItems = cartItems;
      _calculateTotal();  // Recalculate total amount from the cart items
    } catch (error) {
      print("Error fetching user cart: $error");
    }
    notifyListeners();
  }

  // Optionally: Remove a cart item from Firestore
  Future<void> deleteCartItem(CartProducts item) async {
    try{
      await FirebaseFirestore.instance
          .collection("Cart")
          .doc(FirebaseAuth.instance.currentUser!.email)
          .collection("items")
          .doc(item.title)
          .delete();
    } catch(e) {
      print(e);
    }
    notifyListeners();
  }
}
