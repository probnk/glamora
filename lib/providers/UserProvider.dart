import 'package:flutter/material.dart';

class UserProvider with ChangeNotifier {
  String _email = '';
  String _name = '';
  String _pictureUrl = '';

  // Getters
  String get email => _email;
  String get name => _name;
  String get pictureUrl => _pictureUrl;

  // Setters with notifyListeners to update UI
  void setUid(String email) {
    _email = email;
    notifyListeners();
  }

  void setName(String name) {
    _name = name;
    notifyListeners();
  }

  void setPictureUrl(String url) {
    _pictureUrl = url;
    notifyListeners();
  }

  // Optional: A method to set all at once
  void updateUser({required String email, required String name, required String pictureUrl}) {
    _email = email;
    _name = name;
    _pictureUrl = pictureUrl;
    notifyListeners();
  }

  void setUser({required String email, required String name, required String pictureUrl}) {
    _email = email;
    _name = name;
    _pictureUrl = pictureUrl;
    print("\n\n\n\n$_email|$_name|$_pictureUrl\n\n\n\n");
    notifyListeners();
  }
}
