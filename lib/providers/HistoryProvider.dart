import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:glamora/models/HistoryModel.dart';

class HistoryProvider with ChangeNotifier {
  List<HistoryModel> _historyModelList = [];

  List<HistoryModel> get historyModelList => _historyModelList;

  int? _selectedOrderHistory;
  int? get selectedOrderHistory => _selectedOrderHistory;

  // Add History item to the list
  void addHistoryProducts(HistoryModel historyModel) {
    _historyModelList.add(historyModel);
    notifyListeners();
  }

  // Update the status of a specific history item
  void updateSeenStatus(int index) {
    _historyModelList[index].status = "seen";
    notifyListeners();
  }

  Future<void> fetchOrderHistory() async {
    try {
      var querySnapshot = await FirebaseFirestore.instance
          .collection("History")
          .doc(FirebaseAuth.instance.currentUser!.email)
          .collection("orderHistory")
          .get();

      if (querySnapshot.docs.isEmpty) {
        return;
      }

      final historyItems = querySnapshot.docs.map((doc) {
        return HistoryModel.fromSnapshot(doc);
      }).toList();

      _historyModelList = historyItems.toList();

      notifyListeners();
    } catch (e) {
      print("Error fetching history: $e");
    }
  }

  void setSelectedOrderHistory(int index){
    _selectedOrderHistory = index;
    notifyListeners();
  }
}
