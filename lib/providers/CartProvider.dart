import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:glamora/Guest%20Local%20Storage/CartLocalStorage.dart';
import 'package:glamora/models/cartProducts.dart';

class CartProvider with ChangeNotifier {
  List<CartProducts> _cartItems = [];
  List<CartProducts> get cartItems => _cartItems;

  List<CartProducts> _selectedItems = [];
  List<CartProducts> get selectedItems => _selectedItems;

  bool _isSelectionMode = false;
  bool get isSelectionMode => _isSelectionMode;

  int _totalAmount = 0;
  int get totalAmount => _totalAmount;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void addProductToCart(CartProducts product) {
    if (_cartItems.any((item) => item.id == product.id)) {
      return;
    }
    _cartItems.add(product);
    _calculateTotal();
    notifyListeners();
  }

  void removeProductFromCart(String id) {
    _cartItems.removeWhere((item) => item.id == id);
    _selectedItems.removeWhere((item) => item.id == id);
    if (_cartItems.isNotEmpty) {
      _calculateTotal();
    }
    _checkSelectionMode();
    notifyListeners();
  }

  void _calculateTotal() {
    _totalAmount = _cartItems.fold(0, (sum, item) => sum + int.parse(item.total));
    notifyListeners();
  }

  // Selection methods
  void toggleItemSelection(CartProducts item) {
    if (_selectedItems.any((selected) => selected.id == item.id)) {
      _selectedItems.removeWhere((selected) => selected.id == item.id);
    } else {
      _selectedItems.add(item);
    }
    _checkSelectionMode();
    notifyListeners();
  }

  void addToSelectedItems(CartProducts item) {
    if (!_selectedItems.any((selected) => selected.id == item.id)) {
      _selectedItems.add(item);
    }
    _checkSelectionMode();
    notifyListeners();
  }

  void removeFromSelectedItems(CartProducts item) {
    _selectedItems.removeWhere((selected) => selected.id == item.id);
    _checkSelectionMode();
    notifyListeners();
  }

  void clearSelection() {
    _selectedItems.clear();
    _isSelectionMode = false;
    notifyListeners();
  }

  void _checkSelectionMode() {
    _isSelectionMode = _selectedItems.isNotEmpty;
  }

  // Calculate actual price considering discount
  int _calculateActualPrice(int price, int discount) {
    if (discount > 0) {
      return ((price / 100) * (100 - discount)).round();
    }
    return price;
  }

  // Update item quantity - FIXED VERSION
  void updateItemQuantity(String itemId, int newQuantity) {
    final itemIndex = _cartItems.indexWhere((item) => item.id == itemId);
    if (itemIndex != -1) {
      final item = _cartItems[itemIndex];

      // Calculate actual price with discount
      final actualPrice = _calculateActualPrice(item.price, item.discount);
      final newTotal = (actualPrice * newQuantity).toString();

      _cartItems[itemIndex] = CartProducts(
        id: item.id,
        pieces: newQuantity,
        total: newTotal,
        title: item.title,
        price: item.price,
        discount: item.discount,
        size: item.size,
        gender: item.gender,
        category: item.category,
        photoUrl: item.images,
        colorHex: item.colorHex,
      );

      _calculateTotal();
      _updateItemInStorage(_cartItems[itemIndex]);
      notifyListeners();
    }
  }

  Future<void> _updateItemInStorage(CartProducts item) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        await FirebaseFirestore.instance
            .collection("Cart")
            .doc(currentUser.uid)
            .collection("items")
            .doc(item.id)
            .update(item.toMap());
      } catch (e) {
        print("Failed to update item: $e");
      }
    } else {
      await CartLocalStorageService().saveCartToLocal(_cartItems);
    }
  }

  Future<void> storeClothsList(CartProducts cloths) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        final productData = cloths.toMap();
        await FirebaseFirestore.instance
            .collection("Cart")
            .doc(currentUser.uid)
            .collection("items")
            .doc(cloths.id)
            .set(productData);
      } catch (e) {
        print("Failed to upload: $e");
      }
    } else {
      await CartLocalStorageService().saveCartToLocal(_cartItems);
    }
    notifyListeners();
  }

  Future<void> fetchUserCartFromFirestore() async {
    print("Fetching cart...");
    _isLoading = true;

    final currentUser = FirebaseAuth.instance.currentUser;

    _cartItems.clear();
    _selectedItems.clear();
    _isSelectionMode = false;

    if (currentUser != null) {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('Cart')
            .doc(currentUser.uid)
            .collection('items')
            .get();

        print("Fetched ${querySnapshot.docs.length} items from Firestore");

        _cartItems = querySnapshot.docs
            .map((doc) => CartProducts.fromSnapshot(doc))
            .toList();
      } catch (error) {
        print("Error fetching user cart: $error");
        _isLoading = false;
      } finally {
        _isLoading = false;
      }
    } else {
      print("User is guest — loading from local storage");
      _cartItems = await CartLocalStorageService().loadCartFromLocal();
    }

    _calculateTotal();
    notifyListeners();
  }

  Future<void> deleteCartItem(CartProducts item) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        await FirebaseFirestore.instance
            .collection("Cart")
            .doc(currentUser.uid)
            .collection("items")
            .doc(item.id)
            .delete();
      } catch (e) {
        print(e);
      }
    } else {
      await CartLocalStorageService().removeItemFromCartLocal(item.id);
    }
    _selectedItems.removeWhere((selected) => selected.id == item.id);
    _checkSelectionMode();
    notifyListeners();
  }
}