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
    _sortHistory();
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
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection("orderHistory")
          .get();

      if (querySnapshot.docs.isEmpty) {
        _historyModelList = [];
      } else {
        final historyItems = querySnapshot.docs.map((doc) {
          return HistoryModel.fromSnapshot(doc);
        }).toList();

        _historyModelList = historyItems;
        _sortHistory();
      }
    } catch (e) {
      print("Error fetching history: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _sortHistory() {
    _historyModelList.sort((a, b) {
      // First compare dates in descending order
      final dateComparison = b.orderDate.compareTo(a.orderDate);
      if (dateComparison != 0) return dateComparison;

      // If dates are the same, compare times in descending order
      return b.orderTime.compareTo(a.orderTime);
    });
  }

  void setSelectedOrderHistory(int index) {
    _selectedOrderHistory = index;
    notifyListeners();
  }
}