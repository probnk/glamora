import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:glamora/models/ReviewsModel.dart';

class _UploadedImage {
  final File localFile;
  final String remoteUrl;
  final String storagePath; // keeps reference for deletion

  const _UploadedImage({
    required this.localFile,
    required this.remoteUrl,
    required this.storagePath,
  });
}

class ReviewProvider with ChangeNotifier {
  final _firestore = FirebaseFirestore.instance.collection("Cloths");

  // ── Star rating ─────────────────────────────────────────────────────────────
  int _selectedStarRating = 5;
  int get selectedStarRating => _selectedStarRating;

  void setStarRating(int index) {
    _selectedStarRating = index;
    notifyListeners();
  }

  // ── Loading ─────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void toggleLoading(bool isTrue) {
    _isLoading = isTrue;
    notifyListeners();
  }

  // ── Uploaded images (local + remote) ────────────────────────────────────────
  final List<_UploadedImage> _uploadedImages = [];

  /// Public: just the remote URLs (for saving to Firestore)
  List<String> get productPhotoUrls =>
      _uploadedImages.map((e) => e.remoteUrl).toList();

  /// Public: local files shown in the grid (for display before / during upload)
  List<File> get localImageFiles =>
      _uploadedImages.map((e) => e.localFile).toList();

  int get imageCount => _uploadedImages.length;

  // ── Add an image after upload completes ────────────────────────────────────
  void addUploadedImage({
    required File localFile,
    required String remoteUrl,
    required String storagePath,
  }) {
    _uploadedImages.add(_UploadedImage(
      localFile: localFile,
      remoteUrl: remoteUrl,
      storagePath: storagePath,
    ));
    notifyListeners();
  }

  // ── Delete image (both from Storage and from local list) ────────────────────
  Future<void> deleteImage(int index) async {
    if (index < 0 || index >= _uploadedImages.length) return;
    final img = _uploadedImages[index];
    try {
      // Delete from Firebase Storage
      await FirebaseStorage.instance.ref(img.storagePath).delete();
    } catch (_) {
      // If already deleted or path wrong, ignore
    }
    _uploadedImages.removeAt(index);
    notifyListeners();
  }

  // ── Clear all ───────────────────────────────────────────────────────────────
  void clearImages() {
    _uploadedImages.clear();
    _isLoading = false;
    notifyListeners();
  }

  void resetForm() {
    clearImages();
    _selectedStarRating = 5;
    notifyListeners();
  }

  // ── Submit review for ONE product ───────────────────────────────────────────
  Future<void> submitReview({
    required String docId,
    required String gender,
    required String category,
    required ProductReviewModel newReview,
  }) async {
    toggleLoading(true);
    try {
      await _firestore
          .doc(gender)
          .collection(category)
          .doc(docId)
          .update({'reviews': FieldValue.arrayUnion([newReview.toMap()])});
      resetForm();
    } catch (e) {
      debugPrint("Error submitting review: $e");
      rethrow;
    } finally {
      toggleLoading(false);
    }
  }

  // ── Submit review for MULTIPLE products in one order ────────────────────────
  /// [products] is a list of maps with keys: docId, gender, category
  Future<void> submitReviewForMultipleProducts({
    required List<Map<String, String>> products,
    required ProductReviewModel newReview,
  }) async {
    toggleLoading(true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final p in products) {
        final ref = _firestore
            .doc(p['gender']!)
            .collection(p['category']!)
            .doc(p['docId']!);
        // Firestore batch doesn't support arrayUnion; use set+merge workaround
        // or call update individually (fine for small product counts)
        batch.update(ref, {
          'reviews': FieldValue.arrayUnion([newReview.toMap()])
        });
      }
      await batch.commit();
      resetForm();
    } catch (e) {
      debugPrint("Error submitting multi-product review: $e");
      rethrow;
    } finally {
      toggleLoading(false);
    }
  }
}