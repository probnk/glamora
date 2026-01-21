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

class AIChatBotProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final rtdb.FirebaseDatabase _rtdb = rtdb.FirebaseDatabase.instance;
  static const String _apiUrl = "https://api.deepseek.com/chat/completions";
  static const String _embeddingsApiUrl = "https://api.deepseek.com/embeddings";
  String? _apiKey = dotenv.env['DEEPSEEK_API_KEY'];

  // Chat state
  List<Map<String, dynamic>> _messages = [];
  String? _conversationId;
  bool _isLoading = false;
  List<ClothingProductModel> _allProducts = [];
  List<String> _searchHistory = [];
  List<String> _popularSearches = ["T-Shirt", "Hoodie", "Pant", "Cotton Dress", "Winter Collection"];

  // Search context - stores user preferences
  String? _currentGender;
  String? _currentCategory;
  double? _currentBudget;
  String? _currentColor;
  String? _currentSize;
  String? _currentStyle;

  // Filters
  String? filterGender;
  String? filterCategory;
  String? filterColorName;
  String? filterSize;
  double? filterMaxPrice;

  // API request control
  Completer<void>? _requestCompleter;

  // Getters
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
      _conversationId = 'anon_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    }

    await _loadPreviousConversation();
    await _loadAllProducts();

    if (_messages.isEmpty) {
      _addSystemMessage();
    }

    _loadSearchHistory();
    notifyListeners();
  }

  Future<void> _loadAllProducts() async {
    try {
      _isLoading = true;
      notifyListeners();

      List<String> genders = ['Man', 'Woman'];
      List<String> categories = ['T-Shirt', 'Hoodie', 'Pant'];

      _allProducts.clear();

      for (String gender in genders) {
        for (String category in categories) {
          try {
            final collection = _firestore.collection('Cloths').doc(gender).collection(category);
            final snapshot = await collection.get();

            if (snapshot.docs.isNotEmpty) {
              _allProducts.addAll(
                snapshot.docs.map((doc) {
                  final product = ClothingProductModel.fromSnapshot(doc);
                  product.gender = gender; // Ensure gender is set
                  product.category = category; // Ensure category is set
                  return product;
                }),
              );
            }
          } catch (e) {
            print("Error loading $gender $category: $e");
          }
        }
      }

      print("Loaded ${_allProducts.length} products from Firestore");
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print("Error loading products: $e");
    }
  }

  void _extractPreferencesFromQuery(String query) {
    final lowerQuery = query.toLowerCase();

    // Extract gender
    if (lowerQuery.contains('man') || lowerQuery.contains('men') ||
        lowerQuery.contains('male') || lowerQuery.contains('mard') ||
        lowerQuery.contains('larki') || lowerQuery.contains('boy')) {
      _currentGender = 'Man';
    } else if (lowerQuery.contains('woman') || lowerQuery.contains('women') ||
        lowerQuery.contains('female') || lowerQuery.contains('aurat') ||
        lowerQuery.contains('larki') || lowerQuery.contains('girl')) {
      _currentGender = 'Woman';
    } else if (lowerQuery.contains('unisex') || lowerQuery.contains('both')) {
      _currentGender = 'Unisex';
    }

    // Extract category with Roman Urdu support
    if (lowerQuery.contains('t-shirt') || lowerQuery.contains('tshirt') ||
        lowerQuery.contains('tee') || lowerQuery.contains('t zirts') ||
        lowerQuery.contains('t sharat') || lowerQuery.contains('shirt') ||
        lowerQuery.contains('kamiz')) {
      _currentCategory = 'T-Shirt';
    } else if (lowerQuery.contains('hoodie') || lowerQuery.contains('hoody') ||
        lowerQuery.contains('hoodi') || lowerQuery.contains('hood')) {
      _currentCategory = 'Hoodie';
    } else if (lowerQuery.contains('pant') || lowerQuery.contains('pants') ||
        lowerQuery.contains('trouser') || lowerQuery.contains('shalwar') ||
        lowerQuery.contains('patloon') || lowerQuery.contains('jeans')) {
      _currentCategory = 'Pant';
    }

    // Extract color with Urdu support
    final colorMap = {
      'red': ['lal', 'surkh'],
      'blue': ['neela', 'blue'],
      'green': ['hara', 'sabz'],
      'black': ['kala', 'siyah'],
      'white': ['safaid', 'safed'],
      'gray': ['grey', 'dhoosar'],
      'pink': ['gulabi', 'pink'],
      'purple': ['jamni', 'purple'],
      'yellow': ['peela', 'zard'],
      'orange': ['narangi', 'orange'],
      'brown': ['brown', 'bhoora'],
    };

    for (final entry in colorMap.entries) {
      if (entry.value.any((word) => lowerQuery.contains(word))) {
        _currentColor = entry.key;
        break;
      }
    }

    // Extract size with Urdu support
    final sizeMap = {
      'XS': ['xs', 'extra small', 'bohat chota'],
      'S': ['s', 'small', 'chota', 'sab sy chota'],
      'M': ['m', 'medium', 'darmiyana'],
      'L': ['l', 'large', 'bara'],
      'XL': ['xl', 'extra large', 'bohat bara'],
      'XXL': ['xxl', 'double xl', 'do barha'],
    };

    for (final entry in sizeMap.entries) {
      if (entry.value.any((word) => lowerQuery.contains(word))) {
        _currentSize = entry.key;
        break;
      }
    }

    // Extract budget
    final budgetRegex = RegExp(r'(?:rs\.?|pkr|₹|price|daam)?\s*(\d{1,7}(?:,\d{3})*(?:\.\d+)?)', caseSensitive: false);
    final matches = budgetRegex.allMatches(query);

    for (final match in matches) {
      final raw = match.group(1)?.replaceAll(',', '');
      final value = double.tryParse(raw ?? '');
      if (value != null && value > 0) {
        _currentBudget = value;
        break;
      }
    }

    // Extract style
    final styles = ['casual', 'formal', 'sporty', 'party', 'office', 'traditional', 'western'];
    for (final style in styles) {
      if (lowerQuery.contains(style)) {
        _currentStyle = style;
        break;
      }
    }

    // Save context to Firestore
    _updateFirestoreConversation();
  }

  Future<void> sendMessage(String text) async {
    if (text.isEmpty || _isLoading) return;

    _requestCompleter = Completer<void>();
    _addUserMessage(text);
    await _saveMessageToRTDB(text, true);

    _isLoading = true;
    notifyListeners();

    try {
      // Extract preferences from current query
      _extractPreferencesFromQuery(text);

      // Check if this is a product-related query
      if (_isProductQuery(text)) {
        await _handleProductQuery(text);
      } else if (_isStorePolicyQuery(text)) {
        await _handleStorePolicyQuery(text);
      } else if (_isOrderQuery(text)) {
        await _handleOrderQuery(text);
      } else {
        await _generateTextResponse(text);
      }

      // Save to search history
      if (!_searchHistory.any((h) => h.toLowerCase() == text.toLowerCase())) {
        _searchHistory.insert(0, text);
        if (_searchHistory.length > 10) _searchHistory.removeLast();
        _saveSearchHistory();
      }
    } catch (e) {
      print("Error in sendMessage: $e");
      _addBotMessage("I apologize, but I encountered an error. Please try again or contact support if the issue persists.");
    } finally {
      if (_requestCompleter != null && !_requestCompleter!.isCompleted) {
        _requestCompleter!.complete();
      }
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _handleProductQuery(String query) async {
    // Check what information we need
    final missingInfo = <String>[];

    if (_currentGender == null) {
      missingInfo.add("gender (Man/Woman/Unisex)");
    }
    if (_currentCategory == null) {
      missingInfo.add("category (T-Shirt/Hoodie/Pant)");
    }

    // If missing essential info, ask for it
    if (missingInfo.isNotEmpty) {
      final message = "To help you better, I need to know your ${missingInfo.join(' and ')} preference. What are you looking for?";
      _addBotMessage(message);
      return;
    }

    // Apply any active filters
    _applyActiveFilters();

    // Search for products
    final results = await _searchProductsInFirestore();

    if (results.isEmpty) {
      // Try with relaxed criteria
      final relaxedResults = await _searchWithRelaxedCriteria();

      if (relaxedResults.isEmpty) {
        _addBotMessage("I couldn't find any products matching your criteria. Would you like to try a different search?");
      } else {
        _addBotMessage(
          "I found some similar products that might interest you:",
          products: relaxedResults,
        );
      }
    } else {
      _addBotMessage(
        "Here are some ${_currentGender} ${_currentCategory} options for you:",
        products: results,
      );

      // Ask about additional preferences if not specified
      if (_currentColor == null || _currentSize == null || _currentBudget == null) {
        _addBotMessage("Would you like to specify color, size, or budget to refine your search?");
      }
    }
  }

  Future<List<ClothingProductModel>> _searchProductsInFirestore() async {
    try {
      if (_currentGender == null || _currentCategory == null) {
        return [];
      }

      // Query Firestore directly
      final collection = _firestore.collection('Cloths').doc(_currentGender).collection(_currentCategory!);
      Query query = collection;

      // Apply filters
      if (filterMaxPrice != null) {
        query = query.where('price', isLessThanOrEqualTo: filterMaxPrice);
      }

      final snapshot = await query.get();

      List<ClothingProductModel> products = snapshot.docs.map((doc) {
        final product = ClothingProductModel.fromSnapshot(doc);
        product.gender = _currentGender!;
        product.category = _currentCategory!;
        return product;
      }).toList();

      // Apply additional filters in memory
      return products.where((product) {
        // Filter by color if specified
        if (_currentColor != null) {
          final hasColor = product.variants.any((variant) =>
              variant.colors.any((color) =>
              color.colorSpace?.toString().contains(_currentColor!.toLowerCase()) ?? false
              )
          );
          if (!hasColor) return false;
        }

        // Filter by size if specified
        if (_currentSize != null) {
          final hasSize = product.variants.any((variant) =>
              variant.sizes.any((size) =>
              size.size.toUpperCase() == _currentSize!.toUpperCase()
              )
          );
          if (!hasSize) return false;
        }

        // Filter by style if specified
        if (_currentStyle != null) {
          if (!product.tags.any((tag) => tag.toLowerCase().contains(_currentStyle!.toLowerCase()))) {
            return false;
          }
        }

        return true;
      }).toList();
    } catch (e) {
      print("Error searching Firestore: $e");
      return [];
    }
  }

  Future<List<ClothingProductModel>> _searchWithRelaxedCriteria() async {
    try {
      if (_currentGender == null || _currentCategory == null) {
        return [];
      }

      final collection = _firestore.collection('Cloths').doc(_currentGender).collection(_currentCategory!);
      final snapshot = await collection.limit(5).get();

      return snapshot.docs.map((doc) {
        final product = ClothingProductModel.fromSnapshot(doc);
        product.gender = _currentGender!;
        product.category = _currentCategory!;
        return product;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _generateTextResponse(String query) async {
    try {
      final response = await _getAIResponse(query);
      _addBotMessage(response);
    } catch (e) {
      _addBotMessage("I'm having trouble generating a response. Please try again.");
    }
  }

  Future<String> _getAIResponse(String userMessage) async {
    final messages = [
      {
        "role": "system",
        "content": _buildSystemPrompt()
      },
      {
        "role": "user",
        "content": userMessage
      }
    ];

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: json.encode({
          "model": "deepseek-chat",
          "messages": messages,
          "temperature": 0.7,
          "max_tokens": 500,
          "stream": false
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return responseBody['choices'][0]['message']['content'];
      } else {
        return "I apologize, but I'm having trouble connecting right now. Please try again in a moment.";
      }
    } catch (e) {
      return "I'm experiencing some technical difficulties. Please try again or contact support for immediate assistance.";
    }
  }

  String _buildSystemPrompt() {
    return """
You are Vision Cart Assistant, a 24/7 fashion assistant for a Pakistani clothing store. You help customers with:
1. Product inquiries (T-Shirts, Hoodies, Pants for Men and Women)
2. Store policies
3. Order issues
4. Fashion advice

Current Context:
${_currentGender != null ? "• Gender: $_currentGender" : ""}
${_currentCategory != null ? "• Category: $_currentCategory" : ""}
${_currentColor != null ? "• Color: $_currentColor" : ""}
${_currentSize != null ? "• Size: $_currentSize" : ""}
${_currentBudget != null ? "• Budget: Rs. ${_currentBudget!.toStringAsFixed(0)}" : ""}

Guidelines:
- Be friendly, helpful, and professional
- Understand and respond in English, Urdu, and Roman Urdu
- If user asks for products but hasn't specified gender/category, ask for it ONCE
- Maintain context throughout conversation
- If showing products, keep messages concise
- For product queries, focus on available items in our store
- Use "Rs." for Pakistani Rupees
- Keep responses under 3-4 lines unless detailed explanation needed
- Empathize with customer concerns
- Use appropriate emojis occasionally

Store Information:
- Returns: 7-day return policy
- Shipping: 3-5 business days across Pakistan
- Contact: support@visioncart.pk
- Payment: Cash on Delivery, Credit/Debit Cards
""";
  }

  bool _isProductQuery(String message) {
    final productKeywords = [
      't-shirt', 'tshirt', 'hoodie', 'pant', 'jeans', 'clothes',
      'kapray', 'kapra', 'dress', 'shirt', 'kamiz', 'shalwar',
      'product', 'item', 'buy', 'purchase', 'shop', 'shopping',
      'show me', 'find', 'search', 'looking for', 'need', 'want',
      'price', 'daam', 'cost', 'color', 'colour', 'rang', 'size',
      'fit', 'measurement', 'material', 'cotton', 'wool', 'silk'
    ];

    final lowerMessage = message.toLowerCase();
    return productKeywords.any((keyword) => lowerMessage.contains(keyword));
  }

  bool _isStorePolicyQuery(String message) {
    final policyKeywords = [
      'policy', 'return', 'exchange', 'refund', 'shipping',
      'delivery', 'payment', 'cash', 'card', 'warranty',
      'guarantee', 'quality', 'authentic', 'original'
    ];

    final lowerMessage = message.toLowerCase();
    return policyKeywords.any((keyword) => lowerMessage.contains(keyword));
  }

  bool _isOrderQuery(String message) {
    final orderKeywords = [
      'order', 'track', 'status', 'cancel', 'update',
      'delay', 'missing', 'received', 'delivered',
      'tracking', 'order number', 'confirmation'
    ];

    final lowerMessage = message.toLowerCase();
    return orderKeywords.any((keyword) => lowerMessage.contains(keyword));
  }

  Future<void> _handleStorePolicyQuery(String query) async {
    final response = await _getAIResponse("Store policy question: $query");
    _addBotMessage(response);
  }

  Future<void> _handleOrderQuery(String query) async {
    final response = await _getAIResponse("Order related question: $query");
    _addBotMessage(response);
  }

  void _applyActiveFilters() {
    if (filterGender != null) {
      _currentGender = filterGender;
    }
    if (filterCategory != null) {
      _currentCategory = filterCategory;
    }
    if (filterMaxPrice != null) {
      _currentBudget = filterMaxPrice;
    }
    if (filterColorName != null) {
      _currentColor = filterColorName!.toLowerCase();
    }
    if (filterSize != null) {
      _currentSize = filterSize;
    }

    clearFilters();
  }

  // Message Management
  void _addSystemMessage() {
    _messages.add({
      'text': "👋 Welcome to Vision Cart! I'm your personal shopping assistant. How can I help you today?\n\nYou can ask me about:\n• T-Shirts, Hoodies, and Pants\n• Store policies and shipping\n• Order status and tracking\n• Fashion advice and recommendations",
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

  void _addBotMessage(String text, {List<ClothingProductModel>? products}) {
    _messages.add({
      'text': text,
      'isUser': false,
      'timestamp': DateTime.now(),
      'type': products != null ? 'products' : 'text',
      'products': products,
    });

    if (products != null) {
      _saveMessageToRTDB(text, false, type: 'products', products: products);
    } else {
      _saveMessageToRTDB(text, false);
    }

    notifyListeners();
  }

  // Firestore & RTDB Operations
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
    } catch (e) {
      print('[RTDB] Error: $e');
      return false;
    }
  }

  Future<void> _loadPreviousConversation() async {
    if (_conversationId == null) return;

    try {
      final messagesRef = _rtdb.ref('conversations/$_conversationId/messages');
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

        // Limit to last 20 messages
        if (_messages.length > 20) {
          _messages = _messages.sublist(_messages.length - 20);
        }
      }
    } catch (e) {
      print("Error loading conversation: $e");
    }
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
      print("Error updating Firestore: $e");
    }
  }

  void cancelRequest() {
    if (_requestCompleter != null && !_requestCompleter!.isCompleted) {
      _requestCompleter!.complete();
      _isLoading = false;
      notifyListeners();
      _addBotMessage("Request cancelled. How else can I assist you?");
    }
  }

  void _loadSearchHistory() async {
    // Load from local storage or defaults
    _searchHistory = [
      "Men's T-Shirts",
      "Women's Hoodies",
      "Blue Jeans",
      "Winter Collection"
    ];
    notifyListeners();
  }

  void _saveSearchHistory() async {
    // Save to local storage
  }

  // Filter Methods
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
    if (filterGender != null) filters.add(filterGender!);
    if (filterCategory != null) filters.add(filterCategory!);
    if (filterColorName != null) filters.add(filterColorName!);
    if (filterSize != null) filters.add("Size ${filterSize!}");
    if (filterMaxPrice != null)
      filters.add("Under Rs.${filterMaxPrice!.toStringAsFixed(0)}");

    if (filters.isNotEmpty) {
      final text = "Show me ${filters.join(' ')}";
      sendMessage(text);
    }
  }
}