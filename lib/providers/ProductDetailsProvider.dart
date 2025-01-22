import 'package:flutter/cupertino.dart';

class ProductDetailsProvider with ChangeNotifier{
bool _isCart = false;
bool get isCart => _isCart;

int _selectedImage = 0;
int get selectedImage => _selectedImage;

int _quantity = 1;
int get quantity => _quantity;

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

void setSelectedImage(int image){
    _selectedImage = image;
    notifyListeners();
  }
}