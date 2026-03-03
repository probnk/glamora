import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:glamora/models/productModel.dart';
import 'dart:async';
import '../Services/personalization_service.dart';

class SearchProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<ClothingProductModel> _searchResults = [];
  List<String> _suggestions = [];
  String _query = '';
  String _lastSearchedQuery = ''; // Track last searched query
  bool _isLoading = false;
  Timer? _debounce;

  // Valid categories only
  final Map<String, List<String>> _categoryAliases = {
    'T-Shirt': ['tshirt', 't-shirt', 'tee', 'shirt', 'top', 'shrat', 'tshrat', 'tshart', 't shirt'],
    'Pant': ['pant', 'pants', 'trouser', 'trousers', 'jeans', 'jean', 'pent', 'bottom'],
    'Hoodie': ['hoodie', 'hoody', 'sweatshirt', 'jacket', 'sweater', 'hody', 'hudy', 'hoddie'],
  };

  final Map<String, List<String>> _genderAliases = {
    'Man': ['man', 'men', 'male', 'mens', 'boy', 'men\'s', 'mens\'', 'menz', 'mann'],
    'Woman': ['woman', 'women', 'female', 'womens', 'girl', 'women\'s', 'womens\'', 'ladies', 'lady', 'womanz'],
  };

  // Invalid search terms (not in our inventory)
  final List<String> _invalidCategories = [
    'shoe', 'shoes', 'sneaker', 'boot', 'sandal',
    'watch', 'bag', 'cap', 'hat', 'glasses',
    'belt', 'wallet', 'accessory', 'sock', 'socks'
  ];

  List<ClothingProductModel> get searchResults => _searchResults;
  List<String> get suggestions => _suggestions;
  String get query => _query;
  bool get isLoading => _isLoading;

  void initialize() {
    _suggestions = ['men t-shirt', 'women hoodie', 'men pant', 'women t-shirt', 'hoodie'];
  }

  void setQuery(String value) {
    _query = value.trim().toLowerCase();

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _updateSuggestions();
      if (_query.length >= 2) {
        performSearch();
      } else if (_query.isEmpty) {
        _searchResults = [];
        _lastSearchedQuery = '';
        notifyListeners();
      }
    });
  }

  void performSearch() async {
    if (_query.length < 2 || _query == _lastSearchedQuery) return;

    // Clear previous results immediately
    _searchResults = [];
    _lastSearchedQuery = _query;
    _isLoading = true;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Check if searching for invalid category
      bool isInvalidCategory = _invalidCategories.any((invalid) => _query.contains(invalid));

      if (isInvalidCategory) {
        _searchResults = [];
        _isLoading = false;
        notifyListeners();
        return; // Will show "We don't sell this" message
      }

      // Parse query to detect category and gender
      final detectedCategory = _detectCategory(_query);
      final detectedGender = _detectGender(_query);

      // Extract search terms (remove category and gender words)
      String cleanQuery = _getCleanQuery(_query, detectedCategory, detectedGender);

      List<ClothingProductModel> results = [];

      // Determine which collections to search
      List<String> gendersToSearch = detectedGender != null ? [detectedGender] : ['Man', 'Woman'];
      List<String> categoriesToSearch = detectedCategory != null
          ? [detectedCategory]
          : ['T-Shirt', 'Pant', 'Hoodie'];

      print('Searching: Category=$detectedCategory, Gender=$detectedGender, CleanQuery=$cleanQuery');
      print('Collections: $gendersToSearch x $categoriesToSearch');

      // Fetch products
      for (var gender in gendersToSearch) {
        for (var category in categoriesToSearch) {
          try {
            QuerySnapshot snapshot = await _firestore
                .collection('Cloths')
                .doc(gender)
                .collection(category)
                .get();

            print('Fetched ${snapshot.docs.length} docs from $gender/$category');

            for (var doc in snapshot.docs) {
              try {
                ClothingProductModel product = ClothingProductModel.fromSnapshot(doc);

                // Calculate relevance score
                double score = _calculateRelevanceScore(
                    product,
                    cleanQuery,
                    detectedCategory,
                    detectedGender
                );

                print('Product: ${product.title}, Score: $score');

                if (score > 0.3) {
                  results.add(product);
                }
              } catch (e) {
                print('Error parsing document ${doc.id}: $e');
              }
            }
          } catch (e) {
            print('Error fetching $gender/$category: $e');
          }
        }
      }

      print('Total results found: ${results.length}');

      // Sort by relevance (highest score first)
      results.sort((a, b) {
        double scoreA = _calculateRelevanceScore(a, cleanQuery, detectedCategory, detectedGender);
        double scoreB = _calculateRelevanceScore(b, cleanQuery, detectedCategory, detectedGender);
        return scoreB.compareTo(scoreA);
      });

      _searchResults = results;

      // Track personalization only if results found
      if (results.isNotEmpty) {
        final categoryForTracking = detectedCategory ?? 'T-Shirt';
        await trackPersonalization(
          user.uid,
          categoryForTracking,
          'search',
          'increment',
        );
      }

    } catch (e) {
      print('Search error: $e');
      _searchResults = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String? _detectCategory(String query) {
    // Check each category and its aliases
    for (var entry in _categoryAliases.entries) {
      for (var alias in entry.value) {
        if (query.contains(alias)) {
          return entry.key;
        }
      }
    }
    return null;
  }

  String? _detectGender(String query) {
    // Exact matching for gender to avoid confusion
    String? detectedGender;
    int maxMatchLength = 0;

    for (var entry in _genderAliases.entries) {
      for (var alias in entry.value) {
        // Use word boundary check for better accuracy
        if (query.contains(alias)) {
          // Prefer longer matches (e.g., "women" over "men")
          if (alias.length > maxMatchLength) {
            detectedGender = entry.key;
            maxMatchLength = alias.length;
          }
        }
      }
    }

    return detectedGender;
  }

  String _getCleanQuery(String query, String? category, String? gender) {
    String clean = query;

    // Remove category words
    if (category != null) {
      for (var alias in _categoryAliases[category]!) {
        clean = clean.replaceAll(alias, '');
      }
    }

    // Remove gender words
    if (gender != null) {
      for (var alias in _genderAliases[gender]!) {
        clean = clean.replaceAll(alias, '');
      }
    }

    // Remove extra spaces
    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();

    return clean;
  }

  double _calculateRelevanceScore(
      ClothingProductModel product,
      String cleanQuery,
      String? detectedCategory,
      String? detectedGender,
      ) {
    double score = 0.0;

    // Category match (very high weight) - MUST match if specified
    if (detectedCategory != null) {
      if (product.category == detectedCategory) {
        score += 5.0;
      } else {
        return 0.0; // Reject if category doesn't match
      }
    } else {
      score += 1.0; // Small boost for general search
    }

    // Gender match (very high weight) - MUST match if specified
    if (detectedGender != null) {
      if (product.gender == detectedGender) {
        score += 4.0;
      } else {
        return 0.0; // Reject if gender doesn't match
      }
    } else {
      score += 0.5; // Small boost for general search
    }

    // If no specific terms after removing category/gender, return base score
    if (cleanQuery.isEmpty) {
      return score;
    }

    // Title match
    if (product.title.toLowerCase().contains(cleanQuery)) {
      score += 3.0;
    }

    // Description match
    if (product.description.toLowerCase().contains(cleanQuery)) {
      score += 1.5;
    }

    // Tag match
    for (var tag in product.tags) {
      if (tag.toLowerCase().contains(cleanQuery) || cleanQuery.contains(tag.toLowerCase())) {
        score += 2.0;
        break;
      }
    }

    // Fuzzy match for typos (only if no exact matches)
    if (score < 2.0) {
      score += _fuzzyMatch(product.title.toLowerCase(), cleanQuery) * 2.0;
    }

    return score;
  }

  double _fuzzyMatch(String text, String query) {
    if (query.isEmpty) return 0;

    int matches = 0;
    int queryIndex = 0;

    for (int i = 0; i < text.length && queryIndex < query.length; i++) {
      if (text[i] == query[queryIndex]) {
        matches++;
        queryIndex++;
      }
    }

    return matches / query.length;
  }

  void _updateSuggestions() {
    if (_query.isEmpty) {
      _suggestions = ['men t-shirt', 'women hoodie', 'men pant', 'women t-shirt', 'hoodie'];
      notifyListeners();
      return;
    }

    List<String> newSuggestions = [];

    // Smart suggestions based on partial input
    final allSuggestions = [
      'men t-shirt',
      'women t-shirt',
      'men hoodie',
      'women hoodie',
      'men pant',
      'women pant',
      't-shirt',
      'hoodie',
      'pant',
    ];

    for (var suggestion in allSuggestions) {
      if (suggestion.contains(_query) || _fuzzyMatch(suggestion, _query) > 0.6) {
        newSuggestions.add(suggestion);
      }
      if (newSuggestions.length >= 5) break;
    }

    _suggestions = newSuggestions.isNotEmpty ? newSuggestions : ['men t-shirt', 'women hoodie'];
    notifyListeners();
  }

  bool isInvalidSearch() {
    return _invalidCategories.any((invalid) => _query.contains(invalid));
  }

  void clearText() {
    _query = '';
    _lastSearchedQuery = '';
    _suggestions = ['men t-shirt', 'women hoodie', 'men pant', 'women t-shirt', 'hoodie'];
    _debounce?.cancel();
    notifyListeners();
  }

  void clearSearch() {
    _query = '';
    _lastSearchedQuery = '';
    _searchResults = [];
    _suggestions = ['men t-shirt', 'women hoodie', 'men pant', 'women t-shirt', 'hoodie'];
    _debounce?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}