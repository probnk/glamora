import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/returnRequestModel.dart';

/// Firestore path:
///   Return/{uid}/requests/{returnId}     ← customer's own returns
///   collectionGroup('requests')          ← seller sees all (requires index)

class ReturnProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── State ──────────────────────────────────────────────────────────────────
  List<ReturnRequest> _allReturns = []; // seller
  List<ReturnRequest> _myReturns = []; // customer (real-time)
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _error;

  StreamSubscription? _myReturnsSub;
  StreamSubscription? _allReturnsSub;

  // ── Getters ────────────────────────────────────────────────────────────────
  List<ReturnRequest> get allReturns => _allReturns;
  List<ReturnRequest> get myReturns => _myReturns;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get error => _error;

  List<ReturnRequest> get pendingReturns =>
      _allReturns.where((r) => r.status == ReturnStatus.pending).toList();

  // ── Helpers ────────────────────────────────────────────────────────────────
  CollectionReference _requestsRef(String uid) =>
      _db.collection('Return').doc(uid).collection('requests');

  /// Returns existing ReturnRequest for a given orderId if it already exists
  /// in the locally cached [_myReturns]. Call [listenToMyReturns] first so the
  /// cache is populated before navigating to the return screen.
  ReturnRequest? existingReturnForOrder(String orderId) {
    try {
      return _myReturns.firstWhere((r) => r.orderId == orderId);
    } catch (_) {
      return null;
    }
  }

  // ── Customer: real-time listener ───────────────────────────────────────────
  /// Call this once after login / when the customer order section mounts.
  /// Cancels any previous subscription automatically.
  void listenToMyReturns(String uid) {
    _myReturnsSub?.cancel();
    _isLoading = true;
    _error = null;
    notifyListeners();

    _myReturnsSub = _requestsRef(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snap) {
        _myReturns =
            snap.docs.map((d) => ReturnRequest.fromSnapshot(d)).toList();
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  /// Stop listening when the customer logs out.
  void stopListeningToMyReturns() {
    _myReturnsSub?.cancel();
    _myReturnsSub = null;
    _myReturns = [];
  }

  // ── Customer: submit ───────────────────────────────────────────────────────
  Future<bool> submitReturn({
    required String uid,
    required String orderId,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required List<ReturnedItemModel> items,
    required String reason,
    String? additionalNote,
  }) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();

    try {
      final docRef = _requestsRef(uid).doc();
      final now = DateTime.now();
      final request = ReturnRequest(
        returnId: docRef.id,
        orderId: orderId,
        uid: uid,
        customerName: customerName,
        customerEmail: customerEmail,
        customerPhone: customerPhone,
        items: items,
        reason: reason,
        additionalNote: additionalNote,
        submittedDate: DateFormat('dd MMM, yyyy').format(now),
        createdAt: now.toIso8601String(),
        status: ReturnStatus.pending,
      );

      await docRef.set(request.toMap());

      _isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  // ── Seller: real-time listener via collectionGroup ─────────────────────────
  void listenToAllReturns() {
    _allReturnsSub?.cancel();
    _allReturnsSub = _db
        .collectionGroup('requests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snap) {
        _allReturns =
            snap.docs.map((d) => ReturnRequest.fromSnapshot(d)).toList();
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  void stopListeningToAllReturns() {
    _allReturnsSub?.cancel();
    _allReturnsSub = null;
    _allReturns = [];
  }

  // ── Seller: update status ─────────────────────────────────────────────────
  Future<bool> updateReturnStatus({
    required String uid,
    required String returnId,
    required ReturnStatus status,
    String? sellerNote,
  }) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final updates = <String, dynamic>{
        'status': status.name,
        if (sellerNote != null) 'sellerNote': sellerNote,
        if (status == ReturnStatus.completed || status == ReturnStatus.rejected)
          'resolvedDate': DateFormat('dd MMM, yyyy').format(now),
      };

      await _requestsRef(uid).doc(returnId).update(updates);

      // Optimistic local update (listener will also fire, so this just avoids
      // a brief flicker)
      _allReturns = _allReturns.map((r) {
        if (r.returnId != returnId) return r;
        return r.copyWith(
          status: status,
          sellerNote: sellerNote,
          resolvedDate: updates['resolvedDate'] as String?,
        );
      }).toList();

      _isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _myReturnsSub?.cancel();
    _allReturnsSub?.cancel();
    super.dispose();
  }
}