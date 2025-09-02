import 'package:flutter/cupertino.dart';

class DarkModeProvider with ChangeNotifier{
  bool _isDarkMode = true;
  bool get isDarkMode => _isDarkMode;

  void toggleMode(bool isDark) {
    _isDarkMode = isDark;
    notifyListeners();
  }
}