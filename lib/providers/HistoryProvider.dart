import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:glamora/models/HistoryModel.dart';

class HistoryProvider with ChangeNotifier {
  List<HistoryModel> _historyModelList = [];
  List<HistoryModel> get historyModelList => _historyModelList;

  int? _selectedOrderHistory;
  int? get selectedOrderHistory => _selectedOrderHistory;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  void addHistoryProducts(HistoryModel historyModel) {
    _historyModelList.add(historyModel);
    notifyListeners();
  }

  void updateSeenStatus(int index) {
    _historyModelList[index].status = "seen";
    notifyListeners();
  }

  Future<void> fetchOrderHistory() async {
    _isLoading = true;
    notifyListeners();

    try {
      var querySnapshot = await FirebaseFirestore.instance
          .collection("History")
          .doc(FirebaseAuth.instance.currentUser!.email)
          .collection("orderHistory")
          .get();
      print("history: ${querySnapshot}");
      if (querySnapshot.docs.isEmpty) {
        _historyModelList = [];
      } else {
        final historyItems = querySnapshot.docs.map((doc) {
          return HistoryModel.fromSnapshot(doc);
        }).toList();

        _historyModelList = historyItems;
        print(_historyModelList);
      }
    } catch (e) {
      print("Error fetching history: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSelectedOrderHistory(int index) {
    _selectedOrderHistory = index;
    notifyListeners();
  }
}