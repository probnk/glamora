import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:glamora/models/productModel.dart';
import 'package:fuzzy/fuzzy.dart';
import 'dart:async';

class SearchProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<ClothingProductModel> _searchResults = [];
  List<String> _suggestions = [];
  String _query = '';
  bool _isLoading = false;
  Timer? _debounce;
  Map<String, List<ClothingProductModel>> _cache = {};
  final List<String> _defaultKeywords = ['t-shirt', 'pant', 'hoodie', 'man', 'woman'];
  StreamController<List<ClothingProductModel>>? _searchController;

  List<ClothingProductModel> get searchResults => _searchResults;
  List<String> get suggestions => _suggestions;
  String get query => _query;
  bool get isLoading => _isLoading;

  SearchProvider() {
    _searchController = StreamController<List<ClothingProductModel>>.broadcast();
  }

  void setQuery(String value) {
    _query = value.trim().toLowerCase();
    notifyListeners();

    // Update suggestions on every keystroke
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchSuggestions();
      if (_query.isNotEmpty) {
        _performSearch();
      }
    });
  }

  void _performSearch() async {
    if (_query.isEmpty) {
      // Don't clear results when query is empty, just don't search
      return;
    }

    // Check cache first
    if (_cache.containsKey(_query)) {
      _searchResults = _cache[_query]!;
      _searchController?.add(_searchResults);
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final lowerQuery = _query.toLowerCase();
      List<ClothingProductModel> results = [];

      // Determine target collections based on query
      final (categories, genders) = _getTargetCollections(lowerQuery);

      for (var gender in genders) {
        for (var category in categories) {
          QuerySnapshot snapshot = await _firestore
              .collection('Cloths')
              .doc(gender)
              .collection(category)
              .get();

          for (var doc in snapshot.docs) {
            try {
              ClothingProductModel product = ClothingProductModel.fromSnapshot(doc);
              if (_matchesQuery(product, lowerQuery)) {
                results.add(product);
              }
            } catch (e) {
              print('Error parsing document ${doc.id} in $gender/$category: $e');
            }
          }
        }
      }

      // Cache and update results
      _cache[_query] = results;
      _searchResults = results;
      _isLoading = false;
      _searchController?.add(results);
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _searchController?.add([]);
      notifyListeners();
      print('Error searching products: $e');
    }
  }

  (List<String>, List<String>) _getTargetCollections(String query) {
    List<String> categories = ['T-Shirt', 'Pant', 'Hoodie'];
    List<String> genders = ['Man', 'Woman'];

    String? targetCategory;
    String? targetGender;

    // Check for category in query
    for (var cat in categories.map((c) => c.toLowerCase())) {
      if (query.contains(cat)) {
        targetCategory = categories.firstWhere((c) => c.toLowerCase() == cat);
        break;
      }
    }

    // Check for gender in query
    for (var gen in genders.map((g) => g.toLowerCase())) {
      if (query.contains(gen)) {
        targetGender = genders.firstWhere((g) => g.toLowerCase() == gen);
        break;
      }
    }

    return (
    targetCategory != null ? [targetCategory] : categories,
    targetGender != null ? [targetGender] : genders
    );
  }

  bool _matchesQuery(ClothingProductModel product, String query) {
    if (query.isEmpty) return false;

    final searchFields = [
      product.title.toLowerCase(),
      product.category.toLowerCase(),
      product.gender.toLowerCase(),
      product.description.toLowerCase(),
      ...product.tags.map((tag) => tag.toLowerCase()),
    ];

    // Simple contains check first for performance
    for (var field in searchFields) {
      if (field.contains(query)) return true;
    }

    // Fuzzy search as fallback
    final fuzzy = Fuzzy(searchFields);
    final fuzzyResults = fuzzy.search(query);
    return fuzzyResults.isNotEmpty && fuzzyResults.first.score > 0.2;
  }

  Stream<List<ClothingProductModel>> get searchStream {
    return _searchController!.stream;
  }

  void _fetchSuggestions() async {
    if (_query.isEmpty) {
      _suggestions = _defaultKeywords;
      notifyListeners();
      return;
    }

    List<String> tempSuggestions = [];
    try {
      // Add default keywords if they match
      final fuzzy = Fuzzy(_defaultKeywords);
      final defaultMatches = fuzzy.search(_query);
      tempSuggestions.addAll(
          defaultMatches.where((r) => r.score > 0.2).map((r) => r.item));

      // Fetch recent products for suggestions
      if (tempSuggestions.length < 5) {
        final recentProducts = await _fetchRecentProducts();
        for (var product in recentProducts) {
          final fieldsToSearch = [
            product.title.toLowerCase(),
            product.category.toLowerCase(),
            product.gender.toLowerCase(),
            ...product.tags.map((tag) => tag.toLowerCase()),
          ];

          for (var field in fieldsToSearch) {
            if (field.contains(_query) && !tempSuggestions.contains(field)) {
              tempSuggestions.add(field);
              if (tempSuggestions.length >= 5) break;
            }
          }
          if (tempSuggestions.length >= 5) break;
        }
      }

      // Filter and limit suggestions
      _suggestions = tempSuggestions.take(5).toList();
    } catch (e) {
      print('Error fetching suggestions: $e');
      _suggestions = _defaultKeywords;
    }
    notifyListeners();
  }

  Future<List<ClothingProductModel>> _fetchRecentProducts() async {
    List<ClothingProductModel> products = [];
    try {
      // Fetch a few recent products from each category for suggestions
      List<String> categories = ['T-Shirt', 'Pant', 'Hoodie'];
      List<String> genders = ['Man', 'Woman'];

      for (var gender in genders) {
        for (var category in categories) {
          QuerySnapshot snapshot = await _firestore
              .collection('Cloths')
              .doc(gender)
              .collection(category)
              .limit(2)
              .get();

          for (var doc in snapshot.docs) {
            try {
              ClothingProductModel product = ClothingProductModel.fromSnapshot(doc);
              products.add(product);
            } catch (e) {
              print('Error parsing suggestion document: $e');
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching recent products: $e');
    }
    return products;
  }

  // New method: Clear only text and suggestions, keep results
  void clearText() {
    _query = '';
    _suggestions = _defaultKeywords;
    _debounce?.cancel();
    notifyListeners();
  }

  // Clear everything including results
  void clearSearch() {
    _query = '';
    _searchResults = [];
    _suggestions = _defaultKeywords;
    _searchController?.add([]);
    _debounce?.cancel();
    notifyListeners();
  }

  void clearCache() {
    _cache.clear();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController?.close();
    super.dispose();
  }
}