import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:glamora/models/cartProducts.dart'; // Import your CartProducts model

class CartLocalStorageService {
  // Save cart to local storage
  Future<void> saveCartToLocal(List<CartProducts> cart) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> cartJson =
        cart.map((item) => json.encode(item.toMap())).toList();
    await prefs.setStringList('cart', cartJson);
  }

  // Load cart from local storage
  Future<List<CartProducts>> loadCartFromLocal() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? cartJson = prefs.getStringList('cart');

    if (cartJson == null) return [];

    return cartJson.map((item) {
      Map<String, dynamic> cartData = json.decode(item);
      return CartProducts.fromMap(
          cartData); // Assuming CartProducts has a fromMap constructor
    }).toList();
  }

  // Remove a specific item from local storage (for cart)
  Future<void> removeItemFromCartLocal(String itemId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? cartJson = prefs.getStringList('cart');

    if (cartJson != null) {
      cartJson.removeWhere((item) {
        Map<String, dynamic> cartData = json.decode(item);
        return cartData['id'] == itemId;
      });
      await prefs.setStringList('cart', cartJson);
    }
  }
}
