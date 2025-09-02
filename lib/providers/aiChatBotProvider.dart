import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart' as rtdb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:glamora/models/productModel.dart';
// import 'package:sentiment_dart/sentiment_dart.dart';

class AIChatBotProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final rtdb.FirebaseDatabase _rtdb = rtdb.FirebaseDatabase.instance;
  static const String _apiUrl = "https://api.deepseek.com/chat/completions";
  static const String _embeddingsApiUrl = "https://api.deepseek.com/embeddings";
  String? _apiKey = dotenv.env['DEEPSEEK_API_KEY'];
  List<Map<String, dynamic>> _messages = [];
  String? _conversationId;
  String? _currentCategory;
  String? _currentGender;
  double? _currentBudget;
  bool _isLoading = false;
  List<ClothingProductModel> _recommendedProducts = [];
  List<ClothingProductModel> _allProducts = [];
  List<String> _searchHistory = [];
  List<String> _popularSearches = ["T-Shirt", "Pant", "Hoodie"];
  String? _currentColor;
  String? _currentSize;
  String? _currentStyle;
  Map<String, List<double>> _productEmbeddings = {};
  List<double>? _currentQueryEmbedding;
  Completer<void>? _requestCompleter;

  String? filterGender;
  String? filterCategory;
  String? filterColorName;
  String? filterSize;
  double? filterMaxPrice;

  List<ClothingProductModel> get recommendedProducts => _recommendedProducts;

  List<Map<String, dynamic>> get messages => _messages;

  bool get isLoading => _isLoading;

  List<String> get searchHistory => _searchHistory;

  List<String> get popularSearches => _popularSearches;

  String? get getFilterGender => filterGender;

  String? get getFilterCategory => filterCategory;

  String? get getFilterColorName => filterColorName;

  String? get getFilterSize => filterSize;

  double? get getFilterMaxPrice => filterMaxPrice;

  Future<void> initConversation() async {
    _conversationId = FirebaseAuth.instance.currentUser?.uid;
    if (_conversationId == null) {
      _conversationId =
          'anon_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    }

    await _updateFirestoreConversation();
    await _loadPreviousConversation();
    await _loadAllProducts();
    await _loadProductEmbeddings();

    if (_messages.isEmpty) {
      _addSystemMessage();
    }

    _loadSearchHistory();
  }

  Future<bool> _saveMessageToRTDB(String text, bool isUser,
      {String type = 'text', List<ClothingProductModel>? products}) async {
    if (_conversationId == null) return false;

    try {
      final messagesRef = _rtdb.ref('conversations/$_conversationId/messages');
      final messageRef = messagesRef.push();

      Map<String, dynamic> messageData = {
        'text': text,
        'isUser': isUser,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'type': type,
      };

      if (products != null) {
        messageData['products'] = products.map((p) => p.toMap()).toList();
      }

      await messageRef.set(messageData);
      await _updateFirestoreConversation();
      return true;
    } catch (e, st) {
      print('[RTDB] Firebase write error: $e\n$st');
      return false;
    }
  }

  Future<void> _loadProductEmbeddings() async {
    try {
      final snapshot = await _firestore.collection('product_embeddings').get();
      for (var doc in snapshot.docs) {
        List<dynamic> embeddingList = doc['embedding'];
        _productEmbeddings[doc.id] = embeddingList.cast<double>();
      }
    } catch (e) {
      print("Error loading embeddings: $e");
    }
  }

  Future<List<double>> _generateEmbedding(String text) async {
    try {
      final response = await http.post(
        Uri.parse(_embeddingsApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode({"input": text, "model": "text-embedding-3-small"}),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        List<dynamic> data = responseBody['data'];
        if (data.isNotEmpty) {
          return List<double>.from(data[0]['embedding']);
        }
      }
    } catch (e) {
      print("Embedding generation error: $e");
    }
    return [];
  }

  String _normalizeColorDynamic(dynamic value) {
    try {
      if (value == null) return '';

      if (value is int) {
        final hex = value.toRadixString(16).padLeft(8, '0').toLowerCase();
        return hex.substring(hex.length - 6);
      }

      if (value is Map && value.containsKey('value')) {
        final v = value['value'];
        if (v is int) {
          final hex = v.toRadixString(16).padLeft(8, '0').toLowerCase();
          return hex.substring(hex.length - 6);
        }
      }

      if (value is String) {
        var s = value.toLowerCase().trim();
        s = s.replaceAll('#', '');
        s = s.replaceAll('0x', '');
        s = s.replaceAll(RegExp(r'[^0-9a-f]'), '');
        if (s.length > 6) {
          s = s.substring(s.length - 6);
        } else if (s.length < 6) {
          s = s.padLeft(6, '0');
        }
        return s;
      }

      var s = value.toString().toLowerCase();
      s = s.replaceAll(RegExp(r'[^0-9a-f]'), '');
      if (s.length > 6) s = s.substring(s.length - 6);
      return s.padLeft(6, '0');
    } catch (e) {
      print('Color normalizer error: $e');
      return '';
    }
  }

  List<int> _hexToRgb(String hex) {
    final s = hex.replaceAll('#', '').padLeft(6, '0');
    final h = s.length > 6 ? s.substring(s.length - 6) : s;
    final r = int.parse(h.substring(0, 2), radix: 16);
    final g = int.parse(h.substring(2, 4), radix: 16);
    final b = int.parse(h.substring(4, 6), radix: 16);
    return [r, g, b];
  }

  double _colorDistance(List<int> a, List<int> b) {
    final dr = (a[0] - b[0]).toDouble();
    final dg = (a[1] - b[1]).toDouble();
    final db = (a[2] - b[2]).toDouble();
    return sqrt(dr * dr + dg * dg + db * db);
  }

  bool _isColorSimilar(String hexA, String hexB, {double threshold = 100.0}) {
    try {
      final a = _hexToRgb(hexA);
      final b = _hexToRgb(hexB);
      final dist = _colorDistance(a, b);
      return dist <= threshold;
    } catch (e) {
      return hexA == hexB;
    }
  }

  bool _isLightColor(String hex, {int luminanceThreshold = 200}) {
    try {
      final rgb = _hexToRgb(hex);
      final lum = (0.299 * rgb[0]) + (0.587 * rgb[1]) + (0.114 * rgb[2]);
      return lum >= luminanceThreshold;
    } catch (e) {
      return false;
    }
  }

  bool _containsIgnoreCaseInList(List<dynamic>? list, String term) {
    if (list == null || list.isEmpty) return false;
    final t = term.toLowerCase();
    return list.any((item) => item.toString().toLowerCase().contains(t));
  }

  Future<void> _searchProducts(String query) async {
    print('[SEARCHING]: $query');
    _isLoading = true;
    notifyListeners();

    try {
      if (!query.toLowerCase().contains('similar') &&
          !query.toLowerCase().contains('more like this')) {
        _resetSearchContext();
      }

      _updateSearchContext(query);

      // Check if category and gender are already set to avoid asking again
      if (_currentCategory == null || _currentGender == null) {
        // Check if query contains category or gender information
        if (_isProductQuery(query)) {
          _updateSearchContext(
              query); // Update context again to ensure we catch any new info
          if (_currentCategory == null || _currentGender == null) {
            _addBotMessage(
                "To better assist you, please specify the gender (Man, Woman, Unisex) and category (e.g., T-Shirt, Pant, Hoodie). What are your preferences?");
            _isLoading = false;
            notifyListeners();
            return;
          }
        }
      }

      if (filterGender != null && query.contains(filterGender!))
        _currentGender = filterGender;
      if (filterCategory != null && query.contains(filterCategory!))
        _currentCategory = filterCategory;
      if (filterMaxPrice != null && query.contains(filterMaxPrice.toString()))
        _currentBudget = filterMaxPrice;
      if (filterSize != null && query.contains(filterSize!))
        _currentSize = filterSize;
      if (filterColorName != null && query.contains(filterColorName!)) {
        final mapped = _colorNameToHex(filterColorName!);
        if (mapped != null) _currentColor = mapped;
      }

      clearFilters();

      String? targetHex;
      if (_currentColor != null && _currentColor!.trim().isNotEmpty) {
        targetHex = _currentColor!.toLowerCase().replaceAll('#', '');
        if (targetHex.length > 6)
          targetHex = targetHex.substring(targetHex.length - 6);
      }
      final String tHex = targetHex ?? '';

      const double distanceThreshold = 100.0;
      final bool wantsWhite = (filterColorName != null &&
              filterColorName!.toLowerCase().contains('white')) ||
          (tHex.isNotEmpty && (tHex == 'ffffff' || tHex == 'fff'));

      List<ClothingProductModel> filteredProducts =
          _allProducts.where((product) {
        if (_currentGender != null && _currentGender!.isNotEmpty) {
          if (product.gender.toLowerCase() != _currentGender!.toLowerCase()) {
            return false;
          }
        }

        if (_currentCategory != null && _currentCategory!.isNotEmpty) {
          final catLower = _currentCategory!.toLowerCase();
          final prodCatLower = product.category.toLowerCase();
          if (prodCatLower != catLower) {
            return false;
          }
        }

        if (_currentBudget != null && product.price > _currentBudget! * 1.1) {
          return false;
        }

        if (tHex.isNotEmpty) {
          if (product.variants.isEmpty) return false;

          bool foundColor =
              product.variants.any((variant) => variant.colors.any((color) {
                    final hex = _normalizeColorDynamic(color.value);
                    if (hex.isEmpty) return false;

                    if (hex == tHex ||
                        hex.contains(tHex) ||
                        tHex.contains(hex)) {
                      return true;
                    }

                    if (wantsWhite) {
                      if (_isLightColor(hex, luminanceThreshold: 200)) {
                        return true;
                      }
                    }

                    if (_isColorSimilar(hex, tHex,
                        threshold: distanceThreshold)) {
                      return true;
                    }

                    return false;
                  }));

          if (!foundColor) return false;
        }

        if (_currentSize != null) {
          if (product.variants.isEmpty ||
              !product.variants.any((variant) => variant.sizes.any((size) =>
                  size.size.toLowerCase() == _currentSize!.toLowerCase()))) {
            return false;
          }
        }

        if (_currentStyle != null &&
            !_containsIgnoreCaseInList(product.tags, _currentStyle!)) {
          return false;
        }

        if (query.toLowerCase().contains('cotton') &&
            !product.description.toLowerCase().contains('cotton')) {
          return false;
        }

        if ((query.toLowerCase().contains('sale') ||
                query.toLowerCase().contains('discount')) &&
            (product.discount == 0 || product.discount == null)) {
          return false;
        }

        return true;
      }).toList();

      if (filteredProducts.isEmpty) {
        filteredProducts = _allProducts.where((p) {
          final desc = p.description.toLowerCase();
          final title = p.title.toLowerCase();
          final queryLower = query.toLowerCase();

          return desc.contains(queryLower) ||
              title.contains(queryLower) ||
              p.tags.any((tag) => tag.toLowerCase().contains(queryLower));
        }).toList();
      }

      if (filteredProducts.isNotEmpty) {
        filteredProducts.sort((a, b) {
          int scoreA = 0;
          int scoreB = 0;

          if (_currentGender != null &&
              a.gender.toLowerCase() == _currentGender!.toLowerCase())
            scoreA += 2;
          if (_currentGender != null &&
              b.gender.toLowerCase() == _currentGender!.toLowerCase())
            scoreB += 2;

          if (_currentCategory != null &&
              a.category.toLowerCase() == _currentCategory!.toLowerCase())
            scoreA += 3;
          if (_currentCategory != null &&
              b.category.toLowerCase() == _currentCategory!.toLowerCase())
            scoreB += 3;

          if (query.toLowerCase().contains('cotton') &&
              a.description.toLowerCase().contains('cotton')) scoreA += 2;
          if (query.toLowerCase().contains('cotton') &&
              b.description.toLowerCase().contains('cotton')) scoreB += 2;

          if (_currentColor != null &&
              a.variants.any((v) => v.colors.any((c) =>
                  _isColorSimilar(_normalizeColorDynamic(c.value), tHex))))
            scoreA += 3;
          if (_currentColor != null &&
              b.variants.any((v) => v.colors.any((c) =>
                  _isColorSimilar(_normalizeColorDynamic(c.value), tHex))))
            scoreB += 3;

          return scoreB.compareTo(scoreA);
        });

        _processSearchResults(filteredProducts.take(5).toList());
        // Only ask for additional details if the user hasn't provided specific preferences
        if (_currentSize == null &&
            _currentBudget == null &&
            _currentColor == null) {
          _addBotMessage(
              "Would you like details on material, fit, or discounts for these products?");
        }
      } else {
        _addBotMessage(
            "No exact matches found for $_currentGender $_currentCategory. Here are some alternatives:");
        List<ClothingProductModel> fallbackProducts = _allProducts
            .where((p) {
              if (_currentGender != null &&
                  p.gender.toLowerCase() != _currentGender!.toLowerCase())
                return false;
              return true;
            })
            .take(5)
            .toList();
        if (fallbackProducts.isNotEmpty) {
          _processSearchResults(fallbackProducts, isFallback: true);
        } else {
          _addBotMessage(
              "Sorry, no alternatives found. Please try a different query or check our catalog at glamora.com.");
        }
      }
    } catch (e) {
      print("Product search error: $e");
      _addBotMessage(
          "I'm having trouble searching right now. Please try again later.");
    } finally {
      if (_requestCompleter != null && !_requestCompleter!.isCompleted) {
        _requestCompleter!.complete();
      }
      _isLoading = false;
      notifyListeners();
    }
  }

  String? _colorNameToHex(String name) {
    final colorMap = {
      'red': 'ff0000',
      'blue': '0000ff',
      'green': '00ff00',
      'black': '000000',
      'kala': '000000',
      'white': 'ffffff',
      'safaid': 'ffffff',
      'safed': 'ffffff',
      'gray': '808080',
      'grey': '808080',
      'pink': 'ffc1cc',
      'purple': '800080',
      'yellow': 'ffff00',
      'neela': '0000ff',
      'lal': 'ff0000',
      'orange': 'ffa500',
      'brown': 'a52a2a',
      'multi': '000000',
      'multicolor': '000000',
    };
    return colorMap[name.toLowerCase()];
  }

  Future<void> _saveProductEmbedding(ClothingProductModel product) async {
    try {
      final embeddingText =
          "${product.title} ${product.description} ${product.tags.join(' ')} ${product.category} ${product.gender}";
      final embedding = await _generateEmbedding(embeddingText);

      if (embedding.isNotEmpty) {
        await _firestore.collection('product_embeddings').doc(product.id).set({
          'productId': product.id,
          'embedding': embedding,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        _productEmbeddings[product.id] = embedding;
      }
    } catch (e) {
      print("Error saving embedding: $e");
    }
  }

  Future<void> _loadAllProducts() async {
    try {
      _isLoading = true;
      notifyListeners();

      final collections = [
        _firestore.collection('Cloths').doc('Man').collection('T-Shirt'),
      ];

      for (var collection in collections) {
        final snapshot = await collection.get();
        _allProducts.addAll(
          snapshot.docs.map((doc) => ClothingProductModel.fromSnapshot(doc)),
        );
      }

      for (var product in _allProducts) {
        if (!_productEmbeddings.containsKey(product.id)) {
          await _saveProductEmbedding(product);
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print("Error loading products: $e");
    }
  }

  double _cosineSimilarity(List<double> vectorA, List<double> vectorB) {
    if (vectorA.isEmpty ||
        vectorB.isEmpty ||
        vectorA.length != vectorB.length) {
      return 0.0;
    }

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < vectorA.length; i++) {
      dotProduct += vectorA[i] * vectorB[i];
      normA += vectorA[i] * vectorA[i];
      normB += vectorB[i] * vectorB[i];
    }

    if (normA == 0 || normB == 0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  List<ClothingProductModel> _findSimilarProducts(String query, int limit) {
    if (_currentQueryEmbedding == null || _productEmbeddings.isEmpty) {
      return [];
    }

    final similarities = <String, double>{};

    _productEmbeddings.forEach((productId, embedding) {
      final product = _allProducts.firstWhere((p) => p.id == productId,
          orElse: () => ClothingProductModel());
      if (product.id.isEmpty) return;

      if (_currentGender != null &&
          product.gender.toLowerCase() != _currentGender!.toLowerCase()) return;
      if (_currentCategory != null &&
          product.category.toLowerCase() != _currentCategory!.toLowerCase())
        return;

      final similarity = _cosineSimilarity(_currentQueryEmbedding!, embedding);
      if (similarity > 0.3) {
        similarities[productId] = similarity;
      }
    });

    final sortedProductIds = similarities.keys.toList()
      ..sort((a, b) => similarities[b]!.compareTo(similarities[a]!));

    final topProductIds = sortedProductIds.take(limit).toList();
    return _allProducts.where((p) => topProductIds.contains(p.id)).toList();
  }

  String _getAvailableProducts() {
    if (_currentGender == null || _currentCategory == null) return "";

    final avail = _allProducts
        .where((p) =>
            p.gender.toLowerCase() == _currentGender!.toLowerCase() &&
            p.category.toLowerCase() == _currentCategory!.toLowerCase())
        .toList();

    if (avail.isEmpty) {
      final allAvail = _allProducts
          .map((p) =>
              "- ${p.gender} ${p.category}: ${p.title} - Rs.${p.price} (Discount: ${p.discount}%)")
          .join("\n");
      return "No products available in $_currentGender $_currentCategory. Available products:\n$allAvail";
    }

    return "Available products in $_currentGender $_currentCategory:\n" +
        avail
            .map((p) =>
                "- ${p.title}: ${p.description}, Price: Rs.${p.price}, Discount: ${p.discount}%, Colors: ${p.variants.map((v) => v.colors.map((c) => c.colorSpace).join(', ')).join(', ')}, Sizes: ${p.variants.map((v) => v.sizes.map((s) => s.size).join(', ')).join(', ')}")
            .join("\n");
  }

  Future<void> sendMessage(String text) async {
    if (text.isEmpty || _isLoading) return;

    _requestCompleter = Completer<void>();
    _addUserMessage(text);
    // final sentiment = Sentiment.analysis(text).score;
    await _saveMessageToRTDB(text, true);

    _isLoading = true;
    notifyListeners();

    _currentQueryEmbedding = await _generateEmbedding(text);

    if (_isStorePolicyQuery(text)) {
      _handleStorePolicyQuery(text);
    } else if (_isOrderIssueQuery(text)) {
      _handleOrderIssueQuery(text);
    } else if (_isTextOnlyQuery(text)) {
      await _generateBotResponse(text, skipProducts: true);
    } else if (_isProductQuery(text)) {
      await _searchProducts(text);
    } else {
      await _generateBotResponse(text);
    }

    if (!_searchHistory.any((h) => h.toLowerCase() == text.toLowerCase())) {
      _searchHistory.insert(0, text);
      if (_searchHistory.length > 10) _searchHistory.removeLast();
      _saveSearchHistory();
    }

    if (_requestCompleter != null && !_requestCompleter!.isCompleted) {
      _requestCompleter!.complete();
    }
    _isLoading = false;
    notifyListeners();
  }

  bool _isTextOnlyQuery(String message) {
    final textKeywords = [
      'text',
      'form of text',
      'personal assistant',
      'tell me',
      'which',
      'why',
      'how',
      'advice only',
      'no products',
      'without showing'
    ];
    return textKeywords.any((word) => message.toLowerCase().contains(word));
  }

  void cancelRequest() {
    if (_requestCompleter != null && !_requestCompleter!.isCompleted) {
      _requestCompleter!.complete();
      _isLoading = false;
      notifyListeners();
      _addBotMessage("Request cancelled. How can I assist you now?");
    }
  }

  Future<void> _generateBotResponse(String userMessage,
      {bool skipProducts = false}) async {
    try {
      if (_allProducts.isEmpty) {
        _addBotMessage("🔄 Loading our fashion catalog...");
        return;
      }

      List<ClothingProductModel> similarProducts = [];
      if (!skipProducts) {
        similarProducts = _findSimilarProducts(userMessage, 5);
      }

      if (similarProducts.isNotEmpty && !skipProducts) {
        _addBotMessage(
          "✨ Here are some items matching your request:",
          products: similarProducts,
        );
        if (_currentSize == null &&
            _currentBudget == null &&
            _currentColor == null) {
          _addBotMessage(
              "Would you like details on material, fit, or discounts for these products?");
        }
        return;
      }

      String botResponse = await _getAIResponse(userMessage);
      _addBotMessage(_cleanResponse(botResponse));
    } catch (e) {
      print("Error generating response: $e");
      _addBotMessage("⚠️ Oops! Let me try that again...");
    }
  }

  Future<void> _loadPreviousConversation() async {
    if (_conversationId == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(_conversationId)
          .get();

      if (conversationDoc.exists) {
        final messagesRef =
            _rtdb.ref('conversations/$_conversationId/messages');
        final snapshot = await messagesRef.get();

        if (snapshot.exists) {
          _messages.clear();

          final messagesMap = Map<String, dynamic>.from(snapshot.value as Map);
          final sortedMessages = messagesMap.entries.toList()
            ..sort((a, b) => (a.value['timestamp'] ?? 0)
                .compareTo(b.value['timestamp'] ?? 0));

          for (var entry in sortedMessages) {
            final message = entry.value;

            if (message['type'] == 'products') {
              final productList = (message['products'] as List<dynamic>?)
                  ?.map((p) => ClothingProductModel.fromMap(
                      Map<String, dynamic>.from(p)))
                  .toList();

              if (productList != null && productList.isNotEmpty) {
                _messages.add({
                  'text': message['text'] ?? 'Recommended products:',
                  'isUser': false,
                  'timestamp':
                      DateTime.fromMillisecondsSinceEpoch(message['timestamp']),
                  'type': 'products',
                  'products': productList,
                });
                continue;
              }
            }

            _messages.add({
              'text': message['text'],
              'isUser': message['isUser'],
              'timestamp':
                  DateTime.fromMillisecondsSinceEpoch(message['timestamp']),
              'type': 'text',
            });
          }
        }

        if (_messages.length > 20) {
          _messages = _messages.sublist(_messages.length - 20);
        }

        final context =
            conversationDoc.data()?['searchContext'] as Map<String, dynamic>?;
        if (context != null) {
          _currentGender = context['gender'];
          _currentCategory = categoryContext(context['category']);
          _currentBudget = context['budget']?.toDouble();
          _currentColor = context['color'];
          _currentSize = context['size'];
          _currentStyle = context['style'];
        }
      }
    } catch (e) {
      print("Error loading previous conversation: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String? categoryContext(String? category) {
    final categories = [
      't-shirt',
      'tshirt',
      'tee',
      't zirts',
      't sharat',
      'shirt',
      'pant',
      'pants',
      'jean',
      'jeans',
      'hoodie',
      'hoody',
      'jacket',
      'top',
      'kurta',
      'shalwar',
      'kameez',
      'dress',
      'skirt'
    ];

    if (category == null) return null;

    final catLower = category.toLowerCase();
    if (categories.contains(catLower)) {
      if (catLower.contains('t-shirt') ||
          catLower.contains('tshirt') ||
          catLower.contains('tee') ||
          catLower.contains('t zirts') ||
          catLower.contains('t sharat')) {
        return 'T-Shirt';
      } else if (catLower.contains('shirt')) {
        return 'Shirt';
      } else if (catLower.contains('pant') || catLower.contains('jean')) {
        return 'Pant';
      } else if (catLower.contains('hood')) {
        return 'Hoodie';
      } else if (catLower.contains('jacket')) {
        return 'Jacket';
      }
    }
    return category;
  }

  Future<void> _updateFirestoreConversation() async {
    if (_conversationId == null) return;

    try {
      await _firestore.collection('conversations').doc(_conversationId).set({
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'searchContext': {
          'gender': _currentGender,
          'category': _currentCategory,
          'budget': _currentBudget,
          'color': _currentColor,
          'size': _currentSize,
          'style': _currentStyle,
        }
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error updating Firestore conversation: $e");
    }
  }

  void _addSystemMessage() {
    _messages.add({
      'text':
          "👋 Hello! I'm your Vision Cart fashion assistant. Ask me anything about our products, policies, or orders!",
      'isUser': false,
      'timestamp': DateTime.now(),
      'type': 'text'
    });
    notifyListeners();
  }

  void _addUserMessage(String text) {
    _messages.add({
      'text': text,
      'isUser': true,
      'timestamp': DateTime.now(),
      'type': 'text'
    });
    notifyListeners();
  }

  bool _isStorePolicyQuery(String message) {
    final policyKeywords = [
      'return',
      'exchange',
      'refund',
      'policy',
      'shipping',
      'delivery',
      'store hours',
      'contact',
      'payment',
      'help',
      'warranty',
      'privacy',
      'terms'
    ];
    return policyKeywords.any((word) => message.toLowerCase().contains(word));
  }

  bool _isOrderIssueQuery(String message) {
    final orderKeywords = [
      'order',
      'track',
      'status',
      'cancel',
      'missing',
      'problem',
      'issue',
      'not received',
      'where is my order',
      'delay',
      'update'
    ];
    return orderKeywords.any((word) => message.toLowerCase().contains(word));
  }

  void _handleStorePolicyQuery(String query) {
    query = query.toLowerCase();
    String response =
        "ℹ️ For more information about our store policies, please visit our Help Center at help.visioncart.com";
    _addBotMessage(response);
  }

  void _handleOrderIssueQuery(String query) {
    query = query.toLowerCase();
    String response =
        "🛎️ For order assistance, please contact our customer support team at support@glamora.com or call 1-800-Vision-Cart. Provide your order number for faster help.";
    _addBotMessage(response);
  }

  bool _isProductQuery(String message) {
    final productKeywords = [
      't-shirt',
      'tshirt',
      't zirts',
      't sharat',
      'shirt',
      'pant',
      'pants',
      'jean',
      'jeans',
      'hoodie',
      'hoody',
      'jacket',
      'top',
      'bottom',
      'outfit',
      'kurta',
      'shalwar',
      'kameez',
      'dress',
      'skirt',
      'product',
      'item',
      'clothing',
      'fashion',
      'buy',
      'shop',
      'purchase',
      'looking for',
      'need',
      'want',
      'show me',
      'find',
      'search',
      'looking',
      'options',
      'choices',
      'kapra',
      'filter',
      'filters',
      'color',
      'size',
      'price',
      'material',
      'brand',
      'review',
      'rating',
      'availability',
      'stock'
    ];

    return productKeywords.any((kw) => message.toLowerCase().contains(kw));
  }

  void _processSearchResults(List<ClothingProductModel> products,
      {bool isFallback = false}) {
    if (products.isEmpty) {
      _addBotMessage(
          "❌ Sorry, no products found matching your criteria in $_currentGender $_currentCategory. Available products: ${_getAvailableProducts()}");
    } else {
      _addBotMessage(
        isFallback
            ? "🔍 Here are some similar options:"
            : "✅ Found ${products.length} matching products:",
        products: products,
      );
    }
  }

  void _addBotMessage(String text, {List<ClothingProductModel>? products}) {
    _messages.add({
      'text': text,
      'isUser': false,
      'timestamp': DateTime.now(),
      'type': products != null ? 'products' : 'text',
      'products': products,
    });

    _saveMessageToRTDB(text, false,
        type: products != null ? 'products' : 'text', products: products);

    notifyListeners();
  }

  Future<String> _getAIResponse(String userMessage) async {
    final contextMessages = _messages.length > 6
        ? _messages
            .sublist(_messages.length - 6) // Last 3 user + 3 bot messages
        : _messages;

    List<Map<String, dynamic>> messages = [
      {"role": "system", "content": _buildSystemPrompt()},
      ...contextMessages
          .where((msg) => msg['type'] == 'text')
          .map((msg) => {
                "role": msg['isUser'] ? "user" : "assistant",
                "content": msg['text'] as String
              })
          .toList()
    ];

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode({
          "model": "deepseek-chat",
          "messages": messages,
          "temperature": 0.7,
          "max_tokens": 500,
        }),
      );

      if (_requestCompleter != null && _requestCompleter!.isCompleted) {
        return "Request was cancelled.";
      }

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return responseBody['choices'][0]['message']['content'];
      } else {
        print("AI API error: ${response.statusCode} - ${response.body}");
        return "I'm having trouble connecting to our fashion experts. Please try again later.";
      }
    } catch (e) {
      print("AI API exception: $e");
      return "It seems I'm having technical difficulties. Please ask again or try a different question.";
    }
  }

  String _buildSystemPrompt() {
    return """
You are a 24/7 fashion assistant for Vision Cart clothing store. Use PKR (Rs.) for currency. Handle queries in English and Roman Urdu, including typos (e.g., 't zirts', 't sharat' for T-Shirt, 'sab sy chota size' for S).

Key responsibilities:
1. Product Assistance:
   - Help with T-Shirts only (currently only Men's T-Shirts available)
   - Attributes: Gender (Man), Category (T-Shirt), Budget (PKR), Color, Size (XS, S, M, L, XL, XXL), Material
   - Use ONLY the provided product data; do NOT invent or generate product details
   - Suggest alternatives from provided products if no exact match
   - Ask for missing gender or category only if not specified in the last 3 interactions
   - After showing products, ask for size, budget, or color only if not already provided
   - Provide sizing guides, care instructions if asked
   - Assume products are in stock unless specified

2. Store Policies:
   - Returns/Exchanges/Refunds: 7 days, tags attached, free store credit
   - Shipping: Standard  3-5 days business days (Note these days includes only working days"
   - Payments: Visa, MasterCard
   - Warranty: 1 year on defects
   - Contact: support@visioncart.com, 1-800-Vision-Cart

3. Order Issues:
   - Tracking: Guide to account or request order number
   - Cancellations: Within 1 hour, else contact support
   - Delays/Missing: Investigate with order number

Current Context:
${_currentGender != null ? "• Gender: $_currentGender" : ""}
${_currentCategory != null ? "• Category: $_currentCategory" : ""}
${_currentBudget != null ? "• Budget: Rs.${_currentBudget!.toStringAsFixed(0)}" : ""}
${_currentColor != null ? "• Color: $_currentColor" : ""}
${_currentSize != null ? "• Size: $_currentSize" : ""}

Available Products (use ONLY these, do NOT invent others):
${_getAvailableProducts()}

Guidelines:
- Be friendly, empathetic, fashion-savvy
- Use emojis sparingly
- For products, describe vividly using only provided data
- Ask clarifying questions for ambiguous queries only if context is missing
- Handle typos (e.g., 't zirts' → T-Shirt, 'sab sy chota size' → S)
- Escalate complex queries to support@visioncart.com
- Keep responses concise, structured
- Use last 3 user and assistant interactions for context
- Never invent false info; base on provided data
""";
  }

  void _updateSearchContext(String message) {
    final categories = [
      't-shirt',
      'tshirt',
      't zirts',
      't sharat',
      'shirt',
      'pant',
      'pants',
      'jean',
      'jeans',
      'hoodie',
      'hoody',
      'jacket',
      'top',
      'kurta',
      'shalwar',
      'kameez',
      'dress',
      'skirt'
    ];

    for (var category in categories) {
      if (message.toLowerCase().contains(category)) {
        if (category.contains('t-shirt') ||
            category.contains('tshirt') ||
            category.contains('t zirts') ||
            category.contains('t sharat')) {
          _currentCategory = 'T-Shirt';
        } else if (category.contains('shirt')) {
          _currentCategory = 'Shirt';
        } else if (category.contains('pant') || category.contains('jean')) {
          _currentCategory = 'Pant';
        } else if (category.contains('hood')) {
          _currentCategory = 'Hoodie';
        } else if (category.contains('jacket')) {
          _currentCategory = 'Jacket';
        }
        break;
      }
    }

    if (message.toLowerCase().contains('man') ||
        message.toLowerCase().contains('men') ||
        message.toLowerCase().contains('male') ||
        message.toLowerCase().contains('mard')) {
      _currentGender = 'Man';
    } else if (message.toLowerCase().contains('woman') ||
        message.toLowerCase().contains('women') ||
        message.toLowerCase().contains('female') ||
        message.toLowerCase().contains('aurat')) {
      _currentGender = 'Woman';
    } else if (message.toLowerCase().contains('unisex') ||
        message.toLowerCase().contains('both')) {
      _currentGender = 'Unisex';
    }

    final budget = _extractBudget(message);
    if (budget != null) {
      _currentBudget = budget;
    }

    final colorMap = {
      'red': 'ff0000',
      'blue': '0000ff',
      'green': '00ff00',
      'black': '000000',
      'kala': '000000',
      'white': 'ffffff',
      'safaid': 'ffffff',
      'safed': 'ffffff',
      'gray': '808080',
      'grey': '808080',
      'pink': 'ffc1cc',
      'purple': '800080',
      'yellow': 'ffff00',
      'neela': '0000ff',
      'lal': 'ff0000',
      'orange': 'ffa500',
      'brown': 'a52a2a',
      'multi': 'multi'
    };

    for (var colorName in colorMap.keys) {
      if (message.toLowerCase().contains(colorName)) {
        _currentColor = colorMap[colorName];
        break;
      }
    }

    final sizeMap = {
      'xs': 'XS',
      's': 'S',
      'm': 'M',
      'l': 'L',
      'xl': 'XL',
      'xxl': 'XXL',
      'sab sy chota size': 'S',
      'smallest size': 'S',
      'chota size': 'S',
    };

    for (var size in sizeMap.keys) {
      if (message.toLowerCase().contains(size)) {
        _currentSize = sizeMap[size];
        break;
      }
    }

    final styles = [
      'casual',
      'formal',
      'sporty',
      'elegant',
      'party',
      'office',
      'street',
      'vintage',
      'loose',
      'relaxed'
    ];
    for (var style in styles) {
      if (message.toLowerCase().contains(style)) {
        _currentStyle = style;
        break;
      }
    }

    // Save updated context to Firestore
    _updateFirestoreConversation();
  }

  void _resetSearchContext() {
    _currentCategory = null;
    _currentGender = null;
    _currentBudget = null;
    _currentColor = null;
    _currentSize = null;
    _currentStyle = null;
  }

  double? _extractBudget(String message) {
    final RegExp regExp = RegExp(
        r'(?:rs\.?|pkr|₹|\$)?\s*(\d{1,7}(?:,\d{3})*(?:\.\d+)?)',
        caseSensitive: false);
    final matches = regExp.allMatches(message);

    for (var match in matches) {
      final raw = match.group(1)?.replaceAll(',', '');
      final value = double.tryParse(raw ?? '');
      if (value != null && value > 0) return value;
    }
    return null;
  }

  String _cleanResponse(String response) {
    return response
        .replaceAll('☒', '')
        .replaceAll(RegExp(r'[^\x00-\x7F]+'), '')
        .replaceAll("Vision Cart Store Assistant:", "")
        .trim();
  }

  void _loadSearchHistory() async {
    _searchHistory = [
      "Cotton T-Shirts for men",
      "Black T-Shirt under Rs.2000",
      "T-Shirts for men",
      "Casual T-Shirts"
    ];
    notifyListeners();
  }

  void _saveSearchHistory() async {}

  void setFilterGender(String? value) {
    filterGender = value;
    notifyListeners();
  }

  void setFilterCategory(String? value) {
    filterCategory = value;
    notifyListeners();
  }

  void setFilterColorName(String? value) {
    filterColorName = value;
    notifyListeners();
  }

  void setFilterSize(String? value) {
    filterSize = value;
    notifyListeners();
  }

  void setFilterMaxPrice(double? value) {
    filterMaxPrice = value;
    notifyListeners();
  }

  void clearFilters() {
    filterGender = null;
    filterCategory = null;
    filterColorName = null;
    filterSize = null;
    filterMaxPrice = null;
    notifyListeners();
  }

  void applyFilters() {
    final filters = [];
    if (filterGender != null) filters.add("$filterGender");
    if (filterCategory != null) filters.add("$filterCategory");
    if (filterColorName != null) filters.add("$filterColorName color");
    if (filterSize != null) filters.add("size $filterSize");
    if (filterMaxPrice != null)
      filters.add("under Rs.${filterMaxPrice!.toStringAsFixed(0)}");

    if (filters.isNotEmpty) {
      final text = "Show ${filters.join(' ')} clothing";
      sendMessage(text);
    }

    clearFilters();
  }
}
