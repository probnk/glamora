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

// ─── Enums ────────────────────────────────────────────────────────────────────

enum UserSentiment { neutral, frustrated, happy, confused, angry }

enum EscalationState { none, suggested, escalated }

// ─── Provider ─────────────────────────────────────────────────────────────────

class AIChatBotProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final rtdb.FirebaseDatabase _rtdb = rtdb.FirebaseDatabase.instance;

  static const String _apiUrl = "https://api.deepseek.com/chat/completions";
  final String? _apiKey = dotenv.env['DEEPSEEK_API_KEY'];

  // ── Chat State ──────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _messages = [];

  /// Full turn-by-turn history sent to DeepSeek on every call.
  /// Solves "contextual rigidity" [7] — maintains context beyond 3 turns.
  final List<Map<String, String>> _conversationHistory = [];

  String? _conversationId;
  bool _isLoading = false;
  bool _isCancelled = false;

  // ── Products (in-memory catalogue for text-based responses) ─────────────────
  List<ClothingProductModel> _allProducts = [];

  // ── Search History ──────────────────────────────────────────────────────────
  List<String> _searchHistory = [];
  final List<String> _popularSearches = [
    "T-Shirt",
    "Hoodie",
    "Pant",
    "Cotton Dress",
    "Winter Collection",
  ];

  // ── Advanced Filters (set via UI) ───────────────────────────────────────────
  String? filterGender;
  String? filterCategory;
  String? filterColorName;
  String? filterSize;
  double? filterMaxPrice;

  // ── Sentiment / Escalation ──────────────────────────────────────────────────
  // Sentiment detected INSIDE the single DeepSeek call — no second API call.
  // Solves the "Emotional Intelligence Gap" [4] without latency penalty.
  UserSentiment _currentSentiment = UserSentiment.neutral;
  EscalationState _escalationState = EscalationState.none;

  /// Consecutive frustrated/angry turns before escalation is offered.
  /// Threshold = 3 to avoid premature escalation (23% frustration increase [4]).
  int _frustratedTurnCount = 0;
  static const int _escalationThreshold = 3;

  // ── Getters ─────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> get messages => _messages;
  bool get isLoading => _isLoading;
  List<String> get searchHistory => _searchHistory;
  List<String> get popularSearches => _popularSearches;
  String? get getFilterGender => filterGender;
  String? get getFilterCategory => filterCategory;
  String? get getFilterColorName => filterColorName;
  String? get getFilterSize => filterSize;
  double? get getFilterMaxPrice => filterMaxPrice;
  UserSentiment get currentSentiment => _currentSentiment;
  EscalationState get escalationState => _escalationState;

  /// True when the last bot message should show the "Chat with Seller" button.
  bool get showEscalationButton =>
      _escalationState == EscalationState.suggested;

  // ══════════════════════════════════════════════════════════════════════════════
  // INIT
  // ══════════════════════════════════════════════════════════════════════════════

  Future<void> initConversation() async {
    _conversationId = FirebaseAuth.instance.currentUser?.uid ??
        'anon_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';

    await _loadAllProducts();
    await _loadPreviousConversation();

    if (_messages.isEmpty) {
      _addWelcomeMessage();
    }

    _loadSearchHistory();
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // LOAD PRODUCTS FROM FIRESTORE
  // ══════════════════════════════════════════════════════════════════════════════

  Future<void> _loadAllProducts() async {
    try {
      _isLoading = true;
      notifyListeners();
      _allProducts.clear();

      const genders = ['Man', 'Woman'];
      const categories = ['T-Shirt', 'Hoodie', 'Pant'];

      for (final gender in genders) {
        for (final category in categories) {
          try {
            final snap = await _firestore
                .collection('Cloths')
                .doc(gender)
                .collection(category)
                .get();
            for (final doc in snap.docs) {
              final p = ClothingProductModel.fromSnapshot(doc);
              p.gender = gender;
              p.category = category;
              _allProducts.add(p);
            }
          } catch (e) {
            debugPrint("Error loading $gender $category: $e");
          }
        }
      }
      debugPrint("Loaded ${_allProducts.length} products");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // SEND MESSAGE — single entry point, ONE DeepSeek call total
  // ══════════════════════════════════════════════════════════════════════════════

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;

    _isCancelled = false;
    _addUserMessage(text);
    _saveMessageToRTDB(text, true); // fire-and-forget

    _isLoading = true;
    notifyListeners();

    try {
      // ONE DeepSeek call: intent + reply + filters + sentiment + product_summary
      final aiDecision = await _getStructuredAIDecision(text);

      if (_isCancelled) return;

      final intent = aiDecision['intent'] as String? ?? 'general';
      final reply = aiDecision['reply'] as String? ?? '';
      final sentimentStr = aiDecision['sentiment'] as String? ?? 'neutral';

      // Update sentiment — no extra API call needed
      _updateSentiment(sentimentStr);

      // Check escalation AFTER updating sentiment
      if (_shouldEscalate()) {
        _handleEscalation();
        return;
      }

      if (intent == 'product_search') {
        // Build a text-only product summary using local data + AI reply
        final filters =
        Map<String, dynamic>.from(aiDecision['filters'] as Map? ?? {});
        final products = await _searchProducts(filters);

        if (products.isNotEmpty) {
          // Compose a rich text response describing found products
          final textSummary = _buildProductTextSummary(reply, products);
          _addBotMessage(textSummary);
        } else {
          final relaxed = await _relaxedSearch(filters);
          if (relaxed.isNotEmpty) {
            final textSummary = _buildProductTextSummary(
              "Exact match nahi mila, lekin yeh similar options hain:",
              relaxed,
            );
            _addBotMessage(textSummary);
          } else {
            _addBotMessage(
              "Is criteria ky liye products available nahi hain. "
                  "Color, size, ya budget thora adjust kar ky dobara try karein. 🙏",
            );
          }
        }
      } else {
        _addBotMessage(reply);
      }

      _updateSearchHistory(text);
    } catch (e) {
      debugPrint("sendMessage error: $e");
      _addBotMessage(
          "Abhi thori takleef ho rahi hai. Dobara try karein please. 🙏");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // PRODUCT TEXT SUMMARY — no cards, just rich markdown text
  // ══════════════════════════════════════════════════════════════════════════════

  String _buildProductTextSummary(
      String intro, List<ClothingProductModel> products) {
    final buffer = StringBuffer();
    buffer.writeln(intro);
    buffer.writeln();

    final limited = products.take(5).toList();
    for (int i = 0; i < limited.length; i++) {
      final p = limited[i];
      buffer.writeln("**${i + 1}. ${p.title}**");
      buffer.writeln("💰 Price: Rs. ${p.price.toStringAsFixed(0)}");
      if (p.category != null) buffer.writeln("🏷️ Category: ${p.category}");
      if (p.gender != null) buffer.writeln("👤 For: ${p.gender}");

      // List available colors
      final colors = p.variants
          .expand((v) => v.colors)
          .map((c) => c.colorSpace?.toString() ?? '')
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList();
      if (colors.isNotEmpty) {
        buffer.writeln("🎨 Colors: ${colors.join(', ')}");
      }

      // List available sizes
      final sizes = p.variants
          .expand((v) => v.sizes)
          .map((s) => s.size.toUpperCase())
          .toSet()
          .toList();
      if (sizes.isNotEmpty) {
        buffer.writeln("📏 Sizes: ${sizes.join(', ')}");
      }

      if (i < limited.length - 1) buffer.writeln();
    }

    if (products.length > 5) {
      buffer.writeln();
      buffer.writeln(
          "_...aur ${products.length - 5} products available hain. Filters use karein to narrow down._");
    }

    return buffer.toString().trim();
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // CORE DeepSeek CALL — single call, JSON includes sentiment field
  //
  // Literature review alignment:
  //   [7] Contextual rigidity → _conversationHistory (20 turns) injected every call
  //   [4] Emotional intelligence gap → "sentiment" field returned in same JSON,
  //       zero extra latency, NLP-based not keyword-based
  // ══════════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> _getStructuredAIDecision(
      String userMessage) async {
    final catalogueSummary = _buildCatalogueSummary();
    final filterContext = _buildFilterContext();

    final systemPrompt = """
You are Vision Cart Assistant — a smart, empathetic 24/7 fashion assistant for Vision Cart, a Pakistani clothing e-commerce store.

STORE INVENTORY (live data):
$catalogueSummary

ACTIVE USER FILTERS:
$filterContext

YOUR CAPABILITIES:
- Answer questions about our clothing: T-Shirts, Hoodies, Pants for Men and Women
- Handle store policy: returns 7 days, shipping 3-5 days, payment COD/Card
- Handle order and tracking queries
- Give fashion advice relevant to our inventory
- Respond in English, Urdu, or Roman Urdu — match the user's language naturally
- Politely refuse questions unrelated to Vision Cart or clothing/fashion

SENTIMENT DETECTION — classify based on the CURRENT message in context:
- neutral: normal question, no emotion
- happy: grateful, satisfied, positive, thankful
- confused: uncertain, asking for clarification, unclear request
- frustrated: impatient, repeating question, mild complaint, "kaam nahi kar raha", "kyun nahi mila"
- angry: rude language, ALL CAPS frustration, insults, explicit anger, strong complaints

ACCURACY TARGET: Resolve 95% of routine queries (orders, returns, product info, fashion advice) accurately. For anything outside Vision Cart scope, redirect politely — do NOT answer.

RULES:
1. Respond ONLY with a valid JSON object. No markdown, no preamble, no extra text.
2. For off_topic queries, set intent to "off_topic" and redirect politely.
3. For product_search, extract ONLY what the user actually mentioned — do NOT invent missing values (leave null).
4. The full conversation history is provided — remember context from earlier turns (do NOT repeat questions already answered).
5. Use "Rs." for prices. Reply 2-4 sentences unless detail is needed.
6. Be warm and empathetic. Use emojis occasionally. Support Roman Urdu naturally.

RESPONSE FORMAT (strict JSON, no exceptions):
{
  "intent": "product_search" | "store_policy" | "order" | "general" | "off_topic",
  "sentiment": "neutral" | "happy" | "confused" | "frustrated" | "angry",
  "reply": "Conversational message shown to the user",
  "filters": {
    "gender": "Man" | "Woman" | "Unisex" | null,
    "category": "T-Shirt" | "Hoodie" | "Pant" | null,
    "color": "red" | "blue" | "green" | "black" | "white" | "gray" | "pink" | "purple" | "yellow" | "orange" | "brown" | null,
    "size": "XS" | "S" | "M" | "L" | "XL" | "XXL" | null,
    "maxPrice": number | null
  }
}

"filters" is ONLY populated when intent is "product_search". All other intents: return "filters": {}.
""";

    _conversationHistory.add({"role": "user", "content": userMessage});

    final messages = [
      {"role": "system", "content": systemPrompt},
      ..._conversationHistory,
    ];

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          "model": "deepseek-chat",
          "messages": messages,
          "temperature": 0.4,
          "max_tokens": 600,
          "stream": false,
          "response_format": {"type": "json_object"},
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final content = body['choices'][0]['message']['content'] as String;

        _conversationHistory.add({"role": "assistant", "content": content});

        // Keep history bounded — last 20 turns = 40 entries
        if (_conversationHistory.length > 40) {
          _conversationHistory.removeRange(0, 2);
        }

        return jsonDecode(content) as Map<String, dynamic>;
      } else {
        debugPrint("DeepSeek error ${response.statusCode}: ${response.body}");
        return _fallbackResponse();
      }
    } catch (e) {
      debugPrint("AI call error: $e");
      return _fallbackResponse();
    }
  }

  Map<String, dynamic> _fallbackResponse() => {
    "intent": "general",
    "sentiment": "neutral",
    "reply":
    "Connection mein thori masla aa rahi hai. Thori dair baad try karein. 🙏",
    "filters": {},
  };

  // ══════════════════════════════════════════════════════════════════════════════
  // SENTIMENT STATE UPDATE — synchronous, no extra API call
  // ══════════════════════════════════════════════════════════════════════════════

  void _updateSentiment(String sentimentStr) {
    _currentSentiment = _parseSentiment(sentimentStr);

    switch (_currentSentiment) {
      case UserSentiment.frustrated:
      case UserSentiment.angry:
        _frustratedTurnCount++;
        break;
      case UserSentiment.happy:
        _frustratedTurnCount = 0; // positive signal resets counter
        break;
      default:
        break; // neutral/confused: no change
    }

    notifyListeners();
  }

  UserSentiment _parseSentiment(String s) {
    switch (s.toLowerCase()) {
      case 'happy':
        return UserSentiment.happy;
      case 'confused':
        return UserSentiment.confused;
      case 'frustrated':
        return UserSentiment.frustrated;
      case 'angry':
        return UserSentiment.angry;
      default:
        return UserSentiment.neutral;
    }
  }

  bool _shouldEscalate() =>
      _frustratedTurnCount >= _escalationThreshold &&
          _escalationState == EscalationState.none;

  /// Escalation: gentle check-in first, then UI shows the "Chat with Seller"
  /// button. Does NOT hard-redirect — user can still keep chatting.
  void _handleEscalation() {
    _escalationState = EscalationState.suggested;
    _addBotMessage(
      "Lagta hai aapko thori mushkil ho rahi hai — main samajh sakta hoon. 😔\n\n"
          "Kya main aapki puri baat samajh paya? Agar aap chahein toh "
          "hum aapko seller se directly connect kar saktay hain jo personally help kar sakein.",
    );
    _isLoading = false;
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // PRODUCT SEARCH — Firestore + in-memory filter
  // ══════════════════════════════════════════════════════════════════════════════

  Future<List<ClothingProductModel>> _searchProducts(
      Map<String, dynamic> filters) async {
    try {
      final gender = _resolveGender(filters['gender'] as String?);
      final category = filters['category'] as String?;
      final color = (filters['color'] as String?)?.toLowerCase();
      final size = filters['size'] as String?;
      final maxPriceRaw = filters['maxPrice'];
      final maxPrice =
      maxPriceRaw != null ? (maxPriceRaw as num).toDouble() : null;

      final effectiveGender = filterGender ?? gender;
      final effectiveCategory = filterCategory ?? category;
      final effectiveColor = filterColorName?.toLowerCase() ?? color;
      final effectiveSize = filterSize ?? size;
      final effectiveMaxPrice = filterMaxPrice ?? maxPrice;

      List<ClothingProductModel> products;

      if (effectiveGender != null && effectiveCategory != null) {
        Query query = _firestore
            .collection('Cloths')
            .doc(effectiveGender)
            .collection(effectiveCategory);

        if (effectiveMaxPrice != null) {
          query =
              query.where('price', isLessThanOrEqualTo: effectiveMaxPrice);
        }

        final snap = await query.get();
        products = snap.docs.map((doc) {
          final p = ClothingProductModel.fromSnapshot(doc);
          p.gender = effectiveGender;
          p.category = effectiveCategory;
          return p;
        }).toList();
      } else {
        products = List.from(_allProducts);
      }

      return _applyMemoryFilters(
        products,
        gender: effectiveGender,
        category: effectiveCategory,
        color: effectiveColor,
        size: effectiveSize,
        maxPrice: effectiveMaxPrice,
      );
    } catch (e) {
      debugPrint("Product search error: $e");
      return [];
    }
  }

  List<ClothingProductModel> _applyMemoryFilters(
      List<ClothingProductModel> products, {
        String? gender,
        String? category,
        String? color,
        String? size,
        double? maxPrice,
      }) {
    return products.where((p) {
      if (gender != null && p.gender != gender) return false;
      if (category != null && p.category != category) return false;
      if (maxPrice != null && p.price > maxPrice) return false;
      if (color != null) {
        final hasColor = p.variants.any((v) => v.colors.any((c) =>
        c.colorSpace?.toString().toLowerCase().contains(color) ?? false));
        if (!hasColor) return false;
      }
      if (size != null) {
        final hasSize = p.variants.any((v) =>
            v.sizes.any((s) => s.size.toUpperCase() == size.toUpperCase()));
        if (!hasSize) return false;
      }
      return true;
    }).toList();
  }

  Future<List<ClothingProductModel>> _relaxedSearch(
      Map<String, dynamic> filters) async {
    try {
      final gender =
          _resolveGender(filters['gender'] as String?) ?? filterGender;
      final category = (filters['category'] as String?) ?? filterCategory;
      if (gender == null || category == null) return [];

      final snap = await _firestore
          .collection('Cloths')
          .doc(gender)
          .collection(category)
          .limit(6)
          .get();

      return snap.docs.map((doc) {
        final p = ClothingProductModel.fromSnapshot(doc);
        p.gender = gender;
        p.category = category;
        return p;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  String? _resolveGender(String? raw) {
    if (raw == 'Man' || raw == 'Woman' || raw == 'Unisex') return raw;
    return null;
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // CONTEXT BUILDERS
  // ══════════════════════════════════════════════════════════════════════════════

  String _buildCatalogueSummary() {
    final buffer = StringBuffer();
    const genders = ['Man', 'Woman'];
    const categories = ['T-Shirt', 'Hoodie', 'Pant'];

    for (final g in genders) {
      for (final c in categories) {
        final count =
            _allProducts.where((p) => p.gender == g && p.category == c).length;
        if (count > 0) buffer.writeln("• $g $c: $count products");
      }
    }

    if (_allProducts.isNotEmpty) {
      final prices = _allProducts.map((p) => p.price).toList()..sort();
      buffer.writeln(
          "• Price range: Rs. ${prices.first.toStringAsFixed(0)} – Rs. ${prices.last.toStringAsFixed(0)}");
    }

    return buffer.isEmpty ? "Loading inventory..." : buffer.toString();
  }

  String _buildFilterContext() {
    final parts = <String>[];
    if (filterGender != null) parts.add("Gender: $filterGender");
    if (filterCategory != null) parts.add("Category: $filterCategory");
    if (filterColorName != null) parts.add("Color: $filterColorName");
    if (filterSize != null) parts.add("Size: $filterSize");
    if (filterMaxPrice != null) {
      parts.add("Max Price: Rs. ${filterMaxPrice!.toStringAsFixed(0)}");
    }
    return parts.isEmpty ? "None" : parts.join(", ");
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // MESSAGE HELPERS
  // ══════════════════════════════════════════════════════════════════════════════

  void _addWelcomeMessage() {
    _messages.add({
      'text': "👋 Assalam-o-Alaikum! **Vision Cart** mein aapka khair maqdam!\n\n"
          "Main aapka 24/7 AI shopping assistant hoon. Yeh poochh saktay hain:\n"
          "• 👕 Men & Women ke liye T-Shirts, Hoodies, aur Pants\n"
          "• 📦 Orders, shipping aur return policy\n"
          "• 💡 Fashion advice aur personalized recommendations\n\n"
          "Aaj main aapki kya madad kar sakta hoon?",
      'isUser': false,
      'timestamp': DateTime.now(),
      'type': 'text',
    });
    notifyListeners();
  }

  void _addUserMessage(String text) {
    _messages.add({
      'text': text,
      'isUser': true,
      'timestamp': DateTime.now(),
      'type': 'text',
    });
    notifyListeners();
  }

  void _addBotMessage(String text) {
    _messages.add({
      'text': text,
      'isUser': false,
      'timestamp': DateTime.now(),
      'type': 'text',
    });
    _saveMessageToRTDB(text, false); // fire-and-forget
    notifyListeners();
  }

  void _updateSearchHistory(String text) {
    if (!_searchHistory.any((h) => h.toLowerCase() == text.toLowerCase())) {
      _searchHistory.insert(0, text);
      if (_searchHistory.length > 10) _searchHistory.removeLast();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // FIREBASE PERSISTENCE
  // ══════════════════════════════════════════════════════════════════════════════

  Future<void> _saveMessageToRTDB(String text, bool isUser) async {
    if (_conversationId == null) return;
    try {
      final ref =
      _rtdb.ref('conversations/$_conversationId/messages').push();
      await ref.set({
        'text': text,
        'isUser': isUser,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'type': 'text',
      });
      _updateFirestoreConversation(); // fire-and-forget
    } catch (e) {
      debugPrint('[RTDB] save error: $e');
    }
  }

  Future<void> _loadPreviousConversation() async {
    if (_conversationId == null) return;
    try {
      final snap =
      await _rtdb.ref('conversations/$_conversationId/messages').get();
      if (!snap.exists) return;

      _messages.clear();
      _conversationHistory.clear();

      final map = Map<String, dynamic>.from(snap.value as Map);
      final sorted = map.entries.toList()
        ..sort((a, b) => ((a.value['timestamp'] ?? 0) as int)
            .compareTo((b.value['timestamp'] ?? 0) as int));

      for (final entry in sorted) {
        final msg = Map<String, dynamic>.from(entry.value as Map);
        final isUser = msg['isUser'] as bool? ?? false;
        final text = msg['text'] as String? ?? '';
        final timestamp =
        DateTime.fromMillisecondsSinceEpoch(msg['timestamp'] as int? ?? 0);

        _messages.add({
          'text': text,
          'isUser': isUser,
          'timestamp': timestamp,
          'type': 'text',
        });

        _conversationHistory.add({
          'role': isUser ? 'user' : 'assistant',
          'content': text,
        });
      }

      if (_messages.length > 20) {
        _messages = _messages.sublist(_messages.length - 20);
      }
      if (_conversationHistory.length > 40) {
        _conversationHistory
            .removeRange(0, _conversationHistory.length - 40);
      }
    } catch (e) {
      debugPrint("Error loading conversation: $e");
    }
  }

  Future<void> _updateFirestoreConversation() async {
    if (_conversationId == null) return;
    try {
      await _firestore.collection('conversations').doc(_conversationId).set({
        'lastUpdated': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'sentimentState': _currentSentiment.name,
        'escalationState': _escalationState.name,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Firestore update error: $e");
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // CANCEL
  // ══════════════════════════════════════════════════════════════════════════════

  void cancelRequest() {
    _isCancelled = true;
    _isLoading = false;
    notifyListeners();
    _addBotMessage("Request cancel ho gayi. Aur kuch madad kar sakta hoon? 😊");
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // FILTER METHODS
  // ══════════════════════════════════════════════════════════════════════════════

  void setFilterGender(String? v) { filterGender = v; notifyListeners(); }
  void setFilterCategory(String? v) { filterCategory = v; notifyListeners(); }
  void setFilterColorName(String? v) { filterColorName = v; notifyListeners(); }
  void setFilterSize(String? v) { filterSize = v; notifyListeners(); }
  void setFilterMaxPrice(double? v) { filterMaxPrice = v; notifyListeners(); }

  void clearFilters() {
    filterGender = null;
    filterCategory = null;
    filterColorName = null;
    filterSize = null;
    filterMaxPrice = null;
    notifyListeners();
  }

  void applyFilters() {
    final parts = <String>[];
    if (filterGender != null) parts.add(filterGender!);
    if (filterCategory != null) parts.add(filterCategory!);
    if (filterColorName != null) parts.add(filterColorName!);
    if (filterSize != null) parts.add("size ${filterSize!}");
    if (filterMaxPrice != null) {
      parts.add("under Rs.${filterMaxPrice!.toStringAsFixed(0)}");
    }
    if (parts.isNotEmpty) {
      sendMessage("Show me ${parts.join(' ')}");
    }
  }

  void _loadSearchHistory() {
    _searchHistory = [
      "Men's T-Shirts",
      "Women's Hoodies",
      "Blue Jeans",
      "Winter Collection",
    ];
  }
}