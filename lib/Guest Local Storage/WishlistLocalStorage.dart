import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:glamora/models/wishListProducts.dart';

class WishlistLocalStorageService {
  static const String _wishlistKey = 'wishlist';

  // Save wishlist to local storage
  Future<void> saveWishlistToLocal(List<WishlistProducts> wishlist) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Remove duplicates based on item ID
    final Map<String, WishlistProducts> uniqueMap = {
      for (var item in wishlist) item.id: item
    };

    List<String> wishlistJson =
    uniqueMap.values.map((item) => json.encode(item.toMap())).toList();

    await prefs.setStringList(_wishlistKey, wishlistJson);
  }

  // Load wishlist from local storage
  Future<List<WishlistProducts>> loadWishlistFromLocal() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? wishlistJson = prefs.getStringList(_wishlistKey);

    if (wishlistJson == null) return [];

    return wishlistJson.map((item) {
      Map<String, dynamic> wishlistData = json.decode(item);
      return WishlistProducts.fromMap(wishlistData);
    }).toList();
  }

  // Remove a specific item from local storage
  Future<void> removeItemFromLocal(String itemId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? wishlistJson = prefs.getStringList(_wishlistKey);

    if (wishlistJson != null) {
      wishlistJson.removeWhere((item) {
        Map<String, dynamic> wishlistData = json.decode(item);
        return wishlistData['id'] == itemId;
      });
      await prefs.setStringList(_wishlistKey, wishlistJson);
    }
  }
}
