import 'package:flutter/cupertino.dart';

import '../models/productModel.dart';

class ProductDetailsProvider with ChangeNotifier {
  bool _isCart = false;

  bool get isCart => _isCart;

  int _selectedColor = 0;

  int get selectedColor => _selectedColor;

  int _selectedSize = 0;

  int get selectedSize => _selectedSize;

  int _selectedImage = 0;

  int get selectedImage => _selectedImage;

  int _quantity = 1;

  int get quantity => _quantity;

  ClothingProductModel? _productDetails;

  ClothingProductModel? get productDetails => _productDetails;

  void resetQuantity() {
    _quantity = 1;
    notifyListeners();
  }

  void addValue() {
    _quantity = _quantity + 1;
    notifyListeners();
  }

  void subtractValue() {
    _quantity = _quantity - 1;
    notifyListeners();
  }

  void setIsCartProduct() {
    _isCart = !_isCart;
    notifyListeners();
  }

  void setSelectedImage(int image) {
    _selectedImage = image;
    notifyListeners();
  }

  void setSelectedColor(int index) {
    _selectedColor = index;
    notifyListeners();
  }

  void setSelectedSize(int index) {
    _selectedSize = index;
    notifyListeners();
  }

  void addProductDetails(ClothingProductModel product){
    _productDetails = product;
    notifyListeners();
  }
}
