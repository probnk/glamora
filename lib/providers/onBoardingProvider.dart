import 'dart:io';
import 'package:flutter/material.dart';

class GenderCategoryProvider with ChangeNotifier {
  bool _isLoading = false;
  String? _selectedGender;
  List<String> _selectedCategories = [];
  File? _selectedImage;

  bool get isLoading => _isLoading;
  String? get selectedGender => _selectedGender;
  List<String> get selectedCategories => _selectedCategories;
  File? get selectedImage => _selectedImage;

  void setSubmitLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void selectGender(String gender) {
    _selectedGender = gender;
    notifyListeners();
  }

  void toggleCategory(String category) {
    if (_selectedCategories.contains(category)) {
      _selectedCategories.remove(category);
    } else {
      _selectedCategories.add(category);
    }
    notifyListeners();
  }

  void setImage(File? image) {
    _selectedImage = image;
    notifyListeners();
  }

  void clear() {
    _selectedGender = null;
    _selectedCategories = [];
    _selectedImage = null;
    notifyListeners();
  }
}
